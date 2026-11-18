create or replace function public.check_student_link_role() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='student_teachers' then
  if not exists(select 1 from public.profiles where id=new.teacher_id and role='teacher') then raise exception 'Choose a teacher account'; end if;
 elsif tg_table_name='student_parents' then
  if not exists(select 1 from public.profiles where id=new.parent_id and role='parent') then raise exception 'Choose a parent account'; end if;
 end if;
 return new;
end $$;
