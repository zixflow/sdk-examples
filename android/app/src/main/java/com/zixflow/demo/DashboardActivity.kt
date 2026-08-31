package com.zixflow.demo

import android.os.Bundle
import android.widget.Button
import androidx.appcompat.app.AppCompatActivity

/** Demo screen opened via the `zixflowdemo://dashboard` push notification deeplink. */
class DashboardActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_dashboard)
        findViewById<Button>(R.id.btnBack).setOnClickListener { finish() }
    }
}
