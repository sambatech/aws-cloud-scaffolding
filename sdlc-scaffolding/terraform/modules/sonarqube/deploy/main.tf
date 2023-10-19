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
  force_new = true
  sonar_host = "sonar.sambatech.net"
  sonar_host_url = "https://${local.sonar_host}"
}

resource "aws_security_group" "sonarqube_efs_sg" {
  name        = "sonarqube-efs-sg"
  description = "Allow NFS inbound traffic"
  vpc_id      = var.deploy_vpc_id

  ingress {
    description      = "NFS from VPC"
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = var.deploy_cidr_blocks
    ipv6_cidr_blocks = var.deploy_ipv6_cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_efs_file_system" "sonarqube_efs" {
  creation_token   = "sonarqube-efs"
  throughput_mode  = "bursting"
  performance_mode = "generalPurpose"

  tags = {
    Name = "sonarqube-efs"
  }
}

resource "aws_efs_access_point" "sonarqube_access_point" {
  file_system_id = aws_efs_file_system.sonarqube_efs.id
}

resource "aws_efs_mount_target" "sonarqube_efs_mount_target" {
  count           = length(var.deploy_subnet_ids)
  subnet_id       = var.deploy_subnet_ids[count.index]
  security_groups = [aws_security_group.sonarqube_efs_sg.id]
  file_system_id  = aws_efs_file_system.sonarqube_efs.id
}

resource "kubectl_manifest" "sonarqube_storage_class" {
    yaml_body = <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: sonarqube-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
YAML
}

resource "kubectl_manifest" "sonarqube_namespace" {
    yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: sonarqube
YAML
}

resource "kubectl_manifest" "sonarqube_persistent_volume" {
    yaml_body = <<YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: sonarqube-pv
  namespace: sonarqube
spec:
  capacity:
    storage: 64Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: sonarqube-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: "${aws_efs_file_system.sonarqube_efs.id}::${aws_efs_access_point.sonarqube_access_point.id}"
YAML

    depends_on = [
        kubectl_manifest.sonarqube_namespace
    ]
}

resource "kubectl_manifest" "sonarqube_persistent_volume_claim" {
    yaml_body = <<YAML
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: sonarqube-claim
  namespace: sonarqube
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: sonarqube-sc
  resources:
    requests:
      storage: 64Gi
YAML

    depends_on = [
        kubectl_manifest.sonarqube_namespace,
        kubectl_manifest.sonarqube_persistent_volume
    ]
}

resource "kubectl_manifest" "sonarqube_config_map" {
    yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: sonarqube-config
  namespace: sonarqube
  labels:
    app: sonarqube
data:
  SONAR_WEB_JAVAOPTS: "-Xmx2048m -Xms2048m -XX:+HeapDumpOnOutOfMemoryError"
  SONAR_CE_JAVAOPTS: "-Xmx2048m -Xms2048m -XX:+HeapDumpOnOutOfMemoryError"
  SONAR_SEARCH_JAVAOPTS: "-Xmx2048m -Xms2048m -XX:MaxDirectMemorySize=256m -XX:+HeapDumpOnOutOfMemoryError"
YAML

    depends_on = [
        kubectl_manifest.sonarqube_namespace
    ]
}

resource "random_string" "sonar_web_systempasscode" {
  length   = 32
  upper    = true
  numeric  = true
  special  = false
}

resource "kubectl_manifest" "sonarqube_secret" {
    yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: sonarqube-secret
  namespace: sonarqube
  labels:
    app: sonarqube
type: Opaque
data:
  SONAR_WEB_SYSTEMPASSCODE: "${base64encode(random_string.sonar_web_systempasscode.result)}"
  SONAR_JDBC_USERNAME: "${base64encode(var.deploy_jdbc_username)}"
  SONAR_JDBC_PASSWORD: "${base64encode(var.deploy_jdbc_password)}"
  SONAR_JDBC_URL: '${base64encode("jdbc:postgresql://${var.deploy_jdbc_hostname}:${var.deploy_jdbc_port}/sonarqube")}'
YAML

    depends_on = [
        kubectl_manifest.sonarqube_namespace
    ]
}

resource "kubectl_manifest" "sonarqube_deployment" {
    yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonarqube-deployment
  namespace: sonarqube
  labels:
    app: sonarqube
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: sonarqube
  template:
    metadata:
      labels:
        app: sonarqube
    spec:
      tolerations:
      - key: "dedicated"
        operator: "Equal"
        value: "sonarqube"
        effect: "NoSchedule"
      initContainers:
      - name: init-vm
        image: busybox
        command:
        - sysctl
        - -w
        - vm.max_map_count=524288
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: true
      - name: init-fs
        image: busybox
        command:
        - sysctl
        - -w
        - fs.file-max=131072
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: true
      containers:
      - name: sonarqube
        image: sonarqube:9.9.2-community
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9000
        envFrom:
        - configMapRef:
            name: sonarqube-config
        - secretRef:
            name: sonarqube-secret
        volumeMounts:
        - name: sonarqube-storage
          mountPath: "/var/sonarqube/data/"
          subPath: data
        - name: sonarqube-storage
          mountPath: "/var/sonarqube/extensions/"
          subPath: extensions
        resources:
          requests:
            memory: "6144Mi"
            cpu: "500m"
          limits:
            memory: "7168Mi"
            cpu: "2000m"
      volumes:
      - name: sonarqube-storage
        persistentVolumeClaim:
          claimName: sonarqube-claim
YAML

    wait_for_rollout = false

    depends_on = [
        kubectl_manifest.sonarqube_namespace,
        kubectl_manifest.sonarqube_persistent_volume,
        kubectl_manifest.sonarqube_persistent_volume_claim,
        kubectl_manifest.sonarqube_config_map,
        kubectl_manifest.sonarqube_secret
    ]
}

resource "kubectl_manifest" "sonarqube_service" {
    yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  name: sonarqube-service
  namespace: sonarqube
  labels:
    app: sonarqube
spec:
  ports:
  - name: http
    port: 9000
    targetPort: 9000
  selector:
    app: sonarqube
YAML

    depends_on = [
        kubectl_manifest.sonarqube_deployment
    ]
}

data "aws_acm_certificate" "eks_certificate" {
  domain      = "sambatech.net"
  key_types   = ["RSA_2048"]
  most_recent = true
}

resource "kubectl_manifest" "sonarqube_ingress" {
    yaml_body = <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sonarqube-ingress
  namespace: sonarqube
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/group.name: 'platform-engineering'
    alb.ingress.kubernetes.io/load-balancer-name: ${var.deploy_alb_name}
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
    alb.ingress.kubernetes.io/wafv2-acl-arn: '${var.deploy_waf_arn}'
    alb.ingress.kubernetes.io/certificate-arn: '${data.aws_acm_certificate.eks_certificate.arn}'
spec:
  ingressClassName: alb
  rules:
  - host: ${local.sonar_host}
    http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: sonarqube-service
            port: 
              number: 9000
YAML

  depends_on = [
    kubectl_manifest.sonarqube_service
  ]
}