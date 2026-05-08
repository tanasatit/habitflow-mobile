/* @jsx React.createElement */
const { useState: useStateCoach, useRef: useRefCoach, useEffect: useEffectCoach } = React;

function CoachView() {
  const { C, Icon } = window.HF;
  const [messages, setMessages] = useStateCoach([]);
  const [draft, setDraft] = useStateCoach('');
  const [busy, setBusy] = useStateCoach(false);
  const scrollRef = useRefCoach(null);

  useEffectCoach(() => { scrollRef.current?.scrollTo({ top: 9999 }); }, [messages]);

  const send = (text) => {
    const trimmed = (text ?? draft).trim();
    if (!trimmed) return;
    const userMsg = { id: Date.now(), role: 'user', content: trimmed };
    setMessages(m => [...m, userMsg]);
    setDraft('');
    setBusy(true);
    setTimeout(() => {
      const reply = canned(trimmed);
      setMessages(m => [...m, { id: Date.now() + 1, role: 'assistant', content: reply.text, events: reply.events }]);
      setBusy(false);
    }, 900);
  };

  return (
    <div className="hf-screen">
      <div style={{ padding: '14px 20px 8px', borderBottom: `1px solid ${C.outline}` }}>
        <h1 className="hf-page-hero" style={{ fontSize: 26, color: C.text }}>Ask Flow.</h1>
        <p style={{ fontSize: 11, color: C.textDim, marginTop: 2 }}>Your habit planning assistant</p>
      </div>

      <div ref={scrollRef} style={{ flex: 1, overflowY: 'auto', padding: '14px 16px' }} className="hf-no-scrollbar">
        {messages.length === 0 && (
          <div style={{ textAlign: 'center', padding: '24px 12px' }}>
            <div style={{ width: 56, height: 56, margin: '0 auto', borderRadius: 9999, background: 'rgba(6,148,148,.1)', color: C.tertiary, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 12 }}>
              <Icon name="auto_awesome" size={28} fill color={C.tertiary} />
            </div>
            <h3 className="hf-headline" style={{ fontWeight: 700, fontSize: 16 }}>Tell me about your week</h3>
            <p style={{ fontSize: 12, color: C.textDim, marginTop: 4, lineHeight: 1.5 }}>I'll build a habit plan and schedule it on your calendar.</p>
          </div>
        )}

        {messages.map(m => <Bubble key={m.id} m={m} />)}
        {busy && <TypingDots />}
      </div>

      {messages.length === 0 && (
        <div style={{ display: 'flex', gap: 8, overflowX: 'auto', padding: '4px 16px 10px' }} className="hf-no-scrollbar">
          {['Plan my week', 'Build a morning routine', 'Review my progress', 'Add a gym habit'].map(s => (
            <button key={s} onClick={() => send(s)} style={{
              flexShrink: 0, background: C.surface, border: `1px solid ${C.outline}`, color: C.text,
              borderRadius: 9999, padding: '8px 16px', fontSize: 12, fontWeight: 700, cursor: 'pointer',
              fontFamily: 'inherit',
            }}>{s}</button>
          ))}
        </div>
      )}

      <div style={{ borderTop: `1px solid ${C.outline}`, padding: '10px 14px', background: C.bg }}>
        <div style={{
          background: C.surface, border: `1px solid ${C.outline}`, borderRadius: 18,
          display: 'flex', alignItems: 'center', gap: 6, padding: '6px 8px 6px 14px',
        }}>
          <input value={draft} onChange={e => setDraft(e.target.value)} onKeyDown={e => { if (e.key === 'Enter') send(); }}
            placeholder="Describe your week…" style={{
              flex: 1, border: 0, outline: 0, background: 'transparent', fontSize: 13, color: C.text, fontFamily: 'inherit',
            }} />
          <button onClick={() => send()} disabled={busy || !draft.trim()} style={{
            background: C.primary, color: '#fff', border: 0, borderRadius: 12,
            padding: '8px 16px', fontWeight: 700, fontSize: 11, textTransform: 'uppercase', letterSpacing: '.08em',
            cursor: busy ? 'not-allowed' : 'pointer', opacity: (busy || !draft.trim()) ? 0.4 : 1,
            fontFamily: 'Plus Jakarta Sans, system-ui',
          }}>Send</button>
        </div>
      </div>
    </div>
  );
}

