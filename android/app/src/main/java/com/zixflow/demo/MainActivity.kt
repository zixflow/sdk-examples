package com.zixflow.demo

import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.zixflow.sdk.Zixflow

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

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
    }
}
