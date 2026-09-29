-- Mohalla Mart development/demo seed data only.
-- No schema, migration history, Auth users, profiles, policies, or existing rows are changed.
-- Prerequisite: after applying migrations 001-003, create these two demo accounts
-- through the normal signup screen, with the exact names and roles below.
-- This seed intentionally requires those real Auth-backed profiles and never fabricates them.
-- Seeded shops/products remain pending review; only an admin can approve listings.

begin;

do $$
declare
  shopkeeper_count integer;
  customer_count integer;
begin
  select count(*) into shopkeeper_count
  from public.profiles
  where full_name = 'Mohalla Mart Demo Shopkeeper' and role = 'shopkeeper';

  select count(*) into customer_count
  from public.profiles
  where full_name = 'Mohalla Mart Demo Customer' and role = 'customer';

  if shopkeeper_count <> 1 or customer_count <> 1 then
    raise exception 'Demo seed stopped: create exactly one Auth-backed shopkeeper profile named "Mohalla Mart Demo Shopkeeper" and one customer profile named "Mohalla Mart Demo Customer" using the existing signup flow.';
  end if;
end;
$$;
do $$
begin
  if exists (select 1 from public.shops where status = 'approved' and category in ('MOHALLA_DEMO_ONLY_FOOTWEAR','MOHALLA_DEMO_ONLY_ELECTRONICS','MOHALLA_DEMO_ONLY_FASHION')) then
    raise exception 'Demo seed stopped: a live shop uses a reserved demo-only request category; no seed rows were written.';
  end if;
end;
$$;

-- 10 fictional local shops. Stable IDs/slugs and DO NOTHING make reruns idempotent.
with demo_shops(shop_no, name, description, category, address, locality, latitude, longitude, is_open) as (
  values
    (1, 'Sharma General Store', 'Demo listing: a fictional neighborhood store for Mohalla Mart previews.', 'Groceries', '1 Demo Lane', 'Sample Colony', 22.7196, 75.8577, true),
    (2, 'Fresh Basket Grocery', 'Demo listing: a fictional produce and grocery shop for local discovery previews.', 'Groceries', '2 Sample Market Road', 'Demo Nagar', 22.7231, 75.8518, true),
    (3, 'Krishna Garments', 'Demo listing: a fictional clothing shop with sample apparel listings.', 'Fashion', '3 Demo Bazaar Street', 'Sample Colony', 22.7157, 75.8614, true),
    (4, 'Radha Fashion Corner', 'Demo listing: a fictional boutique for clothing catalog previews.', 'Fashion', '4 Sample Plaza', 'Demo Nagar', 22.7262, 75.8641, true),
    (5, 'City Footwear Hub', 'Demo listing: a fictional footwear shop with sample shoe sizes.', 'Footwear', '5 Demo Market Road', 'Sample Colony', 22.7119, 75.8512, true),
    (6, 'Mobile Point', 'Demo listing: a fictional mobile and accessories shop.', 'Electronics', '6 Sample Square', 'Demo Nagar', 22.7303, 75.8552, true),
    (7, 'Neighbourhood Pharmacy', 'Demo listing: a fictional pharmacy for catalog and stock previews.', 'Health & Beauty', '7 Demo Lane', 'Sample Colony', 22.7174, 75.8680, true),
    (8, 'Home & Kitchen Bazaar', 'Demo listing: a fictional home essentials shop.', 'Home & Kitchen', '8 Sample Market Road', 'Demo Nagar', 22.7088, 75.8610, true),
    (9, 'Paper & Pen Stationery', 'Demo listing: a fictional stationery shop for local discovery previews.', 'Stationery', '9 Demo Plaza', 'Sample Colony', 22.7350, 75.8607, true),
    (10, 'Active Sports Corner', 'Demo listing: a fictional sports and fitness shop.', 'Sports', '10 Sample Bazaar Street', 'Demo Nagar', 22.7215, 75.8449, false)
)
insert into public.shops (
  id, owner_id, name, slug, description, category, address, locality, city,
  latitude, longitude, opening_hours, is_open, status, is_active
)
select
  md5('mohalla-mart-demo-shop-' || lpad(s.shop_no::text, 2, '0'))::uuid,
  (select id from public.profiles where full_name = 'Mohalla Mart Demo Shopkeeper' and role = 'shopkeeper'),
  s.name,
  'demo-' || lower(regexp_replace(s.name, '[^a-zA-Z0-9]+', '-', 'g')),
  s.description, s.category, s.address, s.locality, 'Indore',
  s.latitude, s.longitude,
  '{"monday":{"open":"09:00","close":"20:00"},"tuesday":{"open":"09:00","close":"20:00"},"wednesday":{"open":"09:00","close":"20:00"},"thursday":{"open":"09:00","close":"20:00"},"friday":{"open":"09:00","close":"20:00"},"saturday":{"open":"09:00","close":"20:00"},"sunday":{"open":"10:00","close":"16:00"}}'::jsonb,
  s.is_open, 'pending', true
