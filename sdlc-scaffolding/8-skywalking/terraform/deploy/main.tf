terraform {
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "~> 4.4"
    }
  }
}

provider "kubectl" {
  host                   = var.eks_cluster_endpoint
  cluster_ca_certificate = var.eks_cluster_certificate_authority_data
  token                  = var.eks_cluster_auth_token
  load_config_file       = false
}

locals {
  prefer_ipv4_stack = "-Djava.net.preferIPv4Stack=${lower(var.cluster_ip_family) == "ipv4" ? "true" : "false"}"
  prefer_ipv6_stack = "-Djava.net.preferIPv6Addresses=${lower(var.cluster_ip_family) == "ipv6" ? "true" : "false"}"
}

module "eks_fargate-profile" {
  source  = "terraform-aws-modules/eks/aws//modules/fargate-profile"
  version = "~> 20.0"

  name         = "skywalking-fargate"
  cluster_name = var.eks_cluster_name
  subnet_ids   = var.eks_subnet_ids

  selectors = [{
    namespace = "skywalking"
  }]
}

data "aws_iam_policy" "logging_policy" {
  name = var.eks_logging_policy_name
}

resource "aws_iam_role_policy_attachment" "logging_policy_attach" {
  role       = module.eks_fargate-profile.iam_role_name
  policy_arn = data.aws_iam_policy.logging_policy.arn
}

###########################################################################
# Os recursos abaixo foram criados com o uso do comando:
# helm template local oci://registry-1.docker.io/apache/skywalking-helm \
#     --version 4.5.0 -f ./8-skywalking/terraform/deploy/templates/values.yaml > output.yaml
#
# MOTIVO: Usar o provider "helm" e o resource "helm_release" causavam o erro
#         Error: could not download chart: pull access denied, repository 
#                does not exist or may require authorization: server message: 
#                insufficient_scope: authorization failed
###########################################################################

resource "kubectl_manifest" "skywalking_namespace" {
  yaml_body = <<-YAML
  apiVersion: v1
  kind: Namespace
  metadata:
    name: skywalking
  YAML
}

resource "kubectl_manifest" "skywalking_service_account" {
  yaml_body = <<-YAML
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    namespace: skywalking
    name: skywalking-service-account
    labels:
      app: skywalking
      release: samba
      component: oap
  YAML

  depends_on = [
    kubectl_manifest.skywalking_namespace
  ]
}

resource "kubectl_manifest" "skywalking_cluster_role" {
  yaml_body = <<-YAML
  kind: ClusterRole
  apiVersion: rbac.authorization.k8s.io/v1
  metadata:
    name: skywalking-cluster-role
    labels:
      app: skywalking
      release: samba
  rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "endpoints", "services", "nodes", "namespaces", "configmaps"]
    verbs: ["get", "watch", "list"]
  - apiGroups: ["extensions"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "watch", "list"]
  - apiGroups: ["networking.istio.io"]
    resources: ["serviceentries"]
    verbs: ["get", "watch", "list"]
  YAML

  depends_on = [
    kubectl_manifest.skywalking_namespace
  ]
}

resource "kubectl_manifest" "skywalking_cluster_role_binding" {
  yaml_body = <<-YAML
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRoleBinding
  metadata:
    name: skywalking-cluster-role-binding
    labels:
      app: skywalking
      release: samba
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: skywalking-cluster-role
  subjects:
  - kind: ServiceAccount
    name: skywalking-service-account
    namespace: skywalking
  YAML

  depends_on = [
    kubectl_manifest.skywalking_namespace
  ]
}

resource "kubectl_manifest" "skywalking_role" {
  yaml_body = <<-YAML
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    namespace: skywalking
    name: skywalking-role
    labels:
      app: skywalking
      release: samba
  rules:
    - apiGroups: [""]
      resources: ["pods","configmaps"]
      verbs: ["get", "watch", "list"]
  YAML

  depends_on = [
    kubectl_manifest.skywalking_namespace
  ]
}

resource "kubectl_manifest" "skywalking_role_binding" {
  yaml_body = <<-YAML
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    namespace: skywalking
    name: skywalking-role-binding
    labels:
      app: skywalking
      release: samba
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: skywalking-role
  subjects:
    - kind: ServiceAccount
      name: skywalking-service-account
      namespace: skywalking
  YAML

  depends_on = [
    kubectl_manifest.skywalking_namespace
  ]
}

resource "kubectl_manifest" "skywalking_config_map_oap" {
  yaml_body = <<-YAML
  apiVersion: v1
  kind: ConfigMap
  metadata:
    namespace: skywalking
    name: skywalking-config-oap
  data:
    TZ: "America/Sao_Paulo"
    SW_CLUSTER: "kubernetes"
    SW_CLUSTER_K8S_NAMESPACE: "skywalking"
    SW_CLUSTER_K8S_LABEL: "app=skywalking,release=samba,component=oap"
    SW_STORAGE: "elasticsearch"
    SW_STORAGE_ES_HTTP_PROTOCOL: "https"
    SW_STORAGE_ES_CLUSTER_NODES: "${var.opensearch_hostname}:443"
  YAML

  depends_on = [
    kubectl_manifest.skywalking_namespace
  ]
}

