-- Adds editable public website copy to the existing booking configuration.
-- Public clients may read these texts; only the authenticated owner may update them
-- through the existing business_public_config RLS policy.

alter table public.business_public_config
  add column if not exists site_texts jsonb not null default '{}'::jsonb;

grant select on public.business_public_config to anon, authenticated;
grant update (site_texts) on public.business_public_config to authenticated;
