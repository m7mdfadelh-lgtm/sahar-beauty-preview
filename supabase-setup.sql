-- Sahar Beauty dashboard backend. Run this once in the Supabase SQL editor.
-- Use only the browser publishable/anon key in admin-config.js; never put a service-role key in a website.

create table if not exists public.business_public_config (
  id smallint primary key default 1 check (id = 1),
  owner_email text not null,
  service_durations jsonb not null default '{"bridal":40,"engagement":40,"event":40,"photoshoot":40}'::jsonb,
  bit_phone text not null default '0538800769',
  bit_payment_link text not null default '',
  deposit_ils integer not null default 100 check (deposit_ils = 100)
);

create table if not exists public.business_private_settings (
  id smallint primary key default 1 check (id = 1),
  owner_email text not null,
  bank_details text not null default ''
);

create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  owner_email text not null,
  client_name text not null,
  phone text not null,
  service text not null check (service in ('bridal','engagement','event','photoshoot')),
  appointment_date date not null,
  ready_time time not null,
  makeup_start time not null,
  duration_minutes integer not null check (duration_minutes between 5 and 480),
  payment_method text not null check (payment_method in ('bit','bank','cash')),
  deposit_ils integer not null default 100 check (deposit_ils = 100),
  proof_path text,
  status text not null default 'pending' check (status in ('pending','approved')),
  created_at timestamptz not null default now(),
  constraint bit_requires_proof check (payment_method <> 'bit' or proof_path is not null)
);

alter table public.business_public_config enable row level security;
alter table public.business_private_settings enable row level security;
alter table public.appointments enable row level security;

drop policy if exists "public can read booking config" on public.business_public_config;
create policy "public can read booking config" on public.business_public_config for select to anon, authenticated using (true);
drop policy if exists "owner manages booking config" on public.business_public_config;
create policy "owner manages booking config" on public.business_public_config for all to authenticated
  using (lower(auth.jwt()->>'email') = lower(owner_email))
  with check (lower(auth.jwt()->>'email') = lower(owner_email));

drop policy if exists "owner manages private settings" on public.business_private_settings;
create policy "owner manages private settings" on public.business_private_settings for all to authenticated
  using (lower(auth.jwt()->>'email') = lower(owner_email))
  with check (lower(auth.jwt()->>'email') = lower(owner_email));

drop policy if exists "clients can submit pending requests" on public.appointments;
create policy "clients can submit pending requests" on public.appointments for insert to anon, authenticated
  with check (
    owner_email = (select owner_email from public.business_public_config where id = 1)
    and status = 'pending' and deposit_ils = 100
    and (payment_method <> 'bit' or proof_path is not null)
  );
drop policy if exists "owner reads appointments" on public.appointments;
create policy "owner reads appointments" on public.appointments for select to authenticated
  using (lower(auth.jwt()->>'email') = lower(owner_email));
drop policy if exists "owner approves appointments" on public.appointments;
create policy "owner approves appointments" on public.appointments for update to authenticated
  using (lower(auth.jwt()->>'email') = lower(owner_email))
  with check (lower(auth.jwt()->>'email') = lower(owner_email));

grant select on public.business_public_config to anon, authenticated;
grant insert, update on public.business_public_config to authenticated;
grant select, insert, update on public.business_private_settings to authenticated;
grant insert (owner_email, client_name, phone, service, appointment_date, ready_time, makeup_start, duration_minutes, payment_method, deposit_ils, proof_path)
  on public.appointments to anon, authenticated;
grant select on public.appointments to authenticated;
grant update (status) on public.appointments to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('payment-proofs', 'payment-proofs', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "clients upload private payment proofs" on storage.objects;
create policy "clients upload private payment proofs" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'payment-proofs' and split_part(name, '/', 1) = 'pending');
drop policy if exists "owner reads private payment proofs" on storage.objects;
create policy "owner reads private payment proofs" on storage.objects for select to authenticated
  using (
    bucket_id = 'payment-proofs'
    and lower(auth.jwt()->>'email') = lower((select owner_email from public.business_public_config where id = 1))
  );
