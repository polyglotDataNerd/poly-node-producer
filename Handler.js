'use strict'
/*
1. https://stackoverflow.com/questions/41750026/aws-lambda-error-cannot-find-module-var-task-index
2. https://echorand.me/managing-aws-lambda-functions-from-start-to-finish-with-terraform.html
 */
const config = require('./index').prodconfig,
    aws = require('aws-sdk'),
    logging = require('./index').Logger,
    promise = require('bluebird'),
    producer = require("./index").Producer,
    path = require('path'),
    moduleName = path.basename(__filename)
aws.config.update({setPromisesDependency: promise})
const responsetemplate = {
    success: (responseBody) => {
        return {
            "statusCode": 200,
            "isBase64Encoded": false,
            "headers": {"Accept": "application/json", "Content-Type": "application/json"},
            "body": JSON.stringify(responseBody)

        }
    },
    error: (error) => {
        return {
            "statusCode": 400,
            "isBase64Encoded": false,
            "headers": {"Accept": "application/json", "Content-Type": "application/json"},
            "body": JSON.stringify(error)

        }

    }

}


exports.handler = function (event, context, callback) {
    let prod = new producer();
    promise.resolve()
        .then(prod.getSTS(config.sts.sgbdRole)
            .then(cred => {
                    prod.putKinesis(event, context, cred, logging)
                        .then(
                            prod.putS3(event, context, cred, logging)
                                .then(
                                    callback(null, responsetemplate.success(context))
                                )
                        )
                }
            )
        )
        .catch((err) => {
                logging.error(
                    [
                        process.env.GitHash
                        + ":" +
                        moduleName
                        + ":" +
                        exports.handler.name
                        + ":" +
                        err.statusCode.toString()
                    ]
                    , responsetemplate.error(err.message + ": " + err.stack))
                callback(responsetemplate.error(err.message + ": " + err.stack + ": " + event["body"].toString()), null)
            }
        )
}
