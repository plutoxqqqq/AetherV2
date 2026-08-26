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
    return data;
  } catch(error) {
    if (error&&error.code==='ENOENT') return {submissions:[]};
    const wrapped=Error('Submission database is unreadable; refusing to overwrite it'); wrapped.cause=error; throw wrapped;
  }
};
const write = data => { fs.mkdirSync(path.dirname(DATA_FILE),{recursive:true}); const temp=`${DATA_FILE}.${process.pid}.tmp`; fs.writeFileSync(temp,JSON.stringify(data,null,2)); fs.renameSync(temp,DATA_FILE); };
const json = (res, status, value) => { res.writeHead(status, {'content-type':'application/json','access-control-allow-origin':'*','access-control-allow-headers':'authorization,content-type','access-control-allow-methods':'GET,POST,PATCH,DELETE,OPTIONS'}); res.end(JSON.stringify(value)); };
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
  if (!process.env.GITHUB_TOKEN || !process.env.GITHUB_REPO) throw Error('GitHub publishing is not configured');
  return {branch:process.env.GITHUB_BRANCH || 'main',headers:{authorization:`Bearer ${process.env.GITHUB_TOKEN}`,accept:'application/vnd.github+json','user-agent':'aetherv2-review','x-github-api-version':'2022-11-28'}};
};
const apiFor = file => `https://api.github.com/repos/${process.env.GITHUB_REPO}/contents/configs/${file}`;
async function getGithubFile(file, required=true) {
  const {branch,headers}=github(); const response=await fetch(`${apiFor(file)}?ref=${encodeURIComponent(branch)}`,{headers});
  if (!response.ok) { if (!required && response.status===404) return null; throw Error(`Could not load configs/${file} from GitHub (${response.status})`); }
  const value=await response.json(); return {...value,decoded:Buffer.from(value.content.replace(/\n/g,''),'base64').toString()};
}

const safeSourcePath = value => {
  if (!nonEmptyString(value,300) || value.startsWith('/') || value.includes('\\') || value.split('/').some(segment => !segment || segment === '.' || segment === '..')) {
    const error=Error('Invalid source path'); error.status=400; throw error;
  }
  return value;
};
const sourceApiFor = (file, ref) => `https://api.github.com/repos/${process.env.GITHUB_REPO}/contents/${file}?ref=${encodeURIComponent(ref)}`;
async function getGithubSourceFile(file, ref) {
  const {headers}=github();
  const response=await fetch(sourceApiFor(file, ref),{headers});
  if (!response.ok) throw Error(`Could not load source file ${file} from GitHub (${response.status})`);
  const value=await response.json();
  if (value.type !== 'file' || typeof value.content !== 'string') throw Error('GitHub returned an invalid source file');
  return Buffer.from(value.content.replace(/\\n/g,''),'base64').toString();
}
async function getGithubCommit(ref) {
  const {headers}=github();
  const response=await fetch(`https://api.github.com/repos/${process.env.GITHUB_REPO}/commits/${encodeURIComponent(ref)}`,{headers});
  if (!response.ok) throw Error(`Could not resolve source ref ${ref} (${response.status})`);
  const value=await response.json();
  if (typeof value.sha !== 'string') throw Error('GitHub returned an invalid commit');
  return value.sha;
}
async function getGithubTree(ref) {
  const {headers}=github();
  const response=await fetch(`https://api.github.com/repos/${process.env.GITHUB_REPO}/git/trees/${encodeURIComponent(ref)}?recursive=1`,{headers});
  if (!response.ok) throw Error(`Could not load source tree (${response.status})`);
  return await response.text();
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
const reviewing = new Set();
async function publish(item) {
  const slug=item.name.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'')||item.id, file=`${slug}.json`;
  const existingFile=await getGithubFile(file,false);
  const presetRemote=await getGithubFile('presets.json'); const manifest=JSON.parse(presetRemote.decoded); const presets=Array.isArray(manifest.presets)?manifest.presets:[];
  const old=presets.find(p=>p.file===file)||presets.find(p=>String(p.name).toLowerCase()===String(item.name).toLowerCase())||{};
  const metadata={...old,name:item.name,file,credits:supplied(item.creator,old.credits),tags:supplied([item.category,...(item.tags||[])].filter(Boolean),old.tags),description:supplied(item.description,old.description)};
  const wrapper={name:item.name,credits:metadata.credits,tags:metadata.tags,description:metadata.description,game:item.game,config:JSON.stringify(item.config),...(item.gui&&{gui:JSON.stringify(item.gui)})};
  // Publish the payload first: the catalogue is never changed to point at a missing file.
  await putGithubFile(file,JSON.stringify(wrapper,null,2)+'\n',existingFile&&existingFile.sha,`Publish config: ${item.name}`);
  manifest.presets=presets.filter(p=>p.file!==file&&String(p.name).toLowerCase()!==String(item.name).toLowerCase()); manifest.presets.push(metadata);
  await putGithubFile('presets.json',JSON.stringify(manifest,null,2)+'\n',presetRemote.sha,`List config: ${item.name}`);
  return file;
}
async function removePublished(file) {
  if (typeof file!=='string'||!file.endsWith('.json')||file==='presets.json'||file.includes('/')||file.includes('\\')) throw Error('Invalid public config file');
  const presetRemote=await getGithubFile('presets.json'); const manifest=JSON.parse(presetRemote.decoded); const presets=Array.isArray(manifest.presets)?manifest.presets:[];
  if (!presets.some(p=>p.file===file)) { const error=Error('The requested file is not a known Public Config'); error.status=404; throw error; }
  const configRemote=await getGithubFile(file);
  // Remove the pointer first. A failed second operation can leave an unlisted orphan,
  // but never a catalogue entry that points at an unavailable file.
  manifest.presets=presets.filter(p=>p.file!==file);
  await putGithubFile('presets.json',JSON.stringify(manifest,null,2)+'\n',presetRemote.sha,`Unlist config: ${file}`);
  await deleteGithubFile(file,configRemote.sha,`Delete config: ${file}`);
  return file;
}