from demo_shops s
on conflict (id) do nothing;

-- 60 fictional catalog products. Stock split: 36 in stock, 15 limited, 9 out of stock.
with demo_products(product_no, shop_no, name, description, category, price) as (
  values
    (1,1,'Basmati Rice 5kg','Long-grain rice for everyday meals.','Groceries',650.00),
    (2,1,'Tata Salt 1kg','Everyday iodised salt.','Groceries',30.00),
    (3,1,'Toor Dal 1kg','Protein-rich split pigeon peas.','Groceries',145.00),
    (4,1,'Cold-Pressed Mustard Oil 1L','Aromatic mustard oil for home cooking.','Groceries',185.00),
    (5,1,'Whole Wheat Atta 5kg','Stone-ground whole wheat flour.','Groceries',255.00),
    (6,1,'Jaggery Powder 500g','Unrefined sweetener for drinks and desserts.','Groceries',75.00),
    (7,2,'Alphonso Mangoes 1kg','Seasonal mangoes selected for ripeness.','Groceries',240.00),
    (8,2,'Farm Fresh Tomatoes 1kg','Fresh tomatoes for daily cooking.','Groceries',42.00),
    (9,2,'Premium Onions 2kg','Kitchen staple, packed in a two-kilo bag.','Groceries',68.00),
    (10,2,'Bananas 1 Dozen','Naturally ripened bananas.','Groceries',60.00),
    (11,2,'Full Cream Milk 1L','Pasteurised full cream milk.','Groceries',68.00),
    (12,2,'Paneer 200g','Fresh paneer for curries and snacks.','Groceries',92.00),
    (13,3,'Men''s Formal Shirt','Cotton-blend shirt suitable for work and occasions.','Fashion',899.00),
    (14,3,'Men''s Cotton T-Shirt','Soft everyday crew-neck T-shirt.','Fashion',499.00),
    (15,3,'Classic Blue Jeans','Straight-fit denim for daily wear.','Fashion',1199.00),
    (16,3,'Men''s Kurta','Lightweight kurta with a simple finish.','Fashion',999.00),
    (17,3,'Cotton Pajama Set','Comfortable cotton nightwear set.','Fashion',749.00),
    (18,3,'Men''s Casual Jacket','Light jacket for cool evenings.','Fashion',1599.00),
    (19,4,'Women''s Cotton Kurti','Printed cotton kurti for everyday wear.','Fashion',699.00),
    (20,4,'Printed Dupatta','Lightweight printed dupatta in a versatile style.','Fashion',349.00),
    (21,4,'Women''s Leggings','Stretch cotton-blend leggings.','Fashion',399.00),
    (22,4,'Festive Anarkali Suit','Embroidered festive wear with a flowing silhouette.','Fashion',1899.00),
    (23,4,'Women''s Cotton Saree','Breathable cotton saree with a classic border.','Fashion',1299.00),
    (24,4,'Everyday Tunic','Easy-fit tunic for casual outings.','Fashion',599.00),
    (25,5,'Men''s Formal Shoes','Polished lace-up shoes for office and events.','Footwear',999.00),
    (26,5,'Women''s Walking Shoes','Lightweight shoes for daily walks.','Footwear',1199.00),
    (27,5,'Men''s Running Shoes','Cushioned running shoes with a flexible sole.','Footwear',1499.00),
    (28,5,'Kids'' School Shoes','Durable school shoes with a comfortable lining.','Footwear',699.00),
    (29,5,'Women''s Flat Sandals','Everyday sandals with a cushioned footbed.','Footwear',549.00),
    (30,5,'Men''s Casual Sneakers','Versatile low-top sneakers for daily wear.','Footwear',1299.00),
    (31,6,'Bluetooth Earphones','Wireless earphones with a compact charging case.','Electronics',799.00),
    (32,6,'USB-C Cable 1m','Braided charging and data cable.','Electronics',299.00),
    (33,6,'20W USB-C Charger','Compact wall charger for compatible devices.','Electronics',699.00),
    (34,6,'Tempered Glass Screen Guard','Clear screen protection for select phone models.','Electronics',199.00),
    (35,6,'Power Bank 10000mAh','Portable backup charging for daily use.','Electronics',1299.00),
    (36,6,'Wireless Mouse','Compact wireless mouse for laptop and desktop use.','Electronics',599.00),
    (37,7,'Herbal Hand Wash 250ml','Gentle hand wash for everyday use.','Health & Beauty',115.00),
    (38,7,'Aloe Vera Gel 100g','Cooling aloe gel for skin and hair care.','Health & Beauty',95.00),
    (39,7,'Neem Face Wash 100ml','Daily face cleanser with neem extract.','Health & Beauty',145.00),
    (40,7,'SPF 30 Sunscreen 50g','Daily sunscreen for outdoor protection.','Health & Beauty',275.00),
    (41,7,'Vitamin C Tablets 30s','Packaged wellness supplement.','Health & Beauty',199.00),
    (42,7,'Cotton Bandage Roll','First-aid cotton bandage roll.','Health & Beauty',45.00),
    (43,8,'Stainless Steel Bottle 1L','Reusable bottle with a leak-resistant cap.','Home & Kitchen',349.00),
    (44,8,'Non-Stick Frying Pan 24cm','Everyday frying pan with a heat-resistant handle.','Home & Kitchen',699.00),
    (45,8,'Ceramic Tea Mug','Single ceramic mug for tea or coffee.','Home & Kitchen',180.00),
    (46,8,'Food Storage Containers Set','Stackable containers for kitchen storage.','Home & Kitchen',499.00),
    (47,8,'LED Bulb 9W','Energy-saving LED bulb for home lighting.','Home & Kitchen',120.00),
    (48,8,'Cotton Kitchen Towel Set','Absorbent cotton towels for kitchen use.','Home & Kitchen',220.00),
    (49,9,'Ruled Notebook 200 Pages','Hard-cover notebook for school or office.','Stationery',80.00),
    (50,9,'Gel Pen Set of 5','Smooth-writing blue gel pens.','Stationery',95.00),
    (51,9,'Colour Pencils Set of 12','Pencil colours for drawing and school projects.','Stationery',130.00),
    (52,9,'A4 Printer Paper 100 Sheets','Multipurpose white paper for printing and notes.','Stationery',110.00),
    (53,9,'Desk Organizer','Compact organizer for pens and stationery.','Stationery',249.00),
    (54,9,'Sticky Notes Pack','Assorted notes for reminders and study.','Stationery',65.00),
    (55,10,'Cricket Tennis Ball','Durable tennis ball for casual cricket.','Sports',55.00),
    (56,10,'Yoga Mat 6mm','Non-slip exercise mat for home workouts.','Sports',799.00),
    (57,10,'Skipping Rope','Adjustable rope for cardio and warmups.','Sports',199.00),
    (58,10,'Insulated Shaker Bottle','Sports bottle with mixing insert.','Sports',399.00),
    (59,10,'Badminton Shuttlecocks Set','Pack of six nylon shuttlecocks.','Sports',180.00),
    (60,10,'Resistance Band Set','Three resistance levels for home training.','Sports',499.00)
)
insert into public.products (
  id, shop_id, name, description, category, price, stock_quantity, image_url, image_urls, status, is_active
)
select
  md5('mohalla-mart-demo-product-' || lpad(p.product_no::text, 2, '0'))::uuid,
  md5('mohalla-mart-demo-shop-' || lpad(p.shop_no::text, 2, '0'))::uuid,
  p.name, 'Demo sample listing. ' || p.description, p.category, p.price,
  case when p.product_no <= 36 then 4 + (p.product_no % 20)
       when p.product_no <= 51 then 1 + (p.product_no % 3)
       else 0 end,
  null, '{}'::text[], 'pending', true
