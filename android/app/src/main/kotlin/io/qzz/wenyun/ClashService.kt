package io.qzz.wenyun

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.TileService
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.github.oviron.libmihomo.Clash
import io.github.oviron.libmihomo.TunInterface
import java.util.concurrent.atomic.AtomicBoolean

class ClashService : VpnService() {
    companion object {
        const val ACTION_CONNECT = "io.qzz.wenyun.CONNECT"
        const val ACTION_DISCONNECT = "io.qzz.wenyun.DISCONNECT"
        private const val ACTION_ALWAYS_ON = "android.net.VpnService"

        private const val TAG = "ClashWaveVpn"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "vpn_status"
        private const val PREFS = "clashwave_vpn"
        private const val KEY_ENABLED = "enabled"

        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context) {
            setEnabled(context, true)
            ContextCompat.startForegroundService(
                context,
                Intent(context, ClashService::class.java).setAction(ACTION_CONNECT),
            )
        }

        fun stop(context: Context) {
            setEnabled(context, false)
            context.startService(
                Intent(context, ClashService::class.java).setAction(ACTION_DISCONNECT),
            )
        }

        fun shouldRestore(context: Context): Boolean =
            context.getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean(KEY_ENABLED, false)

        private fun setEnabled(context: Context, enabled: Boolean) {
            context.getSharedPreferences(PREFS, MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_ENABLED, enabled)
                .apply()
            refreshTile(context)
        }

        fun refreshTile(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                TileService.requestListeningState(
                    context,
                    ComponentName(context, ClashTileService::class.java),
                )
            }
        }
    }

    private val connecting = AtomicBoolean(false)
    private val tunLock = Any()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var networkWasLost = false
    private var destroyed = false

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
        if (intent?.action == ACTION_DISCONNECT) {
            disconnect(userRequested = true)
            return START_NOT_STICKY
        }

        val alwaysOn = intent?.action == ACTION_ALWAYS_ON
        val explicit = intent?.action == ACTION_CONNECT
        val processRestore = intent == null && shouldRestore(this)
        if (!alwaysOn && !explicit && !processRestore) {
            stopSelf()
            return START_NOT_STICKY
        }

        setEnabled(this, true)
        showNotification()
        startCoreAndConnect()
        return START_STICKY
    }

    private fun startCoreAndConnect() {
        if (isRunning || !connecting.compareAndSet(false, true)) return
        MihomoCore.start(this) { success, error ->
            if (!success) {
                Log.e(TAG, "Mihomo failed to initialize: ${error ?: "unknown error"}")
                connecting.set(false)
                disconnect(userRequested = false)
                return@start
            }
            Thread(
                {
                    try {
                        synchronized(tunLock) { establishTun() }
                        isRunning = true
                        registerNetworkMonitor()
                        refreshTile(this)
                        Log.i(TAG, "Mihomo VPN started")
                    } catch (error: Throwable) {
                        Log.e(TAG, "Mihomo VPN failed to start", error)
                        disconnect(userRequested = false)
                    } finally {
                        connecting.set(false)
                    }
                },
                "mihomo-vpn-connect",
            ).start()
        }
    }

    private fun establishTun() {
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

        Clash.startTUN(
            tun.detachFd(),
            tunCallbacks,
            "clashwave-tun",
            "mixed",
            "172.18.0.1/30,fdfe:dcba:9876::1/126",
            "172.18.0.2,fdfe:dcba:9876::2",
            1500,
        )
    }

    private fun registerNetworkMonitor() {
        if (networkCallback != null) return
        val manager = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        val callback =
            object : ConnectivityManager.NetworkCallback() {
                override fun onLost(network: Network) {
                    networkWasLost = true
                }

                override fun onAvailable(network: Network) {
                    if (!networkWasLost || !isRunning) return
                    networkWasLost = false
                    mainHandler.removeCallbacksAndMessages(null)
                    mainHandler.postDelayed({ reconnectAfterNetworkChange() }, 750)
                }
            }
        manager.registerNetworkCallback(NetworkRequest.Builder().build(), callback)
        connectivityManager = manager
        networkCallback = callback
    }

    private fun reconnectAfterNetworkChange() {
        if (!isRunning || destroyed) return
        Thread(
            {
                try {
                    synchronized(tunLock) {
                        Clash.stopTun()
                        establishTun()
                    }
                    Log.i(TAG, "VPN tunnel restored after network change")
                } catch (error: Throwable) {
                    Log.e(TAG, "Failed to restore VPN after network change", error)
                    disconnect(userRequested = false)
                }
            },
            "mihomo-vpn-network-recovery",
        ).start()
    }

    private fun disconnect(userRequested: Boolean) {
        if (userRequested) setEnabled(this, false)
        isRunning = false
        connecting.set(false)
        unregisterNetworkMonitor()
        try {
            synchronized(tunLock) {
                Clash.stopTun()
                MihomoCore.restoreController()
            }
        } catch (error: Throwable) {
            Log.e(TAG, "Failed to stop Mihomo TUN", error)
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        refreshTile(this)
        if (!destroyed) stopSelf()
    }

    private fun unregisterNetworkMonitor() {
        mainHandler.removeCallbacksAndMessages(null)
        val callback = networkCallback ?: return
        try {
            connectivityManager?.unregisterNetworkCallback(callback)
        } catch (_: Throwable) {
        }
        networkCallback = null
        connectivityManager = null
        networkWasLost = false
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
        val disconnect =
            PendingIntent.getService(
                this,
                1,
                Intent(this, ClashService::class.java).setAction(ACTION_DISCONNECT),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_vpn)
                .setContentTitle("ClashWave")
                .setContentText("Mihomo VPN is running")
                .setContentIntent(openApp)
                .addAction(0, "断开", disconnect)
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
        setEnabled(this, false)
        disconnect(userRequested = false)
        super.onRevoke()
    }

    override fun onDestroy() {
        destroyed = true
        if (isRunning || connecting.get()) disconnect(userRequested = false)
        unregisterNetworkMonitor()
        super.onDestroy()
    }
}
