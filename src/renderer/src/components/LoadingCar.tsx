// A little dancing car shown on the black screen while waiting for the phone.
// CSS animations only (transform/opacity), so it stays light on the Pi.
const css = `
@keyframes lc-dance { 0%,100% { transform: translateY(0) rotate(-6deg) } 25% { transform: translateY(-14px) rotate(0deg) }
  50% { transform: translateY(0) rotate(6deg) } 75% { transform: translateY(-14px) rotate(0deg) } }
@keyframes lc-shadow { 0%,50%,100% { transform: scaleX(1); opacity: .5 } 25%,75% { transform: scaleX(.7); opacity: .25 } }
@keyframes lc-wheel { to { transform: rotate(360deg) } }
@keyframes lc-note { 0% { transform: translate(0,0); opacity: 0 } 20% { opacity: 1 } 100% { transform: translate(18px,-46px); opacity: 0 } }
.lc-wheel { transform-box: fill-box; transform-origin: center; animation: lc-wheel .6s linear infinite }
`

export default function LoadingCar() {
  return (
    <div style={{ position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%, -50%)', pointerEvents: 'none' }}>
      <style>{css}</style>
      <div style={{ position: 'relative', width: 120, height: 140 }}>
        <span style={{ position: 'absolute', right: -6, top: 10, color: '#7fb8ff', fontSize: 22, animation: 'lc-note 1.6s ease-out infinite' }}>♪</span>
        <span style={{ position: 'absolute', left: -4, top: 24, color: '#7fe0a0', fontSize: 18, animation: 'lc-note 1.6s ease-out .8s infinite' }}>♫</span>
        <svg width="120" height="120" viewBox="0 0 120 120" style={{ animation: 'lc-dance 1.2s ease-in-out infinite' }}>
          <defs>
            <linearGradient id="lc-tile" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="#3ddc84" />
              <stop offset="1" stopColor="#1a9f55" />
            </linearGradient>
          </defs>
          <rect x="6" y="6" width="108" height="108" rx="26" fill="url(#lc-tile)" />
          {/* car body */}
          <path d="M24 70 L32 52 Q35 46 42 46 L76 46 Q83 46 86 52 L94 70 Q97 71 97 75 L97 82 Q97 85 94 85 L26 85 Q23 85 23 82 L23 75 Q23 71 24 70 Z" fill="#fff" />
          <path d="M37 66 L42 54 Q43 52 46 52 L72 52 Q75 52 76 54 L81 66 Z" fill="#1a9f55" />
          {/* play triangle on the door */}
          <path d="M55 70 L55 80 L64 75 Z" fill="#1a9f55" />
          <g className="lc-wheel"><circle cx="40" cy="86" r="9" fill="#222" /><rect x="39" y="79" width="2" height="14" fill="#888" /></g>
          <g className="lc-wheel"><circle cx="80" cy="86" r="9" fill="#222" /><rect x="79" y="79" width="2" height="14" fill="#888" /></g>
        </svg>
        <div style={{ margin: '6px auto 0', width: 80, height: 8, borderRadius: '50%', background: '#3ddc84', filter: 'blur(4px)', animation: 'lc-shadow 1.2s ease-in-out infinite' }} />
      </div>
    </div>
  )
}
