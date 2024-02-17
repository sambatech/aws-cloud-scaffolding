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
  host                   = var.deploy_eks_cluster_endpoint
  cluster_ca_certificate = var.deploy_eks_cluster_certificate_authority_data
  token                  = var.deploy_eks_cluster_auth_token
  load_config_file       = false
}

module "eks_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "~> 20.0"

  name            = "sonarqube"
  cluster_name    = var.deploy_cluster_name
  cluster_version = var.deploy_cluster_version

  subnet_ids                        = var.deploy_subnet_ids
  cluster_primary_security_group_id = var.deploy_cluster_primary_security_group_id
  vpc_security_group_ids            = var.deploy_cluster_security_group_ids

  capacity_type  = "SPOT"
  ami_type       = "AL2_x86_64"
  instance_types = ["t3a.large","t3.large","c7i.large","c6i.large","c5a.large","c6in.large","c5ad.large"]

  min_size     = 1
  desired_size = 1
  max_size     = 1

  taints = {
    dedicated = {
      key    = "dedicated"
      value  = "sonarqube"
      effect = "NO_SCHEDULE"
    }
  }
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
  SONAR_TELEMETRY_ENABLE: "false"
  SONAR_PATH_DATA: "/opt/sonarqube/data"
  SONAR_PATH_TEMP: "/opt/sonarqube/temp"
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

resource "kubectl_manifest" "sonarqube_init_fs" {
    yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: sonarqube-init-fs
  namespace: sonarqube
  labels:
    app: sonarqube
data:
  init_fs.sh: |-
    #!/bin/bash
    
    chown -R 1000:0 /opt/sonarqube
YAML

    depends_on = [
        kubectl_manifest.sonarqube_namespace
    ]
}

resource "kubectl_manifest" "sonarqube_init_sysctl" {
    yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: sonarqube-init-sysctl
  namespace: sonarqube
  labels:
    app: sonarqube
data:
  init_sysctl.sh: |-
    #!/bin/bash

    if [[ "$(sysctl -n vm.max_map_count)" -lt 524288 ]]; then
      sysctl -w vm.max_map_count=524288
    fi
    if [[ "$(sysctl -n fs.file-max)" -lt 131072 ]]; then
      sysctl -w fs.file-max=131072
    fi
    if [[ "$(ulimit -n)" != "unlimited" ]]; then
      if [[ "$(ulimit -n)" -lt 131072 ]]; then
        echo "ulimit -n 131072"
        ulimit -n 131072
      fi
    fi
    if [[ "$(ulimit -u)" != "unlimited" ]]; then
      if [[ "$(ulimit -u)" -lt 8192 ]]; then
        echo "ulimit -u 8192"
        ulimit -u 8192
      fi
    fi
YAML

    depends_on = [
        kubectl_manifest.sonarqube_namespace
    ]
}

resource "kubectl_manifest" "sonarqube_check_readiness" {
    yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: sonarqube-check-readiness
  namespace: sonarqube
  labels:
    app: sonarqube
data:
  check-readiness.sh: |-
    #!/bin/bash

    # A Sonarqube container is considered ready if the status is UP, DB_MIGRATION_NEEDED or DB_MIGRATION_RUNNING
    # status about migration are added to prevent the node to be kill while sonarqube is upgrading the database.
    
    STATUS_CODE=1
    if wget --no-proxy -qO- http://127.0.0.1:9000/api/system/status | grep -q -E '"status":"UP|DB_MIGRATION_NEEDED|DB_MIGRATION_RUNNING"'; then
      STATUS_CODE=0
    fi

    exit $STATUS_CODE
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
      - name: init-sysctl
        image: sonarqube:9.9.4-community
        command: ["/bin/bash", "-e", "/tmp/scripts/init_sysctl.sh"]
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: true
        volumeMounts:
        - name: init-sysctl
          mountPath: /tmp/scripts/
      - name: init-fs
        image: sonarqube:9.9.4-community
        command: ["/bin/bash", "-e", "/tmp/scripts/init_fs.sh"]
        imagePullPolicy: IfNotPresent
        securityContext:
          capabilities:
            add:
            - CHOWN
            drop:
            - ALL
          privileged: false
          runAsGroup: 0
          runAsNonRoot: false
          runAsUser: 0
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
          - name: init-fs
            mountPath: /tmp/scripts/
          - name: sonarqube-storage
            mountPath: /opt/sonarqube/data
            subPath: data
          - name: sonarqube-storage
            mountPath: /opt/sonarqube/extensions
            subPath: extensions
          - name: sonarqube-storage
            mountPath: /opt/sonarqube/temp
            subPath: temp
          - name: sonarqube-storage
            mountPath: /opt/sonarqube/logs
            subPath: logs
          - name: tmp-dir
            mountPath: /tmp
      containers:
      - name: sonarqube
        image: sonarqube:9.9.4-community
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 9000
          protocol: TCP
        envFrom:
        - configMapRef:
            name: sonarqube-config
        - secretRef:
            name: sonarqube-secret
        livenessProbe:
          httpGet:
            scheme: HTTP
            path: /api/system/liveness
            port: http
            httpHeaders:
            - name: X-Sonar-Passcode
              value: ${random_string.sonar_web_systempasscode.result}
          initialDelaySeconds: 60
          periodSeconds: 30
          failureThreshold: 6
          timeoutSeconds: 1
        readinessProbe:
          exec:
            command: ["/bin/bash", "-e", "/tmp/scripts/check-readiness.sh"]
          initialDelaySeconds: 60
          periodSeconds: 30
          failureThreshold: 6
          timeoutSeconds: 1
        startupProbe:
          httpGet:
            scheme: HTTP
            path: /api/system/status
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 24
          timeoutSeconds: 1
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          runAsGroup: 0
          runAsNonRoot: true
          runAsUser: 1000
          seccompProfile:
            type: RuntimeDefault
        resources:
          requests:
            memory: "6144Mi"
            cpu: "500m"
          limits:
            memory: "7168Mi"
            cpu: "2000m"
        volumeMounts:
        - name: check-readiness
          mountPath: /tmp/scripts/
        - name: sonarqube-storage
          mountPath: /opt/sonarqube/data
          subPath: data
        - name: sonarqube-storage
          mountPath: /opt/sonarqube/extensions
          subPath: extensions
        - name: sonarqube-storage
          mountPath: /opt/sonarqube/temp
          subPath: temp
        - name: sonarqube-storage
          mountPath: /opt/sonarqube/logs
          subPath: logs
        - name: tmp-dir
          mountPath: /tmp
      volumes:
      - name: sonarqube-storage
        persistentVolumeClaim:
          claimName: sonarqube-claim
      - name: check-readiness
        configMap:
          name: sonarqube-check-readiness
          items:
          - key: check-readiness.sh
            path: check-readiness.sh
      - name: init-fs
        configMap:
          name: sonarqube-init-fs
          items:
          - key: init_fs.sh
            path: init_fs.sh
      - name: init-sysctl
        configMap:
          name: sonarqube-init-sysctl
          items:
          - key: init_sysctl.sh
            path: init_sysctl.sh
      - name: tmp-dir
        emptyDir:
          {}
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
  - host: ${var.sonarqube_host}
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