/*====
This terraform build can only run once if environments persist. The container builds will be ran in a different process.
We can use the apply command to rebuild and the destroy command to delete all the environments in terraform
======*/

/*====
API Gateway Webhook for QSR
https://medium.com/onfido-tech/aws-api-gateway-with-terraform-7a2bebe8b68f
======*/

resource "aws_api_gateway_rest_api" "qsr_api" {
  name = "api-producer-qsr-${var.environment}"
  description = "webhook that will be for QSR Kitchen service"
}


resource "aws_api_gateway_method" "post" {
  rest_api_id = "${aws_api_gateway_rest_api.qsr_api.id}"
  resource_id = "${aws_api_gateway_rest_api.qsr_api.root_resource_id}"
  http_method = "POST"
  authorization = "CUSTOM"
  authorizer_id = "${aws_api_gateway_authorizer.basic_auth.id}"

  /*if resource path was set to a greedy varible {proxy+}*/
  request_parameters = {
    "method.request.path.proxy" = true
  }
}


/*====
Enable CORS for Cross-origin resource sharing
https://medium.com/@MrPonath/terraform-and-aws-api-gateway-a137ee48a8ac
======*/
resource "aws_api_gateway_method" "options" {
  rest_api_id = "${aws_api_gateway_rest_api.qsr_api.id}"
  resource_id = "${aws_api_gateway_rest_api.qsr_api.root_resource_id}"
  http_method = "OPTIONS"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}


resource "aws_api_gateway_method_response" "options_cors200_response" {
  rest_api_id = "${aws_api_gateway_rest_api.qsr_api.id}"
  resource_id = "${aws_api_gateway_rest_api.qsr_api.root_resource_id}"
  http_method = "${aws_api_gateway_method.options.http_method}"
  status_code = "200"
  response_models {
    "application/json" = "Empty"
  }
  response_parameters {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin" = true
  }
  depends_on = [
    "aws_api_gateway_method.options"]
}

resource "aws_api_gateway_integration" "options_integration" {
  http_method = "${aws_api_gateway_method.options.http_method}"
  resource_id = "${aws_api_gateway_rest_api.qsr_api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.qsr_api.id}"
  type = "MOCK"
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = "${aws_api_gateway_rest_api.qsr_api.id}"
  resource_id = "${aws_api_gateway_rest_api.qsr_api.root_resource_id}"
  http_method = "${aws_api_gateway_method.options.http_method}"
  status_code = "${aws_api_gateway_method_response.options_cors200_response.status_code}"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
  depends_on = [
    "aws_api_gateway_method_response.options_cors200_response"]
}

/*====
Enable CORS for Cross-origin resource sharing
======*/


resource "aws_api_gateway_gateway_response" "gateway_response" {
  rest_api_id = "${aws_api_gateway_rest_api.qsr_api.id}"
  status_code = "401"
  response_type = "UNAUTHORIZED"

  response_templates {
    "application/json" = "{'message':$context.error.messageString}"
  }

  response_parameters {
    "gatewayresponse.header.WWW-Authenticate" = "'Basic'"
  }
}

resource "aws_api_gateway_integration" "integration" {
  http_method = "${aws_api_gateway_method.post.http_method}"
  resource_id = "${aws_api_gateway_rest_api.qsr_api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.qsr_api.id}"

  type = "AWS_PROXY"
  integration_http_method = "POST"
  uri = "${aws_lambda_function.producer.invoke_arn}"
}

