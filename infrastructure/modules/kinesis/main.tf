/*====
This terraform build can only run once if environments persist. The container builds will be ran in a different process.
We can use the apply command to rebuild and the destroy command to delete all the environments in terraform
======*/


/*====
Cloudwatch Log Group
======*/
resource "aws_cloudwatch_log_group" "QSRproducer_log_group" {
  name = "QSRproducer-etl-${var.environment}"
  tags {
    Environment = "QSRproducer-${var.environment}"
    Application = "QSRproducer"
  }
}

/*====
Kinesis stream for QSR
======*/
resource "aws_kinesis_stream" "QSR_stream" {
  name = "QSR-data-stream-${var.environment}"
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
    Name = "QSRproducer-etl-${var.environment}"
    Application = "QSR-stream-producer"
    Environment = "${var.environment}"
  }

}

resource "aws_iam_role" "QSR_stream_role" {
  name = "sg-kinesis-QSR-role-${var.environment}"
  description = "QSR role that let's QSR put events in sg Kinesis Stream"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.QSR_account}:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "${var.sts_QSR_name}"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_policy" "QSR_kinesis_policy" {
  name = "sg-kinesis-QSR-policy-${var.environment}"
  description = "QSR Kinesis Policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "QSRKinPolicy",
            "Effect": "Allow",
            "Action": [
                "kinesis:PutRecord",
                "kinesis:PutRecords",
                "kinesis:DescribeStream"
            ],
            "Resource": "arn:aws:kinesis:us-west-2:447388672287:stream/QSR-data-stream-${var.environment}"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "QSR_attach_role" {
  role = "${aws_iam_role.QSR_stream_role.name}"
  policy_arn = "${aws_iam_policy.QSR_kinesis_policy.arn}"
}
