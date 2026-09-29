-- Mohalla Mart initial schema. Apply with `supabase db push` or paste into SQL Editor.
create extension if not exists pgcrypto;

create type public.user_role as enum ('customer', 'shopkeeper', 'admin');
create type public.listing_status as enum ('pending', 'approved', 'rejected', 'suspended');
create type public.inquiry_status as enum ('new', 'in_progress', 'resolved');
create type public.reservation_status as enum ('requested', 'confirmed', 'cancelled', 'completed');

create function public.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 1 and 100),
  role public.user_role not null default 'customer',
  phone text check (phone is null or char_length(phone) <= 25),
  avatar_url text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
declare chosen_role public.user_role;
begin
  chosen_role := case when new.raw_user_meta_data->>'role' = 'shopkeeper' then 'shopkeeper'::public.user_role else 'customer'::public.user_role end;
  insert into public.profiles(id, full_name, role) values(new.id, coalesce(nullif(new.raw_user_meta_data->>'full_name',''), 'New member'), chosen_role) on conflict (id) do nothing;
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
-- Also create profiles for Auth users who predate this schema. This is safe to rerun.
insert into public.profiles(id, full_name, role)
select u.id,
       coalesce(nullif(u.raw_user_meta_data->>'full_name',''), 'New member'),
       case when u.raw_user_meta_data->>'role' = 'shopkeeper'
            then 'shopkeeper'::public.user_role
            else 'customer'::public.user_role
       end
from auth.users u
on conflict (id) do nothing;

