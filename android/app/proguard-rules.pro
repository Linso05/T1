# 自定义混淆字典：用 obf.txt 里的词表替换 R8 默认的 a/b/c 命名，
# 类名/方法字段名/包名都用它，逆向阅读难度更高。文件在 android/app/obf.txt。
-obfuscationdictionary obf.txt
-classobfuscationdictionary obf.txt
-packageobfuscationdictionary obf.txt

# 阿里云 EMAS 云发布 / Taobao OneSDK：全程反射调用，R8 会误判为无用类而删除，必须 keep。
-keep class com.taobao.** { *; }
-keep interface com.taobao.** { *; }
-keep class com.alibaba.** { *; }
-keep interface com.alibaba.** { *; }
-keep class com.aliyun.** { *; }
-keep class com.ta.utdid2.** { *; }
-keep class com.ut.** { *; }
-keep class anet.channel.** { *; }
-keep class mtopsdk.** { *; }
-keep class org.android.** { *; }
-keep class android.taobao.** { *; }

-dontwarn com.taobao.**
-dontwarn com.alibaba.**
-dontwarn com.aliyun.**
-dontwarn com.ta.utdid2.**
-dontwarn anet.channel.**
-dontwarn mtopsdk.**
-dontwarn org.android.**
