variable "awsaccess" {}
variable "awssecret" {}
variable "environment" {
  description = "env will be passed as an arguement in the build"
}
variable "githash" {
  description = "git hash version"
}
variable "kinesis" {
  description = "kinesis stream name"
}

variable "region" {
  description = "Region that the instances will be created"
  default = "us-west-2"
}

variable "availability_zone" {
  type = "list"
  description = "The AZ that the resources will be launched"
  default = [
    "us-west-2a",
    "us-west-2b",
    "us-west-2c"]
}

# Networking

variable "vpc_cidr" {
  description = "The CIDR block of the VPC"
  default = "10.0.0.0/16"
}

variable "ip_cidr" {
  description = "ip CIDR range"
  type = "map"
  default = {
    public = "10.0.4.0/24,10.0.5.0/24,10.0.6.0/24"
    private = "10.0.7.0/24,10.0.8.0/24,10.0.9.0/24"
  }
}

variable "private_subnets" {
  description = "sg data private subnets"
  type = "map"
  default = {
    testing = ""
    production = ""
  }
}

variable "public_subnets" {
  description = "The private subnets to use"

  type = "map"
  default = {
    testing = ""
    production = ""
  }
}

variable "sg_security_groups" {
  description = "sg security groups"
  type = "map"
  default = {
    testing = ""
    production = ""
  }
}

variable "ecs_IAMROLE" {
  description = "The IAM role for the container"
  type = "string"
  default = "arn:aws:iam:::role/bigdata-dev-role"
}

variable "repository_name" {
  description = "repository name for container images"
  type = "string"
  default = ""
}

variable "shard_count" {
  default = 4
  description = "kinesis shard count"
}

variable "SRC_account" {
  default = ""
}

variable "sts_SRC_name" {
  default = ""
}

variable "lambda_role" {
  default = "arn:aws:iam:::role/lambda-invoke-platforms"
  description = "executes lambda role"
}

variable "availability_zones" {
  type = "list"
  description = "The AZ that the resources will be launched"
  default = [
    "us-west-2a",
    "us-west-2b",
    "us-west-2c"]
}