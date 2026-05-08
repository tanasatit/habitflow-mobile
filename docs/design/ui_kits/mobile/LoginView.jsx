/* @jsx React.createElement */
const { useState: useStateLogin } = React;

function LoginView({ onSignIn }) {
  const { C } = window.HF;
  const [email, setEmail] = useStateLogin('tai@habitflow.app');
  const [password, setPassword] = useStateLogin('••••••••••');
  return (
    <div className="hf-screen" style={{ padding: '36px 22px 22px', justifyContent: 'space-between' }}>
      <div>
        <div className="hf-page-hero" style={{ fontSize: 36, marginTop: 30 }}>
          <span style={{ color: C.primary }}>HabitFlow</span> <span style={{ color: C.tertiary }}>AI</span>
        </div>
        <p style={{ fontSize: 14, color: C.textDim, marginTop: 6 }}>Welcome back</p>

        <div style={{ marginTop: 30 }}>
          <label style={{ fontSize: 12, fontWeight: 600, color: C.text, display: 'block', marginBottom: 6 }}>Email</label>
          <input value={email} onChange={(e) => setEmail(e.target.value)} style={{
            width: '100%', padding: '13px 14px', background: C.surface,
            border: `1px solid ${C.outline}`, borderRadius: 14, fontSize: 15,
            color: C.text, outline: 'none', fontFamily: 'inherit',
          }} />
        </div>
        <div style={{ marginTop: 16 }}>
          <label style={{ fontSize: 12, fontWeight: 600, color: C.text, display: 'block', marginBottom: 6 }}>Password</label>
          <input value={password} onChange={(e) => setPassword(e.target.value)} type="password" style={{
            width: '100%', padding: '13px 14px', background: C.surface,
            border: `1px solid ${C.outline}`, borderRadius: 14, fontSize: 15,
            color: C.text, outline: 'none', fontFamily: 'inherit',
          }} />
        </div>

        <button onClick={onSignIn} style={{
          width: '100%', marginTop: 24, padding: '14px', background: C.primary,
          color: '#fff', border: 0, borderRadius: 14, fontWeight: 700, fontSize: 14,
          cursor: 'pointer',
        }}>Sign In</button>

        <div style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '22px 0 14px' }}>
          <div style={{ flex: 1, height: 1, background: C.outline }} />
          <span style={{ fontSize: 11, color: C.textDim, letterSpacing: '.1em' }}>OR</span>
          <div style={{ flex: 1, height: 1, background: C.outline }} />
        </div>

        <button style={{
          width: '100%', padding: '12px', background: C.surface, color: C.text,
          border: `1px solid ${C.outline}`, borderRadius: 14, fontWeight: 600, fontSize: 13,
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10, cursor: 'pointer',
        }}>
          <svg width="18" height="18" viewBox="0 0 48 48"><path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3c-1.6 4.7-6.1 8-11.3 8-6.6 0-12-5.4-12-12s5.4-12 12-12c3 0 5.8 1.1 7.9 3l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z"/><path fill="#FF3D00" d="m6.3 14.7 6.6 4.8C14.7 15.1 19 12 24 12c3 0 5.8 1.1 7.9 3l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z"/><path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2c-2 1.4-4.5 2.4-7.2 2.4-5.2 0-9.6-3.3-11.2-7.9l-6.5 5C9.6 39.6 16.2 44 24 44z"/><path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.1-4.1 5.5l6.2 5.2c-.4.4 6.6-4.8 6.6-14.7 0-1.3-.1-2.4-.4-3.5z"/></svg>
          Continue with Google
        </button>

        <p style={{ marginTop: 22, textAlign: 'center', fontSize: 13, color: C.textDim }}>
          No account? <a href="#" style={{ color: C.primary, fontWeight: 700, textDecoration: 'none' }}>Create one</a>
        </p>
      </div>
    </div>
  );
}
window.LoginView = LoginView;
