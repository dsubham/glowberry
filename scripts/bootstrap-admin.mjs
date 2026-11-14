// Run locally after `npx supabase login`. Secret API keys remain in process memory.
import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { writeFileSync, readFileSync, existsSync } from 'node:fs';
import { createClient } from '@supabase/supabase-js';
const ref=process.argv[2], output=process.argv[3];
if(!/^[a-z]{20}$/.test(ref||'')||!output)throw new Error('Usage: node scripts/bootstrap-admin.mjs PROJECT_REF /absolute/private/credentials.txt');
if(!output.startsWith('/'))throw new Error('Use an absolute path outside the repository for credentials.');
const config=Object.fromEntries(readFileSync('.env.local','utf8').split('\n').filter(x=>x.includes('=')).map(x=>{const i=x.indexOf('=');return [x.slice(0,i),x.slice(i+1).trim()];}));
const url=`https://${ref}.supabase.co`, domain=config.VITE_AUTH_DOMAIN||'accounts.glowberryutopia.in';
const keys=JSON.parse(execFileSync('npx',['--yes','supabase','projects','api-keys',`--remote=${ref}`,'--reveal','--output','json'],{encoding:'utf8',stdio:['ignore','pipe','pipe']}));
const secret=keys.find(k=>k.name==='service_role')?.api_key;
if(!secret)throw new Error('Could not obtain the server key from the authenticated CLI.');
const server=createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false}});
const existing=await server.from('profiles').select('id').eq('username','admin').maybeSingle();if(existing.error)throw existing.error;
let password;
if(existing.data){
 if(!existsSync(output))throw new Error('Admin already exists. No existing password was changed.');
 const contents=readFileSync(output,'utf8');password=contents.match(/^Password: (.+)$/m)?.[1];if(!password)throw new Error('Cannot read the local bootstrap credentials.');
}else{
 if(existsSync(output))throw new Error('Credentials path already exists. Choose a new private output file.');
 password=randomBytes(24).toString('base64url');
 const created=await server.auth.admin.createUser({email:`admin@${domain}`,password,email_confirm:true});if(created.error)throw created.error;
 const profile=await server.from('profiles').insert({id:created.data.user.id,username:'admin',full_name:'Glowberry Administrator',role:'admin'});
 if(profile.error){await server.auth.admin.deleteUser(created.data.user.id);throw profile.error;}
 writeFileSync(output,`Glowberry Utopia — initial Admin credentials\nUsername: admin\nPassword: ${password}\nSign in: https://glowberry-school-admin.soaringlight2.chatgpt.site\n\nChange this generated password from My profile after signing in.\n`,{mode:0o600,flag:'wx'});
 console.log('Created school Admin. Initial credentials saved locally with owner-only file permissions.');
}
const client=createClient(url,config.VITE_SUPABASE_ANON_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
const login=await client.auth.signInWithPassword({email:`admin@${domain}`,password});if(login.error)throw login.error;
const [posts,settings,profiles]=await Promise.all([client.from('content').select('id'),client.from('school_settings').select('id'),client.from('profiles').select('username,role')]);
for(const result of [posts,settings,profiles])if(result.error)throw result.error;
console.log('PASS: Admin password sign-in, content, school settings and directory queries.');
let testId;
try{
 const testUser=`test.${randomBytes(6).toString('hex')}`, testPass=randomBytes(24).toString('base64url');
 const create=await client.functions.invoke('manage-users',{body:{action:'create',username:testUser,full_name:'Temporary integration test',role:'parent',password:testPass}});if(create.error)throw create.error;if(!create.data.id)throw new Error('Account function returned no user ID.');testId=create.data.id;
 const nextPass=randomBytes(24).toString('base64url');const reset=await client.functions.invoke('manage-users',{body:{action:'reset',user_id:testId,password:nextPass}});if(reset.error)throw reset.error;
 const parent=createClient(url,config.VITE_SUPABASE_ANON_KEY,{auth:{persistSession:false,autoRefreshToken:false}});
 const parentLogin=await parent.auth.signInWithPassword({email:`${testUser}@${domain}`,password:nextPass});if(parentLogin.error)throw parentLogin.error;
 const directory=await parent.from('profiles').select('id');if(directory.error||directory.data.length!==1||directory.data[0].id!==testId)throw new Error('Parent directory isolation failed.');
 const escalation=await parent.from('profiles').update({role:'admin'}).eq('id',testId);if(!escalation.error)throw new Error('Role escalation was not rejected.');
 const forbidden=await parent.functions.invoke('manage-users',{body:{action:'create',username:`${testUser}.x`,full_name:'Forbidden',role:'parent',password:testPass}});if(!forbidden.error)throw new Error('Parent account provisioning was not rejected.');
 const unauth=await fetch(`${url}/functions/v1/manage-users`,{method:'POST',headers:{apikey:config.VITE_SUPABASE_ANON_KEY,'Content-Type':'application/json'},body:'{}'});if(unauth.status!==401)throw new Error('Unauthenticated account provisioning was not rejected.');
 console.log('PASS: account creation, password reset, parent sign-in, private profile access, role escalation rejection, parent/unauthenticated function denial.');
}finally{
 if(testId){const removed=await server.auth.admin.deleteUser(testId);if(removed.error)throw new Error('Temporary account cleanup failed.');console.log('Temporary integration account removed.');}
 await client.auth.signOut();
}
