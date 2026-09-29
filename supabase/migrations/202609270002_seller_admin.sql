-- Seller controls, admin reads, and transaction-status hardening.
-- Safe for projects that already applied the original Mohalla Mart migration.
alter table public.shops add column if not exists is_open boolean not null default true;
alter table public.shops alter column opening_hours set default '{}'::jsonb;

-- Normalize older enum values to the statuses used by the current UI.
drop policy if exists "Customers cancel own requested reservations" on public.reservations;
drop policy if exists "Customers cancel only their requested reservations" on public.reservations;
alter table public.inquiries alter column status drop default;
alter table public.inquiries alter column status type text using status::text;
update public.inquiries set status=case status when 'open' then 'new' when 'answered' then 'in_progress' when 'closed' then 'resolved' else status end;
alter table public.inquiries alter column status set default 'new';
alter table public.inquiries drop constraint if exists inquiries_status_check;
alter table public.inquiries add constraint inquiries_status_check check(status in ('new','in_progress','resolved'));

alter table public.reservations alter column status drop default;
alter table public.reservations alter column status type text using status::text;
update public.reservations set status=case status when 'ready' then 'confirmed' when 'collected' then 'completed' when 'expired' then 'cancelled' else status end;
alter table public.reservations alter column status set default 'requested';
alter table public.reservations drop constraint if exists reservations_status_check;
alter table public.reservations add constraint reservations_status_check check(status in ('requested','confirmed','cancelled','completed'));

create or replace function public.can_view_profile(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.conversations c where
   ((c.customer_id=(select auth.uid()) and c.shopkeeper_id=target) or (c.shopkeeper_id=(select auth.uid()) and c.customer_id=target)))
 or exists(select 1 from public.inquiries i join public.shops s on s.id=i.shop_id where
   ((i.customer_id=(select auth.uid()) and s.owner_id=target) or (s.owner_id=(select auth.uid()) and i.customer_id=target)))
 or exists(select 1 from public.reservations r join public.shops s on s.id=r.shop_id where
   ((r.customer_id=(select auth.uid()) and s.owner_id=target) or (s.owner_id=(select auth.uid()) and r.customer_id=target)))
$$;
drop policy if exists "Profiles readable by self and admins" on public.profiles;
create policy "Profiles visible to self admins and transaction participants" on public.profiles for select
using(id=(select auth.uid()) or public.is_admin() or public.can_view_profile(id));

-- Keep private rows private. Shop owners access only records linked to their own shops;
-- customers access only records whose customer_id matches the signed-in account.
drop policy if exists "Public approved shops readable" on public.shops;
create policy "Approved shops public owner and admin readable" on public.shops for select
using((status='approved' and is_active) or owner_id=(select auth.uid()) or public.is_admin());
drop policy if exists "Public approved products readable" on public.products;
create policy "Approved products public owner and admin readable" on public.products for select
using((status='approved' and is_active and public.shop_is_public(shop_id)) or public.owns_shop(shop_id) or public.is_admin());
drop policy if exists "Variants readable with product" on public.product_variants;
create policy "Variants visible with product ownership or public listing" on public.product_variants for select
using(public.product_is_public(product_id) or exists(select 1 from public.products p where p.id=product_id and public.owns_shop(p.shop_id)) or public.is_admin());

drop policy if exists "Inquiry participants read" on public.inquiries;
create policy "Customer shop owner and admin read inquiries" on public.inquiries for select
using(customer_id=(select auth.uid()) or public.owns_shop(shop_id) or public.is_admin());
drop policy if exists "Shopkeepers manage inquiries" on public.inquiries;
create policy "Shop owners update inquiry status" on public.inquiries for update
using(public.owns_shop(shop_id) or public.is_admin()) with check(public.owns_shop(shop_id) or public.is_admin());

drop policy if exists "Participants read conversations" on public.conversations;
create policy "Only conversation participants read" on public.conversations for select
using(customer_id=(select auth.uid()) or shopkeeper_id=(select auth.uid()) or public.is_admin());
drop policy if exists "Customers start conversation" on public.conversations;
create policy "Customer creates conversation with approved shop owner" on public.conversations for insert
with check(customer_id=(select auth.uid()) and exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=shopkeeper_id and s.status='approved' and s.is_active));
drop policy if exists "Participants read messages" on public.messages;
create policy "Only participants read messages" on public.messages for select
using(public.is_admin() or exists(select 1 from public.conversations c where c.id=conversation_id and (c.customer_id=(select auth.uid()) or c.shopkeeper_id=(select auth.uid()))));
drop policy if exists "Participants send messages" on public.messages;
create policy "Only participants send messages as self" on public.messages for insert
with check(sender_id=(select auth.uid()) and exists(select 1 from public.conversations c where c.id=conversation_id and (c.customer_id=(select auth.uid()) or c.shopkeeper_id=(select auth.uid()))));

