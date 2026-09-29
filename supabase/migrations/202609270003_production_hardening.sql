-- Production security fix: non-admin shopkeepers may submit listings only as pending.
-- Approval and visibility remain controlled by the moderation action/RLS path.
create or replace function public.protect_listing_moderation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    if tg_op = 'INSERT' and (new.status is distinct from 'pending' or new.is_active is distinct from true) then
      raise exception 'New listings must be submitted as pending and active';
    end if;
    if tg_op = 'UPDATE' and (new.status is distinct from old.status or new.is_active is distinct from old.is_active) then
      raise exception 'Only an admin can change listing approval or visibility';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists shops_protect_moderation on public.shops;
create trigger shops_protect_moderation
before insert or update on public.shops
for each row execute function public.protect_listing_moderation();

drop trigger if exists products_protect_moderation on public.products;
create trigger products_protect_moderation
before insert or update on public.products
for each row execute function public.protect_listing_moderation();