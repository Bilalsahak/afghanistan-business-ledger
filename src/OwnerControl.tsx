import React,{useEffect,useState}from'react';
import{AlertTriangle,CheckCircle2,Clock,Landmark,ShieldCheck,Trash2,Users}from'lucide-react';
import{MonthlyClose,money,PartnerTransaction,supabase}from'./lib';

type Go=(page:'capital'|'users')=>void;

export default function OwnerControl({closes,transactions,to,reload}:{closes:MonthlyClose[];transactions:PartnerTransaction[];to:Go;reload:()=>void}){
  const[pendingPeople,setPendingPeople]=useState(0);
  const[busyId,setBusyId]=useState<string|null>(null);
  const[msg,setMsg]=useState('');
  const pendingMoney=transactions.filter(x=>x.status==='pending');

  useEffect(()=>{
    supabase.from('profiles').select('id',{count:'exact',head:true}).eq('status','pending')
      .then(({count,error})=>{if(!error)setPendingPeople(count||0)});
  },[closes.length,transactions.length]);

  async function undoClose(id:string,monthStart:string){
    const label=new Date(monthStart+'T00:00:00').toLocaleDateString('en-US',{month:'long',year:'numeric'});
    if(!window.confirm(`Undo monthly close for ${label}? This deletes the close record. Daily entries stay protected.`))return;
    setBusyId(id);setMsg('');
    const{error}=await supabase.from('monthly_closes').delete().eq('id',id);
    setBusyId(null);
    if(error){setMsg(error.message);return}
    setMsg(`Monthly close for ${label} removed.`);
    reload();
  }

  return <section className="owner-control">
    <header className="page-head">
      <div>
        <p className="eyebrow">ADMIN ONLY</p>
        <h1>Owner Control</h1>
        <p>Safe operational controls for the owner. Daily entries stay protected; corrections use the daily adjustment flow.</p>
      </div>
    </header>

    {msg&&<p className="notice">{msg}</p>}

    <div className="control-cards">
      <article className="panel control-card">
        <div className="panel-head">
          <div>
            <p className="eyebrow">MONTHLY CLOSES</p>
            <h2>Undo monthly close</h2>
          </div>
          <Trash2/>
        </div>
        <p className="muted">Remove a mistaken monthly close. Inventory and daily records are not deleted.</p>
        {closes.length===0?<p className="muted">No monthly closes yet.</p>:
          <div className="close-undo-list">
            {closes.map(c=>{
              const label=new Date(c.month_start+'T00:00:00').toLocaleDateString('en-US',{month:'long',year:'numeric'});
              return <article key={c.id} className="close-undo-row">
                <div>
                  <b>{label}</b>
                  <small>Cash {money(Number(c.closing_cash))} · {c.status}</small>
                </div>
                <button className="danger-btn" disabled={busyId===c.id} onClick={()=>undoClose(c.id,c.month_start)}>
                  <Trash2/>{busyId===c.id?'Working…':'Delete / Undo'}
                </button>
              </article>;
            })}
          </div>}
      </article>

      <article className="panel control-card">
        <div className="panel-head">
          <div>
            <p className="eyebrow">APPROVALS</p>
            <h2>Pending partner money</h2>
          </div>
          <Landmark/>
        </div>
        <p className="control-count"><strong>{pendingMoney.length}</strong> request{pendingMoney.length===1?'':'s'} waiting</p>
        <button onClick={()=>to('capital')}>Open Partner money</button>
      </article>

      <article className="panel control-card">
        <div className="panel-head">
          <div>
            <p className="eyebrow">APPROVALS</p>
            <h2>Pending people approvals</h2>
          </div>
          <Users/>
        </div>
        <p className="control-count"><strong>{pendingPeople}</strong> account{pendingPeople===1?'':'s'} waiting</p>
        <button onClick={()=>to('users')}>Open People & access</button>
      </article>

      <article className="panel control-card">
        <div className="panel-head">
          <div>
            <p className="eyebrow">PROTECTION</p>
            <h2>Daily entries stay protected</h2>
          </div>
          <ShieldCheck/>
        </div>
        <p className="muted">Submitted daily records cannot be silently deleted. Use the daily adjustment / correction workflow so every change keeps evidence and approval history.</p>
      </article>

      <article className="panel control-card fresh-start">
        <div className="panel-head">
          <div>
            <p className="eyebrow">FRESH START STATUS</p>
            <h2>Operations can begin from day 1</h2>
          </div>
          <CheckCircle2/>
        </div>
        <p className="muted">Operational tables were cleared for a clean restart. Partner capital is preserved. Record the first daily entry when ready.</p>
        <ul className="fresh-start-note">
          <li><Clock size={16}/> Monthly closes: {closes.length}</li>
          <li><AlertTriangle size={16}/> Pending partner money: {pendingMoney.length}</li>
          <li><Users size={16}/> Pending people: {pendingPeople}</li>
        </ul>
      </article>
    </div>
  </section>;
}
