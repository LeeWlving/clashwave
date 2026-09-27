package io.qzz.wenyun

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import io.github.oviron.libmihomo.Clash
import io.github.oviron.libmihomo.TunInterface
import java.util.concurrent.atomic.AtomicBoolean

class ClashService : VpnService() {
    companion object {
        const val ACTION_CONNECT = "io.qzz.wenyun.CONNECT"
        const val ACTION_DISCONNECT = "io.qzz.wenyun.DISCONNECT"

        private const val TAG = "ClashWaveVpn"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "vpn_status"
    }

    private val running = AtomicBoolean(false)
    private val tunCallbacks =
        object : TunInterface {
            override fun protect(fd: Int) {
                this@ClashService.protect(fd)
            }

            override fun resolverProcess(
                protocol: Int,
                source: String,
                target: String,
                uid: Int,
            ): String = ""
        }

    override fun onCreate() {
        super.onCreate()
        MihomoCore.ensureLoaded(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                showNotification()
                Thread(::connect, "mihomo-vpn-connect").start()
            }
            ACTION_DISCONNECT -> disconnect()
        }
        return START_NOT_STICKY
    }

    private fun connect() {
        if (!running.compareAndSet(false, true)) return
        try {
            val tun =
                Builder()
                    .setSession("ClashWave")
                    .setMtu(1500)
                    .addAddress("172.18.0.1", 30)
                    .addRoute("0.0.0.0", 0)
                    .addDnsServer("172.18.0.2")
                    .addAddress("fdfe:dcba:9876::1", 126)
                    .addRoute("::", 0)
                    .addDnsServer("fdfe:dcba:9876::2")
                    .addDisallowedApplication(packageName)
                    .setMetered(false)
                    .establish()
                    ?: error("Unable to establish Android VPN interface")

            val fd = tun.detachFd()
            Clash.startTUN(
                fd,
                tunCallbacks,
                "clashwave-tun",
                "mixed",
                "172.18.0.1/30,fdfe:dcba:9876::1/126",
                "172.18.0.2,fdfe:dcba:9876::2",
                1500,
            )
            Log.i(TAG, "Mihomo VPN started")
        } catch (error: Throwable) {
            Log.e(TAG, "Mihomo VPN failed to start", error)
            running.set(false)
            disconnect()
        }
    }

    private fun disconnect() {
        running.set(false)
        try {
            Clash.stopTun()
            MihomoCore.restoreController()
        } catch (error: Throwable) {
            Log.e(TAG, "Failed to stop Mihomo TUN", error)
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun showNotification() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "VPN service", NotificationManager.IMPORTANCE_LOW).apply {
                description = "ClashWave VPN connection status"
                setShowBadge(false)
            },
        )

        val openApp =
            PendingIntent.getActivity(
                this,
                0,
                Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("ClashWave")
                .setContentText("Mihomo VPN is running")
                .setContentIntent(openApp)
                .setOngoing(true)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onRevoke() {
        disconnect()
        super.onRevoke()
    }

    override fun onDestroy() {
        if (running.get()) {
            disconnect()
        }
        super.onDestroy()
    }
}
