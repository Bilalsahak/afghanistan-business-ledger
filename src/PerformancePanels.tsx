import React from'react';
import{AlertTriangle,CalendarCheck2,ChartNoAxesCombined,CircleDollarSign,PackageCheck,Scale,TrendingDown,TrendingUp}from'lucide-react';
import{Entry,MonthlyClose,money}from'./lib';

const n=(v:unknown)=>Number(v)||0;
const sum=(rows:Entry[],key:keyof Entry)=>rows.reduce((total,row)=>total+n(row[key]),0);
const monthKey=(date:string)=>date.slice(0,7);
const displayDate=(date:string)=>new Date(date+'T00:00:00').toLocaleDateString(undefined,{month:'short',day:'numeric'});

export default function PerformancePanels({entries,closes}:{entries:Entry[];closes:MonthlyClose[]}){
  const key=new Date().toISOString().slice(0,7);
  const rows=entries.filter(row=>monthKey(row.entry_date)===key).sort((a,b)=>a.entry_date.localeCompare(b.entry_date));
  const sales=sum(rows,'sales_revenue');
  const purchases=sum(rows,'inventory_purchases');
  const expenses=sum(rows,'operating_expenses')+sum(rows,'other_money_out');
  const average=rows.length?sales/rows.length:0;
  const best=rows.length?[...rows].sort((a,b)=>n(b.sales_revenue)-n(a.sales_revenue))[0]:null;
  const lowest=rows.length?[...rows].sort((a,b)=>n(a.sales_revenue)-n(b.sales_revenue))[0]:null;
  const latest=rows.at(-1)||entries[0]||null;
  const first=rows.at(0)?.entry_date;
  const last=rows.at(-1)?.entry_date;
  const expectedDays=first&&last?Math.max(1,Math.round((new Date(last+'T00:00:00').getTime()-new Date(first+'T00:00:00').getTime())/86400000)+1):0;
  const close=closes.find(item=>monthKey(item.month_start)===key);
  const closeExpenses=close?n(close.rent)+n(close.salaries)+n(close.utilities)+n(close.transport)+n(close.other_expenses):0;
  const cogs=close?n(close.beginning_inventory)+purchases-n(close.ending_inventory):null;
  const gross=cogs===null?null:sales-cogs;
  const net=gross===null?null:gross-expenses-closeExpenses;
  const margin=net===null||sales===0?null:(net/sales)*100;
  const expenseRatio=sales?expenses/sales:0;

  return <div className="control-stack">
    <article className="control-panel">
      <header className="control-heading"><div><p className="eyebrow">DAILY CONTROL</p><h2>Operating discipline</h2><p>Where did the money go, and were all seven days recorded?</p></div><CalendarCheck2/></header>
      <div className="control-kpis">
        <div><span>Average daily sales</span><b>{money(average)}</b><small>{rows.length} recorded days this month</small></div>
        <div><span>Best sales day</span><b>{money(n(best?.sales_revenue))}</b><small>{best?displayDate(best.entry_date):'No records yet'}</small></div>
        <div><span>Lowest sales day</span><b>{money(n(lowest?.sales_revenue))}</b><small>{lowest?displayDate(lowest.entry_date):'No records yet'}</small></div>
        <div><span>Month operating expenses</span><b>{money(expenses)}</b><small>{(expenseRatio*100).toFixed(2)}% of recorded sales</small></div>
      </div>
      <div className="cash-strip">
        <div><Scale/><span>Expected cash<b>{money(n(latest?.expected_closing_cash))}</b></span></div>
        <div><CircleDollarSign/><span>Actual cash<b>{money(n(latest?.closing_cash))}</b></span></div>
        <div className={n(latest?.cash_difference)===0?'good':'bad'}>{n(latest?.cash_difference)<0?<TrendingDown/>:<TrendingUp/>}<span>Cash difference<b>{money(n(latest?.cash_difference))}</b></span></div>
        <div className={rows.length===expectedDays&&rows.length>0?'good':'warn'}><CalendarCheck2/><span>Days recorded<b>{rows.length}/{expectedDays||0}</b></span></div>
      </div>
      {sales>0&&expenseRatio<.005&&<div className="data-warning"><AlertTriangle/><span><b>Expense capture looks unusually low.</b><small>Confirm that transport, wages, loading, utilities, food, packaging, repairs and other small costs are entered daily.</small></span></div>}
    </article>

    <article className="control-panel performance-panel">
      <header className="control-heading"><div><p className="eyebrow">MONTHLY PERFORMANCE</p><h2>Profit after inventory valuation</h2><p>Did the business actually make money?</p></div><ChartNoAxesCombined/></header>
      <div className="inventory-equation">
        <div><span>Beginning inventory</span><b>{close?money(n(close.beginning_inventory)):'Pending count'}</b></div><i>+</i>
        <div><span>Purchases</span><b>{money(purchases)}</b></div><i>−</i>
        <div><span>Ending inventory</span><b>{close?money(n(close.ending_inventory)):'Pending count'}</b></div><i>=</i>
        <div className="result"><span>Cost of goods sold</span><b>{cogs===null?'Complete monthly close':money(cogs)}</b></div>
      </div>
      {close?<div className="profit-kpis">
        <div><span>Sales</span><b>{money(sales)}</b></div>
        <div><span>Gross profit</span><b>{money(n(gross))}</b></div>
        <div><span>All operating expenses</span><b>{money(expenses+closeExpenses)}</b></div>
        <div className={n(net)>=0?'good':'bad'}><span>Net operating profit</span><b>{money(n(net))}</b><small>{margin?.toFixed(1)}% net margin</small></div>
      </div>:<div className="profit-pending"><PackageCheck/><span><b>Profit is intentionally pending.</b><small>At month-end, enter beginning inventory, physically count ending inventory, and record all obligations. The system will then calculate COGS, gross profit, net profit and margin.</small></span></div>}
      <p className="accounting-note"><b>Control:</b> Net cash movement is never labelled as profit. Unsold inventory remains a business asset.</p>
    </article>
  </div>
}
