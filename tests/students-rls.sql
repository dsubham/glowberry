begin;
insert into auth.users(id) values('eeee0000-0000-0000-0000-000000000001'),('eeee0000-0000-0000-0000-000000000002'),('eeee0000-0000-0000-0000-000000000003');
insert into public.profiles(id,username,full_name,role) values('eeee0000-0000-0000-0000-000000000001','test.student.admin','Test','admin'),('eeee0000-0000-0000-0000-000000000002','test.student.parent','Test','parent'),('eeee0000-0000-0000-0000-000000000003','test.student.teacher','Test','teacher');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"eeee0000-0000-0000-0000-000000000001","role":"authenticated"}',true);
insert into public.students(id,name,parent_name,grade,joined_on) values('eeee1000-0000-0000-0000-000000000001','Test Child','Test Parent','Nursery','2026-01-01');
insert into public.attendance(student_id,attendance_date,status) values('eeee1000-0000-0000-0000-000000000001','2026-01-02','present');
insert into public.attendance(student_id,attendance_date,status) values('eeee1000-0000-0000-0000-000000000001','2026-01-02','late') on conflict(student_id,attendance_date) do update set status=excluded.status;
insert into storage.objects(bucket_id,name) values('student-photos','eeee1000-0000-0000-0000-000000000001/photo.jpg');
do $$ begin
 if (select count(*) from public.attendance where student_id='eeee1000-0000-0000-0000-000000000001')<>1 then raise exception 'Duplicate attendance';end if;
 if not exists(select 1 from public.attendance where student_id='eeee1000-0000-0000-0000-000000000001' and status='late' and recorded_by=auth.uid()) then raise exception 'Attendance correction failed';end if;
 begin
  update public.students set joined_on='2026-01-03' where id='eeee1000-0000-0000-0000-000000000001';
  raise exception 'Invalid admission allowed' using errcode='23514';
 exception when raise_exception then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"eeee0000-0000-0000-0000-000000000002","role":"authenticated"}',true);
do $$ begin
 if exists(select 1 from public.students) or exists(select 1 from public.attendance) or exists(select 1 from storage.objects where bucket_id='student-photos') then raise exception 'Parent can read private student data';end if;
 begin
 insert into public.students(name,parent_name,grade) values('Forbidden','Forbidden','Nursery');
 raise exception 'Parent write allowed' using errcode='23514';
 exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"eeee0000-0000-0000-0000-000000000003","role":"authenticated"}',true);
do $$ begin
 if exists(select 1 from public.students) or exists(select 1 from public.attendance) or exists(select 1 from storage.objects where bucket_id='student-photos') then raise exception 'Teacher can read private student data';end if;
end $$;
set local role anon;
do $$ begin
 begin perform * from public.students;raise exception 'Guest access allowed' using errcode='23514';exception when insufficient_privilege then null;end;
end $$;
rollback;
select 'PASS: Admin CRUD, attendance correction, admission consistency, parent/teacher/guest privacy; test data rolled back' as result;
