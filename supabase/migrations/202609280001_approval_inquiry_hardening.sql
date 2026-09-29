-- Keep product approval tied to an approved, active shop, and restrict inquiry
-- creation to signed-in customers. Existing listing moderation protections remain.

drop policy if exists "Customers create inquiries for public products" on public.inquiries;
create policy "Customers create inquiries for public products"
on public.inquiries
for insert
with check (
  customer_id = (select auth.uid())
  and public.current_user_role() = 'customer'
  and public.shop_is_public(shop_id)
  and (
    product_id is null
    or (
      public.product_is_public(product_id)
      and exists (
        select 1 from public.products p
        where p.id = product_id and p.shop_id = shop_id
      )
    )
  )
);

create or replace function public.require_approved_shop_for_product_approval()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  shop_is_approved boolean;
begin
  if new.status = 'approved'
     and (tg_op = 'INSERT' or old.status is distinct from 'approved' or old.shop_id is distinct from new.shop_id) then
    select (s.status = 'approved' and s.is_active)
      into shop_is_approved
      from public.shops s
     where s.id = new.shop_id;

    if coalesce(shop_is_approved, false) = false then
      raise exception 'Approve and activate the shop before approving its products';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists products_require_approved_shop on public.products;
create trigger products_require_approved_shop
before insert or update on public.products
for each row
execute function public.require_approved_shop_for_product_approval();
