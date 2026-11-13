import React, { useEffect, useRef, useState } from 'react';

// A small avatar maker: boy or girl, skin, hair, suit and gear. Stored in this browser only.
export interface AvatarConfig {
  gender: 'boy' | 'girl';
  skin: number;
  hair: number;
  hairColor: number;
  suit: number;
  gear: number;
}

export const DEFAULT_AVATAR: AvatarConfig = { gender: 'boy', skin: 1, hair: 0, hairColor: 0, suit: 0, gear: 0 };
export const AVATAR_KEY = 'terralens.avatar.v1';

export function loadAvatar(): AvatarConfig {
  try {
    const r = window.localStorage.getItem(AVATAR_KEY);
    if (r) return { ...DEFAULT_AVATAR, ...(JSON.parse(r) as Partial<AvatarConfig>) };
  } catch { /* storage blocked */ }
  return DEFAULT_AVATAR;
}
export function saveAvatar(a: AvatarConfig): boolean {
  try {
    window.localStorage.setItem(AVATAR_KEY, JSON.stringify(a));
    return true;
  } catch {
    return false;
  }
}

const SKINS = ['#f8d9c0', '#f0cbb0', '#e0ac85', '#c68863', '#8d5a3c', '#5c3a26'];
const HAIR_COLORS = ['#243447', '#6b3f1f', '#c9922b', '#d94f4f', '#7c3aed', '#e5e7eb'];
const SUITS = ['#1e3a5f', '#9D4EDD', '#FF4365', '#FF9E25', '#0f766e', '#334155'];
const SUIT_NAMES = ['Navy', 'Purple', 'Red', 'Orange', 'Teal', 'Slate'];
const GEARS = ['None', 'Visor', 'Headset', 'Goggles'];
const HAIR_NAMES = {
  boy: ['Short', 'Spiky', 'Quiff', 'Curly', 'Buzz'],
  girl: ['Long', 'Ponytail', 'Bob', 'Buns', 'Wavy'],
} as const;

const CAP = 'M29 47 C23 10 77 10 71 47 C67 37 59 33 50 33 C41 33 33 37 29 47Z';

function hairBack(g: 'boy' | 'girl', i: number, c: string) {
  if (g === 'boy') {
    if (i === 3) return <g fill={c}><circle cx="34" cy="28" r="9" /><circle cx="44" cy="22" r="9" /><circle cx="56" cy="22" r="9" /><circle cx="66" cy="28" r="9" /><circle cx="29" cy="40" r="7" /><circle cx="71" cy="40" r="7" /></g>;
    return null;
  }
  switch (i) {
    case 0: return <path fill={c} d="M25 46 C22 16 78 16 75 46 L77 80 C70 86 62 80 60 76 L40 76 C38 80 30 86 23 80Z" />;
    case 1: return <g fill={c}><path d="M68 36 C88 32 92 62 78 76 C76 62 72 52 66 46Z" /></g>;
    case 2: return <path fill={c} d="M26 48 C22 16 78 16 74 48 L74 62 C66 66 62 58 60 54 L40 54 C38 58 34 66 26 62Z" />;
    case 3: return <g fill={c}><circle cx="29" cy="25" r="10" /><circle cx="71" cy="25" r="10" /></g>;
    default: return <path fill={c} d="M25 46 C20 16 80 16 75 46 C80 60 72 70 78 82 C70 86 66 78 62 80 L38 80 C34 78 30 86 22 82 C28 70 20 60 25 46Z" />;
  }
}
function hairFront(g: 'boy' | 'girl', i: number, c: string) {
  if (g === 'boy') {
    if (i === 1) return <g fill={c}><path d={CAP} /><path d="M29 38 L31 16 L39 28 L45 9 L52 27 L59 8 L64 28 L71 15 L72 38 C70 22 30 22 29 38Z" /></g>;
    if (i === 2) return <g fill={c}><path d={CAP} /><path d="M28 42 C20 6 68 -2 74 36 C66 28 52 26 44 30 C38 32 32 36 28 42Z" /></g>;
    if (i === 4) return <path fill={c} opacity="0.85" d="M30 46 C26 14 74 14 70 46 C66 37 34 37 30 46Z" />;
    return <path fill={c} d={CAP} />;
  }
  if (i === 2) return <path fill={c} d="M28 48 C20 8 80 8 72 48 C68 36 56 30 46 30 C40 36 34 42 28 48Z" />;
  if (i === 1) return <g fill={c}><path d={CAP} /><circle cx="69" cy="37" r="3" fill="#FFD166" /></g>;
  return <path fill={c} d={CAP} />;
}

