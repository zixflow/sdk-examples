// public/sw.js — minimal web push worker (prefer the full SDK worker for automatic tracking)
self.addEventListener('install', () => {
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim())
})

self.addEventListener('push', (event) => {
  if (!event.data) return

  let data
  try {
    data = event.data.json()
  } catch {
    return
  }

  const title = data.title || 'Notification'
  const options = {
    body: data.body || '',
    icon: data.icon || '/icon.png',
    badge: data.badge || '/badge.png',
    image: data.image,
    data,
    tag: data.tag || 'zixflow-push',
    requireInteraction: data.requireInteraction || false,
    actions: data.actions || [],
  }

  event.waitUntil(self.registration.showNotification(title, options))
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()

  const clickedUrl = event.action
    ? event.notification.data.actions?.[event.action]?.url
    : event.notification.data.url || '/'

  event.waitUntil(
    clients.openWindow(clickedUrl).then((windowClient) => {
      if (windowClient) windowClient.focus()
    })
  )
})
