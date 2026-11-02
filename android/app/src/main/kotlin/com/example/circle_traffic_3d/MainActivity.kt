package com.example.circle_traffic_3d

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        disableAutofillOnWindow()
    }

    override fun onPostResume() {
        super.onPostResume()
        disableAutofillOnWindow()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            disableAutofillOnWindow()
        }
    }

    private fun disableAutofillOnWindow() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window?.decorView?.let { disableAutofillRecursively(it) }
        }
    }

    private fun disableAutofillRecursively(view: View) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            view.importantForAutofill =
                View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
            if (view is ViewGroup) {
                for (i in 0 until view.childCount) {
                    disableAutofillRecursively(view.getChildAt(i))
                }
            }
        }
    }
}
