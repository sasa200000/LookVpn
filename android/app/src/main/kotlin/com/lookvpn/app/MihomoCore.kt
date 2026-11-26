package com.lookvpn.app

import android.content.Context
import io.github.oviron.libmihomo.Clash
import io.github.oviron.libmihomo.TunInterface
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** State for the independent Mihomo client. It never shares CoreManager with Xray. */
object MihomoStatus {
    enum class State { DISCONNECTED, CONNECTING, CONNECTED, DISCONNECTING }

    fun interface Listener {
        fun onStateChanged(state: State, error: String?)
    }

    @Volatile
    var state: State = State.DISCONNECTED
        private set

    @Volatile
    var lastError: String? = null
        private set

    @Volatile
    var connectedAt: Long = 0L
        private set

    @Volatile
    var remark: String = "Mihomo"
        private set

    private val listeners = CopyOnWriteArraySet<Listener>()
    private val main = android.os.Handler(android.os.Looper.getMainLooper())

    fun addListener(listener: Listener) = listeners.add(listener)

    fun removeListener(listener: Listener) = listeners.remove(listener)

    fun setState(next: State, error: String? = null, nextRemark: String? = null) {
        state = next
        lastError = error
        if (nextRemark != null) remark = nextRemark
        if (next == State.CONNECTED && connectedAt == 0L) connectedAt = System.currentTimeMillis()
        if (next == State.DISCONNECTED) connectedAt = 0L
        main.post { listeners.forEach { it.onStateChanged(next, error) } }
    }
}

/**
 * Owns the mihomo Go core in this process. The AAR is pinned and checksum-verified by Gradle
 * (see android/app/build.gradle.kts). The profile is the usual mihomo config.yaml; the core
 * downloads proxy-providers itself, including base64 and share-link subscriptions.
 */
object MihomoCore {
    private const val DIR = "mihomo"
    private const val PROFILE = "config.yaml"
    private const val DEFAULT_TEST_URL = "https://www.gstatic.com/generate_204"

    private val lock = Any()

    @Volatile
    private var loaded = false

    @Volatile
    private var configured = false

    @Volatile
    private var tunRunning = false

    fun profileDir(context: Context): File =
        File(context.filesDir, DIR).apply {
            mkdirs()
            File(this, "providers").mkdirs()
        }

    fun profileFile(context: Context): File = File(profileDir(context), PROFILE)

    fun ensureLoaded(context: Context) {
        synchronized(lock) {
            if (loaded) return
            Clash.load(context.applicationInfo.nativeLibraryDir)
            loaded = true
        }
    }

    /** Saves the YAML and applies it. Returns "" on success, or a user-facing error. */
    fun setup(context: Context, config: String? = null): String {
        ensureLoaded(context)
        if (config != null) {
            profileFile(context).writeText(config)
            configured = false
        }
        val profile = profileFile(context)
        if (!profile.isFile || profile.length() == 0L) return "No Mihomo profile is configured."
        // v0.3.14's InitParams uses the kebab-case home-dir key and reads
        // `${home-dir}/config.yaml`; its SetupParams only carries selected-map.
        val init = JSONObject()
            .put("home-dir", profileDir(context).absolutePath)
            .put("version", android.os.Build.VERSION.SDK_INT)
            .toString()
        val setup = JSONObject()
            .put("selected-map", JSONObject())
            .toString()
        val error = try {
            await { callback -> Clash.quickSetup(init, setup, callback) }
        } catch (e: Exception) {
            "Mihomo could not start: ${e.message ?: e}"
        }
        if (error.isNotEmpty()) {
            configured = false
            return error
        }
        configured = true
        return ""
    }

    fun isConfigured(): Boolean = configured

    fun startTun(context: Context, fd: Int, callback: TunInterface): String {
        ensureLoaded(context)
        if (!configured) {
            val error = setup(context)
            if (error.isNotEmpty()) return error
        }
        return try {
            Clash.startTUN(
                fd = fd,
                cb = callback,
                device = "lookvpn-mihomo",
                stack = "gvisor",
                address = "172.19.0.1/30,fdfe:dcba:9876::1/126",
                dns = "1.1.1.1,8.8.8.8",
                mtu = 1500,
            )
            tunRunning = true
            ""
        } catch (e: Exception) {
            "Mihomo TUN failed: ${e.message ?: e}"
        }
    }

    fun stopTun() {
        if (!loaded || !tunRunning) return
        try {
            Clash.stopTun()
        } catch (_: Exception) {
        } finally {
            tunRunning = false
        }
    }

    /** Runs one mihomo action and returns its `data` field as text. */
    fun action(method: String, data: Any? = null): String {
        val payload = JSONObject()
            .put("id", UUID.randomUUID().toString())
            .put("method", method)
        if (data != null) payload.put("data", data)
        val raw = await { callback -> Clash.invokeAction(payload.toString(), callback) }
        if (raw.isBlank()) throw IllegalStateException("Mihomo returned no result for $method")
        val result = JSONObject(raw)
        if (result.optInt("code", 0) != 0) {
            throw IllegalStateException(result.opt("data")?.toString() ?: "Mihomo action failed")
        }
        return result.opt("data")?.toString() ?: ""
    }

    fun proxies(): String = action("getProxies")

    fun testGroups(groups: List<String>, url: String = DEFAULT_TEST_URL, timeoutMs: Int = 5000): String {
        val names = org.json.JSONArray()
        groups.forEach { names.put(it) }
        val data = JSONObject()
            .put("group-names", names)
            .put("test-url", url)
            .put("timeout", timeoutMs)
            .toString()
        return action("testGroups", data)
    }

    fun testDelay(name: String, url: String = DEFAULT_TEST_URL, timeoutMs: Int = 5000): Int {
        val data = JSONObject()
            .put("proxy-name", name)
            .put("test-url", url)
            .put("timeout", timeoutMs)
            .toString()
        return action("testDelay", data).toIntOrNull() ?: -1
    }

    fun select(group: String, name: String) {
        val data = JSONObject()
            .put("group-name", group)
            .put("proxy-name", name)
            .toString()
        action("changeProxy", data)
    }

    fun refreshProvider(name: String) {
        val data = JSONObject()
            .put("type", "Proxy")
            .put("name", name)
            .toString()
        action("updateExternalProvider", data)
    }

    fun traffic(): String =
        if (!loaded) """{"up":0,"down":0}""" else Clash.getTraffic()

    fun totalTraffic(): String =
        if (!loaded) """{"up":0,"down":0}""" else Clash.getTotalTraffic()


    private fun await(block: ((String?) -> Unit) -> Unit): String {
        val latch = CountDownLatch(1)
        var value: String? = null
        block {
            value = it
            latch.countDown()
        }
        if (!latch.await(60, TimeUnit.SECONDS)) {
            throw IllegalStateException("Mihomo did not answer in time")
        }
        return value ?: ""
    }
}
