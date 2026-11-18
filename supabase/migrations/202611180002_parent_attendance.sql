-- Linked parents can view their own child's attendance history.
create policy "Linked parents read child attendance" on public.attendance
 for select to authenticated
 using (public.my_school_role()='parent' and public.is_linked_parent(student_id));