function Bubble({ m }) {
  const { C, Icon } = window.HF;
  const isUser = m.role === 'user';
  return (
    <div style={{ display: 'flex', flexDirection: isUser ? 'row-reverse' : 'row', alignItems: 'flex-end', gap: 8, marginBottom: 10 }}>
      <div style={{
        width: 30, height: 30, borderRadius: 9999, flexShrink: 0,
        background: isUser ? 'rgba(255,130,67,.1)' : 'rgba(6,148,148,.1)',
        color: isUser ? C.primary : C.tertiary,
        display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 12,
        fontFamily: 'Plus Jakarta Sans',
      }}>{isUser ? 'T' : <Icon name="smart_toy" size={16} color={C.tertiary} />}</div>
      <div style={{ maxWidth: '75%' }}>
        <div style={{
          background: isUser ? C.primary : C.surface,
          color: isUser ? '#fff' : C.text,
          border: isUser ? 'none' : `1px solid ${C.outline}`,
          borderRadius: 16,
          [isUser ? 'borderTopRightRadius' : 'borderTopLeftRadius']: 4,
          padding: '10px 13px', fontSize: 13, lineHeight: 1.5, whiteSpace: 'pre-wrap',
        }}>{m.content}</div>
        {m.events && m.events.length > 0 && (
          <div style={{ marginTop: 6, background: C.surface, border: `1px solid ${C.outline}`, borderRadius: 14, padding: 10 }}>
            <div style={{ fontSize: 11, color: C.textDim, fontWeight: 600, marginBottom: 6 }}>📅 Scheduled {m.events.length} events</div>
            {m.events.map((e, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 0', fontSize: 12 }}>
                <div style={{ width: 6, height: 6, borderRadius: 9999, background: C.tertiary }} />
                <span style={{ flex: 1 }}>{e.title}</span>
                <span style={{ color: C.textDim, fontSize: 11 }}>{e.day} · {e.time}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function TypingDots() {
  const { C, Icon } = window.HF;
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8, marginBottom: 10 }}>
      <div style={{ width: 30, height: 30, borderRadius: 9999, background: 'rgba(6,148,148,.1)', color: C.tertiary, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon name="smart_toy" size={16} color={C.tertiary} />
      </div>
      <div style={{ background: C.surface, border: `1px solid ${C.outline}`, borderRadius: 16, borderTopLeftRadius: 4, padding: '12px 14px', display: 'flex', gap: 4 }}>
        {[0, 1, 2].map(i => <div key={i} style={{ width: 6, height: 6, borderRadius: 9999, background: C.textDim, opacity: 0.6, animation: `hf-pulse 1.2s ease-in-out ${i * 0.15}s infinite` }} />)}
      </div>
    </div>
  );
}

function canned(prompt) {
  const lc = prompt.toLowerCase();
  if (lc.includes('workout') || lc.includes('gym') || lc.includes('week')) {
    return {
      text: "Got it. I scheduled three 30-min workouts and added a morning meditation. Calendar updated.",
      events: [
        { title: 'Workout', day: 'Mon', time: '7:00 AM' },
        { title: 'Workout', day: 'Wed', time: '7:00 AM' },
        { title: 'Workout', day: 'Fri', time: '7:00 AM' },
      ],
    };
  }
  if (lc.includes('morning') || lc.includes('routine')) {
    return {
      text: "I built a 25-minute morning routine: hydrate, meditate, journal. Added daily reminders at 6:30 AM.",
      events: [{ title: 'Morning routine', day: 'Daily', time: '6:30 AM' }],
    };
  }
  return { text: "Tell me what you'd like to build — a morning routine, a workout schedule, or something else?" };
}

window.CoachView = CoachView;
