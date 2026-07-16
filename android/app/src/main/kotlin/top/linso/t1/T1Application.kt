package top.linso.t1

import android.app.Application

/**
 * 自定义 Application：进程一启动就 init 阿里云更新 SDK。
 *
 * 关键：SDK 的「发现更新→弹窗」依赖它通过 ActivityLifecycleCallbacks 跟踪到的
 * 「当前前台 Activity」。若 init 拖到第一次点检查（那时 MainActivity 已 resume），
 * SDK 注册的生命周期回调错过了这次 resume → 没有 currentActivity → 把通知挂起，
 * 直到下次 Activity resume（home 再进来）才弹。提前到 onCreate 即可修复。
 */
class T1Application : Application() {
    override fun onCreate() {
        super.onCreate()
        runCatching { AliyunUpdateManager.ensureInit(this) }
    }
}
