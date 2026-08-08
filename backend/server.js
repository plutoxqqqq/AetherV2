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
const json = (res, status, value) => { res.writeHead(status, {'content-type':'application/json','access-control-allow-origin':'*','access-control-allow-headers':'authorization,content-type','access-control-allow-methods':'GET,POST,PATCH,OPTIONS'}); res.end(JSON.stringify(value)); };
const body = req => new Promise((resolve, reject) => { let text=''; req.on('data', c => { text += c; if (text.length > MAX_BODY) reject(Error('too large')); }); req.on('end', () => { try { resolve(JSON.parse(text || '{}')); } catch { reject(Error('invalid JSON')); } }); req.on('error', reject); });
const admin = req => { const got=Buffer.from(req.headers.authorization || ''), expected=Buffer.from(`Bearer ${ADMIN_KEY}`); return Boolean(ADMIN_KEY) && got.length===expected.length && crypto.timingSafeEqual(got,expected); };
const canonical = value => JSON.stringify(value, (_, child) => child && typeof child === 'object' && !Array.isArray(child) ? Object.fromEntries(Object.keys(child).sort().map(key => [key, child[key]])) : child);
const matchesPublished = config => { const folder=path.resolve(__dirname,'..','configs'); try { return fs.readdirSync(folder).filter(file=>file.endsWith('.json')&&file!=='presets.json').some(file=>{ const wrapper=JSON.parse(fs.readFileSync(path.join(folder,file),'utf8')); const saved=typeof wrapper.config==='string'?JSON.parse(wrapper.config):wrapper.config; return canonical(saved)===canonical(config); }); } catch { return false; } };
async function publish(item) {
  if (!process.env.GITHUB_TOKEN || !process.env.GITHUB_REPO) throw Error('GitHub publishing is not configured');
  const slug = item.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || item.id;
  const file = `${slug}.json`, branch = process.env.GITHUB_BRANCH || 'main';
  const wrapper = {name:item.name, credits:item.creator, tags:[item.category, ...item.tags], description:item.description, game:item.game, config:JSON.stringify(item.config), gui:item.gui && JSON.stringify(item.gui)};
  const api = `https://api.github.com/repos/${process.env.GITHUB_REPO}/contents/configs/${file}`;
  const headers = {authorization:`Bearer ${process.env.GITHUB_TOKEN}`,accept:'application/vnd.github+json','user-agent':'aetherv2-review','x-github-api-version':'2022-11-28'};
  const current = await fetch(`${api}?ref=${encodeURIComponent(branch)}`, {headers});
  const existing = current.ok ? await current.json() : null;
  const put = await fetch(api, {method:'PUT',headers:{...headers,'content-type':'application/json'},body:JSON.stringify({message:`Publish config: ${item.name}`,branch,content:Buffer.from(JSON.stringify(wrapper,null,2)+'\n').toString('base64'),...(existing && {sha:existing.sha})})});
  if (!put.ok) throw Error(`GitHub config write failed (${put.status})`);
  const presetApi = `https://api.github.com/repos/${process.env.GITHUB_REPO}/contents/configs/presets.json`;
  const presetGet = await fetch(`${presetApi}?ref=${encodeURIComponent(branch)}`, {headers});
  if (!presetGet.ok) throw Error('Could not load presets.json');
  const presetRemote = await presetGet.json();
  const manifest = JSON.parse(Buffer.from(presetRemote.content.replace(/\n/g,''),'base64').toString());
  manifest.presets = (manifest.presets || []).filter(p => p.file !== file);
  manifest.presets.push({name:item.name,file,credits:item.creator,tags:[item.category,...item.tags],description:item.description});
  const saved = await fetch(presetApi,{method:'PUT',headers:{...headers,'content-type':'application/json'},body:JSON.stringify({message:`List config: ${item.name}`,branch,sha:presetRemote.sha,content:Buffer.from(JSON.stringify(manifest,null,2)+'\n').toString('base64')})});
  if (!saved.ok) throw Error(`GitHub manifest write failed (${saved.status})`);
  return file;
}
const server = http.createServer(async (req,res) => { try {
  if (req.method === 'OPTIONS') return json(res,204,{});
  const url = new URL(req.url, 'http://localhost'); const db=read();
  if (req.method === 'POST' && url.pathname === '/submissions') {
    const value=await body(req); const required=['name','submitter','userId','creator','category','description','tags','game','config'];
    if (required.some(k => value[k] == null) || !categories.has(value.category) || !Array.isArray(value.tags) || !value.tags.length || typeof value.config !== 'object') return json(res,400,{error:'Missing or invalid config details'});
    if (matchesPublished(value.config) || db.submissions.some(s => canonical(s.config) === canonical(value.config))) return json(res,409,{error:'An identical config has already been submitted'});
    const item={...value,id:crypto.randomUUID(),token:crypto.randomBytes(24).toString('hex'),status:'pending',createdAt:new Date().toISOString()}; db.submissions.push(item); write(db);
    return json(res,201,{id:item.id,token:item.token,status:item.status});
  }
  if (req.method === 'GET' && url.pathname === '/submissions') {
    if (!admin(req)) return json(res,401,{error:'Maintainer authentication required'});
    const status=url.searchParams.get('status'); return json(res,200,{submissions:db.submissions.filter(s=>!status||s.status===status).map(({token,...s})=>s)});
  }
  const match=url.pathname.match(/^\/submissions\/([^/]+)$/); const item=match&&db.submissions.find(s=>s.id===decodeURIComponent(match[1]));
  if (req.method === 'GET' && item) { if (url.searchParams.get('token') !== item.token && !admin(req)) return json(res,401,{error:'Invalid receipt'}); return json(res,200,{id:item.id,name:item.name,status:item.status,reason:item.reason,decidedAt:item.decidedAt}); }
  if (req.method === 'PATCH' && item) {
    if (!admin(req)) return json(res,401,{error:'Maintainer authentication required'}); const value=await body(req);
    if (!['accept','reject'].includes(value.action) || item.status!=='pending') return json(res,409,{error:'Invalid decision or submission already reviewed'});
    if (value.action==='accept') item.file=await publish(item); item.status=value.action==='accept'?'accepted':'declined'; item.reason=String(value.reason||''); item.decidedAt=new Date().toISOString(); write(db); return json(res,200,{id:item.id,status:item.status,file:item.file});
  }
  return json(res,404,{error:'Not found'});
 } catch (error) { return json(res,500,{error:error.message}); } });
if (require.main === module) server.listen(PORT,()=>console.log(`Aether config backend listening on ${PORT}`));
module.exports={server,canonical};
