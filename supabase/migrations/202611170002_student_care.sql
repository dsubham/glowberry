-- Student links are assigned by an administrator. Child records remain private.
create table public.student_teachers (
 student_id uuid not null references public.students(id) on delete cascade,
 teacher_id uuid not null references public.profiles(id) on delete cascade,
 primary key(student_id,teacher_id)
);
create table public.student_parents (
 student_id uuid not null references public.students(id) on delete cascade,
 parent_id uuid not null references public.profiles(id) on delete cascade,
 primary key(student_id,parent_id)
);
create function public.check_student_link_role() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='student_teachers' and not exists(select 1 from public.profiles where id=new.teacher_id and role='teacher') then raise exception 'Choose a teacher account'; end if;
 if tg_table_name='student_parents' and not exists(select 1 from public.profiles where id=new.parent_id and role='parent') then raise exception 'Choose a parent account'; end if;
 return new;
end $$;
create trigger student_teacher_role before insert or update on public.student_teachers for each row execute function public.check_student_link_role();
create trigger student_parent_role before insert or update on public.student_parents for each row execute function public.check_student_link_role();
alter table public.student_teachers enable row level security;
alter table public.student_parents enable row level security;
grant select,insert,delete on public.student_teachers,public.student_parents to authenticated;
grant all on public.student_teachers,public.student_parents to service_role;
create policy "Admin or linked teacher sees assignments" on public.student_teachers for select to authenticated using(public.my_school_role()='admin' or teacher_id=auth.uid());
create policy "Admin manages teacher assignments" on public.student_teachers for insert to authenticated with check(public.my_school_role()='admin');
create policy "Admin removes teacher assignments" on public.student_teachers for delete to authenticated using(public.my_school_role()='admin');
create policy "Admin or linked parent sees links" on public.student_parents for select to authenticated using(public.my_school_role()='admin' or parent_id=auth.uid());
create policy "Admin manages parent links" on public.student_parents for insert to authenticated with check(public.my_school_role()='admin');
create policy "Admin removes parent links" on public.student_parents for delete to authenticated using(public.my_school_role()='admin');
create index student_teachers_teacher_idx on public.student_teachers(teacher_id);
create index student_parents_parent_idx on public.student_parents(parent_id);

create function public.is_assigned_teacher(child_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.student_teachers where student_id=child_id and teacher_id=auth.uid() and public.my_school_role()='teacher')
$$;
create function public.is_linked_parent(child_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.student_parents where student_id=child_id and parent_id=auth.uid() and public.my_school_role()='parent')
$$;
revoke all on function public.is_assigned_teacher(uuid),public.is_linked_parent(uuid) from public;
grant execute on function public.is_assigned_teacher(uuid),public.is_linked_parent(uuid) to authenticated;

-- Give teachers and parents a limited roster without exposing the full students table.
create function public.my_student_roster()
returns table(id uuid,name text,grade text,joined_on date,active boolean,photo_path text)
language sql stable security definer set search_path='' as $$
 select s.id,s.name,s.grade,s.joined_on,s.active,s.photo_path from public.students s
 where (public.my_school_role()='teacher' and public.is_assigned_teacher(s.id))
    or (public.my_school_role()='parent' and public.is_linked_parent(s.id))
 order by s.name
$$;
revoke all on function public.my_student_roster() from public;
grant execute on function public.my_student_roster() to authenticated;
create policy "Linked families and teachers read student photos" on storage.objects for select to authenticated using (
 bucket_id='student-photos' and (
  public.is_assigned_teacher(split_part(name,'/',1)::uuid) or public.is_linked_parent(split_part(name,'/',1)::uuid)
 )
);