resource "kubectl_manifest" "skywalking_secret_oap" {
  yaml_body = <<-YAML
  apiVersion: v1
  kind: Secret
  metadata:
    namespace: skywalking
    name: skywalking-secret-oap
  type: Opaque
  data:
    SW_ES_USER: "${base64encode(var.opensearch_username)}"
    SW_ES_PASSWORD: "${base64encode(var.opensearch_password)}"
  YAML

  depends_on = [
      kubectl_manifest.skywalking_namespace
  ]
}

resource "kubectl_manifest" "skywalking_oap_init_job" {
  yaml_body = <<-YAML
  apiVersion: batch/v1
  kind: Job
  metadata:
    namespace: skywalking
    name: oap-job-init
    labels:
      app: oap-job-init
      component: job
      release: samba
  spec:
    ttlSecondsAfterFinished: 100
    template:
      metadata:
        name: oap-job-init
        labels:
          app: oap-job-init
          component: job
          release: samba
      spec:
        serviceAccountName: skywalking-service-account
        tolerations:
        - key: "eks.amazonaws.com/compute-type"
          operator: "Equal"
          value: "fargate"
          effect: "NoSchedule"
        restartPolicy: Never
        containers:
        - name: oap-job-init
          image: skywalking.docker.scarf.sh/apache/skywalking-oap-server:9.2.0
          imagePullPolicy: IfNotPresent
          env:
          - name: JAVA_OPTS
            value: "${local.prefer_ipv4_stack} ${local.prefer_ipv6_stack} -Xmx3g -Xms2g -Dmode=init"
          envFrom:
          - configMapRef:
              name: skywalking-config-oap
          - secretRef:
              name: skywalking-secret-oap
          resources:
            requests:
              cpu: "1000m"
              memory: "2000Mi"
            limits:
              cpu: "1000m"
              memory: "4000Mi"
  YAML

  depends_on = [
      kubectl_manifest.skywalking_namespace
  ]
}

resource "kubectl_manifest" "skywalking_oap_deployment" {
  yaml_body = <<-YAML
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    namespace: skywalking
    name: skywalking-oap
    labels:
      app: skywalking
      release: samba
      component: oap
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: skywalking
        release: samba
        component: oap
    template:
      metadata:
        labels:
          app: skywalking
          release: samba
          component: oap
      spec:
        serviceAccountName: skywalking-service-account
        tolerations:
        - key: "eks.amazonaws.com/compute-type"
          operator: "Equal"
          value: "fargate"
          effect: "NoSchedule"
        containers:
        - name: oap
          image: skywalking.docker.scarf.sh/apache/skywalking-oap-server:9.2.0
          imagePullPolicy: IfNotPresent
          ports:
          - containerPort: 11800
            name: grpc
          - containerPort: 12800
            name: rest
          livenessProbe:
            tcpSocket:
              port: 12800
            initialDelaySeconds: 5
            periodSeconds: 10
          startupProbe:
            tcpSocket:
              port: 12800
            failureThreshold: 9
            periodSeconds: 10
          readinessProbe:
            tcpSocket:
              port: 12800
            initialDelaySeconds: 5
            periodSeconds: 10
          env:
          - name: JAVA_OPTS
            value: "${local.prefer_ipv4_stack} ${local.prefer_ipv6_stack} -Dmode=no-init -Xmx2g -Xms2g"
          - name: SKYWALKING_COLLECTOR_UID
            valueFrom:
              fieldRef:
                apiVersion: v1
                fieldPath: metadata.uid
          envFrom:
          - configMapRef:
              name: skywalking-config-oap
          - secretRef:
              name: skywalking-secret-oap
          resources:
            requests:
              cpu: "1000m"
              memory: "2000Mi"
            limits:
              cpu: "2000m"
              memory: "3000Mi"
  YAML

  depends_on = [
      kubectl_manifest.skywalking_namespace,
      kubectl_manifest.skywalking_config_map_oap,
      kubectl_manifest.skywalking_secret_oap,
      kubectl_manifest.skywalking_oap_init_job
  ]
}

resource "kubectl_manifest" "skywalking_oap_service" {
  yaml_body = <<-YAML
  apiVersion: v1
  kind: Service
  metadata:
    namespace: skywalking
    name: skywalking-oap
    labels:
      app: skywalking
      release: samba
      component: oap
  spec:
    type: NodePort
    ports:
    - port: 11800
      name: grpc
    - port: 12800
      name: rest
    selector:
      app: skywalking
      release: samba
      component: oap
  YAML

  depends_on = [
      kubectl_manifest.skywalking_namespace
  ]
}

