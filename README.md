# SRC-producer

The producer application is a suite of objects written in Node.js to be used as broker for an API Gateway endpoint with Basic Authentication that will be provided to SRC. The endpoint will produce data from the SRC webhook to a Kinesis/Kafka Stream and process the stream that will be available to all consumer applications with proper IAM roles.

Dependencies:

* Node.js 12.10
* [npm](https://docs.npmjs.com/cli/install)
* [AWS SDK for node](https://aws.amazon.com/sdk-for-node-js/)
* [Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html)



Summary
-
According to the SRC documentation the endpoint that will need to be provided for the Kitchen service needs to have Basic Authentication of user id and password in order for the Post to be successful. 

**Authorizer**        
   - [/app/utils/Authorizer](./app/utils/Authorizer.js)
        * The mechanism that checks the user id and password passed by an explicit authorization header within the endpoint. To read more about custom authorizers click on this [link](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html). **[terraform ref](https://github.com/polyglotDataNerd/SRC-producer/blob/master/infrastructure/modules/apigateway/main.tf#L224)**
        ![alt text](https://docs.aws.amazon.com/apigateway/latest/developerguide/images/custom-auth-workflow.png)
        * This object is tied to a Lambda function and is invoked first when the API makes a POST request to check if the user id and pw is valid. **[terraform ref](./infrastructure/modules/apigateway/main.tf#L316)**
        * If the credentials are invalid than it goes to a custom gateway 401 response error. **[terraform ref](./infrastructure/modules/apigateway/main.tf#L184)**
  
**Producer**        
   - [/app/core/Producer](./app/core/Producer.js)
        * The object is tied to a Lambda function that is invoked once Basic Auth has been sufficed.  **[terraform ref](./infrastructure/modules/apigateway/main.tf#L220)** 
        * It is invoked by a POST from the Kitchen service
        * This function does several things chained together using a node.js [promise](http://bluebirdjs.com/docs/api-reference.html) wrapper within the [handler](./Handler.js#L38) entry point.
             
             1. Gets an AWS Security Token tied to a role that has access to Kinesis and s3. 
             2. Takes the STS credentials and then invokes a PUT into a Kinesis stream
             3. Takes the STS credentials and then invokes a PUT into the qsr s3 bucket. 
                           
Infrastructure
-          
    
Builds will be broken down into an environment package:

* [environment](./infrastructure): The environment variable will drive what vpc, subnets, security groups and domain Kinesis, API Gateway and Lambda will all live in. i.e. 

        source ~/SRC-producer/infrastructure/apply.sh 'testing'
        source ~/SRC-producer/infrastructure/destroy.sh 'testing'
        
* The shell will install all npm packages needed compress/archive the app and put into s3 for terraform to reference when building the Lambda function.           
 