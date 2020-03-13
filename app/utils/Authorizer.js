/* Reference Links
1. https://medium.com/@Da_vidgf/http-basic-auth-with-api-gateway-and-serverless-5ae14ad0a270

curl Response:
> POST /testing HTTP/2
> Host: 4ky73jj0x5.execute-api.us-west-2.amazonaws.com
> User-Agent: curl/7.54.0
> Accept: *//*
> Authorization: username:pw
> Content-Type: application/json
> Content-Length: 62
 */

'use strict';

const path = require('path'),
    moduleName = path.basename(__filename)

class Authorizer {
    constructor(event, config, callback, logging) {
        this.event = event;
        this.config = config;
        this.callback = callback
        this.logging = logging
    }

    authorize() {
        /*Authorization: username:pw*/
        var authorizationHeader = this.event.headers.Authorization
        this.logging.info([
            process.env.GitHash
            + ":" +
            moduleName
            + ":" +
            this.authorize.name
        ], "event: " + this.event.type)
        this.logging.info([
            process.env.GitHash
            + ":" +
            moduleName
            + ":" +
            this.authorize.name
        ], "authorizationHeader " + authorizationHeader)
        if (!authorizationHeader) return this.callback('Unauthorized', null)

        /*parses the response header string to get auth pw*/
        let encodedCreds = Buffer.from(authorizationHeader.split(' ')[1], 'base64').toString('utf-8')
        let plainCreds = encodedCreds.split(':')
        let username = plainCreds[0]
        let password = plainCreds[1]

        if (!(username === this.config.authCreds.uid && password === this.config.authCreds.pw)) {
            this.logging.error([
                process.env.GitHash
                + ":" +
                moduleName
                + ":" +
                this.authorize.name
            ], "Unauthorized wrong uid/pw")
            this.callback("Unauthorized wrong uid/pw", null)
        } else {
            this.logging.info([
                process.env.GitHash
                + ":" +
                moduleName
                + ":" +
                this.authorize.name
            ], "authentication success")
            this.logging.info([
                process.env.GitHash
                + ":" +
                moduleName
                + ":" +
                this.authorize.name
            ], "Status Code: 200")
            var authResponse = this.buildAllowAllPolicy(this.event, username)
            this.callback(null, authResponse)
        }

    }

    buildAllowAllPolicy(event, principalName) {
        //this.logging.info([process.env.GitHash+ ":" + event.methodArn.split(':')], tmp)
        this.logging.info([
            process.env.GitHash
            + ":" +
            moduleName
            + ":" +
            this.buildAllowAllPolicy.name
        ], event.methodArn)
        const policy = {
            principalId: principalName,
            policyDocument: {
                Version: '2012-10-17',
                Statement: [
                    {
                        Action: ['execute-api:Invoke', 'lambda:InvokeFunction'],
                        Effect: 'Allow',
                        Resource: event.methodArn
                    }
                ]
            }
        }
        return policy
    }
}


module.exports.Authorizer = Authorizer;