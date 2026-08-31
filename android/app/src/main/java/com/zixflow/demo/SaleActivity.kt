package com.zixflow.demo

import android.os.Bundle
import android.widget.Button
import androidx.appcompat.app.AppCompatActivity

/** Demo screen opened via the `zixflowdemo://sale` push notification deeplink. */
class SaleActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_sale)
        findViewById<Button>(R.id.btnBack).setOnClickListener { finish() }
    }
}
