package com.lookvpn.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import io.github.oviron.libmihomo.TunInterface
import java.util.concurrent.Executors

/**
 * The fifth tab's own VPN tunnel. It is deliberately separate from LookVpnService and Xray:
 * its state, profile and lifecycle do not touch CoreManager. Android allows only one active
 * VPN, so starting this one asks the main tunnel to stop first.
 */
class MihomoVpnService : VpnService() {
    companion object {
        private const val TAG = "MihomoVpnService"
        private const val ACTION_START = "com.lookvpn.app.MIHOMO_START"
        private const val ACTION_STOP = "com.lookvpn.app.MIHOMO_STOP"
        private const val CHANNEL_ID = "lookvpn-mihomo"
        private const val NOTIFICATION_ID = 42
        private const val TUN_IPV4 = "172.19.0.1"
        private const val TUN_IPV6 = "fdfe:dcba:9876::1"

        fun start(context: Context) {
            val intent = Intent(context, MihomoVpnService::class.java).setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            if (MihomoStatus.state == MihomoStatus.State.DISCONNECTED) return
            context.startService(
                Intent(context, MihomoVpnService::class.java).setAction(ACTION_STOP),
            )
        }
    }

    private val worker = Executors.newSingleThreadExecutor()
    private var tun: ParcelFileDescriptor? = null

    /** The core's TUN callbacks must not implement TunInterface on the service itself:
     * VpnService.protect(int) returns a boolean while TunInterface.protect(int) is void,
     * so a single class cannot override both JVM signatures. */
    private val tunCallback = object : TunInterface {
        override fun protect(fd: Int) {
            this@MihomoVpnService.protect(fd)
        }

        override fun resolverProcess(
            protocol: Int,
            source: String,
            target: String,
            uid: Int,
        ): String = ""
    }

    @Volatile
    private var stopRequested = false

    private fun fail(message: String) {
        Log.e(TAG, message)
        MihomoCore.stopTun()
        tun?.close()
        tun = null
        MihomoStatus.setState(MihomoStatus.State.DISCONNECTED, message)
        stopForegroundCompat()
        stopSelf()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopRequested = true
            worker.execute { stopVpn() }
            return START_NOT_STICKY
        }
        stopRequested = false
        startForegroundCompat(buildNotification(connected = false))
        worker.execute { startVpn() }
        return START_STICKY
    }

    private fun startVpn() {
        MihomoStatus.setState(MihomoStatus.State.CONNECTING)
        try {
            // Android has a single TUN slot. Stop the Xray tunnel before asking for this one.
            if (CoreManager.state != CoreManager.State.DISCONNECTED) {
                LookVpnService.stop(this)
                val deadline = System.currentTimeMillis() + 10_000
                while (CoreManager.state != CoreManager.State.DISCONNECTED &&
                    System.currentTimeMillis() < deadline
                ) {
                    Thread.sleep(100)
                }
                if (CoreManager.state != CoreManager.State.DISCONNECTED) {
                    fail("Main VPN is still connected. Stop it, then connect Mihomo.")
                    return
                }
            }

            val error = if (MihomoCore.isConfigured()) "" else MihomoCore.setup(this)
            if (error.isNotEmpty()) {
                fail(error)
                return
            }

            val builder = Builder()
                .setSession("LookVPN Mihomo")
                .setMtu(1500)
                .addAddress(TUN_IPV4, 30)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("1.1.1.1")
                .addDnsServer("8.8.8.8")
            builder.addAddress(TUN_IPV6, 126).addRoute("::", 0)
            try {
                builder.addDisallowedApplication(packageName)
            } catch (_: Exception) {
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }
            builder.setConfigureIntent(openAppIntent())

            val descriptor = builder.establish()
                ?: throw IllegalStateException("VPN permission was not granted")
            tun = descriptor
            val rawFd = descriptor.detachFd()
            // The native core owns the detached fd from here; clearing this prevents a
            // second close when the service stops.
            tun = null
            val tunError = MihomoCore.startTun(this, rawFd, tunCallback)
            if (tunError.isNotEmpty()) {
                fail(tunError)
                return
            }
            if (stopRequested) {
                stopVpn()
                return
            }
            MihomoStatus.setState(MihomoStatus.State.CONNECTED, nextRemark = "Mihomo")
            startForegroundCompat(buildNotification(connected = true))
        } catch (e: Exception) {
            if (!stopRequested) fail(e.message ?: e.toString())
        }
    }

    private fun stopVpn() {
        MihomoStatus.setState(MihomoStatus.State.DISCONNECTING)
        MihomoCore.stopTun()
        tun?.close()
        tun = null
        MihomoStatus.setState(MihomoStatus.State.DISCONNECTED)
        stopForegroundCompat()
        stopSelf()
    }

    override fun onRevoke() {
        stopRequested = true
        worker.execute { stopVpn() }
    }

    override fun onDestroy() {
        stopRequested = true
        MihomoCore.stopTun()
        tun?.close()
        tun = null
        if (MihomoStatus.state != MihomoStatus.State.DISCONNECTED) {
            MihomoStatus.setState(MihomoStatus.State.DISCONNECTED)
        }
        worker.shutdownNow()
        super.onDestroy()
    }

    private fun openAppIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    @Suppress("DEPRECATION")
    private fun buildNotification(connected: Boolean): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Mihomo",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, MihomoVpnService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("LookVPN · Mihomo")
            .setContentText(if (connected) "Mihomo tunnel is active" else "Connecting…")
            .setSmallIcon(R.drawable.ic_stat_vpn)
            .setContentIntent(openAppIntent())
            .setOngoing(true)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stop)
            .build()
    }

    private fun startForegroundCompat(notification: Notification) {
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

    private fun stopForegroundCompat() {
        stopForeground(STOP_FOREGROUND_REMOVE)
    }
}
