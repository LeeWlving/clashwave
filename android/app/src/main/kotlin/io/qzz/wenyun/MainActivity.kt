package io.qzz.wenyun

import android.content.Intent
import android.net.VpnService
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "io.qzz.wenyun/mihomo"
        private const val VPN_REQUEST_CODE = 1001
    }

    private var pendingVpnResult: MethodChannel.Result? = null
    private var methodChannel: MethodChannel? = null
    private var initialUrlConsumed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MihomoCore.ensureLoaded(this)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler {
                call,
                result,
            ->
            try {
                when (call.method) {
                    "startVpn" -> requestVpn(result)
                    "stopVpn" -> {
                        stopVpn()
                        result.success(true)
                    }
                    "startService" -> {
                        MihomoCore.start(this) { success, error ->
                            runOnUiThread {
                                if (success) {
                                    result.success(true)
                                } else {
                                    result.error("MIHOMO_START_FAILED", error ?: "Unknown Mihomo error", null)
                                }
                            }
                        }
                    }
                    "setConfig" -> {
                        val path = call.argument<String>("config").orEmpty()
                        result.success(path.isNotBlank() && File(path).isFile)
                    }
                    "setHomeDir" -> {
                        result.success(MihomoCore.setHomeDir(call.argument<String>("dir").orEmpty()))
                    }
                    "startRust" -> {
                        // Mihomo exposes its Clash-compatible controller directly.
                        result.success(call.argument<String>("addr").orEmpty())
                    }
                    "verifyMMDB" -> {
                        val file = File(call.argument<String>("path").orEmpty())
                        result.success(file.isFile && file.length() > 0)
                    }
                    "getInitialUrl" -> {
                        val value = if (initialUrlConsumed) null else intent?.dataString
                        initialUrlConsumed = true
                        result.success(value)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error("MIHOMO_ERROR", error.message, null)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { methodChannel?.invokeMethod("protocolUrl", it) }
    }

    private fun requestVpn(result: MethodChannel.Result) {
        val permissionIntent = VpnService.prepare(this)
        if (permissionIntent == null) {
            startVpn()
            result.success(true)
            return
        }

        pendingVpnResult?.error("VPN_BUSY", "Superseded by a newer VPN request", null)
        pendingVpnResult = result
        @Suppress("DEPRECATION")
        startActivityForResult(permissionIntent, VPN_REQUEST_CODE)
    }

    private fun startVpn() {
        ContextCompat.startForegroundService(
            this,
            Intent(this, ClashService::class.java).setAction(ClashService.ACTION_CONNECT),
        )
    }

    private fun stopVpn() {
        startService(Intent(this, ClashService::class.java).setAction(ClashService.ACTION_DISCONNECT))
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != VPN_REQUEST_CODE) return

        val result = pendingVpnResult
        pendingVpnResult = null
        if (resultCode == RESULT_OK) {
            startVpn()
            result?.success(true)
        } else {
            result?.error("VPN_DENIED", "VPN permission denied", null)
        }
    }

    override fun onDestroy() {
        pendingVpnResult?.error("ACTIVITY_DESTROYED", "VPN request cancelled", null)
        pendingVpnResult = null
        methodChannel = null
        super.onDestroy()
    }
}
