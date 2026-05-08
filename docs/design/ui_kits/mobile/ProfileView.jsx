/* @jsx React.createElement */

function ProfileView({ onLogout }) {
  const { C, Icon } = window.HF;
  return (
    <div className="hf-screen">
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 20px 20px' }} className="hf-no-scrollbar">
        <h1 className="hf-page-hero" style={{ fontSize: 28, color: C.text }}>Profile.</h1>

        {/* Avatar card */}
        <div className="hf-card" style={{ padding: 20, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, marginTop: 18 }}>
          <div style={{
            width: 72, height: 72, borderRadius: 9999, background: 'rgba(255,130,67,.1)', color: C.primary,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontFamily: 'Plus Jakarta Sans', fontWeight: 800, fontSize: 28,
            border: `2px solid ${C.primary}`,
          }}>T</div>
          <div style={{ textAlign: 'center' }}>
            <div className="hf-headline" style={{ fontWeight: 700, fontSize: 18 }}>Tai Tanasatit</div>
            <div style={{ fontSize: 12, color: C.textDim, marginTop: 2 }}>tai@habitflow.app</div>
          </div>
          <span style={{
            background: C.tertiary, color: '#fff', borderRadius: 9999, padding: '4px 12px',
            fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '.08em',
          }}>Premium</span>
        </div>

        {/* Stats */}
        <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
          <StatCard value="12" label="day streak" color={C.primary} icon="local_fire_department" />
          <StatCard value="86%" label="completion" color={C.tertiary} icon="check_circle" />
          <StatCard value="5" label="rituals" color={C.text} icon="checklist" />
        </div>

        {/* Settings list */}
        <div style={{ marginTop: 22 }}>
          <div style={{ fontSize: 11, color: C.textDim, fontWeight: 500, textTransform: 'uppercase', letterSpacing: '.06em', marginBottom: 8, paddingLeft: 4 }}>Settings</div>
          <div style={{ background: C.surface, border: `1px solid ${C.outline}`, borderRadius: 18, overflow: 'hidden' }}>
            <SettingRow icon="notifications" label="Notifications" />
            <SettingRow icon="palette" label="Appearance" right="Light" />
            <SettingRow icon="schedule" label="Reminder time" right="9:00 PM" />
            <SettingRow icon="help" label="Help & feedback" last />
          </div>
        </div>

        <button onClick={onLogout} style={{
          width: '100%', marginTop: 18, padding: '13px', background: 'transparent',
          color: '#EF4444', border: `1px solid ${C.outline}`, borderRadius: 14,
          fontWeight: 600, fontSize: 13, cursor: 'pointer', fontFamily: 'inherit',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
        }}>
          <Icon name="logout" size={16} color="#EF4444" />
          Log out
        </button>
      </div>
    </div>
  );
}

function StatCard({ value, label, color, icon }) {
  const { C, Icon } = window.HF;
  return (
    <div className="hf-card" style={{ flex: 1, padding: 12, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
      <Icon name={icon} size={18} fill color={color} />
      <div className="hf-headline" style={{ fontWeight: 800, fontSize: 22, color, lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>{value}</div>
      <div style={{ fontSize: 10, color: C.textDim, fontWeight: 500 }}>{label}</div>
    </div>
  );
}

function SettingRow({ icon, label, right, last }) {
  const { C, Icon } = window.HF;
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: '13px 14px',
      borderBottom: last ? 0 : `1px solid ${C.outline}`,
    }}>
      <Icon name={icon} size={18} color={C.text} />
      <span style={{ flex: 1, fontSize: 14, fontWeight: 500 }}>{label}</span>
      {right && <span style={{ fontSize: 12, color: C.textDim }}>{right}</span>}
      <Icon name="chevron_right" size={18} color={C.textDim} />
    </div>
  );
}

window.ProfileView = ProfileView;
