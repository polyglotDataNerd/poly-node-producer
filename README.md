# sg-QSR-producer

The producer application is a suite of objects written in Node.js to be used as broker for an API Gateway endpoint with Basic Authentication that will be provided to QSR. The endpoint will produce data from the QSR Kitchen webhook to a Kinesis Stream and process the stream that will be available to all consumer applications with proper IAM roles. Once a bump from the QSR Kitchen service posts to this endpoint it will then enable a consumer to process from the stream.

Dependencies:

* Node.js 8.10
* [npm](https://docs.npmjs.com/cli/install)
* [AWS SDK for node](https://aws.amazon.com/sdk-for-node-js/)
* [QSR Documentation](https://sweetgreen.atlassian.net/wiki/spaces/TEC/pages/641040412/Vendor+QSR)
* [Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html)



Summary
-
According to the QSR documentation the endpoint that will need to be provided for the Kitchen service needs to have Basic Authentication of user id and password in order for the Post to be successful. 

**Authorizer**        
   - [/app/utils/Authorizer](https://github.com/sweetgreen/sg-QSR-producer/blob/master/app/utils/Authorizer.js)
        * The mechanism that checks the user id and password passed by an explicit authorization header within the endpoint. To read more about custom authorizers click on this [link](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html). **[terraform ref](https://github.com/sweetgreen/sg-QSR-producer/blob/master/infrastructure/modules/apigateway/main.tf#L224)**
        ![alt text](https://docs.aws.amazon.com/apigateway/latest/developerguide/images/custom-auth-workflow.png)
        * This object is tied to a Lambda function and is invoked first when the API makes a POST request to check if the user id and pw is valid. **[terraform ref](https://github.com/sweetgreen/sg-QSR-producer/blob/master/infrastructure/modules/infra/main.tf#L316)**
        * If the credentials are invalid than it goes to a custom gateway 401 response error. **[terraform ref](https://github.com/sweetgreen/sg-QSR-producer/blob/master/infrastructure/modules/infra/main.tf#L184)**
  
**Producer**        
   - [/app/core/Producer](https://github.com/sweetgreen/sg-QSR-producer/blob/master/app/core/Producer.js)
        * The object is tied to a Lambda function that is invoked once Basic Auth has been sufficed.  **[terraform ref](https://github.com/sweetgreen/sg-QSR-producer/blob/master/infrastructure/modules/infra/main.tf#L220)** 
        * It is invoked by a POST from the Kitchen service
        * This function does several things chained together using a node.js [promise](http://bluebirdjs.com/docs/api-reference.html) wrapper within the [handler](https://github.com/sweetgreen/sg-QSR-producer/blob/master/Handler.js#L38) entry point.
             
             1. Gets an AWS Security Token tied to a role that has access to Kinesis and s3. 
             2. Takes the STS credentials and then invokes a PUT into a Kinesis stream
             3. Takes the STS credentials and then invokes a PUT into the qsr s3 bucket. 
                           
Infrastructure
-          
    
Builds will be broken down into an environment package:

* [environment](https://github.com/sweetgreen/sg-QSR-producer/tree/master/infrastructure): The enviorment variable will drive what vpc, subnets, security groups and domain Kinesis, API Gateway and Lambda will all live in. i.e. 

        source ~/sg-QSR-producer/infrastructure/apply.sh 'testing'
        source ~/sg-QSR-producer/infrastructure/destroy.sh 'testing'
        
* The shell will install all npm packages needed compress/archive the app and put into s3 for terraform to reference when building the Lambda function.           
 