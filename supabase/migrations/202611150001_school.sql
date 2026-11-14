-- Single-school foundation. Run once using Supabase SQL Editor or `supabase db push`.
create type public.school_role as enum ('admin','teacher','parent','guest');
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique not null check (username ~ '^[a-z0-9][a-z0-9._-]{2,39}$'),
 full_name text not null check (length(full_name) between 1 and 100),
 phone text not null default '', role public.school_role not null default 'parent'
);
create function public.my_school_role() returns public.school_role language sql stable security definer set search_path = public as $$ select role from public.profiles where id = auth.uid() $$;
revoke all on function public.my_school_role() from public;
grant execute on function public.my_school_role() to authenticated;
alter table public.profiles enable row level security;
create policy "Admin reads directory; users read own profile" on public.profiles for select to authenticated using (id=auth.uid() or public.my_school_role()='admin');
-- Column privileges prevent users from changing roles and usernames, including via REST.
grant select on public.profiles to authenticated;
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (full_name,phone) on public.profiles to authenticated;
create policy "Users update their own details" on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid());
create table public.content (
 id uuid primary key default gen_random_uuid(),
 kind text not null check (kind in ('announcement','activity','attachment')),
 title text not null check (length(title) between 1 and 180),
 body text not null check (length(body) between 1 and 10000),
 status text not null default 'draft' check (status in ('draft','published')),
 audience text not null default 'school' check (audience in ('school','staff')),
 class_name text not null default 'All classes' check (class_name in ('All classes','Daycare','Pre Nursery','Nursery','LKG','UKG')),
 event_date date not null default current_date, created_at timestamptz not null default now()
);
alter table public.content enable row level security;
create policy "Admins manage content" on public.content for all to authenticated using (public.my_school_role()='admin') with check (public.my_school_role()='admin');
create policy "Members read published content" on public.content for select to authenticated using (status='published' and (public.my_school_role()='teacher' or (public.my_school_role()='parent' and audience='school')));
grant select,insert,update,delete on public.content to authenticated;
create index content_feed_idx on public.content (kind,status,created_at desc);
create table public.media (
 id uuid primary key default gen_random_uuid(), content_id uuid not null references public.content(id) on delete cascade,
 path text unique not null, name text not null, mime text not null check (mime in ('image/jpeg','image/png','image/webp','application/pdf')),
 constraint content_scoped_path check (split_part(path,'/',1)=content_id::text)
);
create index media_content_idx on public.media(content_id);
alter table public.media enable row level security;
create policy "Admins manage media" on public.media for all to authenticated using (public.my_school_role()='admin') with check (public.my_school_role()='admin');
create policy "Members read permitted media" on public.media for select to authenticated using (exists(select 1 from public.content c where c.id=content_id));
grant select,insert,update,delete on public.media to authenticated;
create table public.school_settings (id integer primary key check(id=1), data jsonb not null);
alter table public.school_settings enable row level security;
create policy "School information is public" on public.school_settings for select to anon,authenticated using(true);
create policy "Admins edit school information" on public.school_settings for update to authenticated using(public.my_school_role()='admin') with check(public.my_school_role()='admin');
grant select on public.school_settings to anon,authenticated;
grant update on public.school_settings to authenticated;
insert into public.school_settings values(1,'{"school_name":"Glowberry Utopia","tagline":"Nurturing Curious Minds","about":"A joyful beginning at Glowberry Utopia Preschool & Daycare. Montessori and Reggio Emilia-inspired learning, guided by our COGS-LIFE framework.","phone":"+91 86387 95925","email":"principal@glowberryutopia.in","address":"214, Varthur Rd, Vinayaka Nagar, Gunjur Post, Bengaluru 560087 (Near Prestige Lake Side)","hours":"Please contact the school for current opening hours."}');
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('school-files','school-files',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf']);
create policy "Admin reads school files" on storage.objects for select to authenticated using (bucket_id='school-files' and public.my_school_role()='admin');
create policy "Admin uploads school files" on storage.objects for insert to authenticated with check (bucket_id='school-files' and public.my_school_role()='admin' and exists(select 1 from public.content c where c.id::text=split_part(name,'/',1)));
create policy "Admin deletes school files" on storage.objects for delete to authenticated using (bucket_id='school-files' and public.my_school_role()='admin');
create policy "Members read permitted school files" on storage.objects for select to authenticated using (bucket_id='school-files' and exists(select 1 from public.media m join public.content c on c.id=m.content_id where m.path=name));
-- School information and content refresh automatically in connected apps.
alter publication supabase_realtime add table public.content, public.media, public.school_settings;
