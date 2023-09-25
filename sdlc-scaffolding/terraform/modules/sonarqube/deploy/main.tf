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
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: efs-sc
  csi:
    driver: efs.csi.aws.com
    volumeHandle: var.deploy_efs_filesystem_id
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
    - ReadWriteOnce
  storageClassName: efs-sc
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
        resources:
          requests:
            memory: "6144Mi"
            cpu: "500m"
          limits:
            memory: "7168Mi"
            cpu: "2000m"
      tolerations:
      - key: name
        operator: Equal
        value: frontend
        effect: NoSchedule
YAML

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
  - port: 9000
    name: sonarqube
  selector:
    app: sonarqube
YAML

    depends_on = [
        kubectl_manifest.sonarqube_deployment
    ]
}
