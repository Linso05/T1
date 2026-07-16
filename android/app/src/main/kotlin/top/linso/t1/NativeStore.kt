package top.linso.t1

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * 原生侧轻量存储：缓存 app 被杀时收到的法院短信队列 + 短信监听开关镜像。
 * 用 SharedPreferences，避免与 Dart 的 sqflite t1.db 耦合。
 */
object NativeStore {
    private const val PREFS = "t1_native"
    private const val KEY_QUEUE = "pending_sms"
    private const val KEY_SMS_ENABLED = "sms_enabled"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isSmsEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_SMS_ENABLED, true)

    fun setSmsEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_SMS_ENABLED, enabled).apply()
    }

    fun addPending(context: Context, address: String, body: String, date: Long) {
        val arr = readArray(context)
        arr.put(
            JSONObject()
                .put("address", address)
                .put("body", body)
                .put("date", date),
        )
        prefs(context).edit().putString(KEY_QUEUE, arr.toString()).apply()
    }

    fun hasPending(context: Context): Boolean = readArray(context).length() > 0

    fun drainPending(context: Context): List<Map<String, Any>> {
        val arr = readArray(context)
        val out = ArrayList<Map<String, Any>>()
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            out.add(
                mapOf(
                    "address" to o.optString("address"),
                    "body" to o.optString("body"),
                    "date" to o.optLong("date"),
                ),
            )
        }
        prefs(context).edit().putString(KEY_QUEUE, "[]").apply()
        return out
    }

    private fun readArray(context: Context): JSONArray =
        try {
            JSONArray(prefs(context).getString(KEY_QUEUE, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
}
