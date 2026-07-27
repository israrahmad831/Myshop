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
