/* @jsx React.createElement */
const { useState: useStateToday } = React;

function TodayView({ habits, toggle }) {
  const { C, CAT, Icon } = window.HF;
  const completed = habits.filter(h => h.done).length;

  return (
    <div className="hf-screen">
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 20px 20px' }} className="hf-no-scrollbar">
        <h1 className="hf-headline" style={{ fontWeight: 800, fontSize: 28, lineHeight: 1.15, letterSpacing: '-0.01em' }}>
          Welcome back, <span style={{ color: C.primary }}>Tai</span>!
        </h1>
        <p style={{ fontSize: 13, color: C.textDim, marginTop: 4 }}>{completed} of {habits.length} rituals done today</p>

        {/* Streak + rings row */}
        <div style={{ display: 'flex', gap: 12, marginTop: 18 }}>
          <div className="hf-card" style={{
            flex: '0 0 130px', padding: '14px 10px', display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center', gap: 4,
          }}>
            <span className="hf-pulse" style={{ display: 'inline-flex' }}>
              <Icon name="local_fire_department" size={36} fill color={C.primary} />
            </span>
            <div className="hf-headline" style={{ fontWeight: 800, fontSize: 38, color: C.primary, lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>12</div>
            <div style={{ fontSize: 11, color: C.textDim, fontWeight: 500 }}>day streak</div>
          </div>
          <div className="hf-card" style={{ flex: 1, padding: 14, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
            <div style={{ fontSize: 12, fontWeight: 600, marginBottom: 8 }}>Progress</div>
            <div style={{ display: 'flex', justifyContent: 'space-around' }}>
              <Ring color={C.tertiary} pct={(completed / Math.max(habits.length, 1)) * 100} value={`${completed}/${habits.length}`} label="Daily" />
              <Ring color={C.primary} pct={86} value="86%" label="Weekly" />
            </div>
          </div>
        </div>

        {/* Section header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 22, marginBottom: 10 }}>
          <h2 className="hf-headline" style={{ fontWeight: 700, fontSize: 16 }}>Today's Rituals</h2>
          <a href="#" style={{ fontSize: 12, color: C.tertiary, textDecoration: 'none' }}>View all</a>
        </div>

        {habits.map(h => <HabitRow key={h.id} h={h} onToggle={() => toggle(h.id)} />)}

        {/* AI Insight */}
        <div style={{
          background: C.accent, border: `1px solid ${C.outline}`, borderRadius: 18, padding: '14px 16px', marginTop: 16,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
            <Icon name="auto_awesome" size={16} fill color={C.text} />
            <span style={{ fontWeight: 600, fontSize: 13 }}>AI Insight</span>
          </div>
          <p style={{ fontSize: 13, lineHeight: 1.5 }}>You're building great momentum! Keep up your consistency and your streak will grow even stronger.</p>
        </div>
      </div>
    </div>
  );
}

function Ring({ color, pct, value, label }) {
  const { C } = window.HF;
  const r = 28, c = 2 * Math.PI * r;
  const off = c - (pct / 100) * c;
  return (
    <div style={{ textAlign: 'center', position: 'relative' }}>
      <svg width={72} height={72}>
        <circle cx={36} cy={36} r={r} stroke={C.outline} strokeWidth={6} fill="none" />
        <circle cx={36} cy={36} r={r} stroke={color} strokeWidth={6} strokeLinecap="round" fill="none"
          strokeDasharray={c} strokeDashoffset={off} transform="rotate(-90 36 36)" />
      </svg>
      <div className="hf-headline" style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 13, marginTop: -14 }}>{value}</div>
      <div style={{ fontSize: 10, color: C.textDim, fontWeight: 500, marginTop: -8 }}>{label}</div>
    </div>
  );
}

function HabitRow({ h, onToggle }) {
  const { C, CAT, Icon } = window.HF;
  const cat = CAT[h.category] ?? { bg: C.surfaceVar, fg: C.textDim, icon: 'star' };
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: 12, marginBottom: 8,
      background: C.surface, border: `1px solid ${C.outline}`, borderRadius: 18,
      opacity: h.done ? 0.6 : 1,
    }}>
      <div style={{
        width: 38, height: 38, borderRadius: 12, background: cat.bg, color: cat.fg,
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
      }}>
        <Icon name={cat.icon} size={18} fill color={cat.fg} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14, fontWeight: 600, textDecoration: h.done ? 'line-through' : 'none', color: h.done ? C.textDim : C.text }}>{h.name}</div>
        <div style={{ fontSize: 11, color: C.textDim, textTransform: 'capitalize', marginTop: 2 }}>{h.category}</div>
      </div>
      {h.streak > 0 && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 3, flexShrink: 0 }}>
          <Icon name="local_fire_department" size={13} fill color={C.primary} />
          <span style={{ color: C.primary, fontWeight: 700, fontSize: 12 }}>{h.streak}</span>
        </div>
      )}
      <button onClick={onToggle} style={{ background: 'transparent', border: 0, padding: 0, cursor: 'pointer', flexShrink: 0 }} aria-label={h.done ? 'Undo' : 'Mark complete'}>
        {h.done ? (
          <div className="hf-checkpop" style={{ width: 26, height: 26, borderRadius: 9999, background: C.tertiary, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="check" size={14} fill color="#fff" />
          </div>
        ) : (
          <div style={{ width: 26, height: 26, borderRadius: 9999, border: `2px solid ${C.outline}` }} />
        )}
      </button>
    </div>
  );
}

window.TodayView = TodayView;
