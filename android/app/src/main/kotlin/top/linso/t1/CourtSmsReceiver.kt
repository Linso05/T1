package top.linso.t1

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Manifest 声明的常驻短信接收器：app 被杀也能触发。
 * 命中疑似法院送达短信时，缓存进队列 + 发通知；真正解析在 app 启动后由 Dart 侧 drain。
 */
class CourtSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val ctx = context ?: return
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        if (!NativeStore.isSmsEnabled(ctx)) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (messages.isEmpty()) return
        val body = messages.joinToString("") { it.messageBody ?: "" }
        val address = messages.firstOrNull()?.originatingAddress ?: ""
        val date = messages.firstOrNull()?.timestampMillis ?: System.currentTimeMillis()

        if (!isCourtSms(address, body)) return
        NativeStore.addPending(ctx, address, body, date)
        NativeNotifier.notifyNewSms(ctx)
    }

    private fun isCourtSms(address: String, body: String): Boolean {
        val hasLink = body.contains("http")
        val courtish = body.contains("法院") ||
            address.contains("12368") ||
            body.contains("送达")
        return hasLink && courtish
    }
}
