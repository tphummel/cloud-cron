'use strict'

const test = require('tape')
const lib = require('./index.js')

test('myCronJob should callback without error', (t) => {
  lib.myCronJob((err) => {
    t.error(err)
    t.end()
  })
})

test('myCronJob should callback without error', (t) => {
  lib.lambda(true, true, (err) => {
    t.error(err)
    t.end()
  })
})
