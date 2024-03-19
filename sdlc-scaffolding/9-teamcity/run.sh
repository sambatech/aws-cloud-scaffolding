#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PARENT_DIR=$( dirname "${SCRIPT_DIR}" )

#terraform -chdir="${SCRIPT_DIR}/terraform" import -var-file="${PARENT_DIR}/0-envs/platform.tfvars" kubernetes_config_map.aws-auth kube-system/aws-auth

terraform -chdir="${SCRIPT_DIR}/terraform" init -upgrade -var-file="${PARENT_DIR}/0-envs/platform.tfvars"

terraform -chdir="${SCRIPT_DIR}/terraform" plan -compact-warnings -var-file="${PARENT_DIR}/0-envs/platform.tfvars" -out="${SCRIPT_DIR}/terraform/teamcity.tfplan"

terraform -chdir="${SCRIPT_DIR}/terraform" apply -compact-warnings ${SCRIPT_DIR}/terraform/teamcity.tfplan