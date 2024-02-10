locals {
  sha1_hash = sha1(join("", [for f in fileset("", "${path.module}/docker/*") : filesha1(f)]))
}

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
  host                   = var.debugger_eks_cluster_endpoint
  cluster_ca_certificate = var.debugger_eks_cluster_certificate_authority_data
  token                  = var.debugger_eks_cluster_auth_token
  load_config_file       = false
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "time_static" "tag" {
  triggers = {
    # Save the time each switch of an AMI id
    run = local.sha1_hash
  }
}

resource "null_resource" "docker_packaging" {
	
	  provisioner "local-exec" {
	    command = <<EOF
	    aws ecr get-login-password --region ${data.aws_region.current.name} --profile ${var.aws_profile} | docker login --username AWS --password-stdin \
        ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com
	    docker build -t "${var.registry_url}:debugger-v${time_static.tag.unix}" "${path.module}/docker"
	    docker push "${var.registry_url}:debugger-v${time_static.tag.unix}"
	    EOF
	  }
	
	  triggers = {
	    run = local.sha1_hash
	  }
}

resource "kubectl_manifest" "debugger_deployment" {
    yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: debugger-deployment
  namespace: default
  labels:
    app: debugger
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: debugger
  template:
    metadata:
      labels:
        app: debugger
    spec:
      containers:
      - name: debugger
        image: ${var.registry_url}:debugger-v${time_static.tag.unix}
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            memory: "32Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
YAML

    depends_on = [
        null_resource.docker_packaging
    ]
}