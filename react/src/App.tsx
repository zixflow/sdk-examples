import { useCallback, useEffect, useRef, useState } from 'react'
import {
  AnalyticsBrowser,
  subscribeToPush,
  unsubscribeFromPush,
  type Analytics,
} from '@zixflow/analytics-browser'

const writeKey = import.meta.env.VITE_ZIXFLOW_WRITE_KEY

function postUserIdToServiceWorker(userId: string) {
  if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
    navigator.serviceWorker.controller.postMessage({
      type: 'SET_USER_ID',
      userId,
    })
  }
}

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
        const [analytics] = await AnalyticsBrowser.load(
          { writeKey },
          {
            webPush: {
              enabled: true,
              swUrl: '/sw.js',
              autoSubscribe: false,
              onNotificationClick: (url, action, data) => {
                log(`Notification click: ${url} action=${action}`)
                console.log('Notification data', data)
                if (url) window.location.href = url
              },
            },
          }
        )

        if (cancelled) return

        analyticsRef.current = analytics
        setStatus(`Loaded · write key …${writeKey.slice(-6)} · webPush`)
        log('SDK loaded with webPush (swUrl=/sw.js, autoSubscribe=false)')
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
      await analytics.identify('user@example.com', {
        first_name: 'John',
        last_name: 'Doe',
        email: 'user@example.com',
      })
      postUserIdToServiceWorker('user@example.com')
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

  const pushSubscribe = useCallback(async () => {
    const analytics = analyticsRef.current
    if (!analytics) {
      log('SDK not ready')
      return
    }
    try {
      await subscribeToPush(analytics)
      log('subscribeToPush ok')
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      log(`Error: ${message}`)
      console.error(err)
    }
  }, [log])

  const pushUnsubscribe = useCallback(async () => {
    const analytics = analyticsRef.current
    if (!analytics) {
      log('SDK not ready')
      return
    }
    try {
      await unsubscribeFromPush(analytics)
      log('unsubscribeFromPush ok')
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
        <p>
          Vite demo: identify, track, page, and web push with action buttons.
        </p>
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
        <h2>Web push</h2>
        <div className="grid">
          <button disabled={!ready} onClick={() => void pushSubscribe()}>
            Subscribe to push
          </button>
          <button
            className="secondary"
            disabled={!ready}
            onClick={() => void pushUnsubscribe()}
          >
            Unsubscribe
          </button>
        </div>
        <p className="hint">
          Uses <code>public/sw.js</code> (<code>swUrl: /sw.js</code>,{' '}
          <code>autoSubscribe: false</code>). Grant notification permission from
          Subscribe, then send a push with <code>action_buttons</code>.
        </p>
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
