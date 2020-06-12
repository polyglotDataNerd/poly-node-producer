'use strict';
const config = require('./producer.json'),
    aws = require('aws-sdk'),
    promise = require('bluebird'),
    moment = require('moment'),
    sts_client = new aws.STS({apiVersion: config.sts.apiVersion}),
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
            "statusCode": error.code,
            "isBase64Encoded": false,
            "headers": {"Accept": "application/json", "Content-Type": "application/json"},
            "body": JSON.stringify(error)

        }

    }

}

/*creates a class module to be able to import into other modules*/
function Producer() {
    this.putKinesis = function (event, log, credentials, logging) {
        var kinesis = new aws.Kinesis({
            apiVersion: config.kinesis.apiVersion,
            region: config.kinesis.region,
            endpoint: config.kinesis.endpoint,
            credentials: credentials
        })
        logging.info([
            process.env.GitHash
            + ":" +
            moduleName
            + ":" +
            process.env.Stream
        ], event["body"])
        return new promise((resolve, reject) => {
            //Put record to Kinesis
            var partitionKey = Math.random().toString(33).substring(2, 20)
            logging.info("Partition Key: ", partitionKey)
            var paramsKinesis = {
                Data: JSON.stringify(JSON.parse(event["body"].toString().toLowerCase())),
                PartitionKey: partitionKey,
                StreamName: process.env.Stream
            };
            kinesis.putRecord(paramsKinesis, (err, data) => {
                if (err) {
                    logging.error([
                        process.env.GitHash
                        + ":" +
                        moduleName
                        + ":" +
                        process.env.Stream
                        + ":" +
                        err.statusCode.toString()
                    ], responsetemplate.error(err.message + ": " + err.stack))
                    return reject("Error: " + responsetemplate.error(err.message + ": " + err.stack))
                } else {
                    logging.info([
                        process.env.GitHash
                        + ":" +
                        moduleName
                        + ":" +
                        process.env.Stream
                    ], data.ShardId + ": " + data.SequenceNumber)
                    return resolve(data.ShardId + ": " + data.SequenceNumber)
                }
            })
        })
    }
    this.putKafka = function(event, log, credentials, logging) {
        logging.info([
            process.env.GitHash
            + ":" +
            moduleName
            + ":" +
            this.putS3.name
        ], event["body"])
        var kafka = new aws.Kafka( {
            apiVersion: config.kinesis.apiVersion,
            region: config.kinesis.region,
            endpoint: config.kinesis.endpoint,
            credentials: credentials
        })
        return new promise((resolve, reject) => {
            kafka.makeRequest()
        })
    }
    this.putS3 = function (event, log, credentials, logging) {
        logging.info([
            process.env.GitHash
            + ":" +
            moduleName
            + ":" +
            this.putS3.name
        ], event["body"])
        var s3 = new aws.S3({
            apiVersion: config.s3.apiVersion,
            region: config.s3.region,
            endpoint: config.s3.endpoint,
            credentials: credentials
        })
        return new promise((resolve, reject) => {
            var S3LogDate = moment.utc(new Date()).format('YYYY-MM-DD/YYYY-MM-DD-HHmmss');
            //Put record to s3
            var paramsS3 = {
                Bucket: config.s3.bucket,
                //Key: config.s3.key + "/raw/" + s3key["channel"] + "/" + S3LogDate + "-events-" + Math.random().toString(36).substring(7),
                Key: config.s3.key + "/" + process.env.Environment + "/" + S3LogDate + "-qsr-events-" + Math.random().toString(36).substring(7),
                Body: JSON.stringify(JSON.parse(event["body"].toString().toLowerCase())),
                ServerSideEncryption: "AES256"
            };
            s3.upload(paramsS3, (err, data) => {
                if (err) {
                    logging.error([
                        process.env.GitHash
                        + ":" +
                        moduleName
                        + ":" +
                        this.putS3.name
                        + ":" +
                        err.lineNumber.toString()
                    ], responsetemplate.error(err.message + ": " + err.stack))
                    return reject("Error: " + responsetemplate.error(err.message + ": " + err.stack) + ": " + responsetemplate.error(err))
                } else {
                    logging.info([
                        process.env.GitHash
                        + ":" +
                        moduleName
                        + ":" +
                        this.putS3.name
                    ], data)
                    return resolve(responsetemplate.success(event) + "-" + log)
                }
            })
        })
    }
    this.getSTS = function (roleARN) {
        return new Promise((resolve, reject) => {
            var stsparams = {
                RoleArn: roleARN,
                RoleSessionName: config.sts.rolename + Math.floor(Math.random() * (1000000 - 0 + 1)) + 0,
                DurationSeconds: 3600
            }
            sts_client.assumeRole(stsparams, (err, data) => {
                if (err) {
                    return reject(err, err.stack);
                    process.exit(1);
                } else {
                    var stscredentials = new aws.Credentials({
                        accessKeyId: data.Credentials.AccessKeyId,
                        secretAccessKey: data.Credentials.SecretAccessKey,
                        sessionToken: data.Credentials.SessionToken
                    })
                    return resolve(stscredentials);
                }
            })
        })
    }
}


module.exports.Producer = Producer;