function gearFront(i: number) {
  if (i === 1) return <g><rect x="31" y="38" width="38" height="13" rx="6" fill="rgba(0,240,255,0.35)" stroke="#00F0FF" strokeWidth="1.5" /><path d="M36 41 L44 41" stroke="rgba(255,255,255,0.7)" strokeWidth="1.5" strokeLinecap="round" /></g>;
  if (i === 2) return <g fill="none" stroke="#cbd5e1" strokeWidth="3" strokeLinecap="round"><path d="M29 46 C26 14 74 14 71 46" /><path d="M71 48 C70 60 62 62 58 60" strokeWidth="2" /><circle cx="29" cy="48" r="4.5" fill="#FF4365" stroke="none" /><circle cx="71" cy="48" r="4.5" fill="#FF4365" stroke="none" /><circle cx="58" cy="60" r="2.5" fill="#FDF5CC" stroke="none" /></g>;
  if (i === 3) return <g><path d="M30 33 C40 29 60 29 70 33" stroke="#475569" strokeWidth="3" fill="none" /><circle cx="42" cy="32" r="7" fill="rgba(251,191,36,0.55)" stroke="#fbbf24" strokeWidth="2.5" /><circle cx="58" cy="32" r="7" fill="rgba(251,191,36,0.55)" stroke="#fbbf24" strokeWidth="2.5" /></g>;
  return null;
}

