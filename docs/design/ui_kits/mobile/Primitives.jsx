/* @jsx React.createElement */
const { useState } = React;

const C = {
  primary: '#FF8243', secondary: '#FFC0CB', tertiary: '#069494', accent: '#FCE883',
  bg: '#FFF9F5', surface: '#FFFFFF', surfaceVar: '#F4F1EF',
  text: '#302E2C', textDim: '#5E5B58', outline: '#E0DAD6',
};

const CAT = {
  health:       { bg: '#DCFCE7', fg: '#15803D', icon: 'favorite' },
  fitness:      { bg: '#FFEDD5', fg: '#C2410C', icon: 'fitness_center' },
  mindfulness:  { bg: '#F3E8FF', fg: '#7E22CE', icon: 'self_improvement' },
  productivity: { bg: '#DBEAFE', fg: '#1D4ED8', icon: 'work' },
  learning:     { bg: '#FEF9C3', fg: '#A16207', icon: 'school' },
  social:       { bg: '#FCE7F3', fg: '#BE185D', icon: 'people' },
};

const Icon = ({ name, size = 20, fill = false, color, style }) => (
  <span className="material-symbols-outlined" style={{
    fontSize: size, color, lineHeight: 1, fontVariationSettings: fill ? "'FILL' 1" : "'FILL' 0",
    flexShrink: 0, ...style,
  }}>{name}</span>
);

// ── Pulsing flame keyframe (signature motion) ──
const StyleInjector = () => (
  <style>{`
    @keyframes hf-pulse { 0%,100% { transform:scale(1); opacity:1 } 50% { transform:scale(1.06); opacity:.92 } }
    .hf-pulse { animation: hf-pulse 2s ease-in-out infinite; transform-origin: center; }
    @keyframes hf-tap { 0% { transform:scale(1) } 40% { transform:scale(1.3) } 100% { transform:scale(1) } }
    .hf-checkpop { animation: hf-tap .35s cubic-bezier(0.34,1.56,0.64,1); }
    .hf-screen { font-family: 'Be Vietnam Pro', -apple-system, system-ui, sans-serif; color:${C.text}; background:${C.bg}; height:100%; display:flex; flex-direction:column; }
    .hf-headline { font-family: 'Plus Jakarta Sans', system-ui, sans-serif; }
    .hf-page-hero { font-family: 'Plus Jakarta Sans', system-ui, sans-serif; font-style: italic; font-weight: 800; letter-spacing: -0.015em; line-height: 1.1; }
    .hf-card { background:${C.surface}; border:1px solid ${C.outline}; border-radius: 22px; }
    .hf-no-scrollbar::-webkit-scrollbar { display: none; }
    .hf-no-scrollbar { scrollbar-width: none; }
  `}</style>
);

// ── Tab bar ──
const Tab = ({ icon, label, active, onClick }) => (
  <button onClick={onClick} style={{
    flex: 1, background: 'transparent', border: 0, padding: '6px 0 4px',
    display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
    color: active ? C.primary : C.textDim, cursor: 'pointer',
  }}>
    <Icon name={icon} size={24} fill={active} color={active ? C.primary : C.textDim} />
    <span style={{ fontSize: 10, fontWeight: active ? 700 : 500 }}>{label}</span>
  </button>
);
const TabBar = ({ tab, setTab }) => (
  <div style={{
    background: C.surface, borderTop: `1px solid ${C.outline}`,
    display: 'flex', padding: '0 4px 8px', flexShrink: 0,
  }}>
    <Tab icon="dashboard" label="Today" active={tab === 'today'} onClick={() => setTab('today')} />
    <Tab icon="checklist" label="Habits" active={tab === 'habits'} onClick={() => setTab('habits')} />
    <Tab icon="auto_awesome" label="Flow" active={tab === 'coach'} onClick={() => setTab('coach')} />
    <Tab icon="calendar_month" label="Calendar" active={tab === 'calendar'} onClick={() => setTab('calendar')} />
    <Tab icon="person" label="Profile" active={tab === 'profile'} onClick={() => setTab('profile')} />
  </div>
);

window.HF = { C, CAT, Icon, StyleInjector, TabBar };