from demo_products p
on conflict (id) do nothing;

-- 90 size/color variants across the clothing, footwear, and mobile-accessory samples.
with variant_specs(product_no, variant_name, attribute_name) as (
  select p.product_no, v.name, 'size'
  from generate_series(13,24) p(product_no)
  cross join unnest(array['S','M','L','XL']) v(name)
  union all
  select p.product_no, v.name, 'size'
  from generate_series(25,30) p(product_no)
  cross join unnest(array['7','8','9','10']) v(name)
  union all
  select p.product_no, v.name, 'color'
  from generate_series(31,36) p(product_no)
  cross join unnest(array['Black','White','Blue']) v(name)
)
insert into public.product_variants (id, product_id, name, stock_quantity, attributes)
select
  md5('mohalla-mart-demo-variant-' || v.product_no::text || '-' || v.variant_name)::uuid,
  md5('mohalla-mart-demo-product-' || lpad(v.product_no::text, 2, '0'))::uuid,
  v.variant_name,
  case when product.stock_quantity = 0 then 0 else greatest(1, product.stock_quantity / 4) end,
  jsonb_build_object(v.attribute_name, v.variant_name)
from variant_specs v
join public.products product on product.id = md5('mohalla-mart-demo-product-' || lpad(v.product_no::text, 2, '0'))::uuid
on conflict (id) do nothing;

