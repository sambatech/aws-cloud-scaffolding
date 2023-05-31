#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

infracost breakdown \
   --path "${SCRIPT_DIR}/terraform" \
   --terraform-var-file "${SCRIPT_DIR}/terraform/envs/platform.tfvars" \
   --show-skipped