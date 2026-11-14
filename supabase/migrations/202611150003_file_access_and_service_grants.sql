-- Explicitly qualify the outer storage row: media also has a `name` column.
drop policy "Members read permitted school files" on storage.objects;
create policy "Members read permitted school files" on storage.objects for select to authenticated
using (bucket_id='school-files' and exists(
 select 1 from public.media m join public.content c on c.id=m.content_id
 where m.path=storage.objects.name
));
-- The server's service role bypasses RLS but still needs table privileges.
grant select,insert,update,delete on public.profiles,public.content,public.media,public.school_settings to service_role;
