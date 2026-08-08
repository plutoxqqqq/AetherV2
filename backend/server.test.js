'use strict';
const test=require('node:test'); const assert=require('node:assert/strict'); const {canonical,server}=require('./server');
test('canonical comparison ignores top-level key order',()=>assert.equal(canonical({b:2,a:1}),canonical({a:1,b:2})));
test('different configs remain different',()=>assert.notEqual(canonical({a:1}),canonical({a:2})));
test('public deletion is authenticated and returns structured JSON',async()=>{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  try {
    const response=await fetch(`http://127.0.0.1:${server.address().port}/public-configs`,{method:'DELETE',headers:{'content-type':'application/json'},body:'{"file":"rage.json"}'});
    assert.equal(response.status,401);
    assert.deepEqual(await response.json(),{success:false,error:'Maintainer authentication required'});
  } finally { await new Promise(resolve=>server.close(resolve)); }
});
