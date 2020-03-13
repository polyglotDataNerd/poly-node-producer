'use strict'
/*
1. https://stackoverflow.com/questions/41750026/aws-lambda-error-cannot-find-module-var-task-index
2. https://echorand.me/managing-aws-lambda-functions-from-start-to-finish-with-terraform.html
 */
const config = require('./index').config,
    aws = require('aws-sdk'),
    logging = require('./index').Logger,
    promise = require('bluebird'),
    auth = require("./index").Authorizer,
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
    logging.info([
        process.env.GitHash
        + ":" +
        moduleName
        + ":" +
        exports.handler.name
        + ":" +
        console.trace()
    ], "event: " + event.type)
    logging.info([
        process.env.GitHash
        + ":" +
        moduleName
        + ":" +
        exports.handler.name
        + ":" +
        console.trace()
    ], 'Method ARN: ' + event.methodArn)
    let authenticate = new auth(event, config, callback, logging)
    try {
        callback(null, authenticate.authorize())

    } catch (err) {
        logging.error([
            process.env.GitHash
            + ":" +
            moduleName
            + ":" +
            exports.handler.name
            + ":" +
            err.statusCode.toString()
        ], responsetemplate.error(err.message + ": " + err.stack))
        callback(err.stack + "->" + err.message, null)
    }

}
