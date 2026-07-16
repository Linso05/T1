package top.linso.t1

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.BaseColumns
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var smsReceiver: BroadcastReceiver? = null
    private var updateReceiver: BroadcastReceiver? = null
    private var updateChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadRecentSms" -> {
                    val limit = call.argument<Int>("limit") ?: 1200
                    // ContentResolver 查询放后台线程，避免阻塞 Android 主线程导致 UI 卡死。
                    Thread {
                        val data = loadRecentSms(limit)
                        runOnUiThread { result.success(data) }
                    }.start()
                }
                "drainPendingSms" -> {
                    result.success(NativeStore.drainPending(this))
                }
                "setNativeSmsEnabled" -> {
                    NativeStore.setSmsEnabled(this, call.argument<Boolean>("enabled") ?: true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, APP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("no_path", "缺少 APK 路径", null)
                    } else {
                        try {
                            installApk(path)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("install_failed", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        updateChannel = MethodChannel(messenger, UPDATE_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkUpdate" -> {
                        // 反射初始化 + 网络检测放后台线程，避免阻塞 UI。
                        Thread {
                            val status = AliyunUpdateManager.start(this, manual = true)
                            runOnUiThread { result.success(status) }
                        }.start()
                    }
                    "confirmUpdate" -> {
                        AliyunUpdateManager.confirmPendingUpdate()
                        result.success(null)
                    }
                    "cancelUpdate" -> {
                        AliyunUpdateManager.cancelPendingUpdate()
                        result.success(null)
                    }
                    "updateStatus" -> result.success(AliyunUpdateManager.lastStatus(this))
                    else -> result.notImplemented()
                }
            }
        }
        registerUpdateReceiver()

        EventChannel(messenger, SMS_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    registerSmsReceiver(events)
                }

                override fun onCancel(arguments: Any?) {
                    unregisterSmsReceiver()
                }
            },
        )
    }

    override fun onDestroy() {
        unregisterSmsReceiver()
        updateReceiver?.let { runCatching { unregisterReceiver(it) } }
        updateReceiver = null
        super.onDestroy()
    }

    /** 监听阿里云 SDK 的"发现更新"广播，转发给 Flutter 弹窗。 */
    private fun registerUpdateReceiver() {
        if (updateReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    AliyunUpdateManager.ACTION_UPDATE_NOTIFY -> {
                        val map = mapOf(
                            "title" to (intent.getStringExtra(AliyunUpdateManager.EXTRA_TITLE) ?: ""),
                            "message" to (intent.getStringExtra(AliyunUpdateManager.EXTRA_MESSAGE) ?: ""),
                            "version" to (intent.getStringExtra(AliyunUpdateManager.EXTRA_VERSION) ?: ""),
                            "size" to (intent.getStringExtra(AliyunUpdateManager.EXTRA_SIZE) ?: ""),
                            "force" to intent.getBooleanExtra(AliyunUpdateManager.EXTRA_FORCE, false),
                            "log" to (intent.getStringExtra(AliyunUpdateManager.EXTRA_LOG) ?: ""),
                            "confirm" to (intent.getStringExtra(AliyunUpdateManager.EXTRA_CONFIRM) ?: "更新"),
                            "cancel" to (intent.getStringExtra(AliyunUpdateManager.EXTRA_CANCEL) ?: "稍后"),
                            "url" to (intent.getStringExtra(AliyunUpdateManager.EXTRA_URL) ?: ""),
                        )
                        runOnUiThread { updateChannel?.invokeMethod("onUpdateNotify", map) }
                    }
                    AliyunUpdateManager.ACTION_UPDATE_RESULT -> {
                        val map = mapOf(
                            "found" to intent.getBooleanExtra(AliyunUpdateManager.EXTRA_FOUND, false),
                            "message" to (intent.getStringExtra(AliyunUpdateManager.EXTRA_MESSAGE) ?: ""),
                        )
                        runOnUiThread { updateChannel?.invokeMethod("onUpdateResult", map) }
                    }
                }
            }
        }
        val filter = IntentFilter(AliyunUpdateManager.ACTION_UPDATE_NOTIFY).apply {
            addAction(AliyunUpdateManager.ACTION_UPDATE_RESULT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
        updateReceiver = receiver
    }

    private fun registerSmsReceiver(events: EventChannel.EventSink?) {
        unregisterSmsReceiver()
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
                if (messages.isEmpty()) return
                val body = messages.joinToString("") { it.messageBody ?: "" }
                val address = messages.firstOrNull()?.originatingAddress ?: ""
                val date = messages.firstOrNull()?.timestampMillis
                    ?: System.currentTimeMillis()
                events?.success(
                    mapOf("address" to address, "body" to body, "date" to date),
                )
            }
        }
        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
        smsReceiver = receiver
    }

    private fun unregisterSmsReceiver() {
        smsReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        smsReceiver = null
    }

    /** 查询收件箱短信，对照 Kotlin 版 SmsImporter.loadRecentSms。权限缺失时返回空列表。 */
    private fun loadRecentSms(limit: Int): List<Map<String, Any>> {
        val list = ArrayList<Map<String, Any>>()
        val projection = arrayOf(
            BaseColumns._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
        )
        try {
            contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                projection,
                "${Telephony.Sms.TYPE} = ?",
                arrayOf(Telephony.Sms.MESSAGE_TYPE_INBOX.toString()),
                "${Telephony.Sms.DATE} DESC, ${BaseColumns._ID} DESC",
            )?.use { cursor ->
                val addressIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
                val bodyIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
                val dateIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
                while (cursor.moveToNext() && list.size < limit) {
                    list.add(
                        mapOf(
                            "address" to (cursor.getString(addressIndex) ?: ""),
                            "body" to (cursor.getString(bodyIndex) ?: ""),
                            "date" to cursor.getLong(dateIndex),
                        )
                    )
                }
            }
        } catch (_: SecurityException) {
            // 未授予 READ_SMS：返回空，由 Dart 侧请求权限后重试。
        } catch (_: Exception) {
        }
        return list
    }

    /** 拉起系统安装器安装下载好的 APK。 */
    private fun installApk(path: String) {
        val file = java.io.File(path)
        val uri = androidx.core.content.FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    companion object {
        private const val SMS_CHANNEL = "top.linso.t1/sms"
        private const val SMS_EVENTS = "top.linso.t1/sms_events"
        private const val APP_CHANNEL = "top.linso.t1/app"
        private const val UPDATE_CHANNEL = "top.linso.t1/update"
    }
}
