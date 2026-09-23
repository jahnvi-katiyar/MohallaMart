### MohallaMart — Features ###

## Core Features ##

1. Authentication & Roles

- Customer and shopkeeper login/signup(Note: I will keep the whole system as easy as possible, So that each and every shopkeeper can use it easily)
- Role-based access

2. Shop Management

- Create/edit shop profile
- Address, contact, timings
- Open/closed status
- Public shop page

3. Product Management

- Add/edit/delete products
- Images, price, category
- Stock status
- Product variants (size, color, etc.)

4. Product Discovery

- Product search
- Category and price filters
- Nearby shop discovery
- Product details

5. Inquiry & Chat

- Product-based inquiries
- In-app customer–shopkeeper chat
- Conversation history
- Inquiry status: "New → In Progress → Resolved"

6. Reservation

- Request product reservation
- Confirm/cancel reservation
- Pickup details

7. Notifications

- New inquiry/message alerts
- Reservation updates

8. Ask Nearby Shops

- Send one product request to multiple nearby shops
- Receive availability responses

9. Sharing

- Shareable shop/product links
- Optional WhatsApp handoff

10. Admin & Safety

- Shop/user management
- Report inappropriate listings
- Basic moderation
- Secure role-based access

---------------------------------------------------------------------------------

## Core Flow ##

flowchart
    A[Search] --> B[View Product]
    B --> C[Check Stock]
    C --> D[Chat / Inquiry]
    D --> E[Shopkeeper Reply]
    E --> F[Reserve / Visit]
    F --> G[Purchase]
-----------------------------------------------------------------------------------
## MVP Priority ##

Must Have:
Authentication · Shop Profile · Products · Search · Stock Status · Inquiry · Chat · Shopkeeper Dashboard

Enhancements:
Reservation · Notifications · Ask Nearby Shops · WhatsApp · Sharing

Future:
Payments · Delivery · AI Recommendations · Advanced Analytics
