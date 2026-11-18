begin;
insert into auth.users(id) values('eef00000-0000-0000-0000-000000000001'),('eef00000-0000-0000-0000-000000000002'),('eef00000-0000-0000-0000-000000000003'),('eef00000-0000-0000-0000-000000000004');
insert into public.profiles(id,username,full_name,role) values
 ('eef00000-0000-0000-0000-000000000001','test.workflow.admin','Admin','admin'),
 ('eef00000-0000-0000-0000-000000000002','test.workflow.teacher','Teacher','teacher'),
 ('eef00000-0000-0000-0000-000000000003','test.workflow.parent','Parent','parent'),
 ('eef00000-0000-0000-0000-000000000004','test.workflow.other','Other','parent');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"eef00000-0000-0000-0000-000000000001","role":"authenticated"}',true);
insert into public.students(id,name,parent_name,grade,joined_on) values('eef10000-0000-0000-0000-000000000001','Child','Parent','Nursery','2026-01-01');
insert into public.student_parents values('eef10000-0000-0000-0000-000000000001','eef00000-0000-0000-0000-000000000003');
insert into public.student_teachers values('eef10000-0000-0000-0000-000000000001','eef00000-0000-0000-0000-000000000002');
insert into public.staff_attendance(staff_id,attendance_date,status) values('eef00000-0000-0000-0000-000000000002','2026-11-18','present');
insert into public.school_documents(id,kind,title,data,status) values('eef20000-0000-0000-0000-000000000001','calendar','Public calendar','{"events":[]}','published'),('eef20000-0000-0000-0000-000000000002','admission','Private draft','{}','draft');
insert into public.school_documents(id,kind,title,student_id,data,status) values('eef20000-0000-0000-0000-000000000003','marksheet','Child marksheet','eef10000-0000-0000-0000-000000000001','{"subjects":[]}','published');
select set_config('request.jwt.claims','{"sub":"eef00000-0000-0000-0000-000000000002","role":"authenticated"}',true);
do $$ begin
 if (select count(*) from public.school_documents)<>2 then raise exception 'Teacher document read';end if;
 if (select count(*) from public.staff_attendance)<>1 then raise exception 'Teacher attendance read';end if;
 begin insert into public.staff_attendance(staff_id,attendance_date,status) values('eef00000-0000-0000-0000-000000000002','2026-11-17','absent');raise exception 'Teacher marked attendance' using errcode='23514';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"eef00000-0000-0000-0000-000000000003","role":"authenticated"}',true);
do $$ begin
 if (select count(*) from public.school_documents)<>2 then raise exception 'Linked parent document read';end if;
 if exists(select 1 from public.staff_attendance) then raise exception 'Parent can read staff attendance';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"eef00000-0000-0000-0000-000000000004","role":"authenticated"}',true);
do $$ begin
 if (select count(*) from public.school_documents)<>1 then raise exception 'Unlinked parent saw marksheet';end if;
end $$;
rollback;
select 'PASS: staff attendance and published document policies; test data rolled back' as result;
