terraform {
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

provider "kubectl" {
  host                   = var.deploy_eks_cluster_endpoint
  cluster_ca_certificate = var.deploy_eks_cluster_certificate_authority_data
  token                  = var.deploy_eks_cluster_auth_token
  load_config_file       = false
}

locals {
  admin_username = "KeycloakAdmin"
  sha1_hash = sha1(join("", [for f in fileset("", "${path.module}/docker/*") : filesha1(f)]))
  prefer_ipv4_stack = "-Djava.net.preferIPv4Stack=${lower(var.cluster_ip_family) == "ipv4" ? "true" : "false"}"
  prefer_ipv6_stack = "-Djava.net.preferIPv6Addresses=${lower(var.cluster_ip_family) == "ipv6" ? "true" : "false"}"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_ecr_repository" "selected" {
  name = var.repository_name
}

resource "time_static" "tag" {
  triggers = {
    run = local.sha1_hash
  }
}

module "eks_fargate-profile" {
  source  = "terraform-aws-modules/eks/aws//modules/fargate-profile"
  version = "~> 20.0"

  name         = "keycloak-fargate"
  cluster_name = var.deploy_cluster_name
  subnet_ids   = var.deploy_subnet_ids

  selectors = [{
    namespace = "keycloak"
  }]
}

data "aws_iam_policy" "logging_policy" {
  name = var.deploy_logging_policy_name
}

resource "aws_iam_role_policy_attachment" "logging_policy_attach" {
  role       = module.eks_fargate-profile.iam_role_name
  policy_arn = data.aws_iam_policy.logging_policy.arn
}

resource "null_resource" "keycloak_build" {
	
  provisioner "local-exec" {
    command = <<-EOF
      aws ecr get-login-password --region ${data.aws_region.current.name} --profile ${var.aws_profile} | docker login --username AWS --password-stdin \
        ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com
      docker build -t "${data.aws_ecr_repository.selected.repository_url}:keycloak-v${time_static.tag.unix}" "${path.module}/docker"
      docker push "${data.aws_ecr_repository.selected.repository_url}:keycloak-v${time_static.tag.unix}"
    EOF
  }

  triggers = {
    run = local.sha1_hash
  }
}

resource "time_static" "suffix" {
  triggers = {
    run = "14/10/2023 14:13:00"
  }
}

resource "random_string" "password" {
  length   = 32
  upper    = true
  numeric  = true
  special  = false
}

resource "aws_secretsmanager_secret" "keycloak_credentials" {
   name                    = "/platform/keycloak/app/credentials/${time_static.suffix.unix}"
   recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "keycloak_credentials_version" {
  secret_id = aws_secretsmanager_secret.keycloak_credentials.id
  secret_string = <<EOF
   {
    "username": "${local.admin_username}",
    "password": "${random_string.password.result}"
   }
EOF
}

resource "kubectl_manifest" "keycloak_namespace" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: Namespace
    metadata:
      name: keycloak
  YAML
}

#
# https://www.keycloak.org/server/all-config
# https://github.com/bitnami/containers/blob/main/bitnami/keycloak/22/debian-11/rootfs/opt/bitnami/scripts/keycloak-env.sh
#
resource "kubectl_manifest" "keycloak_config_map" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: keycloak-config
      namespace: keycloak
    data:
      TZ: "America/Sao_Paulo"
      KC_PROXY: "edge"
      KC_HTTP_PORT: "8080"
      KC_HEALTH_ENABLED: "true"
      KC_CACHE: "ispn"
      KC_CACHE_STACK: "kubernetes"
      KC_HOSTNAME_STRICT: "false"
      KC_HOSTNAME: "${var.keycloak_host}"
      KC_HOSTNAME_ADMIN: "${var.keycloak_host}"
      KC_DB: "postgres"
      KC_DB_URL_HOST: "${var.deploy_jdbc_hostname}"
      KC_DB_URL_PORT: "${var.deploy_jdbc_port}"
      KC_DB_URL_DATABASE: "keycloak"
      JAVA_OPTS_APPEND: "-Djgroups.dns.query=keycloak-headless.keycloak.svc.cluster.local -Dquarkus.transaction-manager.enable-recovery=true ${local.prefer_ipv4_stack} ${local.prefer_ipv6_stack} -Dfile.encoding=UTF-8"
  YAML

  depends_on = [
      kubectl_manifest.keycloak_namespace
  ]
}

resource "kubectl_manifest" "keycloak_secret" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: Secret
    metadata:
      name: keycloak-secret
      namespace: keycloak
    type: Opaque
    data:
      KEYCLOAK_ADMIN: "${base64encode(local.admin_username)}"
      KEYCLOAK_ADMIN_PASSWORD: "${base64encode(random_string.password.result)}"
      KC_DB_USERNAME: "${base64encode(var.deploy_jdbc_username)}"
      KC_DB_PASSWORD: "${base64encode(var.deploy_jdbc_password)}"
  YAML

  depends_on = [
      kubectl_manifest.keycloak_namespace
  ]
}

