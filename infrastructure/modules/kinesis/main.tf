/*====
This terraform build can only run once if environments persist. The container builds will be ran in a different process.
We can use the apply command to rebuild and the destroy command to delete all the environments in terraform
======*/


/*====
Cloudwatch Log Group
======*/
resource "aws_cloudwatch_log_group" "SRCproducer_log_group" {
  name = "SRCproducer-etl-${var.environment}"
  tags {
    Environment = "SRCproducer-${var.environment}"
    Application = "SRCproducer"
  }
}

/*====
Kinesis stream for SRC
======*/
resource "aws_kinesis_stream" "SRC_stream" {
  name = "SRC-data-stream-${var.environment}"
  shard_count = "${var.shard_count}"
  retention_period = 24

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
    "WriteProvisionedThroughputExceeded",
    "ReadProvisionedThroughputExceeded",
    "IteratorAgeMilliseconds"
  ]

  tags {
    Name = "SRCproducer-etl-${var.environment}"
    Application = "SRC-stream-producer"
    Environment = "${var.environment}"
  }

}

resource "aws_iam_role" "SRC_stream_role" {
  name = "kinesis-SRC-role-${var.environment}"
  description = "SRC role that let's SRC put events in sg Kinesis Stream"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.SRC_account}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "${var.sts_SRC_name}"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_policy" "SRC_kinesis_policy" {
  name = "kinesis-SRC-policy-${var.environment}"
  description = "SRC Kinesis Policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "SRCKinPolicy",
            "Effect": "Allow",
            "Action": [
                "kinesis:PutRecord",
                "kinesis:PutRecords",
                "kinesis:DescribeStream"
            ],
            "Resource": "arn:aws:kinesis:us-west-2::stream/SRC-data-stream-${var.environment}"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "SRC_attach_role" {
  role = "${aws_iam_role.SRC_stream_role.name}"
  policy_arn = "${aws_iam_policy.SRC_kinesis_policy.arn}"
}
