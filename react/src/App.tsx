import { useCallback, useEffect, useRef, useState } from 'react'
import { AnalyticsBrowser, type Analytics } from '@zixflow/analytics-browser'

const writeKey = import.meta.env.VITE_ZIXFLOW_WRITE_KEY

export default function App() {
  const [status, setStatus] = useState('Initializing…')
  const [ready, setReady] = useState(false)
  const [lines, setLines] = useState<string[]>([])
  const analyticsRef = useRef<Analytics | null>(null)
  const logElRef = useRef<HTMLDivElement>(null)

  const log = useCallback((message: string) => {
    const stamp = new Date().toLocaleTimeString()
    setLines((prev) => [...prev, `[${stamp}] ${message}`])
  }, [])

  useEffect(() => {
    logElRef.current?.scrollTo({ top: logElRef.current.scrollHeight })
  }, [lines])

  useEffect(() => {
    if (!writeKey || writeKey === 'YOUR_WRITE_KEY') {
      setStatus(
        'Missing write key. Copy .env.example to .env and set VITE_ZIXFLOW_WRITE_KEY.'
      )
      log('Waiting for VITE_ZIXFLOW_WRITE_KEY')
      return
    }

    let cancelled = false

    void (async () => {
      try {
        // Initialize with your write key
        const [analytics] = await AnalyticsBrowser.load({
          writeKey,
        })

        if (cancelled) return

        analyticsRef.current = analytics
        setStatus(`Loaded · write key …${writeKey.slice(-6)}`)
        log('SDK loaded')
        setReady(true)
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err)
        setStatus(`Failed to load SDK: ${message}`)
        log(`Error: ${message}`)
        console.error(err)
      }
    })()

    return () => {
      cancelled = true
    }
  }, [log])

  const identify = useCallback(async () => {
    const analytics = analyticsRef.current
    if (!analytics) {
      log('SDK not ready')
      return
    }
    try {
      // Identify a user
      await analytics.identify('user@example.com', {
        first_name: 'John',
        last_name: 'Doe',
        email: 'user@example.com',
      })
      log('identify sent')
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      log(`Error: ${message}`)
      console.error(err)
    }
  }, [log])

  const track = useCallback(async () => {
    const analytics = analyticsRef.current
    if (!analytics) {
      log('SDK not ready')
      return
    }
    try {
      // Track an event
      await analytics.track('button_clicked', {
        button_name: 'signup',
        page: 'homepage',
      })
      log('track: button_clicked')
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      log(`Error: ${message}`)
      console.error(err)
    }
  }, [log])

  const page = useCallback(async () => {
    const analytics = analyticsRef.current
    if (!analytics) {
      log('SDK not ready')
      return
    }
    try {
      // Track a page view
      await analytics.page('Home', {
        title: 'Homepage',
        url: window.location.href,
      })
      log('page: Home')
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      log(`Error: ${message}`)
      console.error(err)
    }
  }, [log])

  return (
    <main>
      <header>
        <h1>Zixflow React SDK</h1>
        <p>Simple CDP demo: load, identify, track, and page.</p>
      </header>

      <div className="status">{status}</div>

      <section className="panel">
        <h2>Quick Start</h2>
        <div className="grid">
          <button disabled={!ready} onClick={() => void identify()}>
            Identify
          </button>
          <button disabled={!ready} onClick={() => void track()}>
            Track
          </button>
          <button disabled={!ready} onClick={() => void page()}>
            Page
          </button>
        </div>
      </section>

      <section className="panel">
        <h2>Log</h2>
        <div className="log" ref={logElRef}>
          {lines.join('\n')}
        </div>
      </section>
    </main>
  )
}
