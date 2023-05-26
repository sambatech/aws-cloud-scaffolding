@echo off

terraform -chdir=".\terraform" apply -var-file="envs\develop.tfvars"