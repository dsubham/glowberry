-- Do not inherit broad table grants from project-level default privileges.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update(full_name,phone) on public.profiles to authenticated;
revoke all on public.content, public.media from anon, authenticated;
grant select,insert,update,delete on public.content, public.media to authenticated;
revoke all on public.school_settings from anon, authenticated;
grant select on public.school_settings to anon, authenticated;
grant update on public.school_settings to authenticated;
