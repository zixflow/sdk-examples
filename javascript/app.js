;(async function () {
  const writeKey = window.ZIXFLOW_WRITE_KEY
  const statusEl = document.querySelector('#status')
  const logEl = document.querySelector('#log')
  const main = document.querySelector('main')
  const isFileOrigin = window.location.protocol === 'file:'

  function log(message) {
    const stamp = new Date().toLocaleTimeString()
    logEl.textContent += `[${stamp}] ${message}\n`
    logEl.scrollTop = logEl.scrollHeight
  }

  if (!writeKey || writeKey === 'YOUR_WRITE_KEY') {
    statusEl.textContent =
      'Missing write key. Edit config.js and set ZIXFLOW_WRITE_KEY.'
    log('Waiting for ZIXFLOW_WRITE_KEY in config.js')
    return
  }

  const AnalyticsBrowser =
    window.AnalyticsNext && window.AnalyticsNext.AnalyticsBrowser
  if (!AnalyticsBrowser) {
    statusEl.textContent =
      'Failed to load @zixflow/analytics-browser from the CDN script.'
    log('window.AnalyticsNext.AnalyticsBrowser is missing')
    return
  }

  let analytics
  let debugOn = false

  // Docs API: subscribeToPush(analytics). UMD does not export these helpers,
  // so load them from the jsDelivr ESM build when needed (http/https only).
  async function pushHelpers() {
    const fromUmd = window.AnalyticsNext
    if (
      fromUmd &&
      typeof fromUmd.subscribeToPush === 'function' &&
      typeof fromUmd.unsubscribeFromPush === 'function'
    ) {
      return fromUmd
    }
    return import(
      'https://cdn.jsdelivr.net/npm/@zixflow/analytics-browser@1.1.5/+esm'
    )
  }

  const initOptions = {}
  if (!isFileOrigin) {
    initOptions.webPush = {
      enabled: true,
      swUrl: '/sw.js',
      autoSubscribe: false,
      onNotificationClick: function (url, action, data) {
        log('Notification click: ' + url + ' action=' + action)
        console.log('Notification data', data)
        window.location.href = url
      },
    }
  }

  try {
    const [instance] = await AnalyticsBrowser.load({ writeKey }, initOptions)
    analytics = instance
    window.analytics = analytics

    await analytics.page()

    statusEl.textContent =
      'Loaded with write key …' +
      writeKey.slice(-6) +
      (isFileOrigin ? ' (jsDelivr · file://)' : ' (jsDelivr + webPush)')
    log('SDK loaded from @zixflow/analytics-browser@1.1.5')
    if (isFileOrigin) {
      log('file:// origin: web push disabled (needs http://localhost or HTTPS)')
    }

    await analytics.ready(function () {
      log('analytics.ready fired')
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    statusEl.textContent = 'Failed to load SDK: ' + message
    log('Error: ' + message)
    console.error(err)
    return
  }

  main.addEventListener('click', async function (event) {
    const target = event.target
    if (!(target instanceof HTMLElement)) return
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
          if (
            'serviceWorker' in navigator &&
            navigator.serviceWorker.controller
          ) {
            navigator.serviceWorker.controller.postMessage({
              type: 'SET_USER_ID',
              userId: 'user@example.com',
            })
          }
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
          await analytics.ready(function () {
            log('ready callback')
          })
          break
        case 'user': {
          const user = analytics.user()
          log('user id=' + user.id() + ' anon=' + user.anonymousId())
          break
        }
        case 'anon':
          analytics.setAnonymousId('anon-' + Date.now())
          log('setAnonymousId')
          break
        case 'debug':
          debugOn = !debugOn
          analytics.debug(debugOn)
          log('debug=' + debugOn)
          break
        case 'push-sub': {
          if (isFileOrigin) {
            throw new Error(
              'Web push needs http://localhost or HTTPS — open via ./serve.sh'
            )
          }
          const { subscribeToPush } = await pushHelpers()
          await subscribeToPush(analytics)
          log('subscribeToPush ok')
          break
        }
        case 'push-unsub': {
          if (isFileOrigin) {
            throw new Error(
              'Web push needs http://localhost or HTTPS — open via ./serve.sh'
            )
          }
          const { unsubscribeFromPush } = await pushHelpers()
          await unsubscribeFromPush(analytics)
          log('unsubscribeFromPush ok')
          break
        }
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err)
      log('Error: ' + message)
      console.error(err)
    }
  })
})()
