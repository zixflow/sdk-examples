// sw.js — web push worker with action_buttons + CDP tracking
// Write key arrives via SDK_CONFIG from the WebPush plugin (or SET_WRITE_KEY).

var WRITE_KEY = ''
var ZIXFLOW_API = 'https://cdp.zixflow.com/v1/track'
self.__ZIXFLOW_USER_ID__ = null

self.addEventListener('install', function () {
  self.skipWaiting()
})

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim())
})

self.addEventListener('message', function (event) {
  var msg = event.data || {}
  if (msg.type === 'SDK_CONFIG') {
    if (msg.apiKey) WRITE_KEY = msg.apiKey
    if (msg.apiBase) {
      ZIXFLOW_API = String(msg.apiBase).replace(/\/$/, '') + '/track'
    }
  }
  if (msg.type === 'SET_USER_ID') {
    self.__ZIXFLOW_USER_ID__ = msg.userId || null
  }
  if (msg.type === 'SET_WRITE_KEY' && msg.writeKey) {
    WRITE_KEY = msg.writeKey
  }
})

function parseActionButtonsRaw(raw) {
  if (!raw) return []
  try {
    return typeof raw === 'string' ? JSON.parse(raw) : raw
  } catch (e) {
    return []
  }
}

/** Web Notification actions: ACTION_0 / ACTION_1 (max 2). */
function parseActionButtons(raw) {
  return parseActionButtonsRaw(raw)
    .slice(0, 2)
    .map(function (btn, i) {
      return {
        action: 'ACTION_' + i,
        title: (btn && btn.name) || 'Action ' + (i + 1),
      }
    })
}

function trackEvent(eventName, properties) {
  if (!WRITE_KEY) return Promise.resolve()
  return fetch(ZIXFLOW_API, {
    method: 'POST',
    keepalive: true,
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Basic ' + btoa(WRITE_KEY + ':'),
    },
    body: JSON.stringify({
      event: eventName,
      userId: self.__ZIXFLOW_USER_ID__,
      properties: properties,
    }),
  }).catch(function (err) {
    console.error('[Zixflow] Failed to track event:', err)
  })
}

self.addEventListener('push', function (event) {
  if (!event.data) return

  var data
  try {
    data = event.data.json()
  } catch (e) {
    return
  }

  var deliveryId = data['Zixflow-Delivery-ID'] || ''
  var token = data['Zixflow-Delivery-Token'] || ''
  var buttons = parseActionButtons(data.action_buttons)

  var title = data.title || 'Notification'
  var options = {
    body: data.body || '',
    icon: data.image_url || data.icon || '/icon.png',
    badge: data.badge_url || data.badge || '/badge.png',
    image: data.image,
    data: data,
    tag: data.tag || 'zixflow-push',
    requireInteraction: !!data.requireInteraction,
    actions: buttons,
  }

  var tasks = [self.registration.showNotification(title, options)]
  if (deliveryId && token) {
    tasks.push(
      trackEvent('Push Notification Delivered', {
        'Zixflow-Delivery-ID': deliveryId,
        'Zixflow-Delivery-Token': token,
      })
    )
  }

  event.waitUntil(Promise.all(tasks))
})

self.addEventListener('notificationclick', function (event) {
  var data = event.notification.data || {}
  var deliveryId = data['Zixflow-Delivery-ID'] || ''
  var token = data['Zixflow-Delivery-Token'] || ''
  var action = event.action || ''

  event.notification.close()

  var trackPromises = []
  if (deliveryId && token) {
    trackPromises.push(
      trackEvent('Push Notification Opened', {
        'Zixflow-Delivery-ID': deliveryId,
        'Zixflow-Delivery-Token': token,
      })
    )
  }

  var deeplink = data.deeplink_url || data.url || '/'

  if (action) {
    var actionIndex = parseInt(String(action).replace(/\D/g, ''), 10)
    if (isNaN(actionIndex)) actionIndex = 0
    var rawButtons = parseActionButtonsRaw(data.action_buttons)
    var clicked = rawButtons[actionIndex] || {}
    var actionName = clicked.name || ''
    var actionDeeplink = clicked.deeplink || ''

    if (deliveryId && token) {
      trackPromises.push(
        trackEvent('Push Notification Action Clicked', {
          'Zixflow-Delivery-ID': deliveryId,
          'Zixflow-Delivery-Token': token,
          action_index: actionIndex,
          action_name: actionName,
          action_deeplink: actionDeeplink,
          source: 'web_push',
        })
      )
    }

    if (actionDeeplink) {
      deeplink = actionDeeplink
    }
  }

  event.waitUntil(
    Promise.all(trackPromises)
      .then(function () {
        return self.clients.matchAll({
          type: 'window',
          includeUncontrolled: true,
        })
      })
      .then(function (clientList) {
        for (var i = 0; i < clientList.length; i++) {
          var c = clientList[i]
          if (c.url.indexOf(self.location.origin) === 0 && 'focus' in c) {
            c.postMessage({
              type: 'NOTIFICATION_CLICK',
              action: action,
              data: data,
              url: deeplink,
            })
            return c.focus()
          }
        }
        return self.clients.openWindow(deeplink)
      })
  )
})
