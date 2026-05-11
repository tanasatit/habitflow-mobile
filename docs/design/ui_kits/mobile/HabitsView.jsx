/* @jsx React.createElement */

function HabitsView({ habits, openCreate }) {
  const { C, CAT, Icon } = window.HF;
  return (
    <div className="hf-screen">
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 20px 20px' }} className="hf-no-scrollbar">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 18 }}>
          <div>
            <h1 className="hf-page-hero" style={{ fontSize: 34, color: C.text }}>Your Oasis.</h1>
            <p style={{ fontSize: 12, color: C.textDim, marginTop: 2 }}>{habits.length} rituals tracked</p>
          </div>
          <button onClick={openCreate} style={{
            background: C.primary, color: '#fff', border: 0, borderRadius: 9999,
            padding: '9px 16px', fontWeight: 600, fontSize: 13, display: 'flex', alignItems: 'center', gap: 4,
            cursor: 'pointer', boxShadow: '0 8px 24px rgba(255,130,67,.18)',
          }}><Icon name="add" size={16} color="#fff" /> Add</button>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          {habits.map(h => <BentoCard key={h.id} h={h} />)}
          <button onClick={openCreate} style={{
            background: 'transparent', border: `2px dashed ${C.outline}`, borderRadius: 22,
            padding: '16px 12px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
            gap: 6, color: C.textDim, cursor: 'pointer', minHeight: 144, fontFamily: 'inherit',
          }}>
            <Icon name="add" size={22} color={C.textDim} />
            <span style={{ fontSize: 12, fontWeight: 600 }}>New ritual</span>
          </button>
        </div>
      </div>
    </div>
  );
}

function BentoCard({ h }) {
  const { C, CAT, Icon } = window.HF;
  const cat = CAT[h.category] ?? { bg: C.surfaceVar, fg: C.textDim, icon: 'star' };
  const pct = Math.min(100, Math.round(h.streak / 30 * 100));
  return (
    <div className="hf-card" style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 10, position: 'relative', overflow: 'hidden', minHeight: 144 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ width: 34, height: 34, borderRadius: 11, background: cat.bg, color: cat.fg, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name={cat.icon} size={16} fill color={cat.fg} />
        </div>
        <span style={{ fontSize: 10, fontWeight: 500, padding: '2px 8px', borderRadius: 9999, background: cat.bg, color: cat.fg, textTransform: 'capitalize' }}>{h.category}</span>
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 13, fontWeight: 600, lineHeight: 1.3, textDecoration: h.done ? 'line-through' : 'none', opacity: h.done ? 0.6 : 1 }}>{h.name}</div>
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 11 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 3 }}>
          <Icon name="local_fire_department" size={12} fill color={C.primary} />
          <span style={{ color: C.primary, fontWeight: 700 }}>{h.streak} day streak</span>
        </div>
        <span style={{ color: C.textDim }}>{pct}%</span>
      </div>
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: 4, background: C.surfaceVar }}>
        <div style={{ height: '100%', width: `${pct}%`, background: C.tertiary, borderTopRightRadius: 4 }} />
      </div>
    </div>
  );
}

window.HabitsView = HabitsView;
