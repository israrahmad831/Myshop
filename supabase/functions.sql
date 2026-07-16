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
