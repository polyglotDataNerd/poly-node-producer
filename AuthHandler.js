'use strict'
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
            "statusCode": 209,
            "isBase64Encoded": false,
            "headers": {
                "Accept": "*/*",
                "Content-Type": "application/json",
                'Access-Control-Allow-Origin': '*'
            },
            "body": JSON.stringify(responseBody)

        }
    },
    error: (error) => {
        return {
            "statusCode": 409,
            "isBase64Encoded": false,
            "headers": {
                "Accept": "*/*",
                "Content-Type": "application/json",
                'Access-Control-Allow-Origin': '*'
            },
            "body": JSON.stringify(error)

        }

    }
}

exports.handler = function (event, context, callback) {
    let authenticate = new auth(event, context, config, callback, logging)
    try {
        callback(null, authenticate.authorizeToken())

    } catch (err) {
        logging.error([
            moduleName
            + ":" +
            context.functionName
        ], responsetemplate.error(err))
        logging.error(err)
        callback(new Error((JSON.stringify({"handlerFail": moduleName}))))
    }

}
