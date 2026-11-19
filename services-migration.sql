-- Dynamic services for Sahar Beauty.
-- Existing services become the initial catalog. Removed services are archived (active=false), preserving appointment history.

create table if not exists public.services (
  id text primary key,
  names jsonb not null,
  descriptions jsonb not null default '{}'::jsonb,
  duration_minutes integer not null check (duration_minutes between 5 and 480),
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint services_id_format check (id ~ '^[a-z0-9_-]{2,64}$'),
  constraint services_names_object check (jsonb_typeof(names) = 'object'),
  constraint services_descriptions_object check (jsonb_typeof(descriptions) = 'object')
);

alter table public.services enable row level security;

insert into public.services (id, names, descriptions, duration_minutes, active, sort_order)
values
  ('bridal', '{"he":"איפור כלה","ar":"مكياج عروس","en":"Bridal Makeup"}', '{"he":"מראה מוקפד ועמיד ליום החתונה שלך.","ar":"إطلالة متقنة وثابتة ليوم زفافك.","en":"A considered, lasting look for your wedding day."}', 40, true, 1),
  ('engagement', '{"he":"איפור לאירוסין","ar":"مكياج خطوبة","en":"Engagement Makeup"}', '{"he":"זוהר עדין לתחילתו של סיפור חדש.","ar":"تألّق ناعم لبداية حكاية جديدة.","en":"Soft glamour for the beginning of your story."}', 40, true, 2),
  ('event', '{"he":"איפור לאירועים","ar":"مكياج مناسبات","en":"Event Makeup"}', '{"he":"איפור אלגנטי לחגיגות ולערבים מיוחדים.","ar":"مكياج أنيق للاحتفالات والأمسيات الخاصة.","en":"Polished makeup for celebrations and special evenings."}', 40, true, 3),
  ('photoshoot', '{"he":"איפור לצילומים","ar":"مكياج جلسات تصوير","en":"Photoshoot Makeup"}', '{"he":"מראה מצטלם ומאוזן בכל תאורה.","ar":"إطلالة متوازنة وجاهزة للتصوير في كل إضاءة.","en":"Camera-ready beauty, balanced in every light."}', 40, true, 4)
on conflict (id) do nothing;

-- Preserve any durations already configured in the original dashboard.
update public.services s
set duration_minutes = coalesce((c.service_durations->>s.id)::integer, s.duration_minutes)
from public.business_public_config c
where c.id = 1 and c.service_durations ? s.id;

drop policy if exists "public can read active services" on public.services;
create policy "public can read active services" on public.services for select to anon, authenticated
  using (active = true);
drop policy if exists "owner reads all services" on public.services;
create policy "owner reads all services" on public.services for select to authenticated
  using (exists (select 1 from public.business_private_settings p where p.id = 1 and lower(p.owner_email) = lower(auth.jwt()->>'email')));
drop policy if exists "owner inserts services" on public.services;
create policy "owner inserts services" on public.services for insert to authenticated
  with check (exists (select 1 from public.business_private_settings p where p.id = 1 and lower(p.owner_email) = lower(auth.jwt()->>'email')));
drop policy if exists "owner updates services" on public.services;
create policy "owner updates services" on public.services for update to authenticated
  using (exists (select 1 from public.business_private_settings p where p.id = 1 and lower(p.owner_email) = lower(auth.jwt()->>'email')))
  with check (exists (select 1 from public.business_private_settings p where p.id = 1 and lower(p.owner_email) = lower(auth.jwt()->>'email')));

grant select on public.services to anon, authenticated;
grant insert, update on public.services to authenticated;

alter table public.appointments drop constraint if exists appointments_service_check;
alter table public.appointments add column if not exists service_name text;
update public.appointments a
set service_name = coalesce(a.service_name, s.names->>'he', a.service)
from public.services s
where s.id = a.service and a.service_name is null;

drop policy if exists "clients can submit pending requests" on public.appointments;
create policy "clients can submit pending requests" on public.appointments for insert to anon, authenticated
  with check (
    status = 'pending'
    and deposit_ils = 100
    and (payment_method not in ('bit','bank') or proof_path is not null)
    and (service_name is null or length(trim(service_name)) > 0)
    and exists (select 1 from public.business_public_config c where c.id = 1)
    and exists (
      select 1 from public.services s
      where s.id = appointments.service
        and s.active = true
        and s.duration_minutes = appointments.duration_minutes
    )
  );

grant insert (client_name, phone, service, service_name, appointment_date, ready_time, makeup_start, duration_minutes, payment_method, deposit_ils, proof_path)
  on public.appointments to anon, authenticated;