# Lambda producer permissions
resource "aws_lambda_permission" "apigw_lambda_producer_perms" {
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:*"
  function_name = "${aws_lambda_function.producer.arn}"
  principal = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_rest_api.qsr_api.execution_arn}/*/*"
}

/*Producer Lambda: will be coming from the same package in s3 but just different handlers*/
resource "aws_lambda_function" "producer" {
  s3_bucket = "polyglotDataNerd-bigdata-utility"
  s3_key = "lambda/qsr/sg-QSR-producer-Auth.zip"
  function_name = "api-producer-qsr-${var.environment}"
  role = "${var.lambda_role}"
  handler = "Handler.handler"
  runtime = "nodejs8.10"
  memory_size = 528
  description = "QSR invocation trigger for API Gateway"
  vpc_config {
    security_group_ids = [
      "${split(",", var.sg_security_groups[var.environment])}"]
    subnet_ids = [
      "${split(",", var.private_subnets[var.environment])}"]
  }
  environment {
    variables {
      Environment = "${var.environment}"
      GitHash = "${var.githash}"
      Stream = "${var.kinesis}"
    }
  }
  tags {
    Name = "api_producer_qsr-${var.environment}"
    Environment = "${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "producer_log_group" {
  name = "/aws/lambda/${aws_lambda_function.producer.function_name}"
  retention_in_days = 14
}
/*Producer Lambda: will be coming from sg-QSR-producer-Auth.zip package in s3 but just different handlers*/

resource "aws_api_gateway_stage" "api_stage" {
  stage_name = "${var.environment}"
  rest_api_id = "${aws_api_gateway_rest_api.qsr_api.id}"
  deployment_id = "${aws_api_gateway_deployment.qsr_api_deploy.id}"
  access_log_settings {
    destination_arn = "${aws_cloudwatch_log_group.authorizer_log_group.arn}"
    format = "$context.extendedRequestId,$context.authorizer.principalId,$context.authorizer.property,$context.error.validationErrorString,$context.error.message"
  }
  xray_tracing_enabled = true
}

/*deploy API*/
resource "aws_api_gateway_deployment" "qsr_api_deploy" {
  rest_api_id = "${aws_api_gateway_rest_api.qsr_api.id}"
  //stage_name = "${var.environment}"
  stage_description = "QSR Kitchen Service endpoing for ${var.environment}"
  description = "QSR Kitchen Service Endpoint"
  depends_on = [
    "aws_api_gateway_integration.integration",
    "aws_api_gateway_integration.options_integration"]

}


/*usage plans to control throttle*/
resource "aws_api_gateway_usage_plan" "usage" {
  name = "usage_producer_qsr-${var.environment}"
  description = "usage plans to control QSR Webhook throttle"

  api_stages {
    api_id = "${aws_api_gateway_rest_api.qsr_api.id}"
    stage = "${aws_api_gateway_stage.api_stage.stage_name}"
  }

  throttle_settings {
    burst_limit = 5000
    rate_limit = 1000
  }
}

/*Cloudwtach logging enabled on the POST method*/
resource "aws_api_gateway_method_settings" "method_settings" {
  rest_api_id = "${aws_api_gateway_rest_api.qsr_api.id}"
  stage_name = "${aws_api_gateway_stage.api_stage.stage_name}"
  method_path = "${aws_api_gateway_rest_api.qsr_api.root_resource_id}/${aws_api_gateway_method.post.http_method}"

  settings {
    metrics_enabled = true
    logging_level = "ERROR"
    data_trace_enabled = true
  }
}

resource "aws_api_gateway_authorizer" "basic_auth" {
  name = "qsr-basicauth-${var.environment}"
  rest_api_id = "${aws_api_gateway_rest_api.qsr_api.id}"
  authorizer_uri = "${aws_lambda_function.authorizer.invoke_arn}"
  authorizer_credentials = "${var.lambda_role}"
  identity_source = "method.request.header.authorization"
  //identity_source = "method.request.header.Authorization"
  type = "REQUEST"
  authorizer_result_ttl_in_seconds = 300
}


/*Authorizer Lambda: will be coming from sg-QSR-producer-Auth.zip package in s3 but just different handlers*/
resource "aws_lambda_function" "authorizer" {
  s3_bucket = "polyglotDataNerd-bigdata-utility"
  s3_key = "lambda/qsr/sg-QSR-producer-Auth.zip"
  function_name = "api-authorizer-qsr-${var.environment}"
  role = "${var.lambda_role}"
  handler = "AuthHandler.handler"
  runtime = "nodejs8.10"
  memory_size = 320
  description = "authorizer function for QSR"
  vpc_config {
    security_group_ids = [
      "${split(",", var.sg_security_groups[var.environment])}"]
    subnet_ids = [
      "${split(",", var.private_subnets[var.environment])}"]
  }
  environment {
    variables {
      Environment = "${var.environment}"
      GitHash = "${var.githash}"
      Stream = "${var.kinesis}"
    }
  }
  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda-function.zip"))}"
  # source_code_hash = "${filebase64sha256("lambda-function.zip")}"
  tags {
    Name = "api_authorizer_qsr-${var.environment}"
    Environment = "${var.environment}"
  }
}
/*Authorizer Lambda: will be coming from the same package in s3 but just different handlers*/

resource "aws_cloudwatch_log_group" "authorizer_log_group" {
  name = "/aws/lambda/${aws_lambda_function.authorizer.function_name}"
  retention_in_days = 14
}


/*roles and policies*/
data "aws_iam_role" lambda_role {
  name = "sg-lambda-invoke-platforms"
}


resource "aws_iam_policy" "lambda_logging" {
  name = "qsr_lambda_logging-${var.environment}"
  path = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "logs_attach" {
  role = "${data.aws_iam_role.lambda_role.name}"
  policy_arn = "${aws_iam_policy.lambda_logging.arn}"
}

/*map qsr API to the default data custom domain name
resource "aws_api_gateway_base_path_mapping" "qsr_domain_map" {
  api_id = "${aws_api_gateway_rest_api.qsr_api.id}"
  stage_name = "${aws_api_gateway_stage.api_stage.stage_name}"
  domain_name = "data.polyglotDataNerd.com"
  base_path = "qsr"
}*/