#!/bin/bash

terraform -chdir="./terraform" destroy -var-file="envs/develop.tfvars"