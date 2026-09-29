export type UserRole = 'customer' | 'shopkeeper' | 'admin'
export type Profile = { id: string; full_name: string; role: UserRole; phone: string | null; created_at: string }
export type Product = { id: string; shop_id?: string; name: string; description: string | null; price: number; category: string; stock_quantity: number; image_url: string | null; image_urls?: string[]; shops: { name: string; locality: string; id: string } | null }
