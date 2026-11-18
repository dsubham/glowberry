import { createClient } from '@supabase/supabase-js';
export type Role = 'admin' | 'teacher' | 'parent' | 'guest';
export type Kind = 'announcement' | 'activity' | 'attachment';
export type Profile = { id:string; full_name:string; username:string; role:Role; phone:string; };
export type Media = { id:string; content_id:string; path:string; name:string; mime:string; url?:string };
export type Post = { id:string; kind:Kind; title:string; body:string; status:'draft'|'published'; audience:'school'|'staff'; class_name:string; event_date:string; created_at:string; media:Media[] };
export type Settings = { school_name:string; tagline:string; about:string; phone:string; email:string; address:string; hours:string };
export type SchoolData = { posts:Post[]; settings:Settings; profiles:Profile[] };
const url=import.meta.env.VITE_SUPABASE_URL, key=import.meta.env.VITE_SUPABASE_ANON_KEY;
export const supabase=url && key && !url.includes('YOUR_PROJECT') ? createClient(url,key) : null;
export function usernameEmail(username:string) { const normalized=username.trim().toLowerCase(); if(!/^[a-z0-9][a-z0-9._-]{2,39}$/.test(normalized)) throw new Error('Use a school username of 3–40 letters, numbers, dots, underscores or hyphens.'); return `${normalized}@${import.meta.env.VITE_AUTH_DOMAIN || 'accounts.glowberryutopia.in'}`; }
export const demoProfile:Profile={id:'demo-admin',full_name:'School Administrator',username:'admin',role:'admin',phone:''};
export const demoParentProfile:Profile={id:'demo-parent',full_name:'Glowberry Parent',username:'parent',role:'parent',phone:''};
const today=new Date().toLocaleDateString('en-CA');
const initial:SchoolData={settings:{school_name:'Glowberry Utopia',tagline:'Nurturing Curious Minds',about:'A joyful beginning for every little mind. At Glowberry Utopia Preschool & Daycare, we bring together Montessori and Reggio Emilia-inspired learning with our COGS-LIFE framework. Through play, discovery and caring connections, children find the confidence to explore their world.',phone:'+91 86387 95925',email:'principal@glowberryutopia.in',address:'214, Varthur Rd, Vinayaka Nagar, Gunjur Post, Bengaluru 560087 (Near Prestige Lake Side)',hours:'Please contact the school for current opening hours.'},profiles:[demoProfile],posts:[
{id:'sample-welcome',kind:'announcement',title:'A little hello to our Glowberry family',body:'Welcome to our school space! This is where we’ll share little milestones, important updates and everything that brings our learning community together.',status:'published',audience:'school',class_name:'All classes',event_date:today,created_at:new Date().toISOString(),media:[]},
{id:'sample-activity',kind:'activity',title:'Little hands, big discoveries',body:'A peek into our learning spaces, made for curious minds and joyful exploration. Add your own classroom photos and daily stories here.',status:'published',audience:'school',class_name:'All classes',event_date:today,created_at:new Date().toISOString(),media:[{id:'sample-media',content_id:'sample-activity',path:'',name:'Our learning space',mime:'image/jpeg',url:'/brand/glowberry-classroom.jpg'}]},
{id:'sample-calendar',kind:'attachment',title:'Academic calendar',body:'Upload the current academic calendar here, then publish it for your school families.',status:'draft',audience:'school',class_name:'All classes',event_date:today,created_at:new Date().toISOString(),media:[]}
]};
const DEMO_KEY='glowberry-admin-demo-v1';
export function readDemo():SchoolData {const stored=localStorage.getItem(DEMO_KEY); return stored?JSON.parse(stored):structuredClone(initial);}
export function writeDemo(data:SchoolData){localStorage.setItem(DEMO_KEY,JSON.stringify(data));}
export async function loadSchool():Promise<SchoolData> {
 if(!supabase) throw new Error('Supabase is not configured.');
 const [posts,media,settings,profiles]=await Promise.all([supabase.from('content').select('*').order('created_at',{ascending:false}),supabase.from('media').select('*'),supabase.from('school_settings').select('data').eq('id',1).single(),supabase.from('profiles').select('*')]);
 for(const response of [posts,media,settings,profiles]) if(response.error) throw response.error;
 const files=await Promise.all((media.data as Media[]).map(async file=>{const signed=await supabase!.storage.from('school-files').createSignedUrl(file.path,3600);if(signed.error)throw signed.error;return {...file,url:signed.data.signedUrl};}));
 return {posts:(posts.data as Post[]).map(post=>({...post,media:files.filter(m=>m.content_id===post.id)})),settings:settings.data!.data as Settings,profiles:profiles.data as Profile[]};
}
export function validateFiles(files:File[],kind:Kind){if(files.length>8)throw new Error('Choose up to 8 files per post.');for(const file of files){if(file.size>10*1024*1024)throw new Error(`${file.name} is over 10 MB.`);if(!['image/jpeg','image/png','image/webp','application/pdf'].includes(file.type))throw new Error('Please use JPG, PNG, WebP or PDF files.');if(kind==='activity'&&!file.type.startsWith('image/'))throw new Error('Daily activities accept photos only.');}}
export async function savePost(post:Post,files:File[],isNew:boolean){
 if(!supabase)throw new Error('Supabase is not configured.');validateFiles(files,post.kind);
 const {media,...row}=post; void media;
 const result=isNew?await supabase.from('content').insert(row):await supabase.from('content').update(row).eq('id',post.id);if(result.error)throw result.error;
 for(const file of files){const path=`${post.id}/${crypto.randomUUID()}.${file.type==='application/pdf'?'pdf':file.type.split('/')[1]}`;const upload=await supabase.storage.from('school-files').upload(path,file,{contentType:file.type,upsert:false});if(upload.error)throw new Error(`Post saved, but ${file.name} could not upload: ${upload.error.message}. Reopen the post to retry.`);const saved=await supabase.from('media').insert({content_id:post.id,path,name:file.name,mime:file.type});if(saved.error){await supabase.storage.from('school-files').remove([path]);throw new Error(`Post saved, but attachment metadata failed: ${saved.error.message}`);}}
}
export async function deletePost(post:Post){if(!supabase)throw new Error('Supabase is not configured.');const paths=post.media.map(m=>m.path);if(paths.length){const removed=await supabase.storage.from('school-files').remove(paths);if(removed.error)throw removed.error;}const deleted=await supabase.from('content').delete().eq('id',post.id);if(deleted.error)throw deleted.error;}
