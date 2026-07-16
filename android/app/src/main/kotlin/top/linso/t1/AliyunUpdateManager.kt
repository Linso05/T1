package top.linso.t1

import android.app.Application
import android.content.Context
import android.content.Intent
import com.alibaba.fastjson.JSON
import java.lang.reflect.Proxy
import java.util.Locale

/**
 * 阿里云 EMAS 云发布（Taobao OneSDK）更新集成。端口自 L2 `update/T1Application.kt`。
 * 全程反射调用 com.taobao.update.* —— 即使依赖缺失也能编译，运行期类不存在则跳过。
 * 状态字符串存本机 SharedPreferences（替代 L2 的 AppStateStore）。
 */
object AliyunUpdateManager {
    private const val PREFS = "t1_native"
    private const val KEY_STATUS = "cloud_update_status"

    const val ACTION_UPDATE_NOTIFY = "top.linso.t1.action.UPDATE_NOTIFY"
    const val ACTION_UPDATE_RESULT = "top.linso.t1.action.UPDATE_RESULT"
    const val EXTRA_TITLE = "title"
    const val EXTRA_MESSAGE = "message"
    const val EXTRA_VERSION = "version"
    const val EXTRA_SIZE = "size"
    const val EXTRA_FORCE = "force"
    const val EXTRA_LOG = "log"
    const val EXTRA_CONFIRM = "confirm"
    const val EXTRA_CANCEL = "cancel"
    const val EXTRA_FOUND = "found"
    const val EXTRA_URL = "url"

    @Volatile
    var pendingUserAction: Any? = null
    @Volatile
    private var lastRawUpdateInfo: RawUpdateInfo? = null
    @Volatile
    private var initialized = false
    @Volatile
    private var dataSourceRef: Any? = null
    @Volatile
    private var dataSourceClassRef: Class<*>? = null

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun lastStatus(context: Context): String =
        prefs(context).getString(KEY_STATUS, "code=IDLE · 尚未检测更新")
            ?: "code=IDLE · 尚未检测更新"

    private fun record(context: Context, message: String): String {
        prefs(context).edit().putString(KEY_STATUS, message).apply()
        return message
    }

    /** 进程启动即调用（T1Application.onCreate）：init SDK + 注册监听，只做一次。 */
    fun ensureInit(context: Context): Boolean {
        if (initialized) return true
        val appKey = BuildConfig.ALIYUN_UPDATE_APP_KEY
        val appSecret = BuildConfig.ALIYUN_UPDATE_APP_SECRET
        val channelId = BuildConfig.ALIYUN_UPDATE_CHANNEL_ID.ifBlank { "default" }
        if (appKey.isBlank() || appSecret.isBlank()) return false
        if (!hasRequiredUpdateClasses()) return false
        return runCatching {
            val dsClass = Class.forName("com.taobao.update.datasource.UpdateDataSource")
            val ds = dsClass.getMethod("getInstance").invoke(null)
            dsClass
                .getMethod("init", Application::class.java, String::class.java, String::class.java, String::class.java)
                .invoke(ds, context.applicationContext as Application, appKey, appSecret, channelId)
            runCatching {
                Class.forName("com.taobao.update.common.framework.UpdateRuntime")
                    .getMethod("init")
                    .invoke(null)
            }
            registerApkUpdater(context.applicationContext, dsClass, ds)
            dataSourceRef = ds
            dataSourceClassRef = dsClass
            initialized = true
            true
        }.getOrElse { false }
    }

    fun start(context: Context, manual: Boolean): String {
        val appKey = BuildConfig.ALIYUN_UPDATE_APP_KEY
        val appSecret = BuildConfig.ALIYUN_UPDATE_APP_SECRET
        if (appKey.isBlank() || appSecret.isBlank()) {
            return if (manual) {
                record(context, "code=CONFIG_MISSING · 更新参数未配置")
            } else {
                lastStatus(context)
            }
        }
        if (!hasRequiredUpdateClasses()) {
            return if (manual) {
                record(context, "code=DEPENDENCY_MISSING · 更新依赖缺失，已跳过检查")
            } else {
                lastStatus(context)
            }
        }

        return runCatching {
            if (!ensureInit(context)) {
                return if (manual) {
                    record(context, "code=INIT_FAILED · 初始化失败")
                } else {
                    lastStatus(context)
                }
            }
            val dataSource = dataSourceRef!!
            val dataSourceClass = dataSourceClassRef!!
            dataSourceClass.getMethod("setEnableCache", Boolean::class.javaPrimitiveType).invoke(dataSource, !manual)
            dataSourceClass.getMethod("setCacheValidTime", Long::class.javaPrimitiveType).invoke(dataSource, 12 * 60 * 60 * 1000L)
            if (manual) {
                runCatching { dataSourceClass.getMethod("clearCache").invoke(dataSource) }
            }

            val method = if (manual) "startManualUpdate" else "startUpdate"
            dataSourceClass.getMethod(method, Boolean::class.javaPrimitiveType).invoke(dataSource, false)
            if (manual) {
                record(context, "code=CHECKING;at=${System.currentTimeMillis()} · 正在检测更新")
            } else {
                lastStatus(context)
            }
        }.getOrElse { throwable ->
            if (manual) {
                record(context, "code=INIT_FAILED · ${throwable.message ?: throwable.javaClass.simpleName}")
            } else {
                lastStatus(context)
            }
        }
    }

