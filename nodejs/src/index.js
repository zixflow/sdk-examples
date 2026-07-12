import { Analytics } from '@zixflow/analytics-node'

const writeKey = process.env.ZIXFLOW_WRITE_KEY

if (!writeKey || writeKey === 'YOUR_WRITE_KEY') {
  console.error(
    'Missing ZIXFLOW_WRITE_KEY. Copy .env.example to .env and set your write key.'
  )
  process.exit(1)
}

const userId = 'user@example.com'
const anonymousId = 'anon-123'

const analytics = new Analytics({
  writeKey,
  // maxEventsInBatch: 15,
  // flushInterval: 10000,
  // maxRetries: 3,
})

analytics.on('error', (err) => {
  console.error('[emitter:error]', err)
})

analytics.on('drained', () => {
  console.log('[emitter:drained] queue empty')
})

analytics.on('http_request', (event) => {
  console.log('[emitter:http_request]', event?.url || event)
})

console.log('Sending demo events for', userId)

analytics.identify({
  userId,
  traits: {
    first_name: 'John',
    last_name: 'Doe',
    email: userId,
    plan: 'premium',
  },
})

analytics.track({
  userId,
  event: 'purchase_completed',
  properties: {
    product_id: '123',
    product_name: 'Widget',
    price: 29.99,
    currency: 'USD',
    quantity: 1,
  },
})

analytics.page({
  userId,
  name: 'Home',
  properties: {
    title: 'Homepage',
    url: 'https://example.com',
  },
})

analytics.screen({
  userId,
  name: 'Dashboard',
  properties: {
    user_type: 'premium',
    version: '2.0',
  },
})

const shutdown = async (signal) => {
  console.log(`\n${signal}: flushing…`)
  try {
    await analytics.closeAndFlush({ timeout: 5000 })
    console.log('closeAndFlush complete — check the Zixflow dashboard')
    process.exit(0)
  } catch (err) {
    console.error('closeAndFlush failed', err)
    process.exit(1)
  }
}

process.on('SIGTERM', () => void shutdown('SIGTERM'))
process.on('SIGINT', () => void shutdown('SIGINT'))

// Auto-flush after enqueueing demo events
await shutdown('demo')
