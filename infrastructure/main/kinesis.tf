#intializes variables from the ecs module to take variibles from the stage enviorment i.e. production, production
module "kinesis" {
  source = "../modules/kinesis"
  environment = "${var.environment}"
  repository_name = "${var.repository_name}"
  ecs_IAMROLE = "${var.ecs_IAMROLE}"
  public_subnets = "${var.public_subnets}"
  private_subnets = "${var.private_subnets}"
  sg_security_groups = "${var.sg_security_groups}"
  region = "${var.region}"
  availability_zones = "${var.availability_zones}"
  shard_count = "${var.shard_count}"
  QSR_account = "${var.QSR_account}"
  sts_QSR_name = "${var.sts_QSR_name}"
  lambda_role = "${var.lambda_role}"
  githash = "${var.githash}"
  kinesis = "${var.kinesis}"
}
