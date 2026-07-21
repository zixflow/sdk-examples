package com.zixflow.demo

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.zixflow.sdk.Zixflow
import com.zixflow.sdk.events.Metric
import com.zixflow.sdk.events.TrackMetric

class MainActivity : AppCompatActivity() {
    private val tokenPollHandler = Handler(Looper.getMainLooper())
    private lateinit var tokenValue: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        tokenValue = findViewById(R.id.tokenValue)
        val status = findViewById<TextView>(R.id.status)
        status.text = "API key ends with …${Config.apiKey.takeLast(6)}. Replace Config.apiKey before testing."

        fun toast(msg: String) {
            Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
        }

        findViewById<Button>(R.id.btnIdentify).setOnClickListener {
            Zixflow.instance().identify(
                userId = "user@example.com",
                traits = mapOf(
                    "first_name" to "John",
                    "last_name" to "Doe",
                    "email" to "user@example.com",
                    "plan" to "premium"
                )
            )
            toast("identify sent")
        }

        findViewById<Button>(R.id.btnTrack).setOnClickListener {
            Zixflow.instance().track(
                name = "Product Purchased",
                properties = mapOf(
                    "product_id" to "123",
                    "product_name" to "Widget",
                    "price" to 29.99,
                    "currency" to "USD"
                )
            )
            toast("track sent")
        }

        findViewById<Button>(R.id.btnScreen).setOnClickListener {
            Zixflow.instance().screen(
                title = "Product Detail",
                properties = mapOf(
                    "product_id" to "123",
                    "category" to "Electronics"
                )
            )
            toast("screen sent")
        }

        findViewById<Button>(R.id.btnProfile).setOnClickListener {
            Zixflow.instance().setProfileAttributes(
                mapOf(
                    "age" to 30,
                    "gender" to "male",
                    "subscription_status" to "active"
                )
            )
            toast("profile attributes set")
        }

        findViewById<Button>(R.id.btnDeviceAttrs).setOnClickListener {
            Zixflow.instance().setDeviceAttributes(
                mapOf(
                    "app_version" to "2.1.0",
                    "custom_device_flag" to true
                )
            )
            toast("device attributes set")
        }

        findViewById<Button>(R.id.btnShowToken).setOnClickListener {
            toast(Zixflow.instance().registeredDeviceToken ?: "Device token not yet registered")
        }

        findViewById<Button>(R.id.btnCopyToken).setOnClickListener {
            val token = Zixflow.instance().registeredDeviceToken
            if (token.isNullOrEmpty()) {
                toast("No device token registered yet")
            } else {
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("Device Token", token))
                toast("Device token copied to clipboard")
            }
        }

        findViewById<Button>(R.id.btnRegisterToken).setOnClickListener {
            Zixflow.instance().registerDeviceToken("demo-fcm-device-token")
            toast("registerDeviceToken called")
        }

        findViewById<Button>(R.id.btnDeleteToken).setOnClickListener {
            Zixflow.instance().deleteDeviceToken()
            toast("deleteDeviceToken called")
        }

        findViewById<Button>(R.id.btnClear).setOnClickListener {
            Zixflow.instance().clearIdentify()
            toast("clearIdentify()")
        }

        findViewById<Button>(R.id.btnOpenSale).setOnClickListener {
            startActivity(Intent(this, SaleActivity::class.java))
        }

        findViewById<Button>(R.id.btnOpenDashboard).setOnClickListener {
            startActivity(Intent(this, DashboardActivity::class.java))
        }

        startTokenPolling()

        handlePushOpenIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handlePushOpenIntent(intent)
    }

    /**
     * Tracks the Opened metric and follows the deeplink when this Activity was
     * launched by tapping the body of a manually-displayed push notification
     * (see [CustomFirebaseMessagingService]).
     */
    private fun handlePushOpenIntent(intent: Intent) {
        val deliveryId = intent.getStringExtra(PushActionButtons.EXTRA_DELIVERY_ID)
        val deliveryToken = intent.getStringExtra(PushActionButtons.EXTRA_DELIVERY_TOKEN)
        val deeplink = intent.getStringExtra(CustomFirebaseMessagingService.EXTRA_DEEPLINK)

        if (!deliveryId.isNullOrEmpty() && !deliveryToken.isNullOrEmpty()) {
            try {
                Zixflow.instance().trackMetric(
                    TrackMetric.Push(
                        metric = Metric.Opened,
                        deliveryId = deliveryId,
                        deviceToken = deliveryToken
                    )
                )
            } catch (_: Exception) {
            }
        }

        if (!deeplink.isNullOrEmpty()) {
            DeeplinkRouter.open(this, deeplink)
        }
    }

    /** Polls [Zixflow.instance().registeredDeviceToken] since FCM fetch is async on launch. */
    private fun startTokenPolling() {
        val poll = object : Runnable {
            override fun run() {
                val token = Zixflow.instance().registeredDeviceToken
                if (!token.isNullOrEmpty()) {
                    tokenValue.text = token
                } else {
                    tokenPollHandler.postDelayed(this, 1000)
                }
            }
        }
        tokenPollHandler.post(poll)
    }
}
