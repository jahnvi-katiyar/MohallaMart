# Mohalla Mart admin and approval setup

## Run the required migrations

Apply the SQL migrations in `supabase/migrations/` in filename order:

1. `202609270001_initial_schema.sql`
2. `202609270002_seller_admin.sql`
3. `202609270003_production_hardening.sql`
4. `202609280001_approval_inquiry_hardening.sql`

In Supabase Dashboard, open **SQL Editor**, paste one complete migration at a time, and run them in that order. Skip migrations already applied to this project. The last migration restricts inquiry inserts to customer profiles and prevents product approval unless its shop is approved and active. Existing RLS and moderation triggers remain enabled.

## Promote your own existing account to the first admin

1. If you do not already have a Supabase Auth account, create one through Mohalla Mart's normal **Sign up** page as either Customer or Shopkeeper. If you already have an account, use that account; do not create a duplicate. Admin is intentionally unavailable in public signup.
2. In Supabase Dashboard, go to **Authentication → Users**. Locate the row with your own verified email and copy its **ID** (UUID). Verify the email carefully before continuing.
3. In **SQL Editor**, confirm that UUID belongs to your profile. Replace the placeholder with the UUID you copied; do not paste an email or another user's ID:

   ```sql
   select id, full_name, role
   from public.profiles
   where id = 'PASTE-YOUR-VERIFIED-AUTH-USER-UUID'::uuid;
   ```

4. If the returned row is your account, promote only that row:

   ```sql
   update public.profiles
   set role = 'admin'
   where id = 'PASTE-YOUR-VERIFIED-AUTH-USER-UUID'::uuid
   returning id, full_name, role;
   ```

   Confirm the returned UUID is still yours and the role is `admin`. If the first query returns no row, ensure migrations are applied and the account has completed signup before running the update.
5. Open the app's normal **Log in** page and sign in with that same account. The profile role sends you to `/admin`. Admin access is checked from the authenticated profile and enforced again by RLS and role-checked database functions. Public signup metadata cannot create an admin profile, and users cannot update their own role.

No service-role key is needed for this setup. Never add one to `.env.local`, frontend code, or this repository.

## Approve a shop and its products

1. Log in as the admin and open **Shops** from the admin navigation.
2. Review a pending shop, then choose **Approve shop** or **Reject**. Approval activates the shop; rejection keeps it hidden.
3. Open **Products** and review the shop's pending products. Products can be approved only after the parent shop is approved and active. The database rejects approval attempts that do not meet this condition.
4. Once both shop and product are approved and active, customers can find them in discovery/search and open the product page. Shopkeepers' new submissions remain pending until an admin approves them.

## Try a customer inquiry and chat

1. Sign up or log in as a customer.
2. Open an approved product and select **Ask shopkeeper**. The app saves an inquiry; the database creates the linked conversation.
3. The customer is taken to that chat. The owning shopkeeper sees the inquiry under **Inquiries**, and can select **Reply in chat**. Both sides can also reopen conversations from their chat/activity areas.
4. If signed out, the product page offers a login link that returns the customer to that product. Only customer profiles can submit inquiries; RLS verifies the role and public approval state.

## Optional fictional demo data

The existing `supabase/seed.sql` contains fictional shops, products, variants, inquiries, chats, reservations, notifications, nearby requests, and reports. It creates no Auth users and requires two existing Auth-backed profiles:

- Shopkeeper name exactly `Mohalla Mart Demo Shopkeeper`
- Customer name exactly `Mohalla Mart Demo Customer`

Create these through normal signup with their respective roles, then run the entire seed file in Supabase **SQL Editor** after all four migrations are applied. It is idempotent and uses stable IDs. Its shops and products start pending, so use the admin workflow above to approve each shop first and then its products before customer discovery can show them. The seed preflight stops without inserts when the two named profiles are missing or duplicated.
