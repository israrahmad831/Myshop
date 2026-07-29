-- ============================================================================
-- Paint & Hardware Shop Manager — Supabase PostgreSQL Schema
-- ============================================================================
-- Design principles:
--   * UUID primary keys everywhere (gen_random_uuid()).
--   * Every domain table belongs to a shop (shop_id) so data is isolated.
--   * Row Level Security is enabled on every table (policies in policies.sql).
--   * Receipts and Khata are INDEPENDENT of inventory — nothing here mutates
--     product stock automatically. Stock is a manual field only.
--   * Money is stored as numeric(14,2) to avoid floating point errors.
--
-- Run order: run this file first, then policies.sql, then storage.sql.
-- ============================================================================

-- Required extensions --------------------------------------------------------
create extension if not exists "pgcrypto";      -- gen_random_uuid()
create extension if not exists "pg_trgm";        -- fast fuzzy/prefix search

-- ============================================================================
-- ENUM TYPES
-- ============================================================================
do $$ begin
  create type member_role as enum ('owner', 'admin', 'staff', 'viewer');
exception when duplicate_object then null; end $$;

do $$ begin
  create type invite_status as enum ('pending', 'accepted', 'declined', 'revoked');
exception when duplicate_object then null; end $$;

-- Khata transaction direction.
--   udhaar_given   : customer owes shop      (+ to receivable)
--   payment_received: customer pays shop      (- from receivable)
--   udhaar_taken   : shop owes customer      (+ to payable)
--   payment_given  : shop pays customer      (- from payable)
do $$ begin
  create type khata_type as enum (
    'udhaar_given', 'payment_received', 'udhaar_taken', 'payment_given'
  );
exception when duplicate_object then null; end $$;

