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
-- ============================================================================
-- Paint & Hardware Shop Manager — Row Level Security Policies
-- ============================================================================
-- Access model:
--   * A user only ever sees data for shops they are a member of.
--   * Roles: owner > admin > staff > viewer.
--       owner  : everything, incl. members & shop settings & delete shop.
--       admin  : manage products, receipts, customers, khata.
--       staff  : create receipts, view products/customers/khata.
--       viewer : read-only.
--   * Every policy is shop-scoped via the helper functions below.
--
-- IMPORTANT authoring rules (Supabase best practice — required for correctness
-- and performance):
--   * Every policy targets a role explicitly: `to authenticated`.
--   * Every call to an auth helper is wrapped in a scalar sub-select
--     `(select auth.uid())` / `(select public.is_shop_member(...))` so it is
--     evaluated once per statement (an initplan) rather than inline per row.
--     Inline `auth.uid()` in an INSERT/UPDATE WITH CHECK can be rejected.
--
-- Run this AFTER schema.sql.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helper functions (SECURITY DEFINER to avoid recursive RLS on shop_members)
-- ---------------------------------------------------------------------------
create or replace function public.is_shop_member(p_shop uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.shop_members m
    where m.shop_id = p_shop and m.user_id = (select auth.uid())
  );
$$;

-- Returns the caller's role in a shop (null if not a member).
create or replace function public.shop_role(p_shop uuid)
returns member_role language sql stable security definer set search_path = public as $$
  select m.role from public.shop_members m
  where m.shop_id = p_shop and m.user_id = (select auth.uid())
  limit 1;
$$;