create table public.student_fee_months (
 student_id uuid not null references public.students(id) on delete cascade,
 fee_month date not null check(extract(day from fee_month)=1),
 paid_on date check(paid_on <= (now() at time zone 'Asia/Kolkata')::date),
 recorded_by uuid not null default auth.uid() references auth.users(id),
 updated_at timestamptz not null default now(),
 primary key(student_id,fee_month)
);
create function public.stamp_student_fee() returns trigger language plpgsql set search_path=public as $$
begin new.recorded_by=auth.uid();new.updated_at=now();return new;end $$;
create trigger student_fee_stamp before insert or update on public.student_fee_months for each row execute function public.stamp_student_fee();
alter table public.student_fee_months enable row level security;
grant select,insert,update,delete on public.student_fee_months to authenticated;
grant all on public.student_fee_months to service_role;
create policy "Staff and linked parents read fee status" on public.student_fee_months for select to authenticated using(public.my_school_role()='admin' or public.is_assigned_teacher(student_id) or public.is_linked_parent(student_id));
create policy "Assigned staff record fee status" on public.student_fee_months for insert to authenticated with check(public.my_school_role()='admin' or public.is_assigned_teacher(student_id));
create policy "Assigned staff correct fee status" on public.student_fee_months for update to authenticated using(public.my_school_role()='admin' or public.is_assigned_teacher(student_id)) with check(public.my_school_role()='admin' or public.is_assigned_teacher(student_id));
create policy "Assigned staff clear fee status" on public.student_fee_months for delete to authenticated using(public.my_school_role()='admin' or public.is_assigned_teacher(student_id));

create table public.student_daily_notes (
 id uuid primary key default gen_random_uuid(),
 student_id uuid not null references public.students(id) on delete cascade,
 note_date date not null check(note_date <= (now() at time zone 'Asia/Kolkata')::date),
 body text not null check(length(trim(body)) between 1 and 5000),
 author_id uuid not null default auth.uid() references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(student_id,note_date,author_id)
);
create function public.stamp_student_note() returns trigger language plpgsql set search_path=public as $$
begin
 if new.note_date < (select joined_on from public.students where id=new.student_id) then raise exception 'Note cannot precede admission'; end if;
 if tg_op='INSERT' then new.author_id=auth.uid(); else
  if new.student_id<>old.student_id or new.author_id<>old.author_id then raise exception 'Student and author cannot be changed'; end if;
 end if;
 new.updated_at=now();return new;
end $$;
create trigger student_note_stamp before insert or update on public.student_daily_notes for each row execute function public.stamp_student_note();
alter table public.student_daily_notes enable row level security;
grant select,insert,update,delete on public.student_daily_notes to authenticated;
grant all on public.student_daily_notes to service_role;
create policy "Assigned staff read daily notes" on public.student_daily_notes for select to authenticated using(public.my_school_role()='admin' or public.is_assigned_teacher(student_id));
create policy "Assigned staff write daily notes" on public.student_daily_notes for insert to authenticated with check((public.my_school_role()='admin' or public.is_assigned_teacher(student_id)) and author_id=auth.uid());
create policy "Authors or admins edit daily notes" on public.student_daily_notes for update to authenticated using(public.my_school_role()='admin' or (public.is_assigned_teacher(student_id) and author_id=auth.uid())) with check(public.my_school_role()='admin' or (public.is_assigned_teacher(student_id) and author_id=auth.uid()));
create policy "Authors or admins remove daily notes" on public.student_daily_notes for delete to authenticated using(public.my_school_role()='admin' or (public.is_assigned_teacher(student_id) and author_id=auth.uid()));
create index student_daily_notes_date_idx on public.student_daily_notes(student_id,note_date desc);

create table public.student_reports (
 id uuid primary key default gen_random_uuid(),
 student_id uuid not null references public.students(id) on delete cascade,
 cadence text not null check(cadence in ('daily','weekly')),
 period_start date not null,
 period_end date not null,
 title text not null check(length(trim(title)) between 1 and 120),
 summary text not null default '' check(length(summary)<=4000),
 learning text not null default '' check(length(learning)<=4000),
 wellbeing text not null default '' check(length(wellbeing)<=4000),
 next_steps text not null default '' check(length(next_steps)<=4000),
 status text not null default 'draft' check(status in ('draft','published')),
 created_by uuid not null default auth.uid() references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 published_at timestamptz,
 check(period_end>=period_start and (cadence='weekly' or period_end=period_start)),
 check(period_end<=period_start+6)
);
create function public.stamp_student_report() returns trigger language plpgsql set search_path=public as $$
begin
 if new.period_start < (select joined_on from public.students where id=new.student_id) then raise exception 'Report cannot precede admission'; end if;
 if new.period_start > (now() at time zone 'Asia/Kolkata')::date then raise exception 'Report cannot start in the future'; end if;
 if tg_op='INSERT' then new.created_by=auth.uid(); else
  if new.student_id<>old.student_id or new.created_by<>old.created_by then raise exception 'Student and creator cannot be changed'; end if;
 end if;
 if new.status='published' and (tg_op='INSERT' or old.status<>'published') then new.published_at=now(); end if;
 if new.status='draft' then new.published_at=null; end if;
 new.updated_at=now();return new;