-- Six sample inquiries; the existing database trigger creates one conversation per inquiry.
with demo_inquiries(inquiry_no, product_no, shop_no, message, status) as (
  values
    (1,13,3,'Do you have this shirt in size L?','new'),
    (2,25,5,'Is this shoe available in size 9?','in_progress'),
    (3,30,5,'Can I reserve this pair for today?','resolved'),
    (4,32,6,'Do you have the black version of this cable?','new'),
    (5,43,8,'Is this bottle currently available?','in_progress'),
    (6,57,10,'Could you keep one aside until this evening?','resolved')
)
insert into public.inquiries (id, customer_id, shop_id, product_id, message, status)
select
  md5('mohalla-mart-demo-inquiry-' || i.inquiry_no::text)::uuid,
  (select id from public.profiles where full_name = 'Mohalla Mart Demo Customer' and role = 'customer'),
  md5('mohalla-mart-demo-shop-' || lpad(i.shop_no::text, 2, '0'))::uuid,
  md5('mohalla-mart-demo-product-' || lpad(i.product_no::text, 2, '0'))::uuid,
  i.message, i.status
from demo_inquiries i
on conflict (id) do nothing;

-- Three messages for each generated inquiry conversation (18 total).
with message_specs(inquiry_no, message_no, body, from_customer, minutes_ago) as (
  values
    (1,1,'Hi, do you have this shirt in size L?',true,180),
    (1,2,'Yes, size L is available at our shop.',false,170),
    (1,3,'Thank you. I will visit this afternoon.',true,160),
    (2,1,'Is this shoe available in size 9?',true,150),
    (2,2,'We have limited pairs in size 9 today.',false,140),
    (2,3,'Please keep one aside for an hour.',true,130),
    (3,1,'Can I reserve this pair for today?',true,120),
    (3,2,'Certainly, it is ready for pickup.',false,110),
    (3,3,'Thanks, I will be there soon.',true,100),
    (4,1,'Do you have the black version?',true,90),
    (4,2,'Yes, black is available at the moment.',false,80),
    (4,3,'Great, thank you.',true,70),
    (5,1,'Is this bottle currently available?',true,60),
    (5,2,'Yes, we have a few left in stock.',false,50),
    (5,3,'Please keep one aside for me.',true,40),
    (6,1,'Could you keep one aside until this evening?',true,30),
    (6,2,'We can hold it until 6 pm.',false,20),
    (6,3,'That works, thank you.',true,10)
)
insert into public.messages (id, conversation_id, sender_id, body, read_at, created_at)
select
  md5('mohalla-mart-demo-message-' || m.inquiry_no::text || '-' || m.message_no::text)::uuid,
  c.id,
  case when m.from_customer then c.customer_id else c.shopkeeper_id end,
  m.body,
  case when m.message_no < 3 then now() - make_interval(mins => m.minutes_ago - 2) else null end,
  now() - make_interval(mins => m.minutes_ago)