    private fun hasRequiredUpdateClasses(): Boolean {
        val requiredClasses = listOf(
            "com.taobao.update.datasource.UpdateDataSource",
            "com.taobao.update.apk.ApkUpdater",
            "com.alibaba.sdk.android.tool.ProcessUtils",
            "com.alibaba.fastjson.JSONObject",
        )
        val hasRequired = requiredClasses.all(::hasClass)
        val hasUtdid = listOf(
            "com.ta.utdid2.device.UTDevice",
            "com.ut.device.UTDevice",
        ).any(::hasClass)
        return hasRequired && hasUtdid
    }

    private fun hasClass(className: String): Boolean =
        runCatching { Class.forName(className) }.isSuccess

    private fun registerApkUpdater(context: Context, dataSourceClass: Class<*>, dataSource: Any) {
        val updater = Class.forName("com.taobao.update.apk.ApkUpdater")
            .getConstructor()
            .newInstance()
        runCatching {
            updater.javaClass.getMethod("init").invoke(updater)
        }
        registerUpdateLogger(updater)

        runCatching {
            val notifyListenerClass = Class.forName("com.taobao.update.common.dialog.UpdateNotifyListener")
            val notifyListener = Proxy.newProxyInstance(
                notifyListenerClass.classLoader,
                arrayOf(notifyListenerClass),
            ) { _, method, args ->
                if (method.name == "onNotify") {
                    val info = args?.getOrNull(1)
                    val action = args?.getOrNull(2)
                    pendingUserAction = action
                    val infoClass = info?.javaClass
                    val version = infoClass?.getMethod("getVersion")?.invoke(info)?.toString().orEmpty()
                    val size = infoClass?.getMethod("getSize")?.invoke(info)?.toString().orEmpty()
                    val detail = infoClass?.getMethod("getInfo")?.invoke(info)?.toString().orEmpty()
                    val rawInfo = lastRawUpdateInfo
                    val displayVersion = rawInfo?.version.orEmpty().ifBlank { version }
                    val displaySize = rawInfo?.sizeText().orEmpty().ifBlank { size }
                    val displayLog = rawInfo?.info.orEmpty().ifBlank { detail }
                    val downloadUrl = rawInfo?.url.orEmpty().ifBlank {
                        runCatching { infoClass?.getMethod("getDownloadUrl")?.invoke(info)?.toString() }
                            .getOrNull().orEmpty()
                    }
                    val force = infoClass?.getMethod("isForceUpdate")?.invoke(info) as? Boolean ?: false
                    val actionClass = action?.javaClass
                    val confirmText = actionClass?.getMethod("getConfirmText")?.invoke(action)?.toString().orEmpty().ifBlank { "更新" }
                    val cancelText = actionClass?.getMethod("getCancelText")?.invoke(action)?.toString().orEmpty().ifBlank { "稍后" }
                    val titleText = actionClass?.getMethod("getTitleText")?.invoke(action)?.toString().orEmpty().ifBlank { "发现新版本" }
                    val message = buildString {
                        if (displayVersion.isNotBlank()) append("版本：$displayVersion\n")
                        if (displaySize.isNotBlank()) append("大小：$displaySize\n")
                        append(if (force) "类型：强制更新" else "类型：可选更新")
                        if (displayLog.isNotBlank()) append("\n\n$displayLog")
                    }
                    record(context, "code=UPDATE_AVAILABLE · ${displayVersion.ifBlank { titleText }}")
                    // 用 applicationContext 发广播（onNotify 的 activity 可能为空，导致不弹窗）。
                    context.sendBroadcast(
                        Intent(ACTION_UPDATE_NOTIFY)
                            .setPackage(context.packageName)
                            .putExtra(EXTRA_TITLE, titleText)
                            .putExtra(EXTRA_MESSAGE, message)
                            .putExtra(EXTRA_VERSION, displayVersion)
                            .putExtra(EXTRA_SIZE, displaySize)
                            .putExtra(EXTRA_FORCE, force)
                            .putExtra(EXTRA_LOG, displayLog)
                            .putExtra(EXTRA_CONFIRM, confirmText)
                            .putExtra(EXTRA_CANCEL, cancelText)
                            .putExtra(EXTRA_URL, downloadUrl),
                    )
                }
                null
            }
            updater.javaClass.getMethod("setUpdateNotifyListener", notifyListenerClass).invoke(updater, notifyListener)
            updater.javaClass.getMethod("setCancelUpdateNotifyListener", notifyListenerClass).invoke(updater, notifyListener)
            updater.javaClass.getMethod("setInstallUpdateNotifyListener", notifyListenerClass).invoke(updater, notifyListener)
        }

        runCatching {
            val resultListenerClass = Class.forName("com.taobao.update.apk.UpdateResultListener")
            val resultListener = Proxy.newProxyInstance(
                resultListenerClass.classLoader,
                arrayOf(resultListenerClass),
            ) { _, method, args ->
                if (method.name == "onFinish") {
                    val mode = args?.getOrNull(0)
                    val errorCode = args?.getOrNull(1)
                    val message = args?.getOrNull(2)?.toString().orEmpty()
                    record(context, "code=$errorCode · mode=$mode · ${message.ifBlank { "检查完成" }}")
                    // 检查结束 → 通知 Flutter（found=是否发现新版本），用于停转圈/「已是最新」toast。
                    context.sendBroadcast(
                        Intent(ACTION_UPDATE_RESULT)
                            .setPackage(context.packageName)
                            .putExtra(EXTRA_FOUND, pendingUserAction != null)
                            .putExtra(EXTRA_MESSAGE, message),
                    )
                }
                null
            }
            updater.javaClass.getMethod("setUpdateResultListener", resultListenerClass).invoke(updater, resultListener)
        }

        runCatching {
            val downloadListenerClass = Class.forName("com.taobao.update.apk.ApkDownloadListener")
            val downloadListener = Proxy.newProxyInstance(
                downloadListenerClass.classLoader,
                arrayOf(downloadListenerClass),
            ) { _, method, args ->
                when (method.name) {
                    "onPreDownload" -> record(context, "code=DOWNLOAD_START · 开始下载更新包")
                    "onDownloadProgress" -> record(context, "code=DOWNLOADING · ${args?.getOrNull(0) ?: 0}%")
                    "onDownloadFinish" -> record(context, "code=DOWNLOAD_FINISHED · 更新包下载完成，等待安装")
                    "onDownloadError" -> record(context, "code=DOWNLOAD_FAILED · ${args?.getOrNull(2) ?: args?.getOrNull(1) ?: "未知错误"}")
                    "onStartFileMd5Valid" -> record(context, "code=VERIFYING · 正在校验更新包")
                    "onFinishFileMd5Valid" -> record(context, if (args?.getOrNull(0) == true) "code=VERIFY_OK · 更新包校验通过" else "code=VERIFY_FAILED · 更新包校验失败")
                }
                null
            }
            updater.javaClass.getMethod("setApkDownloadListener", downloadListenerClass).invoke(updater, downloadListener)
        }

        val listenerClass = Class.forName("com.taobao.update.datasource.UpdateListener")
        dataSourceClass.getMethod("registerListener", String::class.java, listenerClass)
            .invoke(dataSource, "main", updater)
    }

