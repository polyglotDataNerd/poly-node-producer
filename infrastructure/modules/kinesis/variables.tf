variable "environment" {
  description = "env will be passed in the instance of creation in build"
}

variable "githash" {
  description = "git hash version"
}

variable "kinesis" {
  description = "kinesis stream name"
}

variable "availability_zones" {
  type = "list"
  description = "The azs to use"
}


variable "private_subnets" {
  type = "map"
  description = "The private subnets to use"
}

variable "public_subnets" {
  type = "map"
  description = "The private subnets to use"
}

variable "ecs_IAMROLE" {
  description = "The IAM role for the container"
  type = "string"
}


variable "repository_name" {
  description = "repository name for container images"
  type = "string"
}

variable "region" {
  description = "Region that the instances will be created"
}

variable "sg_security_groups" {
  type = "map"
  description = "sg security groups"
}

variable "shard_count" {
  description = "kinesis shard count"
}

variable "SRC_account" {
}

variable "sts_SRC_name" {
}

variable "lambda_role" {
  description = "executes lambda role"
}

