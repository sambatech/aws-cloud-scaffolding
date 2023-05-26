@echo

terraform -chdir=".\terraform" init -var-file="envs\develop.tfvars"

terraform -chdir=".\terraform" plan -var-file="envs\develop.tfvars"
