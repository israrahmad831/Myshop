-- Run this once in the Supabase SQL Editor for existing projects.
-- The helper functions below are created by policies.sql.

create table if not exists public.expenses (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null references public.shops(id) on delete cascade,
  amount     numeric(14,2) not null check (amount > 0),
  date       timestamptz not null default now(),
  category   text,
  note       text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_expenses_shop_date
  on public.expenses(shop_id, date desc);

alter table public.expenses enable row level security;

drop policy if exists expenses_select on public.expenses;
create policy expenses_select on public.expenses
  for select to authenticated using ((select public.is_shop_member(shop_id)));

drop policy if exists expenses_insert on public.expenses;
create policy expenses_insert on public.expenses
  for insert to authenticated
  with check ((select public.can_create_receipts(shop_id)));

drop policy if exists expenses_update on public.expenses;
create policy expenses_update on public.expenses
  for update to authenticated
  using ((select public.can_manage(shop_id)))
  with check ((select public.can_manage(shop_id)));

drop policy if exists expenses_delete on public.expenses;
create policy expenses_delete on public.expenses
  for delete to authenticated using ((select public.can_manage(shop_id)));

drop trigger if exists trg_expenses_updated_at on public.expenses;
create trigger trg_expenses_updated_at
  before update on public.expenses
  for each row execute function public.set_updated_at();