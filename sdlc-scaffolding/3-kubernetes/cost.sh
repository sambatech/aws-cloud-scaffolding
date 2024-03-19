#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PARENT_DIR=$( dirname "${SCRIPT_DIR}" )

infracost breakdown \
   --path "${SCRIPT_DIR}/terraform" \
   --terraform-var-file "${PARENT_DIR}/0-envs/platform.tfvars" \
   --show-skipped