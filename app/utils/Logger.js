/*backtick https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Template_literals*/
'use strict';
const moment = require('moment')

function Logger(environment, level) {

    return function () {
        const loggingArgs = [
            `${moment.utc(new Date()).format('YYYY-MM-DD HH:mm:ss')}`,
            `${String(level).toUpperCase()}`,
            `${String(environment)}`,
            ...arguments,
        ]
        console.log.apply(console, loggingArgs)

    }
}

module.exports.Logger = {
    info: Logger(process.env.Environment, 'info'),
    error: Logger(process.env.Environment, 'error'),
    warn: Logger(process.env.Environment, 'warn')
}