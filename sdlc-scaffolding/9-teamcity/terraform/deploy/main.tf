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
  sha1_hash = sha1(join("", [for f in fileset("", "${path.module}/docker/*") : filesha1(f)]))
  prefer_ipv4_stack  = "-Djava.net.preferIPv4Stack=${lower(var.cluster_ip_family) == "ipv4" ? "true" : "false"}"
  prefer_ipv6_stack  = "-Djava.net.preferIPv6Addresses=${lower(var.cluster_ip_family) == "ipv6" ? "true" : "false"}"
  teamcity_data_path = "/var/teamcity/datadir"
}

module "eks_fargate-profile" {
  source  = "terraform-aws-modules/eks/aws//modules/fargate-profile"
  version = "~> 20.0"

  name         = "teamcity-fargate"
  cluster_name = var.eks_cluster_name
  subnet_ids   = var.eks_subnet_ids

  selectors = [{
    namespace = "teamcity"
  }]
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

data "aws_iam_policy" "logging_policy" {
  name = var.eks_logging_policy_name
}

resource "aws_iam_role_policy_attachment" "logging_policy_attach" {
  role       = module.eks_fargate-profile.iam_role_name
  policy_arn = data.aws_iam_policy.logging_policy.arn
}

resource "aws_security_group" "teamcity_efs_sg" {
  name        = "teamcity-efs-sg"
  description = "Allow NFS inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description      = "NFS from VPC"
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = var.ipv4_cidr_blocks
    ipv6_cidr_blocks = var.ipv6_cidr_blocks
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_efs_file_system" "teamcity_efs" {
  creation_token   = "teamcity-efs"
  throughput_mode  = "bursting"
  performance_mode = "generalPurpose"

  tags = {
    Name = "teamcity-efs"
  }
}

resource "aws_efs_access_point" "teamcity_access_point" {
  file_system_id = aws_efs_file_system.teamcity_efs.id
}

resource "aws_efs_mount_target" "teamcity_efs_mount_target" {
  count           = length(var.eks_subnet_ids)
  subnet_id       = var.eks_subnet_ids[count.index]
  security_groups = [aws_security_group.teamcity_efs_sg.id]
  file_system_id  = aws_efs_file_system.teamcity_efs.id
}


resource "null_resource" "teamcity_build" {
	
  provisioner "local-exec" {
    command = <<-EOF
      aws ecr get-login-password --region ${data.aws_region.current.name} --profile ${var.aws_profile} | docker login --username AWS --password-stdin \
        ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com
      docker build -t "${data.aws_ecr_repository.selected.repository_url}:teamcity-v${time_static.tag.unix}" "${path.module}/docker"
      docker push "${data.aws_ecr_repository.selected.repository_url}:teamcity-v${time_static.tag.unix}"
    EOF
  }

  triggers = {
    run = local.sha1_hash
  }
}

resource "kubectl_manifest" "teamcity_namespace" {
  yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: teamcity
YAML
}

resource "kubectl_manifest" "teamcity_persistent_volume" {
  yaml_body = <<YAML
apiVersion: v1
kind: PersistentVolume
metadata:
  name: teamcity-server-data
  namespace: teamcity
spec:
  storageClassName: teamcity-sc
  capacity:
    storage: 32Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  csi:
    driver: efs.csi.aws.com
    volumeHandle: "${aws_efs_file_system.teamcity_efs.id}::${aws_efs_access_point.teamcity_access_point.id}"
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_persistent_volume_claim" {
    yaml_body = <<YAML
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: teamcity-server-data
  namespace: teamcity
spec:
  storageClassName: teamcity-sc
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 32Gi
YAML

    depends_on = [
        kubectl_manifest.teamcity_namespace,
        kubectl_manifest.teamcity_persistent_volume
    ]
}

resource "kubectl_manifest" "teamcity_config_map" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: teamcity-config
  namespace: teamcity
data:
  TZ: "America/Sao_Paulo"
  TEAMCITY_LOGS: "/opt/teamcity/logs"
  TEAMCITY_DATA_PATH: "${local.teamcity_data_path}"
  TEAMCITY_SERVER_OPTS: "${local.prefer_ipv4_stack} ${local.prefer_ipv6_stack} -Dsun.net.inetaddr.ttl=60"
  TEAMCITY_SERVER_MEM_OPTS: "-Xms512m -Xmx2048m -XX:ReservedCodeCacheSize=640m"
  TEAMCITY_HTTPS_PROXY_ENABLED: "true"
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_config_database" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: teamcity-database
  namespace: teamcity
data:
  database.properties: |
    maxConnections=50
    testOnBorrow=true
    testOnReturn=true
    testWhileIdle=true
    timeBetweenEvictionRunsMillis=60000
    validationQuery=select case when not pg_is_in_recovery() then 1 else random() / 0 end
    connectionProperties.user=${var.rds_username}
    connectionProperties.password=${var.rds_password}
    connectionUrl=jdbc:postgresql://${var.rds_hostname}:${var.rds_port}/teamcity?allowPublicKeyRetrieval=true&useSSL=false
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace
  ]
}

resource "kubectl_manifest" "teamcity_deployment" {
  yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: teamcity
  namespace: teamcity
spec:
  replicas: 1
  serviceName: teamcity-headless
  podManagementPolicy: OrderedReady
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: teamcity
      component: server
  template:
    metadata:
      labels:
        app: teamcity
        component: server
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      tolerations:
      - key: "eks.amazonaws.com/compute-type"
        operator: "Equal"
        value: "fargate"
        effect: "NoSchedule"
      containers:
      - name: teamcity
        image: ${data.aws_ecr_repository.selected.repository_url}:teamcity-v${time_static.tag.unix}
        imagePullPolicy: Always
        envFrom:
        - configMapRef:
            name: teamcity-config
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        ports:
        - name: http
          containerPort: 8111
          protocol: TCP
        livenessProbe:
          httpGet:
            scheme: HTTP
            path: /healthCheck/healthy
            port: http
          periodSeconds: 10
          failureThreshold: 3
          timeoutSeconds: 2
        readinessProbe:
          httpGet:
            scheme: HTTP
            path: /healthCheck/ready
            port: http
          periodSeconds: 10
          failureThreshold: 3
          timeoutSeconds: 2
        startupProbe:
          httpGet:
            scheme: HTTP
            path: /healthCheck/ready
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
          timeoutSeconds: 2
        resources:
          requests:
            memory: "2048Mi"
            cpu: "1000m"
          limits:
            memory: "2048Mi"
            cpu: "2000m"
        volumeMounts:
        - name: teamcity-server-data
          mountPath: ${local.teamcity_data_path}
        - name: teamcity-database
          mountPath: ${local.teamcity_data_path}/config/database.properties
          subPath: database.properties
        - name: cache
          mountPath: /opt/teamcity/cache
        - name: logs
          mountPath: /opt/teamcity/logs
        - name: temp
          mountPath: /opt/teamcity/temp
        - name: home-tcuser
          mountPath: /home/tcuser
      volumes:
      - name: teamcity-database
        configMap:
          defaultMode: 0644
          name: teamcity-database
      - name: teamcity-server-data
        persistentVolumeClaim:
          claimName: teamcity-server-data
      - emptyDir: {}
        name: cache
      - emptyDir: {}
        name: logs
      - emptyDir: {}
        name: temp
      - emptyDir: {}
        name: home-tcuser
YAML

  depends_on = [
    kubectl_manifest.teamcity_namespace,
    kubectl_manifest.teamcity_persistent_volume_claim,
    null_resource.teamcity_build
  ]
}