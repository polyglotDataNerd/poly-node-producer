'use strict'
const config = require('./index').prodconfig,
    aws = require('aws-sdk'),
    logging = require('./index').Logger,
    promise = require('bluebird'),
    producer = require("./index").Producer,
    path = require('path'),
    moduleName = path.basename(__filename)
aws.config.update({
    setPromisesDependency: promise,
    maxRetries: 5,
    httpOptions: {
        timeout: 30000,
        connectTimeout: 5000
    }
})
let prod = new producer();
const responsetemplate = {
    success: (responseBody) => {
        return {
            "statusCode": 202,
            "isBase64Encoded": false,
            "headers": {
                "Accept": "*/*",
                "Content-Type": "application/json",
                'Access-Control-Allow-Origin': '*'
            },
            "multiValueHeaders": {},
            "body": JSON.stringify(responseBody)

        }
    },
    error: (error) => {
        return {
            "statusCode": 402,
            "isBase64Encoded": false,
            "headers": {
                "Accept": "*/*",
                "Content-Type": "application/json",
                'Access-Control-Allow-Origin': '*'
            },
            "multiValueHeaders": {},
            "body": JSON.stringify(error)

        }

    }
}

exports.handler = function (event, context, callback) {
    prod.getSTS(config.sts.sgbdRole)
        .then(cred => {
                prod.putS3(event, context, cred, logging)
                    // .then(prod.putKafka(event, context, cred, logging)
                    //     .then((callback(null, responsetemplate.success(event.body))))
                    // )
                    .then(
                        callback(null, responsetemplate.success(context))
                    )
            }
        )
        .catch((err) => {
                logging.error(
                    [
                        moduleName
                        + ":" +
                        context.functionName
                    ]
                    , responsetemplate.error(err))
                logging.error(err)
                callback(new Error((JSON.stringify({"handlerFail": moduleName}))))
            }
        )

}
