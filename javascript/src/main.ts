import './style.css'
import {
  AnalyticsBrowser,
  subscribeToPush,
  unsubscribeFromPush,
} from '@zixflow/analytics-browser'

const writeKey = import.meta.env.VITE_ZIXFLOW_WRITE_KEY as string | undefined
const siteId = import.meta.env.VITE_ZIXFLOW_SITE_ID as string | undefined

const app = document.querySelector<HTMLDivElement>('#app')!

app.innerHTML = `
  <main>
    <header>
      <h1>Zixflow Browser SDK</h1>
      <p>Feature demo for identify, track, page, screen, group, alias, reset, web push, and inbox.</p>
    </header>

    <div class="status" id="status">Initializing…</div>

    <section class="panel">
      <h2>Core</h2>
      <div class="grid">
        <button data-action="identify">Identify</button>
        <button data-action="track">Track</button>
        <button data-action="page">Page</button>
        <button data-action="screen">Screen</button>
        <button data-action="group">Group</button>
        <button data-action="alias">Alias</button>
        <button data-action="reset" class="secondary">Reset</button>
      </div>
    </section>

    <section class="panel">
      <h2>Browser helpers</h2>
      <div class="grid">
        <button data-action="ready">Ready</button>
        <button data-action="user">User()</button>
        <button data-action="anon">Set anonymous ID</button>
        <button data-action="debug">Toggle debug</button>
      </div>
    </section>

    <section class="panel">
      <h2>Web push</h2>
      <div class="grid">
        <button data-action="push-sub">Subscribe to push</button>
        <button data-action="push-unsub" class="secondary">Unsubscribe</button>
      </div>
      <p class="hint">Requires HTTPS (or localhost) and notification permission from a user gesture.</p>
    </section>

    <section class="panel">
      <h2>In-app inbox</h2>
      <div class="grid">
        <button data-action="inbox">Refresh inbox</button>
      </div>
      <p class="hint">Set <code>VITE_ZIXFLOW_SITE_ID</code> to enable the in-app plugin.</p>
    </section>

    <section class="panel">
      <h2>Log</h2>
      <div id="log"></div>
    </section>
  </main>
`

const statusEl = document.querySelector('#status')!
const logEl = document.querySelector('#log')!

function log(message: string) {
  const stamp = new Date().toLocaleTimeString()
  logEl.textContent += `[${stamp}] ${message}\n`
  logEl.scrollTop = logEl.scrollHeight
}

if (!writeKey || writeKey === 'YOUR_WRITE_KEY') {
  statusEl.textContent =
    'Missing write key. Copy .env.example to .env and set VITE_ZIXFLOW_WRITE_KEY.'
  log('Waiting for VITE_ZIXFLOW_WRITE_KEY')
} else {
  const initOptions: Record<string, unknown> = {
    initialPageview: true,
    webPush: {
      enabled: true,
      swUrl: '/sw.js',
      autoSubscribe: false,
      onNotificationClick: (url: string, action: string, data: unknown) => {
        log(`Notification click: ${url} action=${action}`)
        console.log('Notification data', data)
        window.location.href = url
      },
    },
  }

  if (siteId && siteId !== 'YOUR_SITE_ID') {
    initOptions.integrations = {
      'Zixflow In-App Plugin': {
        siteId,
        events: (event: { type: string; detail?: unknown }) => {
          log(`In-app event: ${event.type}`)
          console.log('In-app detail', event.detail)
        },
      },
    }
  }

  void (async () => {
    const [analytics] = await AnalyticsBrowser.load({ writeKey }, initOptions)

    statusEl.textContent = `Loaded with write key …${writeKey.slice(-6)} (initialPageview: true)`
    log('SDK loaded')

    await analytics.ready(() => {
      log('analytics.ready fired')
    })

    let debugOn = false

    app.addEventListener('click', async (event) => {
      const target = event.target as HTMLElement
      const action = target.getAttribute('data-action')
      if (!action) return

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
            debugOn = !debugOn
            analytics.debug(debugOn)
            log(`debug=${debugOn}`)
            break
          case 'push-sub':
            await subscribeToPush(analytics)
            log('subscribeToPush ok')
            break
          case 'push-unsub':
            await unsubscribeFromPush(analytics)
            log('unsubscribeFromPush ok')
            break
          case 'inbox': {
            const inbox = analytics.inbox?.()
            if (!inbox) {
              log('inbox() unavailable — set VITE_ZIXFLOW_SITE_ID')
              break
            }
            const total = await inbox.total()
            const unopened = await inbox.totalUnopened()
            const messages = await inbox.messages()
            log(
              `inbox total=${total} unopened=${unopened} messages=${messages.length}`
            )
            break
          }
        }
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err)
        log(`Error: ${message}`)
        console.error(err)
      }
    })
  })()
}