-- Can the caller write "management" data (products/customers/khata)?  admin+.
create or replace function public.can_manage(p_shop uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.shop_role(p_shop) in ('owner', 'admin');
$$;

-- Can the caller create receipts?  staff and above.
create or replace function public.can_create_receipts(p_shop uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.shop_role(p_shop) in ('owner', 'admin', 'staff');
$$;

create or replace function public.is_shop_owner(p_shop uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.shop_role(p_shop) = 'owner';
$$;

-- Caller's email from the JWT (used for invite matching).
create or replace function public.jwt_email()
returns text language sql stable as $$
  select lower(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email');
$$;

-- ============================================================================
-- Enable RLS on all tables
-- ============================================================================
alter table public.profiles              enable row level security;
alter table public.shops                 enable row level security;
alter table public.shop_members          enable row level security;
alter table public.shop_invites          enable row level security;
alter table public.products              enable row level security;
alter table public.customers             enable row level security;
alter table public.receipts              enable row level security;
alter table public.receipt_items         enable row level security;
alter table public.khata_transactions    enable row level security;
alter table public.product_search_stats  enable row level security;

-- ============================================================================
-- PROFILES
-- ============================================================================
drop policy if exists profiles_select_self_or_shopmate on public.profiles;
create policy profiles_select_self_or_shopmate on public.profiles
  for select to authenticated using (
    id = (select auth.uid())
    or exists (  -- can see profiles of people who share a shop with me
      select 1 from public.shop_members me
      join public.shop_members them on them.shop_id = me.shop_id
      where me.user_id = (select auth.uid()) and them.user_id = public.profiles.id
    )
  );

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- ============================================================================
-- SHOPS
-- ============================================================================
-- Owner is allowed directly (owner_id) AND via membership. The direct owner
-- check matters for INSERT ... RETURNING (return=representation): the owner's
-- shop_members row is created by an AFTER-INSERT trigger that hasn't fired yet
-- when the RETURNING row is evaluated, so without this the owner cannot "see"
-- their just-created shop and the insert is rejected.
drop policy if exists shops_select_member on public.shops;
create policy shops_select_member on public.shops
  for select to authenticated
  using (owner_id = (select auth.uid()) or (select public.is_shop_member(id)));

drop policy if exists shops_insert_self_owner on public.shops;
create policy shops_insert_self_owner on public.shops
  for insert to authenticated with check (owner_id = (select auth.uid()));

drop policy if exists shops_update_admin on public.shops;
create policy shops_update_admin on public.shops
  for update to authenticated
  using ((select public.can_manage(id))) with check ((select public.can_manage(id)));

drop policy if exists shops_delete_owner on public.shops;
create policy shops_delete_owner on public.shops
  for delete to authenticated using ((select public.is_shop_owner(id)));

-- ============================================================================
-- SHOP MEMBERS  (only owner can mutate; members can read their shop's roster)
-- ============================================================================
drop policy if exists members_select on public.shop_members;
create policy members_select on public.shop_members
  for select to authenticated using ((select public.is_shop_member(shop_id)));

drop policy if exists members_insert_owner on public.shop_members;
create policy members_insert_owner on public.shop_members
  for insert to authenticated with check ((select public.is_shop_owner(shop_id)));

drop policy if exists members_update_owner on public.shop_members;
create policy members_update_owner on public.shop_members
  for update to authenticated
  using ((select public.is_shop_owner(shop_id))) with check ((select public.is_shop_owner(shop_id)));

-- Owner can remove anyone; a member can remove (leave) themselves.
drop policy if exists members_delete on public.shop_members;
create policy members_delete on public.shop_members
  for delete to authenticated
  using ((select public.is_shop_owner(shop_id)) or user_id = (select auth.uid()));

-- ============================================================================
-- SHOP INVITES  (owner manages; invitee can see invites addressed to them)
-- ============================================================================
drop policy if exists invites_select on public.shop_invites;
create policy invites_select on public.shop_invites
  for select to authenticated using (
    (select public.is_shop_owner(shop_id))
    or lower(email) = (select public.jwt_email())
  );

drop policy if exists invites_insert_owner on public.shop_invites;
create policy invites_insert_owner on public.shop_invites
  for insert to authenticated with check ((select public.is_shop_owner(shop_id)));

drop policy if exists invites_update on public.shop_invites;
create policy invites_update on public.shop_invites
  for update to authenticated using (
    (select public.is_shop_owner(shop_id))
    or lower(email) = (select public.jwt_email())
  );

drop policy if exists invites_delete_owner on public.shop_invites;
create policy invites_delete_owner on public.shop_invites
  for delete to authenticated using ((select public.is_shop_owner(shop_id)));

-- ============================================================================
-- Domain tables (spelled out per table for clarity/auditing)
-- read  : any member;  write: admin+ (or receipts: staff+)
-- ============================================================================

-- PRODUCTS -------------------------------------------------------------------
drop policy if exists products_select on public.products;
create policy products_select on public.products
  for select to authenticated using ((select public.is_shop_member(shop_id)));
drop policy if exists products_insert on public.products;
create policy products_insert on public.products
  for insert to authenticated with check ((select public.can_manage(shop_id)));
drop policy if exists products_update on public.products;
create policy products_update on public.products
  for update to authenticated
  using ((select public.can_manage(shop_id))) with check ((select public.can_manage(shop_id)));
drop policy if exists products_delete on public.products;
create policy products_delete on public.products
  for delete to authenticated using ((select public.can_manage(shop_id)));

-- CUSTOMERS ------------------------------------------------------------------
drop policy if exists customers_select on public.customers;
create policy customers_select on public.customers
  for select to authenticated using ((select public.is_shop_member(shop_id)));
drop policy if exists customers_insert on public.customers;
create policy customers_insert on public.customers
  for insert to authenticated with check ((select public.can_create_receipts(shop_id)));
drop policy if exists customers_update on public.customers;
create policy customers_update on public.customers
  for update to authenticated
  using ((select public.can_manage(shop_id))) with check ((select public.can_manage(shop_id)));
drop policy if exists customers_delete on public.customers;
create policy customers_delete on public.customers
  for delete to authenticated using ((select public.can_manage(shop_id)));

-- RECEIPTS -------------------------------------------------------------------
drop policy if exists receipts_select on public.receipts;
create policy receipts_select on public.receipts
  for select to authenticated using ((select public.is_shop_member(shop_id)));
drop policy if exists receipts_insert on public.receipts;
create policy receipts_insert on public.receipts
  for insert to authenticated with check ((select public.can_create_receipts(shop_id)));
drop policy if exists receipts_update on public.receipts;
create policy receipts_update on public.receipts
  for update to authenticated
  using ((select public.can_manage(shop_id))) with check ((select public.can_manage(shop_id)));
drop policy if exists receipts_delete on public.receipts;
create policy receipts_delete on public.receipts
  for delete to authenticated using ((select public.can_manage(shop_id)));

-- RECEIPT ITEMS --------------------------------------------------------------
drop policy if exists receipt_items_select on public.receipt_items;
create policy receipt_items_select on public.receipt_items
  for select to authenticated using ((select public.is_shop_member(shop_id)));
drop policy if exists receipt_items_insert on public.receipt_items;
create policy receipt_items_insert on public.receipt_items
  for insert to authenticated with check ((select public.can_create_receipts(shop_id)));
drop policy if exists receipt_items_update on public.receipt_items;
create policy receipt_items_update on public.receipt_items
  for update to authenticated
  using ((select public.can_manage(shop_id))) with check ((select public.can_manage(shop_id)));
drop policy if exists receipt_items_delete on public.receipt_items;
create policy receipt_items_delete on public.receipt_items
  for delete to authenticated using ((select public.can_manage(shop_id)));

-- KHATA TRANSACTIONS ---------------------------------------------------------
drop policy if exists khata_select on public.khata_transactions;
create policy khata_select on public.khata_transactions
  for select to authenticated using ((select public.is_shop_member(shop_id)));
drop policy if exists khata_insert on public.khata_transactions;
create policy khata_insert on public.khata_transactions
  for insert to authenticated with check ((select public.can_create_receipts(shop_id)));
drop policy if exists khata_update on public.khata_transactions;
create policy khata_update on public.khata_transactions
  for update to authenticated
  using ((select public.can_manage(shop_id))) with check ((select public.can_manage(shop_id)));
drop policy if exists khata_delete on public.khata_transactions;
create policy khata_delete on public.khata_transactions
  for delete to authenticated using ((select public.can_manage(shop_id)));

-- PRODUCT SEARCH STATS -------------------------------------------------------
drop policy if exists search_stats_select on public.product_search_stats;
create policy search_stats_select on public.product_search_stats
  for select to authenticated using ((select public.is_shop_member(shop_id)));
drop policy if exists search_stats_upsert on public.product_search_stats;
create policy search_stats_upsert on public.product_search_stats
  for insert to authenticated with check ((select public.is_shop_member(shop_id)));
drop policy if exists search_stats_update on public.product_search_stats;
create policy search_stats_update on public.product_search_stats
  for update to authenticated
  using ((select public.is_shop_member(shop_id))) with check ((select public.is_shop_member(shop_id)));
-- ============================================================================
-- Storage bucket + policies for product images
-- ============================================================================
-- Convention: objects are stored under  <shop_id>/<product_id>/<file>
-- so the first path segment is the shop id and we can scope access by it.
-- Store only the public/signed URL in products.image_url.
--
-- Policies target `authenticated` and wrap helper calls in `(select ...)`,
-- matching policies.sql.
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

-- Read: any member of the owning shop.
drop policy if exists product_images_read on storage.objects;
create policy product_images_read on storage.objects
  for select to authenticated using (
    bucket_id = 'product-images'
    and (select public.is_shop_member(((storage.foldername(name))[1])::uuid))
  );

-- Write/update/delete: admin+ of the owning shop.
drop policy if exists product_images_insert on storage.objects;
create policy product_images_insert on storage.objects
  for insert to authenticated with check (
    bucket_id = 'product-images'
    and (select public.can_manage(((storage.foldername(name))[1])::uuid))
  );

drop policy if exists product_images_update on storage.objects;
create policy product_images_update on storage.objects
  for update to authenticated using (
    bucket_id = 'product-images'
    and (select public.can_manage(((storage.foldername(name))[1])::uuid))
  );

drop policy if exists product_images_delete on storage.objects;
create policy product_images_delete on storage.objects
  for delete to authenticated using (
    bucket_id = 'product-images'
    and (select public.can_manage(((storage.foldername(name))[1])::uuid))
  );
-- ============================================================================
-- RPC functions callable from the Flutter client via supabase.rpc(...)
-- Run AFTER schema.sql and policies.sql.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- accept_invite: the invited user (matched by email) joins the shop.
-- Runs as SECURITY DEFINER because the invitee is not yet a shop member and
-- therefore cannot pass member-scoped RLS to insert into shop_members.
-- ---------------------------------------------------------------------------
create or replace function public.accept_invite(p_invite uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_invite public.shop_invites%rowtype;
  v_email  text := lower((auth.jwt() ->> 'email'));
begin
  select * into v_invite from public.shop_invites where id = p_invite;
  if v_invite.id is null then
    raise exception 'Invite not found';
  end if;
  if lower(v_invite.email) <> v_email then
    raise exception 'This invite is not addressed to you';
  end if;
  if v_invite.status <> 'pending' then
    raise exception 'Invite is no longer pending';
  end if;

  insert into public.shop_members (shop_id, user_id, role)
  values (v_invite.shop_id, auth.uid(), v_invite.role)
  on conflict (shop_id, user_id) do update set role = excluded.role;

  update public.shop_invites set status = 'accepted' where id = p_invite;
  return v_invite.shop_id;
end $$;

-- ---------------------------------------------------------------------------
-- record_product_search: bump analytics for the "top searched" report.
-- ---------------------------------------------------------------------------
create or replace function public.record_product_search(
  p_shop uuid, p_product uuid, p_term text
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_shop_member(p_shop) then
    raise exception 'Not a member of this shop';
  end if;
  insert into public.product_search_stats (shop_id, product_id, term)
  values (p_shop, p_product, p_term)
  on conflict (shop_id, product_id) do update
    set search_count = public.product_search_stats.search_count + 1,
        last_searched = now(),
        term = excluded.term;
end $$;

-- ---------------------------------------------------------------------------
-- dashboard_summary: one round-trip for the dashboard counters.
-- ---------------------------------------------------------------------------
create or replace function public.dashboard_summary(p_shop uuid)
returns json language plpgsql stable security definer set search_path = public as $$
declare result json;
begin
  if not public.is_shop_member(p_shop) then
    raise exception 'Not a member of this shop';
  end if;
  select json_build_object(
    'todays_receipts', (
      select count(*) from public.receipts
      where shop_id = p_shop and date::date = current_date),
    'todays_sales', (
      select coalesce(sum(total),0) from public.receipts
      where shop_id = p_shop and date::date = current_date),
    'total_customers', (
      select count(*) from public.customers where shop_id = p_shop),
    'total_products', (
      select count(*) from public.products where shop_id = p_shop),
    'khata_receivable', (
      select coalesce(sum(net_balance),0) from public.customer_khata_balances
      where shop_id = p_shop and net_balance > 0),
    'khata_payable', (
      select coalesce(-sum(net_balance),0) from public.customer_khata_balances
      where shop_id = p_shop and net_balance < 0)
  ) into result;
  return result;
end $$;
