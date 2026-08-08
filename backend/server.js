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
const read = () => { try { return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8')); } catch { return {submissions: []}; } };
const write = data => { const temp = `${DATA_FILE}.tmp`; fs.writeFileSync(temp, JSON.stringify(data, null, 2)); fs.renameSync(temp, DATA_FILE); };
const json = (res, status, value) => { res.writeHead(status, {'content-type':'application/json','access-control-allow-origin':'*','access-control-allow-headers':'authorization,content-type','access-control-allow-methods':'GET,POST,PATCH,DELETE,OPTIONS'}); res.end(JSON.stringify(value)); };
const body = req => new Promise((resolve, reject) => { let text=''; req.on('data', c => { text += c; if (text.length > MAX_BODY) reject(Error('Request body is too large')); }); req.on('end', () => { try { resolve(JSON.parse(text || '{}')); } catch { reject(Error('Invalid JSON')); } }); req.on('error', reject); });
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
async function putGithubFile(file, content, sha, message) {
  const {branch,headers}=github(); const response=await fetch(apiFor(file),{method:'PUT',headers:{...headers,'content-type':'application/json'},body:JSON.stringify({message,branch,content:Buffer.from(content).toString('base64'),...(sha&&{sha})})});
  if (!response.ok) throw Error(`GitHub write failed for configs/${file} (${response.status}): ${await response.text()}`);
}
async function deleteGithubFile(file, sha, message) {
  const {branch,headers}=github(); const response=await fetch(apiFor(file),{method:'DELETE',headers:{...headers,'content-type':'application/json'},body:JSON.stringify({message,branch,sha})});
  if (!response.ok) throw Error(`GitHub delete failed for configs/${file} (${response.status}): ${await response.text()}`);
}
const supplied = (value, fallback) => value !== undefined && value !== null && value !== '' && (!Array.isArray(value) || value.length) ? value : fallback;
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
  const url=new URL(req.url,'http://localhost'); const db=read();
  if (req.method==='POST'&&url.pathname==='/submissions') {
    const value=await body(req), required=['name','submitter','userId','creator','category','description','tags','game','config'];
    if (required.some(k=>value[k]==null)||!categories.has(value.category)||!Array.isArray(value.tags)||!value.tags.length||typeof value.config!=='object') return json(res,400,{success:false,error:'Missing or invalid config details'});
    if (matchesPublished(value.config)||db.submissions.some(s=>canonical(s.config)===canonical(value.config))) return json(res,409,{success:false,error:'An identical config has already been submitted'});
    const item={...value,id:crypto.randomUUID(),token:crypto.randomBytes(24).toString('hex'),status:'pending',createdAt:new Date().toISOString()}; db.submissions.push(item); write(db);
    return json(res,201,{success:true,id:item.id,token:item.token,status:item.status});
  }
  if (req.method==='GET'&&url.pathname==='/submissions') { if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'}); const status=url.searchParams.get('status'); return json(res,200,{success:true,submissions:db.submissions.filter(s=>!status||s.status===status).map(({token,...s})=>s)}); }
  if (req.method==='DELETE'&&url.pathname==='/public-configs') { if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'}); const value=await body(req); const file=await removePublished(value.file); return json(res,200,{success:true,status:'deleted',file}); }
  const match=url.pathname.match(/^\/submissions\/([^/]+)$/), item=match&&db.submissions.find(s=>s.id===decodeURIComponent(match[1]));
  if (req.method==='GET'&&item) { if(url.searchParams.get('token')!==item.token&&!admin(req)) return json(res,401,{success:false,error:'Invalid receipt'}); return json(res,200,{success:true,id:item.id,name:item.name,status:item.status,reason:item.reason,decidedAt:item.decidedAt}); }
  if (req.method==='PATCH'&&item) { if(!admin(req)) return json(res,401,{success:false,error:'Maintainer authentication required'}); const value=await body(req); if(!['accept','reject'].includes(value.action)||item.status!=='pending') return json(res,409,{success:false,error:'Invalid decision or submission already reviewed'}); if(value.action==='accept') item.file=await publish(item); item.status=value.action==='accept'?'accepted':'declined'; item.reason=String(value.reason||''); item.decidedAt=new Date().toISOString(); write(db); return json(res,200,{success:true,id:item.id,status:item.status,file:item.file}); }
  return json(res,404,{success:false,error:'Not found'});
 } catch(error) { return json(res,error.status||500,{success:false,error:error.message||'Operation failed',details:error.cause&&String(error.cause)}); } });
if(require.main===module) server.listen(PORT,()=>console.log(`Aether config backend listening on ${PORT}`));
module.exports={server,canonical,publish,removePublished};