resource "kubectl_manifest" "keycloak_stateful_set" {
    yaml_body = <<YAML
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: keycloak
  namespace: keycloak
  labels:
    app.kubernetes.io/instance: keycloak
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/component: keycloak
spec:
  replicas: 2
  podManagementPolicy: Parallel
  serviceName: keycloak-headless
  updateStrategy:
    rollingUpdate: {}
    type: RollingUpdate
  selector:
    matchLabels:
      app.kubernetes.io/name: keycloak
      app.kubernetes.io/instance: keycloak
      app.kubernetes.io/component: keycloak
  template:
    metadata:
      labels:
        app.kubernetes.io/name: keycloak
        app.kubernetes.io/instance: keycloak
        app.kubernetes.io/component: keycloak
    spec:
      tolerations:
      - key: "eks.amazonaws.com/compute-type"
        operator: "Equal"
        value: "fargate"
        effect: "NoSchedule"
      containers:
        - name: keycloak
          image: ${data.aws_ecr_repository.selected.repository_url}:keycloak-v${time_static.tag.unix}
          imagePullPolicy: IfNotPresent
          command: ["/opt/keycloak/bin/kc.sh"]
          args:
          - start
          - --optimized
          - --spi-sticky-session-encoder-infinispan-should-attach-route=false
          - --spi-x509cert-lookup-nginx-ssl-client-cert=SSL_CLIENT_CERT
          - --spi-x509cert-lookup-nginx-ssl-cert-chain-prefix=CERT_CHAIN
          - --spi-x509cert-lookup-nginx-certificate-chain-length=10
          securityContext:
            runAsNonRoot: true
            runAsUser: 1001
          envFrom:
          - configMapRef:
              name: keycloak-config
          - secretRef:
              name: keycloak-secret
          resources:
            requests:
              cpu: "500m"
              memory: "1000Mi"
            limits:
              cpu: "1000m"
              memory: "1000Mi"
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
            - name: infinispan
              containerPort: 7800
              protocol: TCP
          startupProbe:
            httpGet:
              scheme: HTTP
              path: /health/started
              port: http
            initialDelaySeconds: 90
            periodSeconds: 10
            failureThreshold: 24
            timeoutSeconds: 2
          readinessProbe:
            failureThreshold: 3
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 2
            httpGet:
              scheme: HTTP
              path: /health/ready
              port: http
          livenessProbe:
            failureThreshold: 3
            initialDelaySeconds: 30
            periodSeconds: 1
            successThreshold: 1
            timeoutSeconds: 5
            httpGet:
              scheme: HTTP
              path: /health/live
              port: http
YAML

    depends_on = [
        kubectl_manifest.keycloak_namespace
    ]
}

resource "kubectl_manifest" "keycloak_service" {
    yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  name: keycloak-headless
  namespace: keycloak
  labels:
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/instance: keycloak
    app.kubernetes.io/component: keycloak
spec:
  type: ClusterIP
  clusterIP: None
  ports:
    - name: http
      port: 8080
      protocol: TCP
      targetPort: http
  publishNotReadyAddresses: true
  selector:
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/instance: keycloak
    app.kubernetes.io/component: keycloak
YAML

    depends_on = [
        kubectl_manifest.keycloak_namespace
    ]
}

data "aws_acm_certificate" "eks_certificate" {
  domain      = "sambatech.net"
  key_types   = ["RSA_2048"]
  most_recent = true
}

resource "kubectl_manifest" "keycloak_ingress" {
    yaml_body = <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  namespace: keycloak
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/group.name: "platform-engineering"
    alb.ingress.kubernetes.io/load-balancer-name: ${var.deploy_alb_name}
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/ip-address-type: dualstack
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/success-codes: "200"
    alb.ingress.kubernetes.io/healthcheck-path: "/health"
    alb.ingress.kubernetes.io/healthcheck-port: traffic-port
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "2"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/shield-advanced-protection: "true"
    alb.ingress.kubernetes.io/wafv2-acl-arn: "${var.deploy_waf_arn}"
    alb.ingress.kubernetes.io/certificate-arn: "${data.aws_acm_certificate.eks_certificate.arn}"
    alb.ingress.kubernetes.io/target-group-attributes: "stickiness.enabled=true,stickiness.type=app_cookie,stickiness.app_cookie.cookie_name=AUTH_SESSION_ID"
    alb.ingress.kubernetes.io/load-balancer-attributes: "routing.http.preserve_host_header.enabled=true"
spec:
  ingressClassName: alb
  rules:
  - host: ${var.keycloak_host}
    http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: keycloak-headless
            port: 
              number: 8080
YAML

  depends_on = [
    kubectl_manifest.keycloak_service
  ]
}