import { useEffect, useMemo, useRef, useState } from 'react'
import { CartesianGrid, Line, LineChart, ReferenceLine, ResponsiveContainer, XAxis, YAxis } from 'recharts'
import { formatClock } from '../lib/chicago-time'
import { emaSlope, forwardRay, rebasePrior, slopeFromPoints, yDomain } from '../lib/forecast'
import type { DeskSide, Point } from '../lib/types'

type Zoom = 60 | 30 | 15

function mergePath(a: Point[] | undefined, b: Point[] | undefined) {
  const map = new Map<number, number>()
  for (const p of a ?? []) {
    if (p && Number.isFinite(p.t) && Number.isFinite(p.px)) map.set(Math.round(p.t / 1000) * 1000, p.px)
  }
  for (const p of b ?? []) {
    if (p && Number.isFinite(p.t) && Number.isFinite(p.px)) map.set(Math.round(p.t / 1000) * 1000, p.px)
  }
  return [...map.entries()]
    .map(([t, px]) => ({ t, px }))
    .sort((x, y) => x.t - y.t)
}

export function WindowChart(props: {
  live: number
  closeAt: number
  openAt: number
  points?: Point[]
  prior?: Point[]
  trail?: Point[]
  lean: DeskSide
}) {
  const [zoom, setZoom] = useState<Zoom>(60)
  const [pan, setPan] = useState(0)
  const [ready, setReady] = useState(false)
  const slopeRef = useRef<number | null>(null)

  useEffect(() => {
    setReady(true)
  }, [])

  const now = props.points?.length ? props.points[props.points.length - 1]?.t || Date.now() : Date.now()
  const actual = mergePath(props.points, props.trail)
  const rawSlope = slopeFromPoints(actual, now)
  const slope = emaSlope(slopeRef.current, rawSlope)
  slopeRef.current = slope

  const prior = rebasePrior(props.prior, props.live)
  const forecast = forwardRay({
    now,
    closeAt: props.closeAt,
    live: props.live,
    slopePerMin: slope,
    lean: props.lean,
  })

  const end = now + pan
  const start = end - zoom * 60_000
  const rows = useMemo(() => {
    const keys = new Set<number>()
    const add = (list: Point[]) => {
      for (const p of list) {
        if (p.t >= start - 2000 && p.t <= end + 16 * 60_000) keys.add(p.t)
      }
    }
    add(actual)
    add(prior)
    add(forecast)
    const times = [...keys].sort((a, b) => a - b)
    const find = (list: Point[], t: number) => {
      let best: Point | null = null
      let d = Infinity
      for (const p of list) {
        const nd = Math.abs(p.t - t)
        if (nd < d) {
          d = nd
          best = p
        }
      }
      return best && d < 90_000 ? best.px : null
    }
    return times.map((t) => ({
      t,
      actual: t <= now + 1500 ? find(actual, t) : null,
      prior: find(prior, t),
      next: t >= now - 1500 ? find(forecast, t) : null,
    }))
  }, [actual, prior, forecast, start, end, now])

  const ys = [
    ...actual.map((p) => p.px),
    ...prior.map((p) => p.px),
    ...forecast.map((p) => p.px),
    props.live,
  ]
  const [lo, hi] = yDomain(props.live, ys)

  const forecastPts = forecast.map((p) => p.px.toFixed(2)).join(',')

  return (
    <section className="mt-3 px-4" data-testid="window-chart">
      <div className="mb-2 flex items-center justify-between gap-2">
        <p className="text-[11px] uppercase tracking-[0.14em] text-mute">Trend</p>
        <div className="flex items-center gap-1">
          <button
            type="button"
            className="h-9 min-w-9 rounded-lg bg-chip px-2 text-sm text-ink"
            onClick={() => setPan((p) => p - zoom * 30_000)}
            aria-label="Pan earlier"
          >
            {'<'}
          </button>
          {([60, 30, 15] as Zoom[]).map((z) => (
            <button
              key={z}
              type="button"
              onClick={() => {
                setZoom(z)
                setPan(0)
              }}
              className={`h-9 min-w-[3.1rem] rounded-lg px-2 text-sm ${
                zoom === z ? 'bg-up text-black' : 'bg-chip text-ink'
              }`}
            >
              {z}m
            </button>
          ))}
          <button
            type="button"
            className="h-9 min-w-9 rounded-lg bg-chip px-2 text-sm text-ink"
            onClick={() => setPan((p) => p + zoom * 30_000)}
            aria-label="Pan later"
          >
            {'>'}
          </button>
        </div>
      </div>
      <div data-testid="forecast-pts" data-pts={forecastPts} className="hidden" />
      <div className="h-[220px] w-full">
        {ready ? (
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={rows} margin={{ top: 8, right: 8, left: 0, bottom: 4 }}>
              <CartesianGrid stroke="#1c1c1c" vertical={false} />
              <XAxis
                dataKey="t"
                type="number"
                domain={[start, end]}
                tickFormatter={(t) => formatClock(Number(t))}
                stroke="#8a938c"
                tick={{ fill: '#8a938c', fontSize: 10 }}
                minTickGap={28}
              />
              <YAxis
                domain={[lo, hi]}
                width={44}
                stroke="#8a938c"
                tick={{ fill: '#8a938c', fontSize: 10 }}
                tickFormatter={(v) => String(Math.round(Number(v)))}
              />
              <ReferenceLine y={props.live} stroke="#2a2a2a" />
              <Line
                dataKey="prior"
                stroke="#6b6b6b"
                strokeWidth={1.5}
                dot={false}
                isAnimationActive={false}
                connectNulls
              />
              <Line
                dataKey="actual"
                stroke="#00e57a"
                strokeWidth={2}
                dot={false}
                isAnimationActive={false}
                connectNulls
                name="actual"
              />
              <Line
                dataKey="next"
                stroke="#00e57a"
                strokeWidth={1.6}
                strokeDasharray="5 4"
                dot={false}
                isAnimationActive={false}
                connectNulls
                name="next"
              />
            </LineChart>
          </ResponsiveContainer>
        ) : (
          <div className="h-full w-full" />
        )}
      </div>
      <p className="mt-1 text-[11px] text-mute">
        Green this week · gray last week rebased · dashed next 15m
      </p>
    </section>
  )
}
