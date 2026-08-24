'use strict';
const test=require('node:test'); const assert=require('node:assert/strict'); const {PassThrough}=require('node:stream'); const {canonical,server,validSubmission,body}=require('./server');
test('canonical comparison ignores top-level key order',()=>assert.equal(canonical({b:2,a:1}),canonical({a:1,b:2})));
test('different configs remain different',()=>assert.notEqual(canonical({a:1}),canonical({a:2})));
test('submission validation rejects blank fields and non-object configs',()=>{
  const valid={name:'Example',submitter:'tester',userId:'1',creator:'tester',category:'Closet',description:'Useful config',tags:['safe'],game:'BedWars',config:{Modules:{}}};
  assert.equal(validSubmission(valid),true);
  assert.equal(validSubmission({...valid,name:'   '}),false);
  assert.equal(validSubmission({...valid,config:[]}),false);
  assert.equal(validSubmission({...valid,tags:['']}),false);
});
test('request body limit counts UTF-8 bytes',async()=>{
  const request=new PassThrough(); const parsed=body(request);
  request.end('é'.repeat(1024*1024+1));
  await assert.rejects(parsed,error=>error.status===413);
});
test('invalid JSON is a client error',async()=>{
  const request=new PassThrough(); const parsed=body(request); request.end('{');
  await assert.rejects(parsed,error=>error.status===400);
});
test('public deletion is authenticated and returns structured JSON',async()=>{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  try {
    const response=await fetch(`http://127.0.0.1:${server.address().port}/public-configs`,{method:'DELETE',headers:{'content-type':'application/json'},body:'{"file":"rage.json"}'});
    assert.equal(response.status,401);
    assert.deepEqual(await response.json(),{success:false,error:'Maintainer authentication required'});
  } finally { await new Promise(resolve=>server.close(resolve)); }
});