from message_specs m
join public.conversations c on c.inquiry_id = md5('mohalla-mart-demo-inquiry-' || m.inquiry_no::text)::uuid
order by m.inquiry_no, m.message_no
on conflict (id) do nothing;

-- Four sample reservations use products with sufficient stock.
with reservation_specs(reservation_no, product_no, shop_no, quantity, status, pickup_offset_days) as (
  values
    (1,4,1,1,'requested',0),
    (2,27,5,1,'confirmed',0),
    (3,38,7,2,'cancelled',-1),
    (4,50,9,1,'completed',-2)
)
insert into public.reservations (id, customer_id, shop_id, product_id, quantity, status, pickup_at)
select
  md5('mohalla-mart-demo-reservation-' || r.reservation_no::text)::uuid,
  (select id from public.profiles where full_name = 'Mohalla Mart Demo Customer' and role = 'customer'),
  md5('mohalla-mart-demo-shop-' || lpad(r.shop_no::text, 2, '0'))::uuid,
  md5('mohalla-mart-demo-product-' || lpad(r.product_no::text, 2, '0'))::uuid,
  r.quantity, r.status,
  now() + make_interval(days => r.pickup_offset_days)
from reservation_specs r
on conflict (id) do nothing;

-- Three clearly marked nearby demo requests and five replies. Reserved categories prevent the existing notification trigger from notifying real shops.
with request_specs(request_no, title, category, variant, budget, message, locality, latitude, longitude) as (
  values
    (1,'Black formal shoes, size 9','MOHALLA_DEMO_ONLY_FOOTWEAR','Size 9',1000.00,'Looking for black formal shoes in size 9, under ₹1,000.','Sample Colony',22.7190,75.8580),
    (2,'Wireless mouse for laptop','MOHALLA_DEMO_ONLY_ELECTRONICS','Black',700.00,'Need a reliable wireless mouse for everyday laptop use.','Demo Nagar',22.7260,75.8550),
    (3,'Cotton kurti for daily wear','MOHALLA_DEMO_ONLY_FASHION','Medium',800.00,'Looking for a comfortable cotton kurti in medium size.','Sample Colony',22.7160,75.8620)
)
insert into public.product_requests (id, customer_id, title, category, variant, budget, message, locality, latitude, longitude, status)
select
  md5('mohalla-mart-demo-request-' || r.request_no::text)::uuid,
  (select id from public.profiles where full_name = 'Mohalla Mart Demo Customer' and role = 'customer'),
  r.title, r.category, r.variant, r.budget, r.message, r.locality, r.latitude, r.longitude, 'open'
from request_specs r
on conflict (id) do nothing;

