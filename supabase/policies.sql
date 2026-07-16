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
-- Run this AFTER schema.sql.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helper functions (SECURITY DEFINER to avoid recursive RLS on shop_members)
-- ---------------------------------------------------------------------------
create or replace function public.is_shop_member(p_shop uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.shop_members m
    where m.shop_id = p_shop and m.user_id = auth.uid()
  );
$$;

-- Returns the caller's role in a shop (null if not a member).
create or replace function public.shop_role(p_shop uuid)
returns member_role language sql stable security definer set search_path = public as $$
  select m.role from public.shop_members m
  where m.shop_id = p_shop and m.user_id = auth.uid()
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
  for select using (
    id = auth.uid()
    or exists (  -- can see profiles of people who share a shop with me
      select 1 from public.shop_members me
      join public.shop_members them on them.shop_id = me.shop_id
      where me.user_id = auth.uid() and them.user_id = public.profiles.id
    )
  );

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- ============================================================================
-- SHOPS
-- ============================================================================
drop policy if exists shops_select_member on public.shops;
create policy shops_select_member on public.shops
  for select using (public.is_shop_member(id));

drop policy if exists shops_insert_self_owner on public.shops;
create policy shops_insert_self_owner on public.shops
  for insert with check (owner_id = auth.uid());

drop policy if exists shops_update_admin on public.shops;
create policy shops_update_admin on public.shops
  for update using (public.can_manage(id)) with check (public.can_manage(id));

drop policy if exists shops_delete_owner on public.shops;
create policy shops_delete_owner on public.shops
  for delete using (public.is_shop_owner(id));

-- ============================================================================
-- SHOP MEMBERS  (only owner can mutate; members can read their shop's roster)
-- ============================================================================
drop policy if exists members_select on public.shop_members;
create policy members_select on public.shop_members
  for select using (public.is_shop_member(shop_id));

drop policy if exists members_insert_owner on public.shop_members;
create policy members_insert_owner on public.shop_members
  for insert with check (public.is_shop_owner(shop_id));

drop policy if exists members_update_owner on public.shop_members;
create policy members_update_owner on public.shop_members
  for update using (public.is_shop_owner(shop_id)) with check (public.is_shop_owner(shop_id));

-- Owner can remove anyone; a member can remove (leave) themselves.
drop policy if exists members_delete on public.shop_members;
create policy members_delete on public.shop_members
  for delete using (public.is_shop_owner(shop_id) or user_id = auth.uid());

-- ============================================================================
-- SHOP INVITES  (owner manages; invitee can see invites addressed to them)
-- ============================================================================
drop policy if exists invites_select on public.shop_invites;
create policy invites_select on public.shop_invites
  for select using (
    public.is_shop_owner(shop_id)
    or lower(email) = lower((auth.jwt() ->> 'email'))
  );

drop policy if exists invites_insert_owner on public.shop_invites;
create policy invites_insert_owner on public.shop_invites
  for insert with check (public.is_shop_owner(shop_id));

drop policy if exists invites_update on public.shop_invites;
create policy invites_update on public.shop_invites
  for update using (
    public.is_shop_owner(shop_id)
    or lower(email) = lower((auth.jwt() ->> 'email'))
  );

drop policy if exists invites_delete_owner on public.shop_invites;
create policy invites_delete_owner on public.shop_invites
  for delete using (public.is_shop_owner(shop_id));

-- ============================================================================
-- Generic shop-scoped policy generator for domain tables
-- ============================================================================
-- read  : any member;  write: admin+ (or receipts: staff+)
-- We spell these out per table for clarity/auditing.

-- PRODUCTS -------------------------------------------------------------------
drop policy if exists products_select on public.products;
create policy products_select on public.products
  for select using (public.is_shop_member(shop_id));
drop policy if exists products_insert on public.products;
create policy products_insert on public.products
  for insert with check (public.can_manage(shop_id));
drop policy if exists products_update on public.products;
create policy products_update on public.products
  for update using (public.can_manage(shop_id)) with check (public.can_manage(shop_id));
drop policy if exists products_delete on public.products;
create policy products_delete on public.products
  for delete using (public.can_manage(shop_id));

-- CUSTOMERS ------------------------------------------------------------------
drop policy if exists customers_select on public.customers;
create policy customers_select on public.customers
  for select using (public.is_shop_member(shop_id));
drop policy if exists customers_insert on public.customers;
create policy customers_insert on public.customers
  for insert with check (public.can_create_receipts(shop_id));
drop policy if exists customers_update on public.customers;
create policy customers_update on public.customers
  for update using (public.can_manage(shop_id)) with check (public.can_manage(shop_id));
drop policy if exists customers_delete on public.customers;
create policy customers_delete on public.customers
  for delete using (public.can_manage(shop_id));

-- RECEIPTS -------------------------------------------------------------------
drop policy if exists receipts_select on public.receipts;
create policy receipts_select on public.receipts
  for select using (public.is_shop_member(shop_id));
drop policy if exists receipts_insert on public.receipts;
create policy receipts_insert on public.receipts
  for insert with check (public.can_create_receipts(shop_id));
drop policy if exists receipts_update on public.receipts;
create policy receipts_update on public.receipts
  for update using (public.can_manage(shop_id)) with check (public.can_manage(shop_id));
drop policy if exists receipts_delete on public.receipts;
create policy receipts_delete on public.receipts
  for delete using (public.can_manage(shop_id));

-- RECEIPT ITEMS --------------------------------------------------------------
drop policy if exists receipt_items_select on public.receipt_items;
create policy receipt_items_select on public.receipt_items
  for select using (public.is_shop_member(shop_id));
drop policy if exists receipt_items_insert on public.receipt_items;
create policy receipt_items_insert on public.receipt_items
  for insert with check (public.can_create_receipts(shop_id));
drop policy if exists receipt_items_update on public.receipt_items;
create policy receipt_items_update on public.receipt_items
  for update using (public.can_manage(shop_id)) with check (public.can_manage(shop_id));
drop policy if exists receipt_items_delete on public.receipt_items;
create policy receipt_items_delete on public.receipt_items
  for delete using (public.can_manage(shop_id));

-- KHATA TRANSACTIONS ---------------------------------------------------------
drop policy if exists khata_select on public.khata_transactions;
create policy khata_select on public.khata_transactions
  for select using (public.is_shop_member(shop_id));
drop policy if exists khata_insert on public.khata_transactions;
create policy khata_insert on public.khata_transactions
  for insert with check (public.can_create_receipts(shop_id));
drop policy if exists khata_update on public.khata_transactions;
create policy khata_update on public.khata_transactions
  for update using (public.can_manage(shop_id)) with check (public.can_manage(shop_id));
drop policy if exists khata_delete on public.khata_transactions;
create policy khata_delete on public.khata_transactions
  for delete using (public.can_manage(shop_id));

-- PRODUCT SEARCH STATS -------------------------------------------------------
drop policy if exists search_stats_select on public.product_search_stats;
create policy search_stats_select on public.product_search_stats
  for select using (public.is_shop_member(shop_id));
drop policy if exists search_stats_upsert on public.product_search_stats;
create policy search_stats_upsert on public.product_search_stats
  for insert with check (public.is_shop_member(shop_id));
drop policy if exists search_stats_update on public.product_search_stats;
create policy search_stats_update on public.product_search_stats
  for update using (public.is_shop_member(shop_id)) with check (public.is_shop_member(shop_id));