export const PilotAvatar: React.FC<{ cfg: AvatarConfig; size?: number; ring?: boolean }> = ({ cfg, size = 80, ring = false }) => {
  const g = cfg.gender;
  const skin = SKINS[cfg.skin] ?? SKINS[1];
  const shade = `color-mix(in srgb, ${skin} 80%, #7a3b1e)`;
  const hc = HAIR_COLORS[cfg.hairColor] ?? HAIR_COLORS[0];
  const suit = SUITS[cfg.suit] ?? SUITS[0];
  const dark = `color-mix(in srgb, ${suit} 70%, #000)`;
  const HEAD = 'M32 44 C32 29 39 24 50 24 C61 24 68 29 68 44 C68 58 60 68 50 68 C40 68 32 58 32 44Z';
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" style={{ display: 'block', borderRadius: '50%', border: ring ? '3px solid #FDF5CC' : undefined, boxSizing: 'border-box' }} aria-hidden="true">
      <defs><radialGradient id="tlav-bg" cx="50%" cy="35%" r="75%"><stop offset="0%" stopColor="#1d3f7a" /><stop offset="100%" stopColor="#091830" /></radialGradient></defs>
      <circle cx="50" cy="50" r="50" fill="url(#tlav-bg)" />
      {hairBack(g, cfg.hair, hc)}

      {/* neck */}
      <path d="M44 60 L44 76 L56 76 L56 60Z" fill={shade} />

      {g === 'boy' ? (
        <g>
          {/* flight suit: shoulders, sleeves, zip, collar, chest pocket, patch */}
          <path d="M8 100 L10 86 C12 77 26 73 40 71 L60 71 C74 73 88 77 90 86 L92 100Z" fill={suit} stroke="#FDF5CC" strokeWidth="1.4" strokeLinejoin="round" />
          <path d="M8 96 L10 86 C11 82 14 80 17 79 L17 100Z" fill={dark} opacity="0.55" />
          <path d="M92 96 L90 86 C89 82 86 80 83 79 L83 100Z" fill={dark} opacity="0.55" />
          <path d="M50 78 L50 100" stroke="rgba(255,255,255,0.6)" strokeWidth="1.6" />
          <path d="M40 71 L50 84 L60 71 L56 70 L50 77 L44 70Z" fill="#e2e8f0" stroke="rgba(0,0,0,0.25)" strokeWidth="0.8" strokeLinejoin="round" />
          <rect x="60" y="86" width="12" height="9" rx="1.5" fill="none" stroke="rgba(255,255,255,0.5)" strokeWidth="1.2" />
          <path d="M31 90 l1.5 3.1 3.4 .5 -2.5 2.4 .6 3.4 -3 -1.6 -3 1.6 .6 -3.4 -2.5 -2.4 3.4 -.5z" fill="#FFD166" />
        </g>
      ) : (
        <g>
          {/* dress: cap sleeves, scoop neckline, sash and flared skirt */}
          <path d="M12 100 L16 86 C18 78 30 74 40 72 C44 82 56 82 60 72 C70 74 82 78 84 86 L88 100Z" fill={suit} stroke="#FDF5CC" strokeWidth="1.4" strokeLinejoin="round" />
          <path d="M40 72 C44 82 56 82 60 72" fill="none" stroke="#FDF5CC" strokeWidth="2" strokeLinecap="round" />
          <path d="M14 94 L16 86 C18 80 24 77 29 76 L26 94Z" fill={dark} opacity="0.4" />
          <path d="M86 94 L84 86 C82 80 76 77 71 76 L74 94Z" fill={dark} opacity="0.4" />
          <path d="M26 91 C40 94 60 94 74 91 L75 96 C60 99 40 99 25 96Z" fill="#FFD166" />
          <path d="M50 94 C44 90 40 93 41 97 C44 99 48 98 50 95 C52 98 56 99 59 97 C60 93 56 90 50 94Z" fill="#FFB020" stroke="rgba(0,0,0,0.2)" strokeWidth="0.6" />
          <circle cx="50" cy="94.5" r="1.8" fill="#FDF5CC" />
        </g>
      )}

      {/* ears, head and face */}
      <ellipse cx="32" cy="47" rx="2.6" ry="4" fill={skin} /><ellipse cx="68" cy="47" rx="2.6" ry="4" fill={skin} />
      <path d={HEAD} fill={skin} />
      <path d="M46 62 C48 64 52 64 54 62" stroke={shade} strokeWidth="2" fill="none" strokeLinecap="round" opacity="0.5" />
      {g === 'girl' && <><ellipse cx="38.5" cy="53" rx="3.6" ry="2.4" fill="#f472b6" opacity="0.3" /><ellipse cx="61.5" cy="53" rx="3.6" ry="2.4" fill="#f472b6" opacity="0.3" /></>}
      {/* brows */}
      <path d={g === 'boy' ? 'M38 39.5 Q42.5 37 47 39' : 'M38.5 40 Q42.5 38 47 39.8'} stroke={hc} strokeWidth={g === 'boy' ? 2 : 1.4} strokeLinecap="round" fill="none" />
      <path d={g === 'boy' ? 'M53 39 Q57.5 37 62 39.5' : 'M53 39.8 Q57.5 38 61.5 40'} stroke={hc} strokeWidth={g === 'boy' ? 2 : 1.4} strokeLinecap="round" fill="none" />
      {/* eyes: white, iris, pupil, sparkle */}
      <ellipse cx="42.5" cy="45.5" rx="3.6" ry="3" fill="#fff" /><ellipse cx="57.5" cy="45.5" rx="3.6" ry="3" fill="#fff" />
      <circle cx="42.8" cy="45.7" r="2.2" fill="#3b2a20" /><circle cx="57.2" cy="45.7" r="2.2" fill="#3b2a20" />
      <circle cx="42.8" cy="45.7" r="1.1" fill="#0b0b10" /><circle cx="57.2" cy="45.7" r="1.1" fill="#0b0b10" />
      <circle cx="43.6" cy="44.8" r="0.8" fill="#fff" /><circle cx="58" cy="44.8" r="0.8" fill="#fff" />
      <path d="M38.6 43.5 Q42.5 41.8 46.4 43.5" stroke="#2a1d16" strokeWidth="1" fill="none" strokeLinecap="round" />
      <path d="M53.6 43.5 Q57.5 41.8 61.4 43.5" stroke="#2a1d16" strokeWidth="1" fill="none" strokeLinecap="round" />
      {g === 'girl' && <g stroke="#2a1d16" strokeWidth="1.1" strokeLinecap="round"><path d="M38.8 44 L37.4 42.8" /><path d="M61.2 44 L62.6 42.8" /></g>}
      {/* nose and mouth */}
      <path d="M49 50 Q50.4 52.4 52 51.2" stroke={shade} strokeWidth="1.3" fill="none" strokeLinecap="round" />
      <path d="M45.5 57 Q50 60 54.5 57" stroke="#b5655a" strokeWidth="1.6" strokeLinecap="round" fill="none" />
      {hairFront(g, cfg.hair, hc)}
      {gearFront(cfg.gear)}
    </svg>
  );
};

