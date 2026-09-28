package io.qzz.wenyun

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Bundle

class VpnPermissionActivity : Activity() {
    companion object {
        private const val REQUEST_VPN = 1
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val permission = VpnService.prepare(this)
        if (permission == null) {
            ClashService.start(this)
            finish()
        } else {
            @Suppress("DEPRECATION")
            startActivityForResult(permission, REQUEST_VPN)
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_VPN && resultCode == RESULT_OK) {
            ClashService.start(this)
        }
        finish()
    }
}