drop policy if exists "Reservation parties read" on public.reservations;
create policy "Only reservation parties and admins read" on public.reservations for select
using(customer_id=(select auth.uid()) or public.owns_shop(shop_id) or public.is_admin());
drop policy if exists "Shopkeepers manage reservations" on public.reservations;
create policy "Shop owners update their reservations" on public.reservations for update
using(public.owns_shop(shop_id) or public.is_admin()) with check(public.owns_shop(shop_id) or public.is_admin());
drop policy if exists "Customers cancel own requested reservations" on public.reservations;
create policy "Customers cancel only their requested reservations" on public.reservations for update
using(customer_id=(select auth.uid()) and status='requested') with check(customer_id=(select auth.uid()) and status='cancelled');

drop policy if exists "Users read own notifications" on public.notifications;
create policy "Profiles read only their notifications" on public.notifications for select
using(profile_id=(select auth.uid()) or public.is_admin());
drop policy if exists "Users mark own notifications" on public.notifications;
create policy "Profiles update only their notifications" on public.notifications for update
using(profile_id=(select auth.uid()) or public.is_admin()) with check(profile_id=(select auth.uid()) or public.is_admin());

drop policy if exists "Reporters and admins read reports" on public.reports;
create policy "Reporter and admin report visibility" on public.reports for select
using(reporter_id=(select auth.uid()) or public.is_admin());
drop policy if exists "Admins moderate reports" on public.reports;
create policy "Only admins update reports" on public.reports for update
using(public.is_admin()) with check(public.is_admin());

-- Admins need a single role-checked policy to manage listings and review reports.
drop policy if exists "Owners and admins update shops" on public.shops;
create policy "Owners or admins update shops" on public.shops for update
using(owner_id=(select auth.uid()) or public.is_admin()) with check(owner_id=(select auth.uid()) or public.is_admin());
drop policy if exists "Shopkeepers update products" on public.products;
create policy "Owners or admins update products" on public.products for update
using(public.owns_shop(shop_id) or public.is_admin()) with check(public.owns_shop(shop_id) or public.is_admin());

-- Restrict customer-created reservation quantities and validate variant/product/shop linkage server-side.
create or replace function public.validate_reservation() returns trigger language plpgsql security definer set search_path = '' as $$
declare available integer; linked_shop uuid; variant_product uuid;
begin
 select stock_quantity,shop_id into available,linked_shop from public.products where id=new.product_id;
 if linked_shop is null or linked_shop<>new.shop_id then raise exception 'Product does not belong to this shop'; end if;
 if new.variant_id is not null then
  select product_id,stock_quantity into variant_product,available from public.product_variants where id=new.variant_id;
  if variant_product is null or variant_product<>new.product_id then raise exception 'Variant does not belong to this product'; end if;
 end if;
 if new.quantity>available then raise exception 'Requested quantity exceeds available stock'; end if;
 return new;
end; $$;
drop trigger if exists reservations_validate on public.reservations;
create trigger reservations_validate before insert on public.reservations for each row execute function public.validate_reservation();

-- Email is available only through this role-checked admin RPC, never through public profile reads.
create or replace function public.admin_list_users()
returns table(id uuid,full_name text,role public.user_role,phone text,created_at timestamptz,email text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 return query select p.id,p.full_name,p.role,p.phone,p.created_at,u.email::text from public.profiles p join auth.users u on u.id=p.id order by p.created_at desc;
end; $$;
grant execute on function public.admin_list_users() to authenticated;

create or replace function public.notify_request_customer() returns trigger language plpgsql security definer set search_path = '' as $$
declare customer uuid; shop_title text;
begin
 select customer_id into customer from public.product_requests where id=new.request_id;
 select name into shop_title from public.shops where id=new.shop_id;
 insert into public.notifications(profile_id,title,body,href)
 values(customer,'A shop replied to your request',coalesce(shop_title,'A local shop')||' · '||new.availability,'/activity');
 return new;
end; $$;
drop trigger if exists request_response_notify_customer on public.product_request_responses;
create trigger request_response_notify_customer after insert or update on public.product_request_responses for each row execute function public.notify_request_customer();

create or replace function public.notify_shopkeeper_customer_cancellation() returns trigger language plpgsql security definer set search_path = '' as $$
declare shop_owner uuid;
begin
 if tg_table_name='reservations' and new.status is distinct from old.status and new.customer_id=(select auth.uid()) then
  select owner_id into shop_owner from public.shops where id=new.shop_id;
  insert into public.notifications(profile_id,title,body,href)
  values(shop_owner,'Reservation changed','A customer changed a reservation to '||new.status,'/seller/reservations');
 end if;
 return new;
end; $$;
drop trigger if exists reservation_notify_shopkeeper_change on public.reservations;
create trigger reservation_notify_shopkeeper_change after update of status on public.reservations for each row execute function public.notify_shopkeeper_customer_cancellation();

