create table public.staff_attendance (
 staff_id uuid not null references public.profiles(id) on delete cascade,
 attendance_date date not null check(attendance_date <= (now() at time zone 'Asia/Kolkata')::date),
 status text not null check(status in ('present','absent','leave')),
 note text not null default '' check(length(note)<=500),
 marked_by uuid not null default auth.uid() references auth.users(id),
 updated_at timestamptz not null default now(),
 primary key(staff_id,attendance_date)
);
create function public.stamp_staff_attendance() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.profiles where id=new.staff_id and role in ('admin','teacher')) then raise exception 'Choose an administrator or teacher';end if;
 new.marked_by=auth.uid();new.updated_at=now();return new;
end $$;
create trigger staff_attendance_stamp before insert or update on public.staff_attendance for each row execute function public.stamp_staff_attendance();
alter table public.staff_attendance enable row level security;
grant select,insert,update,delete on public.staff_attendance to authenticated;
grant all on public.staff_attendance to service_role;
create policy "Admins and staff see attendance" on public.staff_attendance for select to authenticated using(public.my_school_role()='admin' or staff_id=auth.uid());
create policy "Admins mark staff attendance" on public.staff_attendance for insert to authenticated with check(public.my_school_role()='admin');
create policy "Admins correct staff attendance" on public.staff_attendance for update to authenticated using(public.my_school_role()='admin') with check(public.my_school_role()='admin');
create policy "Admins clear staff attendance" on public.staff_attendance for delete to authenticated using(public.my_school_role()='admin');
create index staff_attendance_date_idx on public.staff_attendance(attendance_date);

create table public.school_documents (
 id uuid primary key default gen_random_uuid(),
 kind text not null check(kind in ('calendar','timetable','admission','marksheet')),
 title text not null check(length(trim(title)) between 1 and 180),
 student_id uuid references public.students(id) on delete cascade,
 data jsonb not null default '{}'::jsonb,
 status text not null default 'draft' check(status in ('draft','published')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check((kind='marksheet' and student_id is not null) or (kind<>'marksheet' and student_id is null))
);
create function public.stamp_school_document() returns trigger language plpgsql set search_path=public as $$
begin new.updated_at=now();return new;end $$;
create trigger school_document_stamp before insert or update on public.school_documents for each row execute function public.stamp_school_document();
alter table public.school_documents enable row level security;
grant select,insert,update,delete on public.school_documents to authenticated;
grant all on public.school_documents to service_role;
create policy "Admins manage school documents" on public.school_documents for all to authenticated using(public.my_school_role()='admin') with check(public.my_school_role()='admin');
create policy "Families read published school documents" on public.school_documents for select to authenticated using(status='published' and (
 (student_id is null and public.my_school_role() in ('parent','teacher')) or
 (student_id is not null and (public.is_linked_parent(student_id) or public.is_assigned_teacher(student_id)))
));
create index school_documents_kind_idx on public.school_documents(kind,status,updated_at desc);
