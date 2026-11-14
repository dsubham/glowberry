-- Run with `supabase db query --remote=PROJECT --file tests/rls.sql --yes`.
-- All test records roll back. The test does not create usable login credentials.
begin;
insert into auth.users(id) values ('ffff0000-0000-0000-0000-000000000001'),('ffff0000-0000-0000-0000-000000000002'),('ffff0000-0000-0000-0000-000000000003');
insert into public.profiles(id,username,full_name,role) values
('ffff0000-0000-0000-0000-000000000001','rls.test.parent','Test Parent','parent'),
('ffff0000-0000-0000-0000-000000000002','rls.test.teacher','Test Teacher','teacher'),
('ffff0000-0000-0000-0000-000000000003','rls.test.admin','Test Admin','admin');
insert into public.content(id,kind,title,body,status,audience) values
('ffff1000-0000-0000-0000-000000000001','announcement','RLS School','Test','published','school'),
('ffff1000-0000-0000-0000-000000000002','announcement','RLS Staff','Test','published','staff'),
('ffff1000-0000-0000-0000-000000000003','announcement','RLS Draft','Test','draft','school');
insert into public.media(content_id,path,name,mime) select id,id::text||'/test.jpg','test.jpg','image/jpeg' from public.content where id::text like 'ffff1000-%';
insert into storage.objects(bucket_id,name) select 'school-files',path from public.media where content_id::text like 'ffff1000-%';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"ffff0000-0000-0000-0000-000000000001","role":"authenticated"}',true);
do $$ declare affected integer; begin
 if (select count(*) from public.content where id::text like 'ffff1000-%')<>1 then raise exception 'Parent visibility failed';end if;
 if (select count(*) from public.profiles where id::text like 'ffff0000-%')<>1 then raise exception 'Parent directory privacy failed';end if;
 if (select count(*) from public.media where content_id::text like 'ffff1000-%')<>1 then raise exception 'Parent media privacy failed';end if;
 if (select count(*) from storage.objects where name like 'ffff1000-%')<>1 then raise exception 'Parent storage privacy failed';end if;
 begin
  update public.profiles set role='admin' where id=auth.uid();
  raise exception 'Role escalation succeeded';
 exception when insufficient_privilege then null;end;
 begin
  insert into public.content(kind,title,body) values('announcement','Forbidden','Test');
  raise exception 'Parent inserted content';
 exception when insufficient_privilege then null;end;
 update public.content set body='Forbidden' where id::text like 'ffff1000-%';get diagnostics affected=row_count;
 if affected<>0 then raise exception 'Parent edited content';end if;
 update public.profiles set phone='test' where id=auth.uid();get diagnostics affected=row_count;
 if affected<>1 then raise exception 'Parent cannot edit own safe profile fields';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"ffff0000-0000-0000-0000-000000000002","role":"authenticated"}',true);
do $$ begin
 if (select count(*) from public.content where id::text like 'ffff1000-%')<>2 then raise exception 'Teacher content visibility failed';end if;
 if (select count(*) from storage.objects where name like 'ffff1000-%')<>2 then raise exception 'Teacher file privacy failed';end if;
 begin
  insert into public.content(kind,title,body) values('announcement','Forbidden','Test');
  raise exception 'Teacher inserted content';
 exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"ffff0000-0000-0000-0000-000000000003","role":"authenticated"}',true);
do $$ begin
 if (select count(*) from public.content where id::text like 'ffff1000-%')<>3 then raise exception 'Admin content visibility failed';end if;
 if (select count(*) from storage.objects where name like 'ffff1000-%')<>3 then raise exception 'Admin file access failed';end if;
 if (select count(*) from public.profiles where id::text like 'ffff0000-%')<>3 then raise exception 'Admin directory access failed';end if;
end $$;
set local role anon;
select set_config('request.jwt.claims','{}',true);
do $$ begin
 if (select count(*) from public.school_settings)<>1 then raise exception 'Public school information missing';end if;
 begin
  perform * from public.content;
  raise exception 'Guest has content table privileges';
 exception when insufficient_privilege then null;end;
end $$;
rollback;
select 'PASS: parent, teacher, admin, guest, role escalation and private file boundaries; test data rolled back' as result;
