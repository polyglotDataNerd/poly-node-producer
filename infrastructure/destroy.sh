#!/usr/bin/env bash
#sampe call
# source ~/sg-QSR-producer/infrastructure/environment/consumer_ecs_infra_destroy.sh 'production'


AWS_ACCESS_KEY_ID=$(aws ssm get-parameters --names /s3/sweetgreen/admin/AccessKey --query Parameters[0].Value --with-decryption --output text)
AWS_SECRET_ACCESS_KEY=$(aws ssm get-parameters --names /s3/sweetgreen/admin/SecretKey --query Parameters[0].Value --with-decryption --output text)
CURRENTDATE="$(date  +%Y)"
#shell parameter for env.
environment=$1

#copy tfstate files into dir
aws s3 cp s3://sweetgreen-bigdata-utility/terraform/QSRproducer/$environment/infra/$CURRENTDATE ~/sg-QSR-producer/infrastructure/main  --recursive --sse --quiet --include "*"

export TF_VAR_awsaccess=$AWS_ACCESS_KEY_ID
export TF_VAR_awssecret=$AWS_SECRET_ACCESS_KEY
export TF_VAR_environment=$environment
cd ~/sg-QSR-producer/infrastructure/main
terraform init
terraform validate -check-variables=false
terraform destroy -auto-approve

#copy tfstate files to s3
aws s3 cp ~/sg-QSR-producer/infrastructure/main/ s3://sweetgreen-bigdata-utility/terraform/QSRproducer/$environment/infra/$CURRENTDATE/  --recursive --sse --quiet --exclude "*" --include "*terraform.tfstate*"

cd ~/sg-QSR-producer/