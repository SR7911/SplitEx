package com.splitex.`in`.app

import android.Manifest
import android.app.Activity
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

/** App-private SMS storage. This preference file is excluded from backup. */
object BankSmsStore {
    const val CHANNEL = "com.splitex.in.app/bank_sms"
    const val PERMISSION_REQUEST = 4812
    const val JOB_ID = 4813
    private const val FILE = "splitex_bank_sms"
    var foregroundChannel: MethodChannel? = null
    var pendingPermission: MethodChannel.Result? = null
    var jobRunning = false
    private fun prefs(context: Context) = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
    fun hasPermission(context: Context) = ContextCompat.checkSelfPermission(context, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
    fun isEnabled(context: Context) = prefs(context).getBoolean("enabled", false) && hasPermission(context)

    @Synchronized fun bindUser(context: Context, owner: String?) {
        val p = prefs(context)
        if (p.getString("owner", null) == owner) return
        p.edit().clear().apply { if (owner != null) putString("owner", owner) }.commit()
        (context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).cancel(JOB_ID)
    }

    @Synchronized fun status(context: Context): String {
        val p = prefs(context)
        return JSONObject().put("enabled", p.getBoolean("enabled", false))
            .put("owner", p.getString("owner", ""))
            .put("autoRecord", p.getBoolean("autoRecord", true))
            .put("permission", hasPermission(context))
            .put("pendingCount", JSONArray(p.getString("queue", "[]")).length())
            .put("reviews", JSONArray(p.getString("reviews", "[]")))
            .put("trustedSenders", JSONArray((p.getStringSet("trusted", emptySet()) ?: emptySet()).toList()))
            .put("lastError", p.getString("error", "")).toString()
    }

    @Synchronized fun configure(context: Context, enabled: Boolean, autoRecord: Boolean) {
        val p = prefs(context)
        require(!enabled || (hasPermission(context) && !p.getString("owner", null).isNullOrEmpty())) { "SMS permission and sign-in are required." }
        p.edit().putBoolean("enabled", enabled).putBoolean("autoRecord", autoRecord)
            .apply { if (!enabled) putString("queue", "[]") }.commit()
        if (!enabled) (context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).cancel(JOB_ID)
    }

    @Synchronized fun capture(context: Context, sender: String, body: String, timestamp: Long) {
        val p = prefs(context)
        if (!p.getBoolean("enabled", false) || !hasPermission(context)) return
        val owner = p.getString("owner", null) ?: return
        if (!Regex("^[A-Za-z][A-Za-z0-9-]{2,24}$").matches(sender)) return
        if (!Regex("(?:INR|Rs\\.?|₹)\\s*[0-9]", RegexOption.IGNORE_CASE).containsMatchIn(body)) return
        if (!Regex("\\b(?:debited|credited|paid|sent|spent|charged|deducted|withdrawn|received|purchase(?:d)?)\\b", RegexOption.IGNORE_CASE).containsMatchIn(body)) return
        if (!Regex("\\b(?:a\\s*/?c|account|acct|card|upi|bank)\\b", RegexOption.IGNORE_CASE).containsMatchIn(body)) return
        if (Regex("\\b(?:otp|one.time password|verification code|failed|declined|unsuccessful|collect request|payment request|will be debited|scheduled)\\b", RegexOption.IGNORE_CASE).containsMatchIn(body)) return
        val id = MessageDigest.getInstance("SHA-256").digest("$owner|$sender|$timestamp|$body".toByteArray()).joinToString("") { "%02x".format(it) }
        val queue = JSONArray(p.getString("queue", "[]"))
        for (i in 0 until queue.length()) if (queue.getJSONObject(i).getString("id") == id) return
        if (queue.length() >= 500) {
            p.edit().putString("error", "SMS queue is full. Open SplitEx to process pending messages; the latest message was not captured.").commit()
            return
        }
        queue.put(JSONObject().put("id", id).put("sender", sender).put("body", body.take(6000)).put("timestamp", timestamp).put("owner", owner))
        p.edit().putString("queue", queue.toString()).commit()
        Handler(Looper.getMainLooper()).post { foregroundChannel?.invokeMethod("queueChanged", null) }
        schedule(context)
    }

    @Synchronized fun queue(context: Context) = prefs(context).getString("queue", "[]")!!
    @Synchronized fun acknowledge(context: Context, id: String) {
        val p = prefs(context)
        val queue = JSONArray(p.getString("queue", "[]"))
        val remaining = JSONArray()
        for (i in 0 until queue.length()) if (queue.getJSONObject(i).getString("id") != id) remaining.put(queue.getJSONObject(i))
        p.edit().putString("queue", remaining.toString()).commit()
    }
    @Synchronized fun putReview(context: Context, json: String) {
        val p = prefs(context)
        val item = JSONObject(json)
        val list = JSONArray(p.getString("reviews", "[]"))
        val next = JSONArray()
        for (i in 0 until list.length()) if (list.getJSONObject(i).getString("messageId") != item.getString("messageId")) next.put(list.getJSONObject(i))
        require(next.length() < 200) { "Review list is full. Review or dismiss messages before importing more." }
        next.put(item)
        p.edit().putString("reviews", next.toString()).commit()
    }
    @Synchronized fun deleteReview(context: Context, id: String) {
        val p = prefs(context)
        val list = JSONArray(p.getString("reviews", "[]"))
        val next = JSONArray()
        for (i in 0 until list.length()) if (list.getJSONObject(i).getString("messageId") != id) next.put(list.getJSONObject(i))
        p.edit().putString("reviews", next.toString()).commit()
    }
    @Synchronized fun trust(context: Context, sender: String, trusted: Boolean) {
        val p = prefs(context)
        val set = (p.getStringSet("trusted", emptySet()) ?: emptySet()).toMutableSet()
        if (trusted) set.add(sender) else set.remove(sender)
        p.edit().putStringSet("trusted", set).commit()
    }
    fun schedule(context: Context) {
        if (jobRunning) return
        val job = JobInfo.Builder(JOB_ID, ComponentName(context, BankSmsJobService::class.java))
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setMinimumLatency(1000L).setPersisted(true)
            .setBackoffCriteria(30000L, JobInfo.BACKOFF_POLICY_EXPONENTIAL).build()
        (context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).schedule(job)
    }

    fun attach(context: Context, engine: FlutterEngine, activity: Activity? = null,
        complete: ((Boolean) -> Unit)? = null): MethodChannel {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "status" -> result.success(status(context))
                    "bindUser" -> { bindUser(context, call.argument<String>("userId")); result.success(null) }
                    "configure" -> { requireOwner(context, call.argument<String>("userId")); configure(context, call.argument<Boolean>("enabled") == true, call.argument<Boolean>("autoRecord") != false); result.success(null) }
                    "requestPermission" -> {
                        if (activity == null) result.success(false)
                        else if (hasPermission(context)) result.success(true)
                        else {
                            require(pendingPermission == null)
                            pendingPermission = result
                            ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.RECEIVE_SMS), PERMISSION_REQUEST)
                        }
                    }
                    "queue" -> { requireOwner(context, call.argument<String>("userId")); result.success(queue(context)) }
                    "acknowledge" -> { requireOwner(context, call.argument<String>("userId")); acknowledge(context, call.argument<String>("id")!!); result.success(null) }
                    "putReview" -> { requireOwner(context, call.argument<String>("userId")); putReview(context, call.argument<String>("json")!!); result.success(null) }
                    "deleteReview" -> { requireOwner(context, call.argument<String>("userId")); deleteReview(context, call.argument<String>("id")!!); result.success(null) }
                    "trust" -> { requireOwner(context, call.argument<String>("userId")); trust(context, call.argument<String>("sender")!!, call.argument<Boolean>("trusted") == true); result.success(null) }
                    "backgroundComplete" -> { result.success(null); Handler(Looper.getMainLooper()).post { complete?.invoke(call.argument<Boolean>("retry") == true) } }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("BANK_SMS", "Unable to update bank SMS settings or queue. Check sign-in, permission, and review-list capacity.", null)
            }
        }
        return channel
    }

    private fun requireOwner(context: Context, owner: String?) {
        require(!owner.isNullOrEmpty() && prefs(context).getString("owner", null) == owner)
    }
}

class BankSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION || !BankSmsStore.isEnabled(context)) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (parts.isEmpty()) return
        val sender = parts.first().originatingAddress ?: return
        if (parts.any { it.originatingAddress != sender }) return
        BankSmsStore.capture(context, sender, parts.joinToString("") { it.messageBody ?: "" }, parts.first().timestampMillis)
    }
}

class BankSmsJobService : JobService() {
    private var engine: FlutterEngine? = null
    private var active: JobParameters? = null
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { finish(true) }
    override fun onStartJob(params: JobParameters): Boolean {
        active = params
        BankSmsStore.jobRunning = true
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val workerEngine = FlutterEngine(this)
            engine = workerEngine
            BankSmsStore.attach(this, workerEngine, complete = { retry -> finish(retry) })
            handler.postDelayed(timeout, 120000L)
            workerEngine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(
                loader.findAppBundlePath(), "package:split_ex/services/bank_sms_service.dart", "bankSmsBackgroundMain"))
        } catch (_: Exception) { finish(true) }
        return true
    }
    private fun finish(retry: Boolean) {
        val params = active ?: return
        active = null
        handler.removeCallbacks(timeout)
        BankSmsStore.jobRunning = false
        engine?.destroy()
        engine = null
        jobFinished(params, retry)
    }
    override fun onStopJob(params: JobParameters): Boolean {
        active = null
        handler.removeCallbacks(timeout)
        BankSmsStore.jobRunning = false
        engine?.destroy()
        engine = null
        return true
    }
    override fun onDestroy() {
        handler.removeCallbacks(timeout)
        engine?.destroy()
        engine = null
        BankSmsStore.jobRunning = false
        super.onDestroy()
    }
}