    private fun registerUpdateLogger(updater: Any) {
        runCatching {
            val logClass = Class.forName("com.taobao.update.IUpdateLog")
            val logProxy = Proxy.newProxyInstance(
                logClass.classLoader,
                arrayOf(logClass),
            ) { _, _, args ->
                if (args?.firstOrNull() is String) {
                    captureMainUpdateData(args.first() as String)
                }
                null
            }
            updater.javaClass.getMethod("setUpdateLog", logClass).invoke(updater, logProxy)
        }
    }

    private fun captureMainUpdateData(message: String) {
        val marker = "mainUpdateData is:"
        val start = message.indexOf(marker)
        if (start < 0) return
        val jsonText = message.substring(start + marker.length).trim()
        val json = runCatching { JSON.parseObject(jsonText) }.getOrNull() ?: return
        val url = listOf("url", "downloadUrl", "publishUrl", "apkUrl", "remoteUrl")
            .asSequence()
            .mapNotNull { runCatching { json.getString(it) }.getOrNull() }
            .firstOrNull { !it.isNullOrBlank() }
            .orEmpty()
        lastRawUpdateInfo = RawUpdateInfo(
            info = json.getString("info").orEmpty(),
            version = json.getString("version").orEmpty(),
            size = json.getLong("size") ?: 0L,
            url = url,
        )
    }

    private data class RawUpdateInfo(
        val info: String,
        val version: String,
        val size: Long,
        val url: String = "",
    ) {
        fun sizeText(): String = when {
            size <= 0L -> ""
            size >= 1024L * 1024L -> String.format(Locale.US, "%.1f MB", size / 1024f / 1024f)
            size >= 1024L -> String.format(Locale.US, "%.1f KB", size / 1024f)
            else -> "$size B"
        }
    }

    fun confirmPendingUpdate() {
        val action = pendingUserAction ?: return
        runCatching { action.javaClass.getMethod("onConfirm").invoke(action) }
        pendingUserAction = null
    }

    fun cancelPendingUpdate() {
        val action = pendingUserAction ?: return
        runCatching { action.javaClass.getMethod("onCancel").invoke(action) }
        pendingUserAction = null
    }
}
