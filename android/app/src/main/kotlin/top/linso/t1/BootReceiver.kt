package top.linso.t1

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** 开机/更新后：若有未处理的法院短信队列，重新提醒。 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val ctx = context ?: return
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> {
                if (NativeStore.hasPending(ctx)) NativeNotifier.notifyNewSms(ctx)
            }
        }
    }
}
