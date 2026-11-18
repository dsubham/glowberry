begin;
insert into auth.users(id) values
 ('eeef0000-0000-0000-0000-000000000001'),('eeef0000-0000-0000-0000-000000000002'),
 ('eeef0000-0000-0000-0000-000000000003'),('eeef0000-0000-0000-0000-000000000004');
insert into public.profiles(id,username,full_name,role) values
 ('eeef0000-0000-0000-0000-000000000001','test.care.admin','Care Admin','admin'),
 ('eeef0000-0000-0000-0000-000000000002','test.care.teacher','Care Teacher','teacher'),
 ('eeef0000-0000-0000-0000-000000000003','test.care.parent','Care Parent','parent'),
 ('eeef0000-0000-0000-0000-000000000004','test.care.other','Other Parent','parent');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"eeef0000-0000-0000-0000-000000000001","role":"authenticated"}',true);
insert into public.students(id,name,parent_name,grade,joined_on) values
 ('eeef1000-0000-0000-0000-000000000001','Linked Child','Care Parent','Nursery','2026-01-01'),
 ('eeef1000-0000-0000-0000-000000000002','Other Child','Other Parent','Nursery','2026-01-01');
insert into public.student_teachers values('eeef1000-0000-0000-0000-000000000001','eeef0000-0000-0000-0000-000000000002');
insert into public.student_parents values('eeef1000-0000-0000-0000-000000000001','eeef0000-0000-0000-0000-000000000003');
insert into public.student_fee_months(student_id,fee_month,paid_on) values('eeef1000-0000-0000-0000-000000000001','2026-11-01','2026-11-03');
insert into public.student_daily_notes(id,student_id,note_date,body) values('eeef2000-0000-0000-0000-000000000001','eeef1000-0000-0000-0000-000000000001','2026-11-03','A lovely day.');
insert into public.student_reports(id,student_id,cadence,period_start,period_end,title,summary,status) values
 ('eeef3000-0000-0000-0000-000000000001','eeef1000-0000-0000-0000-000000000001','daily','2026-11-03','2026-11-03','Draft report','Private draft','draft'),
 ('eeef3000-0000-0000-0000-000000000002','eeef1000-0000-0000-0000-000000000001','weekly','2026-11-02','2026-11-08','Published report','Ready for family','published');
insert into public.student_report_images(id,report_id,path,caption,mime) values('eeef4000-0000-0000-0000-000000000001','eeef3000-0000-0000-0000-000000000002','eeef3000-0000-0000-0000-000000000002/photo.jpg','Activity','image/jpeg');
insert into storage.objects(bucket_id,name) values('report-images','eeef3000-0000-0000-0000-000000000002/photo.jpg');
select set_config('request.jwt.claims','{"sub":"eeef0000-0000-0000-0000-000000000002","role":"authenticated"}',true);
do $$ begin
 if (select count(*) from public.my_student_roster())<>1 then raise exception 'Teacher roster access';end if;
 if (select count(*) from public.students)<>0 then raise exception 'Teacher can read full student rows';end if;
 if (select count(*) from public.student_reports)<>2 then raise exception 'Teacher report access';end if;
end $$;
insert into public.student_fee_months(student_id,fee_month,paid_on) values('eeef1000-0000-0000-0000-000000000001','2026-10-01',null);
insert into public.student_daily_notes(student_id,note_date,body) values('eeef1000-0000-0000-0000-000000000001','2026-11-04','Teacher observation');
insert into public.student_reports(student_id,cadence,period_start,period_end,title,summary,status) values('eeef1000-0000-0000-0000-000000000001','daily','2026-11-04','2026-11-04','Teacher report','A good day','published');
do $$ begin
 begin insert into public.student_daily_notes(student_id,note_date,body) values('eeef1000-0000-0000-0000-000000000002','2026-11-04','Forbidden');raise exception 'Unassigned teacher wrote note' using errcode='23514';exception when insufficient_privilege then null;end;
 begin insert into public.student_fee_months(student_id,fee_month) values('eeef1000-0000-0000-0000-000000000002','2026-11-01');raise exception 'Unassigned teacher wrote fee' using errcode='23514';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"sub":"eeef0000-0000-0000-0000-000000000003","role":"authenticated"}',true);
do $$ begin
 if (select count(*) from public.my_student_roster())<>1 then raise exception 'Parent roster access';end if;
 if (select count(*) from public.student_fee_months)<>2 then raise exception 'Parent fee access';end if;
 if (select count(*) from public.student_reports)<>2 then raise exception 'Parent should see published reports only';end if;
 if (select count(*) from public.student_daily_notes)<>0 then raise exception 'Parent can read staff notes';end if;
 if (select count(*) from public.student_report_images)<>1 then raise exception 'Parent cannot read published report image';end if;
 if (select count(*) from storage.objects where bucket_id='report-images')<>1 then raise exception 'Parent cannot fetch published report photo';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"eeef0000-0000-0000-0000-000000000004","role":"authenticated"}',true);
do $$ begin
 if exists(select 1 from public.my_student_roster()) or exists(select 1 from public.student_fee_months) or exists(select 1 from public.student_reports) or exists(select 1 from public.student_report_images) then raise exception 'Unlinked parent can see child data';end if;
end $$;
rollback;
select 'PASS: assigned staff can write, linked parents see paid status and published reports only, unlinked accounts denied; test data rolled back' as result;