const server = http.createServer(async (req,res) => { try {
  if (req.method==='OPTIONS') return json(res,204,{success:true});
  const url=new URL(req.url,'http://localhost');
  if (req.method==='GET'&&url.pathname==='/source') {
    const file=safeSourcePath(url.searchParams.get('path'));
    const ref=nonEmptyString(url.searchParams.get('ref'),200)?url.searchParams.get('ref'):'main';
    const content=await getGithubSourceFile(file,ref);
    res.writeHead(200,{'content-type':'text/plain; charset=utf-8','cache-control':'no-store','access-control-allow-origin':'*'});
    return res.end(content);
  }
  if (req.method==='GET'&&url.pathname==='/commit') {
    const ref=nonEmptyString(url.searchParams.get('ref'),200)?url.searchParams.get('ref'):'main';
    const commit=await getGithubCommit(ref);
    res.writeHead(200,{'content-type':'text/plain; charset=utf-8','cache-control':'no-store','access-control-allow-origin':'*'});
    return res.end(commit);
  }
  if (req.method==='GET'&&url.pathname==='/tree') {
    const ref=nonEmptyString(url.searchParams.get('ref'),200)?url.searchParams.get('ref'):'main';
    const tree=await getGithubTree(ref);
    res.writeHead(200,{'content-type':'application/json; charset=utf-8','cache-control':'no-store','access-control-allow-origin':'*'});
    return res.end(tree);
  }
  if (req.method==='POST'&&url.pathname==='/submissions') {
    const value=await body(req);
    if (!validSubmission(value)) return json(res,400,{success:false,error:'Missing or invalid config details'});
    const db=read();
    if (matchesPublished(value.config)||db.submissions.some(s=>canonical(s.config)===canonical(value.config))) return json(res,409,{success:false,error:'An identical config has already been submitted'});
    const item={...value,id:crypto.randomUUID(),token:crypto.randomBytes(24).toString('hex'),status:'pending',createdAt:new Date().toISOString()}; db.submissions.push(item); write(db);
    return json(res,201,{success:true,id:item.id,token:item.token,status:item.status});
  }
  if (req.method==='GET'&&url.pathname==='/submissions') { if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'}); const db=read(),status=url.searchParams.get('status'); return json(res,200,{success:true,submissions:db.submissions.filter(s=>!status||s.status===status).map(({token,...s})=>s)}); }
  if (req.method==='DELETE'&&url.pathname==='/public-configs') { if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'}); const value=await body(req); const file=await removePublished(value.file); return json(res,200,{success:true,status:'deleted',file}); }
  const match=url.pathname.match(/^\/submissions\/([^/]+)$/), id=match&&decodeURIComponent(match[1]);
  if (req.method==='GET'&&id) { const item=read().submissions.find(s=>s.id===id); if(!item)return json(res,404,{success:false,error:'Not found'}); if(url.searchParams.get('token')!==item.token&&!admin(req)) return json(res,401,{success:false,error:'Invalid receipt'}); return json(res,200,{success:true,id:item.id,name:item.name,status:item.status,reason:item.reason,decidedAt:item.decidedAt}); }
  if (req.method==='PATCH'&&id) {
    if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'});
    const value=await body(req),db=read(),item=db.submissions.find(s=>s.id===id);
    if(!item)return json(res,404,{success:false,error:'Not found'});
    if(!['accept','reject'].includes(value.action)||item.status!=='pending'||reviewing.has(id)) return json(res,409,{success:false,error:'Invalid decision or submission already reviewed'});
    reviewing.add(id);
    let decided;
    try {
      const file=value.action==='accept'?await publish(item):undefined;
      // Publishing awaits external I/O. Re-read before committing so a submission received in
      // that window is not erased by this request's stale snapshot.
      const latest=read(); decided=latest.submissions.find(s=>s.id===id);
      if(!decided||decided.status!=='pending') throw Object.assign(Error('Submission changed while it was being reviewed'),{status:409});
      decided.file=file; decided.status=value.action==='accept'?'accepted':'declined'; decided.reason=String(value.reason||'').slice(0,5000); decided.decidedAt=new Date().toISOString(); write(latest);
    }
    finally { reviewing.delete(id); }
    return json(res,200,{success:true,id:decided.id,status:decided.status,file:decided.file});
  }
  return json(res,404,{success:false,error:'Not found'});
 } catch(error) { return json(res,error.status||500,{success:false,error:error.message||'Operation failed',details:error.cause&&String(error.cause)}); } });
if(require.main===module) server.listen(PORT,()=>console.log(`Aether config backend listening on ${PORT}`));
module.exports={server,canonical,publish,removePublished,validSubmission,body,read};
