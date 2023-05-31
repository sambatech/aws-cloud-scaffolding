#!/bin/bash

terraform -chdir="./terraform" destroy -var-file="envs/platform.tfvars"