#!/bin/bash

terraform -chdir="./terraform" init -var-file="envs/platform.tfvars"

terraform -chdir="./terraform" plan -var-file="envs/platform.tfvars"
