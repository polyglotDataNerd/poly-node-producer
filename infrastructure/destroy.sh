#!/usr/bin/env bash
#sampe call
# source ~/SRC-producer/infrastructure/environment/consumer_ecs_infra_destroy.sh 'production'


AWS_ACCESS_KEY_ID=$(aws ssm get-parameters --names /s3/polyglotDataNerd/admin/AccessKey --query Parameters[0].Value --with-decryption --output text)
AWS_SECRET_ACCESS_KEY=$(aws ssm get-parameters --names /s3/polyglotDataNerd/admin/SecretKey --query Parameters[0].Value --with-decryption --output text)
CURRENTDATE="$(date  +%Y)"
#shell parameter for env.
environment=$1

#copy tfstate files into dir
aws s3 cp s3://polyglotDataNerd-bigdata-utility/terraform/SRCproducer/$environment/infra/$CURRENTDATE ~/SRC-producer/infrastructure/main  --recursive --sse --quiet --include "*"

export TF_VAR_awsaccess=$AWS_ACCESS_KEY_ID
export TF_VAR_awssecret=$AWS_SECRET_ACCESS_KEY
export TF_VAR_environment=$environment
cd ~/SRC-producer/infrastructure/main
terraform init
terraform validate -check-variables=false
terraform destroy -auto-approve

#copy tfstate files to s3
aws s3 cp ~/SRC-producer/infrastructure/main/ s3://polyglotDataNerd-bigdata-utility/terraform/SRCproducer/$environment/infra/$CURRENTDATE/  --recursive --sse --quiet --exclude "*" --include "*terraform.tfstate*"

cd ~/SRC-producer/