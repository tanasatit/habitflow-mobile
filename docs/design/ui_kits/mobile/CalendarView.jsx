/* @jsx React.createElement */
const { useState: useStateCal } = React;

function CalendarView() {
  const { C, Icon } = window.HF;
  const [selectedDay, setSelectedDay] = useStateCal(2); // Wed

  const days = [
    { d: 'M', n: 28 }, { d: 'T', n: 29 }, { d: 'W', n: 30 },
    { d: 'T', n: 1 },  { d: 'F', n: 2 },  { d: 'S', n: 3 }, { d: 'S', n: 4 },
  ];

  // events keyed by day index
  const eventsByDay = {
    0: [
      { time: '7:00 AM', dur: '30 min', title: 'Morning Workout', source: 'manual', cat: 'fitness' },
      { time: '9:00 AM', dur: '15 min', title: 'Daily Standup',   source: 'google', cat: 'work' },
    ],
    1: [
      { time: '6:30 AM', dur: '15 min', title: 'Meditate',        source: 'manual', cat: 'mindfulness' },
      { time: '7:00 PM', dur: '30 min', title: 'Read 30 pages',   source: 'manual', cat: 'learning' },
    ],
    2: [
      { time: '7:00 AM', dur: '30 min', title: 'Morning Workout', source: 'ai',     cat: 'fitness' },
      { time: '12:00 PM', dur: '20 min', title: 'Lunch walk',     source: 'manual', cat: 'health' },
      { time: '5:30 PM', dur: '45 min', title: 'Evening Run',     source: 'ai',     cat: 'fitness' },
      { time: '9:00 PM', dur: '10 min', title: 'Journal',         source: 'manual', cat: 'mindfulness' },
    ],
    3: [
      { time: '9:00 PM', dur: '30 min', title: 'Read 30 pages',   source: 'manual', cat: 'learning' },
    ],
    4: [
      { time: '7:00 AM', dur: '30 min', title: 'Morning Workout', source: 'ai',     cat: 'fitness' },
      { time: '6:00 PM', dur: '60 min', title: 'Call with Mom',   source: 'google', cat: 'social' },
    ],
    5: [
      { time: '9:00 AM', dur: '60 min', title: 'Yoga class',      source: 'manual', cat: 'mindfulness' },
    ],
    6: [],
  };

  const events = eventsByDay[selectedDay] || [];
  const monthLabel = 'April – May 2026';

  return (
    <div className="hf-screen">
      {/* Header */}
      <div style={{ padding: '14px 20px 12px', flexShrink: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <div style={{ fontSize: 11, color: C.textDim, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '.08em' }}>{monthLabel}</div>
            <h1 className="hf-page-hero" style={{ fontSize: 28, color: C.text, marginTop: 2 }}>This Week.</h1>
          </div>
          <button style={{
            width: 40, height: 40, borderRadius: 9999, background: C.primary, color: '#fff',
            border: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
            boxShadow: '0 6px 18px rgba(255,130,67,.3)', flexShrink: 0,
          }}><Icon name="add" size={20} color="#fff" /></button>
        </div>
      </div>

      {/* Day strip */}
      <div style={{
        display: 'flex', gap: 6, padding: '0 16px 14px', flexShrink: 0,
        borderBottom: `1px solid ${C.outline}`,
      }}>
        {days.map((day, i) => {
          const active = i === selectedDay;
          const hasEvents = (eventsByDay[i] || []).length > 0;
          return (
            <button key={i} onClick={() => setSelectedDay(i)} style={{
              flex: 1, padding: '8px 0 10px', borderRadius: 14,
              background: active ? C.primary : 'transparent',
              border: 0, cursor: 'pointer', display: 'flex', flexDirection: 'column',
              alignItems: 'center', gap: 4, fontFamily: 'inherit',
              transition: 'background .2s',
            }}>
              <span style={{
                fontSize: 10, fontWeight: 600, letterSpacing: '.05em',
                color: active ? 'rgba(255,255,255,.85)' : C.textDim,
              }}>{day.d}</span>
              <span className="hf-headline" style={{
                fontSize: 18, fontWeight: 700,
                color: active ? '#fff' : C.text,
                fontVariantNumeric: 'tabular-nums',
              }}>{day.n}</span>
              <span style={{
                width: 4, height: 4, borderRadius: 9999,
                background: hasEvents ? (active ? '#fff' : C.primary) : 'transparent',
              }} />
            </button>
          );
        })}
      </div>

      {/* Day details */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 20px 20px' }} className="hf-no-scrollbar">
        {events.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '40px 20px' }}>
            <div style={{
              width: 56, height: 56, margin: '0 auto 12px', borderRadius: 9999,
              background: C.surfaceVar, color: C.textDim, display: 'flex',
              alignItems: 'center', justifyContent: 'center',
            }}>
              <Icon name="event_busy" size={26} color={C.textDim} />
            </div>
            <h3 className="hf-headline" style={{ fontWeight: 700, fontSize: 16 }}>Nothing scheduled</h3>
            <p style={{ fontSize: 12, color: C.textDim, marginTop: 4, lineHeight: 1.5 }}>
              Tap + to add an event, or ask the AI Coach to plan your day.
            </p>
          </div>
        ) : (
          <>
            <div style={{ fontSize: 11, color: C.textDim, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '.06em', marginBottom: 10 }}>
              {events.length} event{events.length === 1 ? '' : 's'}
            </div>
            {events.map((e, i) => <EventCard key={i} e={e} />)}
          </>
        )}
      </div>
    </div>
  );
}

function EventCard({ e }) {
  const { C, CAT, Icon } = window.HF;
  const cat = CAT[e.cat] || { bg: C.surfaceVar, fg: C.textDim, icon: 'event' };

  // source colors
  const sourceColor = e.source === 'ai' ? C.tertiary : e.source === 'google' ? C.secondary : C.primary;
  const sourceLabel = e.source === 'ai' ? 'AI Coach' : e.source === 'google' ? 'Google' : 'Manual';
  const sourceIcon  = e.source === 'ai' ? 'auto_awesome' : e.source === 'google' ? 'event' : 'edit';

  return (
    <div style={{
      display: 'flex', gap: 12, marginBottom: 10, alignItems: 'stretch',
    }}>
      {/* time gutter */}
      <div style={{ width: 60, flexShrink: 0, paddingTop: 12 }}>
        <div className="hf-headline" style={{ fontSize: 13, fontWeight: 700, color: C.text, fontVariantNumeric: 'tabular-nums' }}>{e.time}</div>
        <div style={{ fontSize: 10, color: C.textDim, marginTop: 1 }}>{e.dur}</div>
      </div>

      {/* card */}
      <div style={{
        flex: 1, background: C.surface, border: `1px solid ${C.outline}`, borderRadius: 16,
        padding: 12, position: 'relative', overflow: 'hidden',
      }}>
        {/* left accent bar */}
        <div style={{ position: 'absolute', top: 0, bottom: 0, left: 0, width: 3, background: sourceColor }} />

        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <div style={{
            width: 32, height: 32, borderRadius: 10, background: cat.bg, color: cat.fg,
            display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
          }}>
            <Icon name={cat.icon} size={16} fill color={cat.fg} />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 14, fontWeight: 600, lineHeight: 1.2 }}>{e.title}</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 4, marginTop: 4 }}>
              <Icon name={sourceIcon} size={11} color={sourceColor} fill={e.source === 'ai'} />
              <span style={{ fontSize: 10, color: sourceColor, fontWeight: 600 }}>{sourceLabel}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

window.CalendarView = CalendarView;
