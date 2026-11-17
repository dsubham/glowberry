create table public.students (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(trim(name)) between 1 and 100),
 parent_name text not null check(length(trim(parent_name)) between 1 and 100),
 parent_phone text not null default '' check(length(parent_phone)<=30),
 grade text not null check(grade in ('Daycare','Pre Nursery','Nursery','LKG','UKG')),
 admission_number text unique check(length(admission_number) between 1 and 40),
 date_of_birth date, joined_on date not null default current_date,
 active boolean not null default true,
 photo_path text check(photo_path is null or split_part(photo_path,'/',1)=id::text),
 notes text not null default '' check(length(notes)<=2000),
 created_at timestamptz not null default now(),
 check(date_of_birth is null or date_of_birth<=joined_on)
);
create table public.attendance (
 student_id uuid not null references public.students(id) on delete restrict,
 attendance_date date not null check(attendance_date<= (now() at time zone 'Asia/Kolkata')::date),
 status text not null check(status in ('present','absent','late','excused')),
 recorded_by uuid not null default auth.uid() references auth.users(id),
 updated_at timestamptz not null default now(),
 primary key(student_id,attendance_date)
);
create function public.stamp_attendance() returns trigger language plpgsql set search_path=public as $$
begin
 if new.attendance_date < (select joined_on from public.students where id=new.student_id) then raise exception 'Attendance cannot precede admission'; end if;
 new.recorded_by=auth.uid(); new.updated_at=now(); return new;
end $$;
create trigger attendance_stamp before insert or update on public.attendance for each row execute function public.stamp_attendance();
alter table public.students enable row level security;
alter table public.attendance enable row level security;
revoke all on public.students,public.attendance from anon,authenticated;
grant select,insert,update on public.students to authenticated;
grant select,insert,update,delete on public.attendance to authenticated;
grant all on public.students,public.attendance to service_role;
create policy "Admins manage students" on public.students for all to authenticated using(public.my_school_role()='admin') with check(public.my_school_role()='admin');
create policy "Admins manage attendance" on public.attendance for all to authenticated using(public.my_school_role()='admin') with check(public.my_school_role()='admin');
create index students_grade_idx on public.students(grade,active);
create index attendance_date_idx on public.attendance(attendance_date);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('student-photos','student-photos',false,5242880,array['image/jpeg','image/png','image/webp']);
create policy "Admins read student photos" on storage.objects for select to authenticated using(bucket_id='student-photos' and public.my_school_role()='admin');
create policy "Admins upload student photos" on storage.objects for insert to authenticated with check(bucket_id='student-photos' and public.my_school_role()='admin');
create policy "Admins remove student photos" on storage.objects for delete to authenticated using(bucket_id='student-photos' and public.my_school_role()='admin');
-- Changing admission must not invalidate attendance already recorded.
create function public.validate_student_admission() returns trigger language plpgsql set search_path=public as $$
begin
 if new.joined_on > (now() at time zone 'Asia/Kolkata')::date then raise exception 'Admission date cannot be in the future'; end if;
 if exists(select 1 from public.attendance where student_id=new.id and attendance_date<new.joined_on) then raise exception 'Admission cannot be after existing attendance records'; end if;
 return new;
end $$;
create trigger student_admission before insert or update on public.students for each row execute function public.validate_student_admission();
