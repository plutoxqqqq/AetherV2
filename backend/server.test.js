'use strict';
const test=require('node:test'); const assert=require('node:assert/strict'); const {canonical}=require('./server');
test('canonical comparison ignores top-level key order',()=>assert.equal(canonical({b:2,a:1}),canonical({a:1,b:2})));
test('different configs remain different',()=>assert.notEqual(canonical({a:1}),canonical({a:2})));
