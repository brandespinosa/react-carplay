import { useEffect, useState } from "react";
import SunCalc from 'suncalc'

// True between today's sunset and sunrise at this location
export const isNight = (now: Date, latitude: number, longitude: number) => {
  const { sunrise, sunset } = SunCalc.getTimes(now, latitude, longitude)
  return now >= sunset || now < sunrise
}

// Dims the whole screen to `brightness`% (100 = no change) from sunset to sunrise; off until a location is set
export default function NightDim({ latitude, longitude, brightness }: { latitude: number | null, longitude: number | null, brightness: number }) {
  const [dim, setDim] = useState(false)

  useEffect(() => {
    if (latitude == null || longitude == null) return
    const update = () => setDim(isNight(new Date(), latitude, longitude))
    update()
    const timer = setInterval(update, 60000)
    return () => {
      clearInterval(timer)
      setDim(false)
    }
  }, [latitude, longitude])

  return dim && brightness < 100 ? (
    <div style={{ position: 'fixed', inset: 0, background: '#000', opacity: 1 - brightness / 100, pointerEvents: 'none', zIndex: 2000 }} />
  ) : null
}
