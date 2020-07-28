/* Reference Links

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
    moduleName = path.basename(__filename),
    jwtdecode = require('jwt-decode')

class Authorizer {
    constructor(event, context, config, callback, logging) {
        this.event = event;
        this.context = context;
        this.config = config;
        this.callback = callback
        this.logging = logging
    }

    authorizeToken() {
        // var authHeader = this.event.headers.Authorization
        var token = this.event.authorizationToken.toString().replace("Bearer", "").trim()
        //var token = this.event.headers.Authorization
        var payload = (JSON.parse(JSON.stringify(jwtdecode(token))))["auth"].toString().trim()
        this.logging.warn("principal ID", JSON.stringify(this.context))
        this.logging.info([moduleName, payload, JSON.stringify(this.event)])
        switch (payload) {
            case 'grant':
                this.callback(null, this.buildAllowTokenPolicy(this.event, payload))
                break;
            case 'deny':
                this.callback(null, this.buildAllowTokenPolicy(this.event, payload))
                break;
            case 'unauthorized':
                this.callback("Unauthorized")
                break;
            default:
                this.logging.error(["Error: Invalid Token", payload])
                this.callback("Error: Invalid Token")
        }
    }

    authorizeBasic() {
        /*Authorization: username:pw*/
        var authorizationHeader = this.event.headers.Authorization
        this.logging.info([
            moduleName
        ], "event: " + this.event.type)
        this.logging.info(
            moduleName
            , "authorizationHeader " + authorizationHeader)
        if (!authorizationHeader) return this.callback('Unauthorized', null)

        /*parses the response header string to get auth pw*/
        let decodedCreds = Buffer.from(authorizationHeader.split(' ')[1], 'base64').toString('utf-8')
        let plainCreds = decodedCreds.split(':')
        let username = plainCreds[0]
        let password = plainCreds[1]

        if (!(username === this.config.authCreds.uid && password === this.config.authCreds.pw)) {
            this.logging.error([
                moduleName
            ], "Unauthorized wrong uid/pw")
            this.callback("Unauthorized wrong uid/pw", null)
        } else {
            this.logging.info([
                moduleName
            ], "authentication success")
            this.logging.info([
                moduleName
            ], "Status Code: 200")
            var authResponse = this.buildAllowAllPolicy(this.event, username)
            this.callback(null, authResponse)
        }

    }

    buildAllowAllPolicy(event, principalName) {
        //this.logging.info([process.env.GitHash+ ":" + event.methodArn.split(':')], tmp)
        this.logging.info(moduleName, this.buildAllowAllPolicy.name, this.event.methodArn)
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

    buildAllowTokenPolicy(event, token) {
        this.logging.info("buildAllowTokenPolicy: " + moduleName, this.buildAllowTokenPolicy.name, this.event.methodArn)
        const allowPolicy = {
            principalId: token,
            policyDocument: {
                Version: '2012-10-17',
                Statement: [
                    {
                        Action: ['execute-api:Invoke', 'lambda:InvokeFunction'],
                        Effect: 'Allow',
                        Resource: this.event.methodArn
                    }
                ]
            }
        }
        const denyPolicy = {
            principalId: token,
            policyDocument: {
                Version: '2012-10-17',
                Statement: [
                    {
                        Action: ['execute-api:Invoke', 'lambda:InvokeFunction'],
                        Effect: 'Deny',
                        Resource: this.event.methodArn
                    }
                ]
            }
        }

        if (token === "grant") {
            this.logging.info("success: ", JSON.stringify(allowPolicy))
            return allowPolicy
        } else {
            this.logging.error("deny: ", JSON.stringify(denyPolicy))
            return denyPolicy
        }


    }


}


module.exports.Authorizer = Authorizer;