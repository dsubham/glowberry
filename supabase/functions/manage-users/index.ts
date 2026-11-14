import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
// JWT is verified below using Auth; supports Supabase publishable client keys.
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
Deno.serve(async req=>{
 const respond=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...cors,'Content-Type':'application/json'}});
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return respond({error:'Method not allowed'},405);
 const token=req.headers.get('Authorization')?.replace(/^Bearer /i,'');if(!token)return respond({error:'Sign in first'},401);
 const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:auth,error:authError}=await admin.auth.getUser(token);if(authError||!auth.user)return respond({error:'Invalid session'},401);
 const {data:profile,error:roleError}=await admin.from('profiles').select('role').eq('id',auth.user.id).single();
 if(roleError||profile?.role!=='admin')return respond({error:'Administrator access required'},403);
 try{
 const body=await req.json();
 if(typeof body.password!=='string'||body.password.length<12||body.password.length>128)return respond({error:'Use a password of 12–128 characters'},400);
 if(body.action==='reset'){
  const {data:target,error}=await admin.from('profiles').select('role').eq('id',body.user_id).single();
  if(error||!target||!['parent','teacher'].includes(target.role))return respond({error:'Choose a parent or teacher account'},400);
  const reset=await admin.auth.admin.updateUserById(body.user_id,{password:body.password});if(reset.error)throw reset.error;
  return respond({ok:true});
 }
 if(body.action!=='create')return respond({error:'Invalid action'},400);
 const username=String(body.username||'').trim().toLowerCase();const fullName=String(body.full_name||'').trim();
 if(!/^[a-z0-9][a-z0-9._-]{2,39}$/.test(username)||!fullName||fullName.length>100||!['parent','teacher'].includes(body.role))return respond({error:'Check name, username and role'},400);
 const domain=Deno.env.get('AUTH_DOMAIN')||'accounts.glowberryutopia.in';
 const {data:created,error:createError}=await admin.auth.admin.createUser({email:`${username}@${domain}`,password:body.password,email_confirm:true});if(createError)throw createError;
 const inserted=await admin.from('profiles').insert({id:created.user.id,username,full_name:fullName,role:body.role});
 if(inserted.error){const cleanup=await admin.auth.admin.deleteUser(created.user.id);if(cleanup.error)console.error('Profile creation cleanup failed for user',created.user.id);throw inserted.error;}
 return respond({id:created.user.id,username,role:body.role},201);
 }catch(error){return respond({error:error instanceof Error?error.message:'Unable to update account'},400);}
});
