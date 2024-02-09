#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PARENT_DIR=$( dirname "${SCRIPT_DIR}" )

terraform -chdir="${SCRIPT_DIR}/terraform" plan -destroy -compact-warnings -var-file="${PARENT_DIR}/0-envs/platform.tfvars" -out="${SCRIPT_DIR}/terraform/kubernetes-extra.tfplan"

terraform -chdir="${SCRIPT_DIR}/terraform" apply -compact-warnings ${SCRIPT_DIR}/terraform/kubernetes-extra.tfplan