const randomOf = (n: number) => Math.floor(Math.random() * n);

const sec: React.CSSProperties = { display: 'flex', flexDirection: 'column', gap: '6px' };
const lab: React.CSSProperties = { fontFamily: "'Lilita One', sans-serif", fontSize: '13px', letterSpacing: '1px', color: '#FDF5CC' };

const Swatches: React.FC<{ colors: string[]; value: number; onPick: (i: number) => void; names?: string[] }> = ({ colors, value, onPick, names }) => (
  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
    {colors.map((c, i) => (
      <button key={c} type="button" title={names?.[i]} aria-label={names?.[i] ?? `Colour ${i + 1}`} onClick={() => onPick(i)}
        style={{ width: '30px', height: '30px', borderRadius: '50%', cursor: 'pointer', background: c, padding: 0,
          border: i === value ? '3px solid #FFD166' : '3px solid rgba(255,255,255,0.3)', boxShadow: i === value ? '0 0 12px #FFD166' : 'none', transform: i === value ? 'scale(1.12)' : 'none' }} />
    ))}
  </div>
);

const Chips: React.FC<{ items: readonly string[]; value: number; onPick: (i: number) => void }> = ({ items, value, onPick }) => (
  <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
    {items.map((n, i) => (
      <button key={n} type="button" onClick={() => onPick(i)}
        style={{ padding: '5px 12px', borderRadius: '14px', cursor: 'pointer', fontFamily: "'Lilita One', sans-serif", fontSize: '13px', letterSpacing: '0.6px',
          background: i === value ? '#FF9E25' : 'rgba(15,23,42,0.8)', color: i === value ? '#0B0D26' : '#cbd5e1',
          border: `2px solid ${i === value ? '#FFE68C' : '#475569'}` }}>{n}</button>
    ))}
  </div>
);