create table public.shops (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check(char_length(name) between 2 and 120), slug text unique,
  description text, category text not null default 'General', phone text, address text not null,
  locality text not null, city text not null, postal_code text, latitude double precision, longitude double precision,
  logo_url text, cover_url text, opening_hours jsonb not null default '{}'::jsonb, is_open boolean not null default true,
  status public.listing_status not null default 'pending', is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(latitude is null or latitude between -90 and 90), check(longitude is null or longitude between -180 and 180)
);
create table public.products (
  id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null check(char_length(name) between 2 and 160), description text,
  category text not null default 'General', price numeric(12,2) not null check(price >= 0), currency char(3) not null default 'INR',
  stock_quantity integer not null default 0 check(stock_quantity >= 0), image_url text, image_urls text[] not null default '{}', status public.listing_status not null default 'pending',
  is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.product_variants (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id) on delete cascade,
  name text not null check(char_length(name) between 1 and 100), sku text, price numeric(12,2) check(price is null or price >= 0),
  stock_quantity integer not null default 0 check(stock_quantity >= 0), attributes jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(product_id, sku)
);
create table public.inquiries (
  id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.profiles(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade, product_id uuid references public.products(id) on delete set null,
  message text not null check(char_length(message) between 1 and 2000), status public.inquiry_status not null default 'new',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.conversations (
  id uuid primary key default gen_random_uuid(), inquiry_id uuid unique references public.inquiries(id) on delete set null,
  customer_id uuid not null references public.profiles(id) on delete cascade, shopkeeper_id uuid not null references public.profiles(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade, last_message_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check(customer_id <> shopkeeper_id)
);
create table public.messages (
  id uuid primary key default gen_random_uuid(), conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade, body text not null check(char_length(body) between 1 and 4000),
  read_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.reservations (
  id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.profiles(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade, product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid references public.product_variants(id) on delete set null, quantity integer not null default 1 check(quantity between 1 and 1000),
  status public.reservation_status not null default 'requested', note text, pickup_at timestamptz, expires_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(), profile_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check(char_length(title) between 1 and 160), body text not null check(char_length(body) between 1 and 1000),
  href text, read_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.reports (
  id uuid primary key default gen_random_uuid(), reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_profile_id uuid references public.profiles(id) on delete cascade, shop_id uuid references public.shops(id) on delete cascade,
  product_id uuid references public.products(id) on delete cascade, reason text not null check(char_length(reason) between 3 and 1000),
  status text not null default 'open' check(status in ('open','reviewing','resolved','dismissed')), resolution_note text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(num_nonnulls(target_profile_id, shop_id, product_id) = 1)
);
create table public.product_requests (
  id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check(char_length(title) between 3 and 160), category text not null,
  variant text, budget numeric(12,2) check(budget is null or budget >= 0), message text not null check(char_length(message) between 5 and 2000),
  latitude double precision, longitude double precision, locality text, status text not null default 'open' check(status in ('open','closed')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(latitude is null or latitude between -90 and 90), check(longitude is null or longitude between -180 and 180)
);
create table public.product_request_responses (
  id uuid primary key default gen_random_uuid(), request_id uuid not null references public.product_requests(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  availability text not null check(availability in ('available','limited','not_available')),
  message text not null check(char_length(message) between 1 and 1000), price numeric(12,2) check(price is null or price >= 0),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(request_id,shop_id)
);

create index shops_owner_idx on public.shops(owner_id); create index shops_public_idx on public.shops(status,is_active,locality);
create index products_shop_idx on public.products(shop_id); create index products_public_idx on public.products(status,is_active,category);
create index variants_product_idx on public.product_variants(product_id); create index inquiries_customer_idx on public.inquiries(customer_id,created_at desc);
create index inquiries_shop_idx on public.inquiries(shop_id,created_at desc); create index conversations_customer_idx on public.conversations(customer_id,updated_at desc);
create index conversations_shopkeeper_idx on public.conversations(shopkeeper_id,updated_at desc); create index messages_conversation_idx on public.messages(conversation_id,created_at);
create index reservations_customer_idx on public.reservations(customer_id,created_at desc); create index reservations_shop_idx on public.reservations(shop_id,status);
create index notifications_profile_idx on public.notifications(profile_id,created_at desc); create index reports_status_idx on public.reports(status,created_at desc);
create index product_requests_customer_idx on public.product_requests(customer_id,created_at desc); create index product_requests_geo_idx on public.product_requests(latitude,longitude);
create index request_responses_request_idx on public.product_request_responses(request_id,created_at desc);

do $$ declare t text; begin foreach t in array array['profiles','shops','products','product_variants','inquiries','conversations','messages','reservations','notifications','reports','product_requests','product_request_responses'] loop
 execute format('create trigger %I_updated_at before update on public.%I for each row execute function public.set_updated_at()', t, t);
 execute format('alter table public.%I enable row level security', t);
end loop; end $$;

-- SECURITY DEFINER helpers avoid recursive RLS checks across shop/profile ownership.
create function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') $$;
create function public.current_user_role() returns public.user_role language sql stable security definer set search_path = '' as $$
 select role from public.profiles where id = (select auth.uid()) $$;
create function public.owns_shop(check_shop uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.shops where id = check_shop and owner_id = (select auth.uid())) $$;
create function public.shop_is_public(check_shop uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.shops where id = check_shop and status = 'approved' and is_active) $$;
create function public.product_is_public(check_product uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.products p join public.shops s on s.id=p.shop_id where p.id=check_product and p.status='approved' and p.is_active and s.status='approved' and s.is_active) $$;

create policy "Public approved shops readable" on public.shops for select using ((status='approved' and is_active) or owner_id=(select auth.uid()) or public.is_admin());
create policy "Shopkeepers create own shop" on public.shops for insert with check(owner_id=(select auth.uid()) and (select role from public.profiles where id=(select auth.uid()))='shopkeeper');
create policy "Owners and admins update shops" on public.shops for update using(owner_id=(select auth.uid()) or public.is_admin()) with check(owner_id=(select auth.uid()) or public.is_admin());
create policy "Admins delete shops" on public.shops for delete using(public.is_admin());
create policy "Public approved products readable" on public.products for select using((status='approved' and is_active and public.shop_is_public(shop_id)) or public.owns_shop(shop_id) or public.is_admin());
create policy "Shopkeepers create products" on public.products for insert with check(public.owns_shop(shop_id));
create policy "Shopkeepers update products" on public.products for update using(public.owns_shop(shop_id) or public.is_admin()) with check(public.owns_shop(shop_id) or public.is_admin());
create policy "Admins or owners delete products" on public.products for delete using(public.owns_shop(shop_id) or public.is_admin());
-- Moderation fields can only be changed by admins (RLS alone does not restrict updated columns).
create function public.protect_listing_moderation() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() and (new.status is distinct from old.status or new.is_active is distinct from old.is_active) then
    raise exception 'Only an admin can change listing approval or visibility';
  end if;
  return new;
end; $$;
create trigger shops_protect_moderation before update on public.shops for each row execute function public.protect_listing_moderation();
create trigger products_protect_moderation before update on public.products for each row execute function public.protect_listing_moderation();
create policy "Variants readable with product" on public.product_variants for select using(public.product_is_public(product_id) or exists(select 1 from public.products p where p.id=product_id and public.owns_shop(p.shop_id)) or public.is_admin());
create policy "Owners manage variants" on public.product_variants for all using(exists(select 1 from public.products p where p.id=product_id and public.owns_shop(p.shop_id)) or public.is_admin()) with check(exists(select 1 from public.products p where p.id=product_id and public.owns_shop(p.shop_id)) or public.is_admin());

create policy "Profiles readable by self and admins" on public.profiles for select using(id=(select auth.uid()) or public.is_admin());
create policy "Users update own basic profile" on public.profiles for update using(id=(select auth.uid()) or public.is_admin()) with check((id=(select auth.uid()) and role=public.current_user_role()) or public.is_admin());
create policy "Customers create inquiries for public products" on public.inquiries for insert with check(customer_id=(select auth.uid()) and public.shop_is_public(shop_id) and (product_id is null or (public.product_is_public(product_id) and exists(select 1 from public.products p where p.id=product_id and p.shop_id=shop_id))));
create function public.start_inquiry_conversation() returns trigger language plpgsql security definer set search_path = '' as $$
declare seller uuid;
begin
  select owner_id into seller from public.shops where id=new.shop_id;
  insert into public.conversations(inquiry_id,customer_id,shopkeeper_id,shop_id) values(new.id,new.customer_id,seller,new.shop_id);
  return new;
end; $$;
create trigger inquiry_starts_conversation after insert on public.inquiries for each row execute function public.start_inquiry_conversation();
create policy "Inquiry participants read" on public.inquiries for select using(customer_id=(select auth.uid()) or public.owns_shop(shop_id) or public.is_admin());
create policy "Shopkeepers manage inquiries" on public.inquiries for update using(public.owns_shop(shop_id) or public.is_admin()) with check(public.owns_shop(shop_id) or public.is_admin());
create policy "Participants read conversations" on public.conversations for select using(customer_id=(select auth.uid()) or shopkeeper_id=(select auth.uid()) or public.is_admin());
create policy "Customers start conversation" on public.conversations for insert with check(customer_id=(select auth.uid()) and public.owns_shop(shop_id)=false and exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=shopkeeper_id and s.status='approved'));
create policy "Admins manage conversations" on public.conversations for all using(public.is_admin()) with check(public.is_admin());
create policy "Participants read messages" on public.messages for select using(exists(select 1 from public.conversations c where c.id=conversation_id and (c.customer_id=(select auth.uid()) or c.shopkeeper_id=(select auth.uid()))) or public.is_admin());
create policy "Participants send messages" on public.messages for insert with check(sender_id=(select auth.uid()) and exists(select 1 from public.conversations c where c.id=conversation_id and (c.customer_id=(select auth.uid()) or c.shopkeeper_id=(select auth.uid()))));
create policy "Participants update own or read messages" on public.messages for update using(sender_id=(select auth.uid()) or exists(select 1 from public.conversations c where c.id=conversation_id and (c.customer_id=(select auth.uid()) or c.shopkeeper_id=(select auth.uid()))) or public.is_admin()) with check(sender_id=(select auth.uid()) or exists(select 1 from public.conversations c where c.id=conversation_id and (c.customer_id=(select auth.uid()) or c.shopkeeper_id=(select auth.uid()))) or public.is_admin());
create function public.protect_message_content() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if not public.is_admin() then
  if new.sender_id is distinct from old.sender_id or new.conversation_id is distinct from old.conversation_id then
   raise exception 'Message sender and conversation cannot be changed';
  end if;
  if old.sender_id <> (select auth.uid()) and new.body is distinct from old.body then
   raise exception 'Conversation participants may only mark received messages as read';
  end if;
 end if;
 return new;
end; $$;
create trigger messages_protect_content before update on public.messages for each row execute function public.protect_message_content();
create policy "Customers request reservation" on public.reservations for insert with check(customer_id=(select auth.uid()) and public.product_is_public(product_id) and exists(select 1 from public.products p where p.id=product_id and p.shop_id=shop_id));
create policy "Reservation parties read" on public.reservations for select using(customer_id=(select auth.uid()) or public.owns_shop(shop_id) or public.is_admin());
create policy "Shopkeepers manage reservations" on public.reservations for update using(public.owns_shop(shop_id) or public.is_admin()) with check(public.owns_shop(shop_id) or public.is_admin());
create policy "Customers cancel own requested reservations" on public.reservations for update using(customer_id=(select auth.uid()) and status='requested') with check(customer_id=(select auth.uid()) and status='cancelled');
create function public.protect_customer_transactions() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    if tg_table_name = 'inquiries' and (new.customer_id is distinct from old.customer_id or new.shop_id is distinct from old.shop_id or new.product_id is distinct from old.product_id or new.message is distinct from old.message) then
      raise exception 'Shopkeepers can only update inquiry status';
    elsif tg_table_name = 'reservations' and (new.customer_id is distinct from old.customer_id or new.shop_id is distinct from old.shop_id or new.product_id is distinct from old.product_id or new.variant_id is distinct from old.variant_id or new.quantity is distinct from old.quantity) then
      raise exception 'Shopkeepers can only update reservation status and note';
    end if;
  end if;
  return new;
end; $$;
create trigger inquiries_protect_parties before update on public.inquiries for each row execute function public.protect_customer_transactions();
create trigger reservations_protect_parties before update on public.reservations for each row execute function public.protect_customer_transactions();
create policy "Users read own notifications" on public.notifications for select using(profile_id=(select auth.uid()) or public.is_admin());
create policy "Users mark own notifications" on public.notifications for update using(profile_id=(select auth.uid()) or public.is_admin()) with check(profile_id=(select auth.uid()) or public.is_admin());
create policy "Users file reports" on public.reports for insert with check(reporter_id=(select auth.uid()));
create policy "Reporters and admins read reports" on public.reports for select using(reporter_id=(select auth.uid()) or public.is_admin());
create policy "Admins moderate reports" on public.reports for update using(public.is_admin()) with check(public.is_admin());
create policy "Customers manage own requests" on public.product_requests for all using(customer_id=(select auth.uid()) or public.is_admin()) with check(customer_id=(select auth.uid()) or public.is_admin());
create policy "Open requests are visible to shopkeepers" on public.product_requests for select using(status='open' and (select role from public.profiles where id=(select auth.uid()))='shopkeeper');
create policy "Shopkeepers respond to open requests" on public.product_request_responses for insert with check(public.owns_shop(shop_id) and exists(select 1 from public.product_requests r where r.id=request_id and r.status='open'));
create policy "Request parties read responses" on public.product_request_responses for select using(public.owns_shop(shop_id) or public.is_admin() or exists(select 1 from public.product_requests r where r.id=request_id and r.customer_id=(select auth.uid())));
create policy "Shopkeepers update their request responses" on public.product_request_responses for update using(public.owns_shop(shop_id) or public.is_admin()) with check(public.owns_shop(shop_id) or public.is_admin());

-- Public listing imagery. Upload object paths as <auth.uid()>/<filename>; writes remain owner-scoped.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('shop-media','shop-media',true,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do update set public=true;
create policy "Public listing images readable" on storage.objects for select using(bucket_id='shop-media');
create policy "Users upload own listing images" on storage.objects for insert with check(bucket_id='shop-media' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "Users manage own listing images" on storage.objects for update using(bucket_id='shop-media' and (storage.foldername(name))[1]=(select auth.uid())::text) with check(bucket_id='shop-media' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "Users delete own listing images" on storage.objects for delete using(bucket_id='shop-media' and (storage.foldername(name))[1]=(select auth.uid())::text);

-- Enable Supabase Realtime for customer-facing updates.
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.reservations;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.inquiries;
alter publication supabase_realtime add table public.product_request_responses;

create function public.notify_message_participant() returns trigger language plpgsql security definer set search_path = '' as $$
declare recipient uuid; conv public.conversations;
begin
 select * into conv from public.conversations where id=new.conversation_id;
 recipient := case when new.sender_id=conv.customer_id then conv.shopkeeper_id else conv.customer_id end;
 update public.conversations set last_message_at=new.created_at where id=conv.id;
 insert into public.notifications(profile_id,title,body,href) values(recipient,'New chat message',left(new.body,160),'/chat/'||conv.id);
 return new;
end; $$;
create trigger messages_notify_participant after insert on public.messages for each row execute function public.notify_message_participant();

create function public.notify_shopkeeper_activity() returns trigger language plpgsql security definer set search_path = '' as $$
declare recipient uuid; shop_title text; product_title text;
begin
 if tg_table_name='inquiries' then
  select owner_id,name into recipient,shop_title from public.shops where id=new.shop_id;
  select name into product_title from public.products where id=new.product_id;
  insert into public.notifications(profile_id,title,body,href) values(recipient,'New product inquiry',coalesce(product_title,'A product')||' · '||left(new.message,120),'/seller/inquiries');
 elsif tg_table_name='reservations' then
  select owner_id,name into recipient,shop_title from public.shops where id=new.shop_id;
  select name into product_title from public.products where id=new.product_id;
  insert into public.notifications(profile_id,title,body,href) values(recipient,'New reservation request',coalesce(product_title,'A product')||' · Quantity '||new.quantity,'/seller/reservations');
 end if;
 return new;
end; $$;
create trigger inquiry_notify_shopkeeper after insert on public.inquiries for each row execute function public.notify_shopkeeper_activity();
create trigger reservation_notify_shopkeeper after insert on public.reservations for each row execute function public.notify_shopkeeper_activity();

create function public.notify_relevant_shops_request() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.notifications(profile_id,title,body,href)
 select s.owner_id,'Nearby customer request',new.title||' · '||coalesce(new.locality,'Your area'),'/seller/requests'
 from public.shops s
 where s.status='approved' and s.is_active and s.category=new.category
 and (new.latitude is null or new.longitude is null or s.latitude is null or s.longitude is null or
   (6371 * 2 * asin(sqrt(least(1,
     power(sin(radians(s.latitude-new.latitude)/2),2)+cos(radians(new.latitude))*cos(radians(s.latitude))*power(sin(radians(s.longitude-new.longitude)/2),2)
   )))) <= 30);
 return new;
end; $$;
create trigger product_request_notify_shops after insert on public.product_requests for each row execute function public.notify_relevant_shops_request();

create function public.notify_customer_updates() returns trigger language plpgsql security definer set search_path = '' as $$
declare recipient uuid; label text;
begin
 if tg_table_name='reservations' then
  if new.status is distinct from old.status then recipient:=new.customer_id; label:='Reservation updated';
  else return new; end if;
 elsif tg_table_name='inquiries' then
  if new.status is distinct from old.status then recipient:=new.customer_id; label:='Inquiry updated';
  else return new; end if;
 else return new; end if;
 insert into public.notifications(profile_id,title,body,href) values(recipient,label,'There is an update to your request.','/activity');
 return new;
end; $$;
create trigger reservation_notify_customer after update on public.reservations for each row execute function public.notify_customer_updates();
create trigger inquiry_notify_customer after update on public.inquiries for each row execute function public.notify_customer_updates();
