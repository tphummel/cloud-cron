'use strict'

module.exports = { myCronJob, lambda }

function lambda (event, context, callback) {
  return myCronJob(callback)
}

function myCronJob (callback) {
  return process.nextTick(() => {
    callback()
  })
}