-- ============================================================================
-- PROFILES  (mirror of auth.users, 1:1)
-- ============================================================================
-- Populated by a trigger on auth.users so we can display member names/avatars
-- without exposing the auth schema through the API.
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  full_name   text,
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ============================================================================
-- SHOPS
-- ============================================================================
create table if not exists public.shops (
  id             uuid primary key default gen_random_uuid(),
  owner_id       uuid not null references public.profiles(id) on delete restrict,
  name           text not null,
  address        text,
  phone          text,
  logo_url       text,
  currency       text not null default 'PKR',
  receipt_footer text,
  receipt_header_url text,          -- banner image shown atop printed receipts
  owner_name     text,              -- shown on the receipt stamp
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists idx_shops_owner on public.shops(owner_id);

-- ============================================================================
-- SHOP MEMBERS  (many-to-many between profiles and shops, with a role)
-- ============================================================================
create table if not exists public.shop_members (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null references public.shops(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       member_role not null default 'staff',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, user_id)
);
create index if not exists idx_shop_members_shop on public.shop_members(shop_id);
create index if not exists idx_shop_members_user on public.shop_members(user_id);

-- ============================================================================
-- SHOP INVITES  (invite by email before the user has accepted)
-- ============================================================================
create table if not exists public.shop_invites (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null references public.shops(id) on delete cascade,
  email      text not null,
  role       member_role not null default 'staff',
  status     invite_status not null default 'pending',
  invited_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (shop_id, email)
);
create index if not exists idx_shop_invites_shop on public.shop_invites(shop_id);
create index if not exists idx_shop_invites_email on public.shop_invites(lower(email));

-- ============================================================================
-- PRODUCTS  (information store only — stock is manual)
-- ============================================================================
create table if not exists public.products (
  id             uuid primary key default gen_random_uuid(),
  shop_id        uuid not null references public.shops(id) on delete cascade,
  image_url      text,
  name           text not null,
  brand          text,
  category       text,
  purchase_price numeric(14,2) not null default 0,
  selling_price  numeric(14,2) not null default 0,
  current_stock  numeric(14,2) not null default 0,   -- manual, never auto-changed
  unit           text default 'pcs',
  barcode        text,
  description     text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index if not exists idx_products_shop on public.products(shop_id);
create index if not exists idx_products_barcode on public.products(shop_id, barcode);
-- Trigram index powers instant "type-ahead" suggestions (e.g. "be" -> Berger...)
create index if not exists idx_products_name_trgm
  on public.products using gin (name gin_trgm_ops);
create index if not exists idx_products_category on public.products(shop_id, category);

-- ============================================================================
-- CUSTOMERS
-- ============================================================================
create table if not exists public.customers (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null references public.shops(id) on delete cascade,
  name       text not null,
  phone      text,
  address    text,
  notes      text,
  image_url  text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_customers_shop on public.customers(shop_id);
create index if not exists idx_customers_name_trgm
  on public.customers using gin (name gin_trgm_ops);
create index if not exists idx_customers_phone on public.customers(shop_id, phone);

-- ============================================================================
-- RECEIPTS  (independent records — DO NOT affect inventory)
-- ============================================================================
create table if not exists public.receipts (
  id             uuid primary key default gen_random_uuid(),
  shop_id        uuid not null references public.shops(id) on delete cascade,
  -- Human-facing sequential number, unique within a shop. Assigned by trigger.
  receipt_number bigint not null,
  customer_id    uuid references public.customers(id) on delete set null,
  customer_name  text,   -- denormalised snapshot (customer optional)
  customer_phone text,
  date           timestamptz not null default now(),
  discount       numeric(14,2) not null default 0,  -- receipt-level discount
  subtotal       numeric(14,2) not null default 0,  -- sum of line totals
  total          numeric(14,2) not null default 0,  -- subtotal - discount
  note           text,
  created_by     uuid references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (shop_id, receipt_number)
);
create index if not exists idx_receipts_shop on public.receipts(shop_id);
create index if not exists idx_receipts_shop_date on public.receipts(shop_id, date desc);
create index if not exists idx_receipts_customer on public.receipts(customer_id);

-- ============================================================================
-- RECEIPT ITEMS
-- ============================================================================
create table if not exists public.receipt_items (
  id           uuid primary key default gen_random_uuid(),
  receipt_id   uuid not null references public.receipts(id) on delete cascade,
  shop_id      uuid not null references public.shops(id) on delete cascade,
  product_id   uuid references public.products(id) on delete set null,
  product_name text not null,                    -- snapshot at time of sale
  quantity     numeric(14,2) not null default 1,
  unit         text,                              -- optional label, e.g. "kg"
  price        numeric(14,2) not null default 0, -- editable selling price
  discount     numeric(14,2) not null default 0, -- line-level discount
  line_total   numeric(14,2) not null default 0, -- quantity*price - discount
  created_at   timestamptz not null default now()
);
create index if not exists idx_receipt_items_receipt on public.receipt_items(receipt_id);
create index if not exists idx_receipt_items_shop on public.receipt_items(shop_id);
create index if not exists idx_receipt_items_product on public.receipt_items(product_id);

-- ============================================================================
-- KHATA (Udhaar) TRANSACTIONS  — independent of receipts & inventory
-- ============================================================================
create table if not exists public.khata_transactions (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null references public.shops(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  type        khata_type not null,
  amount      numeric(14,2) not null check (amount >= 0),
  date        timestamptz not null default now(),
  note        text,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists idx_khata_shop on public.khata_transactions(shop_id);
create index if not exists idx_khata_customer on public.khata_transactions(customer_id, date);

-- ============================================================================
-- SEARCH ANALYTICS  (powers "Top searched products" report)
-- ============================================================================
create table if not exists public.product_search_stats (
  id           uuid primary key default gen_random_uuid(),
  shop_id      uuid not null references public.shops(id) on delete cascade,
  product_id   uuid references public.products(id) on delete cascade,
  term         text,
  search_count bigint not null default 1,
  last_searched timestamptz not null default now(),
  unique (shop_id, product_id)
);
create index if not exists idx_search_stats_shop on public.product_search_stats(shop_id, search_count desc);

-- ============================================================================
-- HELPER: keep updated_at fresh
-- ============================================================================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'profiles','shops','shop_members','products','customers',
    'receipts','khata_transactions'
  ] loop
    execute format(
      'drop trigger if exists trg_%1$s_updated_at on public.%1$s;', t);
    execute format(
      'create trigger trg_%1$s_updated_at before update on public.%1$s
       for each row execute function public.set_updated_at();', t);
  end loop;
end $$;

-- ============================================================================
-- HELPER: mirror auth.users into public.profiles
-- ============================================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do update
    set email = excluded.email,
        full_name = coalesce(excluded.full_name, public.profiles.full_name),
        avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url);
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
-- HELPER: auto-add shop owner as an 'owner' member + accept pending invites
-- ============================================================================
create or replace function public.handle_new_shop()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.shop_members (shop_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict (shop_id, user_id) do nothing;
  return new;
end $$;

drop trigger if exists on_shop_created on public.shops;
create trigger on_shop_created
  after insert on public.shops
  for each row execute function public.handle_new_shop();

-- ============================================================================
-- HELPER: per-shop sequential receipt numbers (concurrency-safe)
-- ============================================================================
create or replace function public.assign_receipt_number()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  next_num bigint;
begin
  if new.receipt_number is not null and new.receipt_number > 0 then
    return new;  -- caller supplied one (e.g. offline id reconciliation)
  end if;
  -- Lock the shop row to serialise number assignment for this shop only.
  perform 1 from public.shops where id = new.shop_id for update;
  select coalesce(max(receipt_number), 0) + 1
    into next_num
    from public.receipts
   where shop_id = new.shop_id;
  new.receipt_number := next_num;
  return new;
end $$;

drop trigger if exists trg_assign_receipt_number on public.receipts;
create trigger trg_assign_receipt_number
  before insert on public.receipts
  for each row execute function public.assign_receipt_number();

-- ============================================================================
-- VIEW: customer khata balances (running balance per customer)
-- ============================================================================
-- Positive net_balance => customer owes the shop (receivable).
-- Negative net_balance => shop owes the customer (payable).
-- security_invoker=true so the view runs with the *querying user's* privileges
-- and RLS on the base tables applies (never bypasses it via the view owner).
create or replace view public.customer_khata_balances
with (security_invoker = true) as
select
  c.id            as customer_id,
  c.shop_id       as shop_id,
  c.name          as customer_name,
  coalesce(sum(case
    when k.type = 'udhaar_given'      then  k.amount
    when k.type = 'payment_received'  then -k.amount
    when k.type = 'udhaar_taken'      then -k.amount
    when k.type = 'payment_given'     then  k.amount
    else 0 end), 0) as net_balance
from public.customers c
left join public.khata_transactions k on k.customer_id = c.id
group by c.id, c.shop_id, c.name;