export const AvatarEditor: React.FC<{
  initial: AvatarConfig; callsign: string;
  onSave: (cfg: AvatarConfig, callsign: string) => boolean; onClose: () => void;
}> = ({ initial, callsign, onSave, onClose }) => {
  const [cfg, setCfg] = useState<AvatarConfig>(initial);
  const [name, setName] = useState<string>(callsign);
  const [saveError, setSaveError] = useState("");
  const dialogRef = useRef<HTMLDivElement>(null);
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;
  const set = (p: Partial<AvatarConfig>) => setCfg(c => ({ ...c, ...p }));
  const setGender = (g: 'boy' | 'girl') => set({ gender: g, hair: 0 });

  useEffect(() => {
    const dialog = dialogRef.current;
    const previousFocus =
      document.activeElement instanceof HTMLElement
        ? document.activeElement
        : null;
    const focusable = () =>
      dialog?.querySelectorAll<HTMLElement>(
        'button:not(:disabled), input:not(:disabled), [tabindex]:not([tabindex="-1"])',
      );
    focusable()?.[0]?.focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        onCloseRef.current();
        return;
      }
      if (event.key !== 'Tab') return;
      const items = focusable();
      if (!items?.length) {
        event.preventDefault();
        dialog?.focus();
        return;
      }
      const first = items[0];
      const last = items[items.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      previousFocus?.focus();
    };
  }, []);

  return (
    <div role="dialog" aria-modal="true" aria-label="Customise your pilot"
      onClick={onClose}
      style={{ position: 'fixed', inset: 0, zIndex: 200, background: 'rgba(3,6,18,0.78)', backdropFilter: 'blur(6px)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '16px' }}>
      <div className="tl-acard" ref={dialogRef} tabIndex={-1} onClick={e => e.stopPropagation()}
        style={{ ['--ac' as string]: '#9D4EDD', width: 'min(720px, 100%)', maxHeight: '92vh', overflowY: 'auto', display: 'grid', gridTemplateColumns: 'minmax(180px, 220px) 1fr', gap: '22px', background: 'rgba(8,14,34,0.96)' } as React.CSSProperties}>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px' }}>
          <div style={{ padding: '8px', borderRadius: '50%', border: '3px dashed rgba(0,240,255,0.5)' }}>
            <PilotAvatar cfg={cfg} size={170} ring />
          </div>
          <div className="tl-gsub" style={{ fontSize: '15px' }}>YOUR PILOT</div>
          <button type="button" onClick={() => setCfg({ gender: Math.random() < 0.5 ? 'boy' : 'girl', skin: randomOf(6), hair: randomOf(5), hairColor: randomOf(6), suit: randomOf(6), gear: randomOf(4) })}
            style={{ padding: '6px 14px', borderRadius: '16px', border: '2px solid #00F0FF', background: 'rgba(0,240,255,0.1)', color: '#7df9ff', fontFamily: "'Lilita One', sans-serif", fontSize: '14px', cursor: 'pointer' }}>🎲 SURPRISE ME</button>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', minWidth: 0 }}>
          <div style={sec}><span style={lab}>CALLSIGN</span>
            <input value={name} maxLength={24} onChange={e => setName(e.target.value)} aria-label="Callsign"
              style={{ padding: '8px 12px', borderRadius: '12px', border: '2px solid #475569', background: 'rgba(15,23,42,0.85)', color: '#f8fafc', fontSize: '14px', outline: 'none' }} />
          </div>
          <div style={sec}><span style={lab}>PILOT TYPE</span>
            <div style={{ display: 'flex', gap: '8px' }}>
              {(['boy', 'girl'] as const).map(g => (
                <button key={g} type="button" onClick={() => setGender(g)}
                  style={{ flex: 1, padding: '8px', borderRadius: '16px', cursor: 'pointer', fontFamily: "'Lilita One', sans-serif", fontSize: '16px', letterSpacing: '1px',
                    background: cfg.gender === g ? (g === 'boy' ? '#38bdf8' : '#f472b6') : 'rgba(15,23,42,0.8)', color: cfg.gender === g ? '#0B0D26' : '#cbd5e1',
                    border: `3px solid ${cfg.gender === g ? '#FDF5CC' : '#475569'}` }}>{g === 'boy' ? '👦 BOY' : '👧 GIRL'}</button>
              ))}
            </div>
          </div>
          <div style={sec}><span style={lab}>SKIN</span><Swatches colors={SKINS} value={cfg.skin} onPick={i => set({ skin: i })} /></div>
          <div style={sec}><span style={lab}>HAIRSTYLE</span><Chips items={HAIR_NAMES[cfg.gender]} value={cfg.hair} onPick={i => set({ hair: i })} /></div>
          <div style={sec}><span style={lab}>HAIR COLOUR</span><Swatches colors={HAIR_COLORS} value={cfg.hairColor} onPick={i => set({ hairColor: i })} /></div>
          <div style={sec}><span style={lab}>FLIGHT SUIT</span><Swatches colors={SUITS} names={SUIT_NAMES} value={cfg.suit} onPick={i => set({ suit: i })} /></div>
          <div style={sec}><span style={lab}>GEAR</span><Chips items={GEARS} value={cfg.gear} onPick={i => set({ gear: i })} /></div>
          <div style={{ display: 'flex', gap: '10px', marginTop: '6px' }}>
            <button type="button" className="tl-btn3d" style={{ flex: 1, padding: '8px', cursor: 'pointer' }}
              onClick={() => {
                if (!onSave(cfg, name.trim() || callsign)) {
                  setSaveError("Your look is active for this session, but could not be saved in this browser.");
                }
              }}>SAVE LOOK</button>
            <button type="button" onClick={onClose}
              style={{ padding: '8px 18px', borderRadius: '28px', border: '3px solid #475569', background: 'transparent', color: '#cbd5e1', fontFamily: "'Lilita One', sans-serif", fontSize: '16px', cursor: 'pointer' }}>CANCEL</button>
          </div>
          {saveError && <p className="avatar-save-message" role="alert">{saveError}</p>}
        </div>
      </div>
    </div>
  );
};