resource "kubectl_manifest" "skywalking_config_map_ui" {
  yaml_body = <<-YAML
  apiVersion: v1
  kind: ConfigMap
  metadata:
    namespace: skywalking
    name: skywalking-config-ui
  data:
    TZ: "America/Sao_Paulo"
    SW_OAP_ADDRESS: "http://skywalking-oap:12800"
  YAML

  depends_on = [
    kubectl_manifest.skywalking_namespace
  ]
}

resource "kubectl_manifest" "skywalking_ui_deployment" {
  yaml_body = <<-YAML
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    namespace: skywalking
    name: skywalking-ui
    labels:
      app: skywalking
      release: samba
      component: ui
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: skywalking
        release: samba
        component: ui
    template:
      metadata:
        labels:
          app: skywalking
          release: samba
          component: ui
      spec:
        tolerations:
        - key: "eks.amazonaws.com/compute-type"
          operator: "Equal"
          value: "fargate"
          effect: "NoSchedule"
        containers:
        - name: ui
          image: skywalking.docker.scarf.sh/apache/skywalking-ui:9.2.0
          imagePullPolicy: IfNotPresent
          ports:
          - name: page
            containerPort: 8080
            protocol: TCP
          envFrom:
          - configMapRef:
              name: skywalking-config-ui
          resources:
            requests:
              cpu: "500m"
              memory: "1000Mi"
            limits:
              cpu: "1000m"
              memory: "2000Mi"
  YAML

  depends_on = [
      kubectl_manifest.skywalking_namespace,
      kubectl_manifest.skywalking_config_map_ui
  ]
}

resource "kubectl_manifest" "skywalking_ui_service" {
  yaml_body = <<-YAML
  apiVersion: v1
  kind: Service
  metadata:
    namespace: skywalking
    labels:
      app: skywalking
      release: samba
      component: ui
    name: skywalking-ui
  spec:
    type: NodePort
    ports:
      - port: 8080
        targetPort: page
        protocol: TCP
    selector:
      app: skywalking
      release: samba
      component: ui
  YAML

  depends_on = [
      kubectl_manifest.skywalking_namespace
  ]
}

resource "kubectl_manifest" "skywalking_secret_alb" {
  yaml_body = <<-YAML
  apiVersion: v1
  kind: Secret
  metadata:
    namespace: skywalking
    name: skywalking-secret-alb
  type: Opaque
  data:
    clientID: "${base64encode(keycloak_openid_client.client.client_id)}"
    clientSecret: "${base64encode(keycloak_openid_client.client.client_secret)}"
  YAML

  depends_on = [
      kubectl_manifest.skywalking_namespace,
      keycloak_openid_client.client
  ]
}

data "aws_acm_certificate" "eks_certificate" {
  domain      = "sambatech.net"
  key_types   = ["RSA_2048"]
  most_recent = true
}

resource "kubectl_manifest" "skywalking_ingress" {
  yaml_body = <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: skywalking-ingress
  namespace: skywalking
  annotations:
    alb.ingress.kubernetes.io/auth-type: 'oidc'
    alb.ingress.kubernetes.io/auth-idp-oidc: '${jsonencode({
      issuer = "https://${var.keycloak_host}/realms/samba"
      authorizationEndpoint = "https://${var.keycloak_host}/realms/samba/protocol/openid-connect/auth"
      tokenEndpoint = "https://${var.keycloak_host}/realms/samba/protocol/openid-connect/token"
      userInfoEndpoint = "https://${var.keycloak_host}/realms/samba/protocol/openid-connect/userinfo"
      secretName = "skywalking-secret-alb"
    })}'
    alb.ingress.kubernetes.io/auth-on-unauthenticated-request: authenticate
    alb.ingress.kubernetes.io/auth-session-cookie: skywalking-cookie
    alb.ingress.kubernetes.io/auth-session-timeout: '7200'
    alb.ingress.kubernetes.io/auth-scope: 'email openid'
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/group.name: 'platform-engineering'
    alb.ingress.kubernetes.io/load-balancer-name: '${var.alb_name}'
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/ip-address-type: dualstack
    alb.ingress.kubernetes.io/backend-protocol: HTTP
    alb.ingress.kubernetes.io/success-codes: '200'
    alb.ingress.kubernetes.io/healthcheck-path: /
    alb.ingress.kubernetes.io/healthcheck-port: traffic-port
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/shield-advanced-protection: 'true'
    alb.ingress.kubernetes.io/wafv2-acl-arn: '${var.waf_arn}'
    alb.ingress.kubernetes.io/certificate-arn: '${data.aws_acm_certificate.eks_certificate.arn}'
spec:
  ingressClassName: alb
  rules:
  - host: ${var.skywalking_host}
    http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: skywalking-ui
            port: 
              number: 8080
YAML

  depends_on = [
    kubectl_manifest.skywalking_namespace,
    kubectl_manifest.skywalking_ui_service,
    kubectl_manifest.skywalking_secret_alb
  ]
}