end $$;
create trigger student_report_stamp before insert or update on public.student_reports for each row execute function public.stamp_student_report();
alter table public.student_reports enable row level security;
grant select,insert,update,delete on public.student_reports to authenticated;
grant all on public.student_reports to service_role;
create policy "Staff and linked parents read reports" on public.student_reports for select to authenticated using(public.my_school_role()='admin' or public.is_assigned_teacher(student_id) or (status='published' and public.is_linked_parent(student_id)));
create policy "Assigned staff create reports" on public.student_reports for insert to authenticated with check((public.my_school_role()='admin' or public.is_assigned_teacher(student_id)) and created_by=auth.uid());
create policy "Assigned staff edit reports" on public.student_reports for update to authenticated using(public.my_school_role()='admin' or public.is_assigned_teacher(student_id)) with check(public.my_school_role()='admin' or public.is_assigned_teacher(student_id));
create policy "Assigned staff remove reports" on public.student_reports for delete to authenticated using(public.my_school_role()='admin' or public.is_assigned_teacher(student_id));
create index student_reports_period_idx on public.student_reports(student_id,period_start desc);

create table public.student_report_images (
 id uuid primary key default gen_random_uuid(),
 report_id uuid not null references public.student_reports(id) on delete cascade,
 path text unique not null check(split_part(path,'/',1)=report_id::text),
 caption text not null default '' check(length(caption)<=180),
 mime text not null check(mime in ('image/jpeg','image/png')),
 created_at timestamptz not null default now()
);
alter table public.student_report_images enable row level security;
grant select,insert,update,delete on public.student_report_images to authenticated;
grant all on public.student_report_images to service_role;
create policy "Readers see permitted report images" on public.student_report_images for select to authenticated using(exists(select 1 from public.student_reports where id=report_id));
create policy "Staff add report images" on public.student_report_images for insert to authenticated with check(exists(select 1 from public.student_reports where id=report_id and (public.my_school_role()='admin' or public.is_assigned_teacher(student_id))));
create policy "Staff edit report images" on public.student_report_images for update to authenticated using(exists(select 1 from public.student_reports where id=report_id and (public.my_school_role()='admin' or public.is_assigned_teacher(student_id)))) with check(exists(select 1 from public.student_reports where id=report_id and (public.my_school_role()='admin' or public.is_assigned_teacher(student_id))));
create policy "Staff remove report images" on public.student_report_images for delete to authenticated using(exists(select 1 from public.student_reports where id=report_id and (public.my_school_role()='admin' or public.is_assigned_teacher(student_id))));
create index student_report_images_report_idx on public.student_report_images(report_id);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('report-images','report-images',false,5242880,array['image/jpeg','image/png']);
create policy "Permitted readers download report images" on storage.objects for select to authenticated using(bucket_id='report-images' and exists(select 1 from public.student_report_images i where i.path=name));
create policy "Assigned staff upload report images" on storage.objects for insert to authenticated with check(bucket_id='report-images' and exists(select 1 from public.student_reports r where r.id::text=split_part(name,'/',1) and (public.my_school_role()='admin' or public.is_assigned_teacher(r.student_id))));
create policy "Assigned staff remove report images" on storage.objects for delete to authenticated using(bucket_id='report-images' and exists(select 1 from public.student_report_images i join public.student_reports r on r.id=i.report_id where i.path=name and (public.my_school_role()='admin' or public.is_assigned_teacher(r.student_id))));
