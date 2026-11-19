-- Sahar Beauty: editable public website images.
alter table public.business_public_config
  add column if not exists site_images jsonb not null default '{}'::jsonb;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('site-images', 'site-images', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "public reads Sahar site images" on storage.objects;
create policy "public reads Sahar site images" on storage.objects for select to anon, authenticated
  using (bucket_id = 'site-images');
drop policy if exists "owner uploads Sahar site images" on storage.objects;
create policy "owner uploads Sahar site images" on storage.objects for insert to authenticated
  with check (bucket_id = 'site-images' and exists (
    select 1 from public.business_private_settings p
    where p.id = 1 and lower(p.owner_email) = lower(auth.jwt()->>'email')
  ));
drop policy if exists "owner deletes Sahar site images" on storage.objects;
create policy "owner deletes Sahar site images" on storage.objects for delete to authenticated
  using (bucket_id = 'site-images' and exists (
    select 1 from public.business_private_settings p
    where p.id = 1 and lower(p.owner_email) = lower(auth.jwt()->>'email')
  ));
