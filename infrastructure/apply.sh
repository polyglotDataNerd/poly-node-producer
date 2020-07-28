#!/bin/bash
#sampe call
# source ~/SRC-producer/infrastructure/environment/consumer_ecs_infra_apply.sh 'production'
# https://echorand.me/managing-aws-lambda-functions-from-start-to-finish-with-terraform.html

AWS_ACCESS_KEY_ID=$(aws ssm get-parameters --names /s3/polyglotDataNerd/admin/AccessKey --query Parameters[0].Value --with-decryption --output text)
AWS_SECRET_ACCESS_KEY=$(aws ssm get-parameters --names /s3/polyglotDataNerd/admin/SecretKey --query Parameters[0].Value --with-decryption --output text)
CURRENTDATE="$(date  +%Y)"
#shell parameter for env.
environment=$1
GitHash=$(cd ~/SRC-producer && (git rev-parse --verify HEAD))

#copy tfstate files into dir
aws s3 cp s3://polyglotDataNerd-bigdata-utility/terraform/SRCproducer/$environment/infra/$CURRENTDATE ~/SRC-producer/infrastructure/main  --recursive --sse --quiet --include "*"

#copy creds into SRC folder before Lambda is zipped
aws s3 cp s3://polyglotDataNerd-bigdata-utility/lambda/qsr/config/ ~/SRC-producer/app/utils --recursive --sse --quiet --include "*"

#install node dependencies with npm
cd ~/SRC-producer/
npm init --yes
npm install -l

#zip repo authorizer .js files to put into s3 for Lambda to ingest
zip -r9 SRC-producer-Auth.zip * -x \*.git\* -x \*.zip\* -x \*infrastructure\*
aws s3 cp ~/SRC-producer/ s3://polyglotDataNerd-bigdata-utility/lambda/qsr/ --recursive --sse --quiet --exclude "*" --include "*SRC-producer-Auth.zip*"
rm -rf ~/SRC-producer/*.zip


#terraform variables
export TF_VAR_awsaccess=$AWS_ACCESS_KEY_ID
export TF_VAR_awssecret=$AWS_SECRET_ACCESS_KEY
export TF_VAR_environment=$environment
export TF_VAR_githash=$GitHash
export TF_VAR_kinesis="SRC-data-stream-$environment"

#runs terraform ecs to build infrastructure. does not have to be ran every all the time
#can be re-used to register task definition
cd ~/SRC-producer/infrastructure/main/
terraform init
terraform get
terraform validate -check-variables=false
terraform plan
terraform apply -auto-approve

#copy tfstate files to s3
aws s3 cp ~/SRC-producer/infrastructure/main/ s3://polyglotDataNerd-bigdata-utility/terraform/SRCproducer/$environment/infra/$CURRENTDATE/  --recursive --sse --quiet --exclude "*" --include "*terraform.tfstate*"


cd ~/SRC-producer/
