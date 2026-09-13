'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const PORT = Number(process.env.PORT || 3000);
const DATA_FILE = process.env.DATA_FILE || path.join(__dirname, 'data.json');
const ADMIN_KEY = process.env.ADMIN_KEY || '';
const MAX_BODY = 2 * 1024 * 1024;
const categories = new Set(['Closet', 'Semi-closet', 'Blatant']);
const read = () => {
  try {
    const data=JSON.parse(fs.readFileSync(DATA_FILE,'utf8'));
    if (!data||typeof data!=='object'||!Array.isArray(data.submissions)) throw Error('Invalid submission database shape');
    if (!data.bans||typeof data.bans!=='object'||Array.isArray(data.bans)) data.bans={};
    if (!data.ratings||typeof data.ratings!=='object'||Array.isArray(data.ratings)) data.ratings={};
    if (!data.versions||typeof data.versions!=='object'||Array.isArray(data.versions)) data.versions={};
    if (!data.downloads||typeof data.downloads!=='object'||Array.isArray(data.downloads)) data.downloads={};
    return data;
  } catch(error) {
    if (error&&error.code==='ENOENT') return {submissions:[],bans:{},ratings:{},versions:{},downloads:{}};
    const wrapped=Error('Submission database is unreadable; refusing to overwrite it'); wrapped.cause=error; throw wrapped;
  }
};
const write = data => { fs.mkdirSync(path.dirname(DATA_FILE),{recursive:true}); const temp=`${DATA_FILE}.${process.pid}.tmp`; fs.writeFileSync(temp,JSON.stringify(data,null,2)); fs.renameSync(temp,DATA_FILE); };
const json = (res, status, value) => { res.writeHead(status, {'content-type':'application/json','access-control-allow-origin':'*','access-control-allow-headers':'authorization,content-type','access-control-allow-methods':'GET,POST,PATCH,DELETE,OPTIONS'}); res.end(JSON.stringify(value)); };
const raw = (res, status, value) => { res.writeHead(status, {'content-type':'application/json','access-control-allow-origin':'*'}); res.end(value); };
const body = req => new Promise((resolve, reject) => {
  let size=0, settled=false; const chunks=[];
  req.on('data',chunk=>{ if(settled)return; const value=Buffer.isBuffer(chunk)?chunk:Buffer.from(chunk); size+=value.length; if(size>MAX_BODY){settled=true;reject(Object.assign(Error('Request body is too large'),{status:413}));return;} chunks.push(value); });
  req.on('end',()=>{ if(settled)return; settled=true; try{resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')||'{}'));}catch{reject(Object.assign(Error('Invalid JSON'),{status:400}));} });
  req.on('error',error=>{if(!settled){settled=true;reject(error);}});
});
const admin = req => { const got=Buffer.from(req.headers.authorization || ''), expected=Buffer.from(`Bearer ${ADMIN_KEY}`); return Boolean(ADMIN_KEY) && got.length===expected.length && crypto.timingSafeEqual(got,expected); };
const canonical = value => JSON.stringify(value, (_, child) => child && typeof child === 'object' && !Array.isArray(child) ? Object.fromEntries(Object.keys(child).sort().map(key => [key, child[key]])) : child);
const matchesPublished = config => { const folder=path.resolve(__dirname,'..','configs'); try { return fs.readdirSync(folder).filter(file=>file.endsWith('.json')&&file!=='presets.json').some(file=>{ const wrapper=JSON.parse(fs.readFileSync(path.join(folder,file),'utf8')); const saved=typeof wrapper.config==='string'?JSON.parse(wrapper.config):wrapper.config; return canonical(saved)===canonical(config); }); } catch { return false; } };
const github = () => {
  if (!process.env.GITHUB_TOKEN || !process.env.GITHUB_REPO || !process.env.GITHUB_BRANCH) throw Error('GitHub publishing requires GITHUB_TOKEN, GITHUB_REPO, and GITHUB_BRANCH');
  return {branch:process.env.GITHUB_BRANCH,headers:{authorization:`Bearer ${process.env.GITHUB_TOKEN}`,accept:'application/vnd.github+json','user-agent':'aetherv2-review','x-github-api-version':'2022-11-28'}};
};
const apiFor = file => `https://api.github.com/repos/${process.env.GITHUB_REPO}/contents/configs/${file}`;
async function getGithubFile(file, required=true) {
  const {branch,headers}=github(); const response=await fetch(`${apiFor(file)}?ref=${encodeURIComponent(branch)}`,{headers});
  if (!response.ok) { if (!required && response.status===404) return null; throw Error(`Could not load configs/${file} from GitHub (${response.status})`); }
  const value=await response.json(); return {...value,decoded:Buffer.from(value.content.replace(/\n/g,''),'base64').toString()};
}
async function putGithubFile(file, content, sha, message) {
  const {branch,headers}=github(); const response=await fetch(apiFor(file),{method:'PUT',headers:{...headers,'content-type':'application/json'},body:JSON.stringify({message,branch,content:Buffer.from(content).toString('base64'),...(sha&&{sha})})});
  if (!response.ok) throw Error(`GitHub write failed for configs/${file} (${response.status}): ${await response.text()}`);
}
async function deleteGithubFile(file, sha, message) {
  const {branch,headers}=github(); const response=await fetch(apiFor(file),{method:'DELETE',headers:{...headers,'content-type':'application/json'},body:JSON.stringify({message,branch,sha})});
  if (!response.ok) throw Error(`GitHub delete failed for configs/${file} (${response.status}): ${await response.text()}`);
}
const supplied = (value, fallback) => value !== undefined && value !== null && value !== '' && (!Array.isArray(value) || value.length) ? value : fallback;
const nonEmptyString = (value,max=500) => typeof value==='string'&&value.trim().length>0&&value.length<=max;
const validSubmission = value => value&&typeof value==='object'&&!Array.isArray(value)
  && nonEmptyString(value.name,120)&&nonEmptyString(value.submitter,120)
  && (nonEmptyString(value.userId,120)||Number.isSafeInteger(value.userId))
  && nonEmptyString(value.creator,120)&&categories.has(value.category)&&nonEmptyString(value.description,5000)
  && Array.isArray(value.tags)&&value.tags.length>0&&value.tags.length<=30&&value.tags.every(tag=>nonEmptyString(tag,80))
  && nonEmptyString(value.game,120)&&value.config&&typeof value.config==='object'&&!Array.isArray(value.config)
  && (value.gui===undefined||value.gui===null||(typeof value.gui==='object'&&!Array.isArray(value.gui)));
const validUpdate = value => value&&typeof value==='object'&&!Array.isArray(value)
  && nonEmptyString(value.submitter,120)
  && (nonEmptyString(value.userId,120)||Number.isSafeInteger(value.userId))
  && nonEmptyString(value.changelog,5000)&&value.config&&typeof value.config==='object'&&!Array.isArray(value.config)
  && (value.gui===undefined||value.gui===null||(typeof value.gui==='object'&&!Array.isArray(value.gui)));
const validFile = file => typeof file==='string'&&file.endsWith('.json')&&file!=='presets.json'&&!file.includes('/')&&!file.includes('\\');
const reviewing = new Set();
async function readManifest() {
  const remote=await getGithubFile('presets.json'); const manifest=JSON.parse(remote.decoded); const presets=Array.isArray(manifest.presets)?manifest.presets:[];
  return {manifest,presets,sha:remote.sha};
}
async function publish(item, db) {
  // The public name is the submitter-entered display name; the local profile name is only a
  // fallback. Using the profile name here is why published configs could show up misnamed.
  const title=String(item.displayName||item.name);
  const slug=title.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'')||item.id, file=validFile(item.file)?item.file:`${slug}.json`;
  const existingFile=await getGithubFile(file,false);
  const {manifest,presets,sha}=await readManifest();
  const old=presets.find(p=>p.file===file)||presets.find(p=>String(p.name).toLowerCase()===title.toLowerCase())||{};
  const now=new Date().toISOString();
  const version=Math.max(1,(Number(old.version)||0)+1);
  const metadata={...old,name:title,file,credits:supplied(item.creator,old.credits),tags:supplied([item.category,...(item.tags||[])].filter(Boolean),old.tags),description:supplied(item.description,old.description),version,createdAt:old.createdAt||now,updatedAt:now,lastPublishedAt:now};
  const wrapper={name:title,credits:metadata.credits,tags:metadata.tags,description:metadata.description,game:item.game,config:JSON.stringify(item.config),...(item.gui&&{gui:JSON.stringify(item.gui)})};
  // Publish the payload first: the catalogue is never changed to point at a missing file.
  await putGithubFile(file,JSON.stringify(wrapper,null,2)+'\n',existingFile&&existingFile.sha,`Publish config: ${title}`);
  manifest.presets=presets.filter(p=>p.file!==file&&String(p.name).toLowerCase()!==title.toLowerCase()); manifest.presets.push(metadata);
  await putGithubFile('presets.json',JSON.stringify(manifest,null,2)+'\n',sha,`List config: ${item.name}`);
  if (db) {
    db.versions[file]=Array.isArray(db.versions[file])?db.versions[file]:[];
    db.versions[file].unshift({version,versionLabel:'v'+version,changelog:String(item.changelog||'').slice(0,5000),publishedAt:now});
    db.versions[file]=db.versions[file].slice(0,30);
  }
  return file;
}
async function editPublished(file, patch) {
  const remote=await getGithubFile(file); const wrapper=JSON.parse(remote.decoded);
  if (nonEmptyString(patch.name,120)) wrapper.name=patch.name.trim();
  if (nonEmptyString(patch.credits,120)) wrapper.credits=patch.credits.trim();
  if (nonEmptyString(patch.description,5000)) wrapper.description=patch.description.trim();
  if (Array.isArray(patch.tags)&&patch.tags.length&&patch.tags.length<=30) wrapper.tags=patch.tags.map(tag=>String(tag).trim()).filter(Boolean);
  if (nonEmptyString(patch.game,120)) wrapper.game=patch.game.trim();
  if (patch.config&&typeof patch.config==='object'&&!Array.isArray(patch.config)) wrapper.config=JSON.stringify(patch.config);
  if (patch.gui&&typeof patch.gui==='object'&&!Array.isArray(patch.gui)) wrapper.gui=JSON.stringify(patch.gui);
  await putGithubFile(file,JSON.stringify(wrapper,null,2)+'\n',remote.sha,`Edit config: ${wrapper.name}`);
  const {manifest,presets,sha}=await readManifest();
  const entry=presets.find(p=>p.file===file);
  if (entry) {
    entry.name=wrapper.name; entry.credits=wrapper.credits; entry.tags=wrapper.tags; entry.description=wrapper.description; entry.updatedAt=new Date().toISOString();
    await putGithubFile('presets.json',JSON.stringify(manifest,null,2)+'\n',sha,`Edit config listing: ${wrapper.name}`);
  }
  return file;
}
async function removePublished(file) {
  if (!validFile(file)) throw Error('Invalid public config file');
  const {manifest,presets,sha}=await readManifest();
  if (!presets.some(p=>p.file===file)) { const error=Error('The requested file is not a known Public Config'); error.status=404; throw error; }
  const configRemote=await getGithubFile(file);
  // Remove the pointer first. A failed second operation can leave an unlisted orphan,
  // but never a catalogue entry that points at an unavailable file.
  manifest.presets=presets.filter(p=>p.file!==file);
  await putGithubFile('presets.json',JSON.stringify(manifest,null,2)+'\n',sha,`Unlist config: ${file}`);
  await deleteGithubFile(file,configRemote.sha,`Delete config: ${file}`);
  return file;
}
const ratingSummary = (db, file, userId) => {
  const votes=db.ratings[file]||{}; const values=Object.values(votes);
  const likes=values.filter(value=>value===1).length, dislikes=values.filter(value=>value===-1).length;
  const ratingCount=likes+dislikes;
  return {likes,dislikes,ratingCount,ratingPercentage:ratingCount?Math.round((likes/ratingCount)*100):0,userRating:userId!==undefined?Number(votes[String(userId)])||0:0};
};
const presetsWithActivity = async (db, userId) => {
  let presets=[];
  try {
    const remote=await readManifest();
    presets=remote.presets;
  } catch {
    const file=path.resolve(__dirname,'..','configs','presets.json');
    try {
      const manifest=JSON.parse(fs.readFileSync(file,'utf8'));
      presets=Array.isArray(manifest.presets)?manifest.presets:[];
    } catch { presets=[]; }
  }
  return presets.map(preset=>({...preset,downloads:Number(db.downloads[preset.file])||0,...ratingSummary(db,preset.file,userId)}));
};
const banRecord = db => ({bans:db.bans});

const server = http.createServer(async (req,res) => { try {
  if (req.method==='OPTIONS') return json(res,204,{success:true});
  const url=new URL(req.url,'http://localhost');
  const pathname=url.pathname.replace(/\/+$/, '')||'/';

  if (req.method==='POST'&&pathname==='/submissions') {
    const value=await body(req);
    if (!validSubmission(value)) return json(res,400,{success:false,error:'Missing or invalid config details'});
    const db=read();
    if (db.bans[String(value.userId)]) return json(res,403,{success:false,error:'This account is banned from submitting configs'});
    if (matchesPublished(value.config)||db.submissions.some(s=>canonical(s.config)===canonical(value.config))) return json(res,409,{success:false,error:'An identical config has already been submitted'});
    const item={...value,id:crypto.randomUUID(),token:crypto.randomBytes(24).toString('hex'),status:'pending',submissionType:'new',createdAt:new Date().toISOString()}; db.submissions.push(item); write(db);
    return json(res,201,{success:true,id:item.id,token:item.token,status:item.status,submissionType:item.submissionType});
  }
  if (req.method==='GET'&&pathname==='/submissions') { if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'}); const db=read(),status=url.searchParams.get('status'); return json(res,200,{success:true,submissions:db.submissions.filter(s=>!status||s.status===status).map(({token,...s})=>({...s,publishedFile:s.file||undefined,banned:Boolean(db.bans[String(s.userId)])}))}); }
  if (req.method==='GET'&&pathname==='/bans') { if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'}); const db=read(); return json(res,200,{success:true,...banRecord(db)}); }
  if (req.method==='POST'&&pathname==='/bans') {
    if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'});
    const value=await body(req); const id=String(value.userId||'').trim(); if(!id) return json(res,400,{success:false,error:'A Roblox UserId is required'});
    const db=read();
    if (value.banned===false) delete db.bans[id];
    else db.bans[id]={userId:id,username:String(value.username||'').slice(0,120),reason:String(value.reason||'').slice(0,500),at:new Date().toISOString()};
    write(db); return json(res,200,{success:true,...banRecord(db)});
  }
  if (req.method==='DELETE'&&pathname.startsWith('/bans/')) {
    if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'});
    const id=decodeURIComponent(pathname.slice('/bans/'.length)); const db=read(); delete db.bans[id]; write(db);
    return json(res,200,{success:true,...banRecord(db)});
  }
  if (req.method==='DELETE'&&pathname==='/public-configs') { if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'}); const value=await body(req); const file=await removePublished(value.file); return json(res,200,{success:true,status:'deleted',file}); }
  if (req.method==='PATCH'&&pathname.startsWith('/public-configs/')) {
    if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'});
    const file=decodeURIComponent(pathname.slice('/public-configs/'.length)); if(!validFile(file)) return json(res,400,{success:false,error:'Invalid public config file'});
    const file_=await editPublished(file,await body(req)); return json(res,200,{success:true,file:file_});
  }
  if (req.method==='DELETE'&&pathname.startsWith('/public-configs/')) { if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'}); const file=await removePublished(decodeURIComponent(pathname.slice('/public-configs/'.length))); return json(res,200,{success:true,status:'deleted',file}); }

  if (req.method==='GET'&&pathname==='/public-configs') {
    const db=read(); const list=await presetsWithActivity(db,url.searchParams.get('userId'));
    const sort=url.searchParams.get('sort');
    if (sort==='most-downloaded') list.sort((a,b)=>(b.downloads||0)-(a.downloads||0));
    else if (sort==='highest-rated') list.sort((a,b)=>(b.ratingPercentage||0)-(a.ratingPercentage||0)||(b.ratingCount||0)-(a.ratingCount||0));
    else if (sort==='newest') list.sort((a,b)=>String(b.lastPublishedAt||b.updatedAt||'').localeCompare(String(a.lastPublishedAt||a.updatedAt||'')));
    else if (sort==='recently-updated') list.sort((a,b)=>String(b.updatedAt||b.lastPublishedAt||'').localeCompare(String(a.updatedAt||a.lastPublishedAt||'')));
    return json(res,200,{success:true,presets:list});
  }
  const publicMatch=pathname.match(/^\/public-configs\/([^/]+)$/);
  if (req.method==='GET'&&publicMatch) {
    const file=decodeURIComponent(publicMatch[1]); if(!validFile(file)) return json(res,400,{success:false,error:'Invalid public config file'});
    const remote=await getGithubFile(file).catch(error=>{error.status=404;throw error;});
    const db=read(); db.downloads[file]=(Number(db.downloads[file])||0)+1; write(db);
    return raw(res,200,remote.decoded);
  }
  const versionsMatch=pathname.match(/^\/public-configs\/([^/]+)\/versions$/);
  if (req.method==='GET'&&versionsMatch) {
    const file=decodeURIComponent(versionsMatch[1]); const db=read();
    return json(res,200,{success:true,versions:Array.isArray(db.versions[file])?db.versions[file]:[]});
  }
  const ratingsMatch=pathname.match(/^\/public-configs\/([^/]+)\/ratings$/);
  if (req.method==='POST'&&ratingsMatch) {
    const file=decodeURIComponent(ratingsMatch[1]); const value=await body(req); const clientId=String(value.clientId||value.userId||'').slice(0,120);
    if(!validFile(file)||!clientId) return json(res,400,{success:false,error:'A clientId and public config file are required'});
    const db=read(); db.ratings[file]=db.ratings[file]||{};
    const rating=value.rating==='like'?1:value.rating==='dislike'?-1:0;
    if (rating===0) delete db.ratings[file][clientId]; else db.ratings[file][clientId]=rating;
    write(db); return json(res,200,{success:true,...ratingSummary(db,file,value.userId)});
  }
  const updatesMatch=pathname.match(/^\/public-configs\/([^/]+)\/updates$/);
  if (req.method==='POST'&&updatesMatch) {
    const file=decodeURIComponent(updatesMatch[1]); const value=await body(req);
    if(!validFile(file)||!validUpdate(value)) return json(res,400,{success:false,error:'Missing or invalid update details'});
    const db=read();
    if (db.bans[String(value.userId)]) return json(res,403,{success:false,error:'This account is banned from submitting configs'});
    const preset=(await presetsWithActivity(db)).find(p=>p.file===file); if(!preset) return json(res,404,{success:false,error:'The requested file is not a known Public Config'});
    const item={...value,id:crypto.randomUUID(),token:crypto.randomBytes(24).toString('hex'),status:'pending',submissionType:'update',targetFile:file,name:preset.name,displayName:value.displayName||preset.name,createdAt:new Date().toISOString()}; db.submissions.push(item); write(db);
    return json(res,201,{success:true,id:item.id,token:item.token,status:item.status,submissionType:item.submissionType,file,changelog:item.changelog});
  }
  if (req.method==='POST'&&pathname==='/public-configs') {
    if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'});
    const value=await body(req);
    const item={...value,submitter:value.submitter||value.credits||'maintainer',userId:value.userId||'0',id:crypto.randomUUID(),status:'accepted',submissionType:'direct',createdAt:new Date().toISOString()};
    if (!validSubmission(item)) return json(res,400,{success:false,error:'Missing or invalid config details'});
    const db=read(); const file=await publish(item,db); write(db);
    return json(res,201,{success:true,file});
  }

  const match=pathname.match(/^\/submissions\/([^/]+)$/), id=match&&decodeURIComponent(match[1]);
  if (req.method==='GET'&&id) { const item=read().submissions.find(s=>s.id===id); if(!item)return json(res,404,{success:false,error:'Not found'}); if(url.searchParams.get('token')!==item.token&&!admin(req)) return json(res,401,{success:false,error:'Invalid receipt'}); return json(res,200,{success:true,id:item.id,name:item.displayName||item.name,status:item.status,reason:item.reason,decidedAt:item.decidedAt,submissionType:item.submissionType,publishedFile:item.file||undefined,changelog:item.changelog}); }
  if (req.method==='DELETE'&&id) { if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'}); const db=read(),index=db.submissions.findIndex(s=>s.id===id); if(index<0)return json(res,404,{success:false,error:'Not found'}); db.submissions.splice(index,1); write(db); return json(res,200,{success:true,id}); }
  if (req.method==='PATCH'&&id) {
    if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'});
    const value=await body(req),db=read(),item=db.submissions.find(s=>s.id===id);
    if(!item)return json(res,404,{success:false,error:'Not found'});
    if (value.action==='edit') {
      for (const key of ['name','displayName','creator','description','tags','category','game']) if (value[key]!==undefined) item[key]=value[key];
      if (value.config&&typeof value.config==='object'&&!Array.isArray(value.config)) item.config=value.config;
      if (value.gui&&typeof value.gui==='object'&&!Array.isArray(value.gui)) item.gui=value.gui;
      write(db); return json(res,200,{success:true,id,status:item.status});
    }
    if (value.action==='ban'||value.action==='unban') {
      const userId=String(value.userId||item.userId||'').trim(); if(!userId) return json(res,400,{success:false,error:'A Roblox UserId is required'});
      if (value.action==='ban') db.bans[userId]={userId,username:String(value.username||item.submitter||'').slice(0,120),reason:String(value.reason||'').slice(0,500),at:new Date().toISOString()};
      else delete db.bans[userId];
      write(db); return json(res,200,{success:true,id,banned:value.action==='ban'});
    }
    if(!['accept','reject'].includes(value.action)||item.status!=='pending'||reviewing.has(id)) return json(res,409,{success:false,error:'Invalid decision or submission already reviewed'});
    reviewing.add(id);
    let decided;
    try {
      const overrides=value.overrides&&typeof value.overrides==='object'&&!Array.isArray(value.overrides)?value.overrides:{};
      for (const key of ['name','displayName','creator','description','tags','category','game','changelog']) if (overrides[key]!==undefined) item[key]=overrides[key];
      if (overrides.config&&typeof overrides.config==='object'&&!Array.isArray(overrides.config)) item.config=overrides.config;
      if (overrides.gui&&typeof overrides.gui==='object'&&!Array.isArray(overrides.gui)) item.gui=overrides.gui;
      // Updates keep publishing over their original catalogue file.
      if (item.submissionType==='update'&&item.targetFile) item.file=item.targetFile;
      const file=value.action==='accept'?await publish(item,db):undefined;
      // Publishing awaits external I/O. Re-read before committing so a submission received in
      // that window is not erased by this request's stale snapshot.
      const latest=read(); decided=latest.submissions.find(s=>s.id===id);
      if(!decided||decided.status!=='pending') throw Object.assign(Error('Submission changed while it was being reviewed'),{status:409});
      decided.file=file; decided.status=value.action==='accept'?'accepted':'declined'; decided.reason=String(value.reason||'').slice(0,5000); decided.decidedAt=new Date().toISOString(); write(latest);
    }
    finally { reviewing.delete(id); }
    return json(res,200,{success:true,id:decided.id,status:decided.status,file:decided.file,submissionType:decided.submissionType});
  }
  return json(res,404,{success:false,error:'Not found'});
 } catch(error) { return json(res,error.status||500,{success:false,error:error.message||'Operation failed',details:error.cause&&String(error.cause)}); } });
if(require.main===module) server.listen(PORT,()=>console.log(`Aether config backend listening on ${PORT}`));
module.exports={server,canonical,publish,removePublished,editPublished,validSubmission,validUpdate,body,read};
