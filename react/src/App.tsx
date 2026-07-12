import { useCallback, useEffect, useRef, useState } from 'react'
import {
  AnalyticsBrowser,
  type Analytics,
  subscribeToPush,
  unsubscribeFromPush,
} from '@zixflow/analytics-browser'

const writeKey = import.meta.env.VITE_ZIXFLOW_WRITE_KEY

type Action =
  | 'identify'
  | 'track'
  | 'page'
  | 'screen'
  | 'group'
  | 'alias'
  | 'reset'
  | 'ready'
  | 'user'
  | 'anon'
  | 'debug'
  | 'push-sub'
  | 'push-unsub'

export default function App() {
  const [status, setStatus] = useState('Initializing…')
  const [lines, setLines] = useState<string[]>([])
  const [ready, setReady] = useState(false)
  const analyticsRef = useRef<Analytics | null>(null)
  const debugOnRef = useRef(false)
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
          // {
          //   initialPageview: true,
          //   webPush: {
          //     enabled: true,
          //     swUrl: '/sw.js',
          //     autoSubscribe: false,
          //     onNotificationClick: (
          //       url: string,
          //       action: string,
          //       data: unknown
          //     ) => {
          //       log(`Notification click: ${url} action=${action}`)
          //       console.log('Notification data', data)
          //       window.location.href = url
          //     },
          //   },
          // }
        )

        if (cancelled) return

        analyticsRef.current = analytics
        setStatus(
          `Loaded with write key …${writeKey.slice(-6)} (initialPageview: true)`
        )
        log('SDK loaded')

        await analytics.ready(() => {
          log('analytics.ready fired')
        })

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

  const run = useCallback(
    async (action: Action) => {
      const analytics = analyticsRef.current
      if (!analytics) {
        log('SDK not ready')
        return
      }

      try {
        switch (action) {
          case 'identify':
            await analytics.identify('user@example.com', {
              first_name: 'John',
              last_name: 'Doe',
              email: 'user@example.com',
              plan: 'premium',
              created_at: new Date().toISOString(),
            })
            log('identify sent')
            break
          case 'track':
            await analytics.track('button_clicked', {
              button_name: 'signup',
              page: 'homepage',
            })
            log('track: button_clicked')
            break
          case 'page':
            await analytics.page('Home', {
              title: 'Homepage',
              url: window.location.href,
            })
            log('page: Home')
            break
          case 'screen':
            await analytics.screen('Dashboard', { user_type: 'premium' })
            log('screen: Dashboard')
            break
          case 'group':
            await analytics.group('company-123', {
              name: 'Acme Inc',
              plan: 'enterprise',
              employees: 100,
            })
            log('group: company-123')
            break
          case 'alias':
            await analytics.alias('user@example.com')
            log('alias: user@example.com')
            break
          case 'reset':
            analytics.reset()
            log('reset()')
            break
          case 'ready':
            await analytics.ready(() => log('ready callback'))
            break
          case 'user': {
            const user = analytics.user()
            log(`user id=${user.id()} anon=${user.anonymousId()}`)
            break
          }
          case 'anon':
            analytics.setAnonymousId(`anon-${Date.now()}`)
            log('setAnonymousId')
            break
          case 'debug':
            debugOnRef.current = !debugOnRef.current
            analytics.debug(debugOnRef.current)
            log(`debug=${debugOnRef.current}`)
            break
          case 'push-sub':
            await subscribeToPush(analytics)
            log('subscribeToPush ok')
            break
          case 'push-unsub':
            await unsubscribeFromPush(analytics)
            log('unsubscribeFromPush ok')
            break
        }
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err)
        log(`Error: ${message}`)
        console.error(err)
      }
    },
    [log]
  )

  return (
    <main>
      <header>
        <h1>Zixflow React SDK</h1>
        <p>
          Feature demo for identify, track, page, screen, group, alias, reset,
          and web push.
        </p>
      </header>

      <div className="status">{status}</div>

      <section className="panel">
        <h2>Core</h2>
        <div className="grid">
          <button disabled={!ready} onClick={() => void run('identify')}>
            Identify
          </button>
          <button disabled={!ready} onClick={() => void run('track')}>
            Track
          </button>
          <button disabled={!ready} onClick={() => void run('page')}>
            Page
          </button>
          <button disabled={!ready} onClick={() => void run('screen')}>
            Screen
          </button>
          <button disabled={!ready} onClick={() => void run('group')}>
            Group
          </button>
          <button disabled={!ready} onClick={() => void run('alias')}>
            Alias
          </button>
          <button
            className="secondary"
            disabled={!ready}
            onClick={() => void run('reset')}
          >
            Reset
          </button>
        </div>
      </section>

      <section className="panel">
        <h2>Browser helpers</h2>
        <div className="grid">
          <button disabled={!ready} onClick={() => void run('ready')}>
            Ready
          </button>
          <button disabled={!ready} onClick={() => void run('user')}>
            User()
          </button>
          <button disabled={!ready} onClick={() => void run('anon')}>
            Set anonymous ID
          </button>
          <button disabled={!ready} onClick={() => void run('debug')}>
            Toggle debug
          </button>
        </div>
      </section>

      <section className="panel">
        <h2>Web push</h2>
        <div className="grid">
          <button disabled={!ready} onClick={() => void run('push-sub')}>
            Subscribe to push
          </button>
          <button
            className="secondary"
            disabled={!ready}
            onClick={() => void run('push-unsub')}
          >
            Unsubscribe
          </button>
        </div>
        <p className="hint">
          Requires HTTPS (or localhost) and notification permission from a user
          gesture.
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
