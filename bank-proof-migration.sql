-- Require a payment screenshot for new Bit and bank-transfer requests.
-- NOT VALID leaves existing historical rows untouched while enforcing future inserts and updates.
alter table public.appointments drop constraint if exists bit_requires_proof;
alter table public.appointments drop constraint if exists deposit_methods_require_proof;
alter table public.appointments
  add constraint deposit_methods_require_proof
  check (payment_method not in ('bit','bank') or proof_path is not null) not valid;

