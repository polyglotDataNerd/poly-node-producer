'use strict';
const config = require('./producer.json'),
    aws = require('aws-sdk'),
    promise = require('bluebird'),
    moment = require('moment'),
    sts_client = new aws.STS({apiVersion: config.sts.apiVersion}),
    path = require('path'),
    fs = require('fs'),
    kafkaAPI = require('kafka-node'),
    moduleName = path.basename(__filename),
    kafkaClient = new kafkaAPI.KafkaClient({
        kafkaHost: process.env.BootStrapServers,
        sslOptions: {
            rejectUnauthorized: false,
            // ca: [fs.readFileSync('/my/custom/ca.crt', 'utf-8')],
            // key: fs.readFileSync('/my/custom/client-key.pem', 'utf-8'),
            // cert: fs.readFileSync('/my/custom/client-cert.pem', 'utf-8')
        }
    }),
    kafkaProducer = new kafkaAPI.Producer(kafkaClient, {
        requireAcks: 1,
        ackTimeoutMs: 100
    })
aws.config.update({
    setPromisesDependency: promise
})
const responsetemplate = {
    success: (responseBody) => {
        return {
            "statusCode": 208,
            "isBase64Encoded": false,
            "headers": {"Accept": "*/*", "Content-Type": "application/json"},
            "multiValueHeaders": {},
            "body": JSON.stringify(responseBody)

        }
    },
    error: (error) => {
        return {
            "statusCode": 408,
            "isBase64Encoded": false,
            "headers": {"Accept": "*/*", "Content-Type": "application/json"},
            "multiValueHeaders": {},
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
                        moduleName
                        + ":" +
                        process.env.Stream
                        + ":" +
                        err.statusCode.toString()
                    ], responsetemplate.error(err))
                    return reject("Error: " + responsetemplate.error(err))
                } else {
                    logging.info([
                        moduleName
                        + ":" +
                        process.env.Stream
                    ], data.ShardId + ": " + data.SequenceNumber)
                    return resolve(data.ShardId + ": " + data.SequenceNumber)
                }
            })
        })
    }
    /* this is still in POC for AWS MSK, Kafka needs SSL cert to put into Brokers */
    this.putKafka = function (event, log, credentials, logging) {
        return new promise((resolve, reject) => {
            if (event.body !== null && event.body != undefined) {
                let body = JSON.parse(event.body)
                let payloads = [
                    {
                        topic: config.msk.topic,
                        messages: body
                        //timestamp: Date.now()
                    }
                ]
                logging.info("kafka producer put", event.body)
                kafkaProducer.on("ready", async () => {
                    kafkaProducer.send(payloads, (err, data) => {
                        if (err) {
                            logging.error("kafka producer error", err)
                            return reject(responsetemplate.error(new Error('{"message": err.message}')))
                        } else {
                            logging.info("kafka payload", data.Key)
                            return resolve(responsetemplate.success(event.body))
                        }
                    })
                })
                kafkaProducer.on("error", (err) => {
                    logging.error("kafka producer error", err)
                    logging.error('[kafka-producer -> ' + config.msk.topic + ']: connection errored')
                    return reject(responsetemplate.error(new Error('{"message": err.message}')))
                })
            }
        })
    }
    this.putS3 = function (event, context, credentials, logging) {
        var s3 = new aws.S3({
            apiVersion: config.s3.apiVersion,
            region: config.s3.region,
            endpoint: config.s3.endpoint,
            credentials: credentials
        })
        return new promise((resolve, reject) => {
            console.log(moduleName + " -> " + event.body)
            if (event.body !== null && event.body != undefined) {
                let body = JSON.parse(event.body)
                var S3LogDate = moment.utc(new Date()).format('YYYY-MM-DD/YYYY-MM-DD-HHmmss');
                //Put record to s3
                var paramsS3 = {
                    Bucket: config.s3.bucket,
                    Key: config.s3.key + "/" + process.env.Environment + "/" + S3LogDate + "-test-events-" + Math.random().toString(36).substring(7),
                    Body: JSON.stringify(body).toLowerCase(),
                    ServerSideEncryption: "AES256"
                };
                s3.upload(paramsS3, (err, data) => {
                    if (err) {
                        return reject(responsetemplate.error(err))
                    } else {
                        logging.info(
                            moduleName
                            + ":" +
                            data.Key)
                        return resolve(responsetemplate.success(event.body))
                    }
                })
            }
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