with response_specs(request_no, shop_no, availability, message, price) as (
  values
    (1,5,'available','Size 9 is available for pickup today.',999.00),
    (1,3,'not_available','We do not stock formal footwear.',null::numeric),
    (2,6,'limited','One black wireless mouse is available.',599.00),
    (2,8,'not_available','We do not carry computer accessories.',null::numeric),
    (3,4,'available','Cotton kurtis in medium are available.',699.00)
)
insert into public.product_request_responses (id, request_id, shop_id, availability, message, price)
select
  md5('mohalla-mart-demo-response-' || r.request_no::text || '-' || r.shop_no::text)::uuid,
  md5('mohalla-mart-demo-request-' || r.request_no::text)::uuid,
  md5('mohalla-mart-demo-shop-' || lpad(r.shop_no::text, 2, '0'))::uuid,
  r.availability, r.message, r.price
from response_specs r
on conflict (id) do nothing;

-- Two sample reports to populate the existing moderation queue.
-- Exactly one target is supplied per report, as required by the existing CHECK constraint.
insert into public.reports (id, reporter_id, shop_id, product_id, reason, status)
values
  (md5('mohalla-mart-demo-report-1')::uuid,
   (select id from public.profiles where full_name = 'Mohalla Mart Demo Customer' and role = 'customer'),
   md5('mohalla-mart-demo-shop-3')::uuid, null,
   'Demo report: sample listing detail needs a moderation review.', 'open'),
  (md5('mohalla-mart-demo-report-2')::uuid,
   (select id from public.profiles where full_name = 'Mohalla Mart Demo Customer' and role = 'customer'),
   null, md5('mohalla-mart-demo-product-19')::uuid,
   'Demo report: sample product description is included for moderation preview.', 'reviewing')
on conflict (id) do nothing;
-- Eight explicit demo notifications. Existing insert triggers also create activity
-- notifications for inquiries, messages, reservations, and nearby-request replies.
insert into public.notifications (id, profile_id, title, body, href, read_at)
values
  (md5('mohalla-mart-demo-notification-1')::uuid,(select id from public.profiles where full_name='Mohalla Mart Demo Customer' and role='customer'),'Demo inquiry received','A sample shop has received your product inquiry.','/activity',null),
  (md5('mohalla-mart-demo-notification-2')::uuid,(select id from public.profiles where full_name='Mohalla Mart Demo Customer' and role='customer'),'Demo shopkeeper replied','There is a sample reply in your conversation.','/chat',null),
  (md5('mohalla-mart-demo-notification-3')::uuid,(select id from public.profiles where full_name='Mohalla Mart Demo Customer' and role='customer'),'Demo reservation confirmed','Your sample reservation is confirmed.','/reservations',null),
  (md5('mohalla-mart-demo-notification-4')::uuid,(select id from public.profiles where full_name='Mohalla Mart Demo Customer' and role='customer'),'Demo nearby response','A sample shop replied to your product request.','/activity',null),
  (md5('mohalla-mart-demo-notification-5')::uuid,(select id from public.profiles where full_name='Mohalla Mart Demo Shopkeeper' and role='shopkeeper'),'Demo customer inquiry','A sample customer asked about a product.','/seller/inquiries',null),
  (md5('mohalla-mart-demo-notification-6')::uuid,(select id from public.profiles where full_name='Mohalla Mart Demo Shopkeeper' and role='shopkeeper'),'Demo reservation request','A sample customer requested a reservation.','/seller/reservations',null),
  (md5('mohalla-mart-demo-notification-7')::uuid,(select id from public.profiles where full_name='Mohalla Mart Demo Shopkeeper' and role='shopkeeper'),'Demo message received','There is a sample message from a customer.','/seller/chat',null),
  (md5('mohalla-mart-demo-notification-8')::uuid,(select id from public.profiles where full_name='Mohalla Mart Demo Shopkeeper' and role='shopkeeper'),'Demo nearby request','A sample customer is looking for a local product.','/seller/requests',null)
on conflict (id) do nothing;

commit;