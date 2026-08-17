import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY
export const configured = Boolean(url && key)
export const supabase = createClient(url || 'https://placeholder.supabase.co', key || 'placeholder')

export type Profile = { id:string; email:string; full_name:string; role:'admin'|'user'; status:'pending'|'approved'|'rejected'; created_at:string }
export type Entry = { id:string; entry_date:string; opening_cash:number; sales_revenue:number; inventory_purchases:number; operating_expenses:number; other_money_in:number; other_money_out:number; closing_cash:number; notes:string; created_by:string; created_at:string; profiles?:{full_name:string}|null }

export const money = (n:number) => new Intl.NumberFormat('en-US',{maximumFractionDigits:0}).format(n || 0) + ' AFN'
