package top.linso.t1

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build

/** 原生侧通知：app 被杀/重启时也能提醒收到法院短信。 */
object NativeNotifier {
    private const val CHANNEL_ID = "t1_new_sms"
    private const val NOTIF_ID = 4201

    fun notifyNewSms(context: Context) {
        val nm =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "法院短信提醒",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = "收到疑似法院送达短信时提醒" }
            nm.createNotificationChannel(channel)
        }

        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pending = PendingIntent.getActivity(
            context,
            0,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("收到新的法院送达短信")
            .setContentText("点按打开 T1 处理")
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        nm.notify(NOTIF_ID, notification)
    }
}
