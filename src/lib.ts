import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY
export const configured = Boolean(url && key)
export const supabase = createClient(url || 'https://placeholder.supabase.co', key || 'placeholder')

export type UserRole = 'admin'|'manager'|'data_entry'|'viewer'|'user'
export type Profile = { id:string; email:string; full_name:string; role:UserRole; status:'pending'|'approved'|'rejected'; created_at:string }
export type Entry = { id:string; entry_date:string; opening_cash:number; sales_revenue:number; inventory_purchases:number; operating_expenses:number; other_money_in:number; other_money_out:number; closing_cash:number; expected_closing_cash:number; cash_difference:number; notes:string; status?:string; created_by:string; created_at:string; profiles?:{full_name:string}|null }
export type MonthlyClose = { id:string; month_start:string; beginning_inventory:number; ending_inventory:number; rent:number; salaries:number; utilities:number; transport:number; other_expenses:number; closing_cash:number; receivables:number; payables:number; notes:string; status:string; created_at:string }
export type QuarterlyReview = { id:string; year:number; quarter:number; retained_profit:number; distributions:number; inventory_actions:string; cash_actions:string; major_decisions:string; approved_by_partners:string; status:string }
export type Partner = { id:string; display_order:number; name:string; name_local:string; capital_afn:number; ownership_percent:number|null; contribution_basis:string; is_confirmed:boolean; notes:string }
export type StartupSummary = { transaction_count:number; total_afn:number; total_usd:number; notes:string }
export type AuditEvent = { id:number; table_name:string; record_id:string; action:string; actor_id:string|null; occurred_at:string }
export type PartnerTransaction = { id:string; partner_id:string; transaction_date:string; transaction_type:'capital_contribution'|'partner_withdrawal'|'partner_loan_in'|'loan_repayment'|'profit_distribution'; amount_afn:number; notes:string; status:'pending'|'approved'|'rejected'; submitted_by:string; approved_by:string|null; created_at:string; partners?:{name:string;name_local:string}|null; profiles?:{full_name:string}|null }
export type ActivityMessage = { id:string; message:string; created_by:string; created_at:string; profiles?:{full_name:string}|null }

export const money = (n:number) => new Intl.NumberFormat('en-US',{maximumFractionDigits:0}).format(n || 0) + ' AFN'
export const compactMoney = (n:number) => new Intl.NumberFormat('en-US',{notation:'compact',maximumFractionDigits:1}).format(n || 0) + ' AFN'
