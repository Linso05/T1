import 'package:flutter/cupertino.dart';

import 'fp/fp_tokens.dart';
import 'fp/fp_widgets.dart';
import 'fp/fp_transitions.dart';

/// 法律文本（端口 L2 `LegalDialogs.kt`）。
enum LegalDoc {
  userAgreement('用户协议', '使用规则、责任边界和服务说明', _userAgreement),
  privacy('隐私政策', '个人信息处理、权限和第三方服务说明', kPrivacyPolicyText),
  permission('权限说明', '短信、通知、网络和图片选择用途', _permission),
  thirdParty('第三方 SDK 清单', '当前接入的第三方组件和用途', _thirdParty);

  const LegalDoc(this.title, this.summary, this.body);
  final String title;
  final String summary;
  final String body;
}

/// 弹出文档选择（关于/法律），点选后全屏查看。
void showLegalDocs(BuildContext context) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('用户协议 · 隐私政策'),
      actions: [
        for (final d in LegalDoc.values)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                fpSharedAxisRoute((_) => LegalDocPage(doc: d)),
              );
            },
            child: Text(d.title),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('取消'),
      ),
    ),
  );
}

class LegalDocPage extends StatelessWidget {
  const LegalDocPage({super.key, required this.doc});
  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    return FpScreen(
      bottom: true,
      child: Column(
        children: [
          FpBackBar(label: doc.title, onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: Text(
                doc.body,
                style: const TextStyle(
                  inherit: false,
                  fontFamily: 'CupertinoSystemText',
                  fontSize: 13.5,
                  height: 1.7,
                  color: FpColors.ink2,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const String _userAgreement = '''T1 用户协议

更新日期：2026-06-07
生效日期：2026-06-07

一、服务说明
T1 是面向律师工作场景的本机工具，用于法院短信送达任务整理、法院文书链接解析、PDF 文书查看、待办提醒和 AI 辅助问答。

二、使用规则
1. 你应确保导入、解析、查看和发送给 AI 的案件材料来源合法，并已取得必要授权。
2. 你应自行核对法院短信、法院网页、PDF 文书、案件材料和 AI 返回内容，不应仅依赖 T1 的解析结果作出办案决定。
3. 你不得使用 T1 从事侵害他人合法权益、违反法律法规或绕过平台限制的行为。

三、AI 辅助说明
T1 的 AI 功能仅用于材料整理、文字辅助和办案参考，不构成法律意见、代理意见或最终结论。案件判断应以原始文书、法律规定、证据材料和律师专业判断为准。

四、数据与风险
T1 会在本机保存任务、PDF、头像和设置。你应妥善管理手机、系统账号、备份、截图、复制内容和第三方输入法环境，避免案件材料泄露。

五、服务变更
T1 可能因功能升级、第三方 SDK 变更、应用市场审核要求或法规政策变化调整功能与协议内容。重要变更会在应用内提示。

六、联系我们
如需反馈问题，请通过应用发布页面或项目维护渠道联系开发者。''';

/// 完整隐私政策（端口 L2 `T1_PRIVACY_POLICY_TEXT`）。
/// 首启隐私门槛与设置法律弹窗共用。
const String kPrivacyPolicyText = '''T1 隐私政策

更新日期：2026-06-23
生效日期：2026-06-23

T1 是律师工作台工具，用于法院短信送达任务整理、法院文书链接解析、PDF 文书查看、待办提醒和 AI 辅助问答。

一、我们处理的信息
1. 短信信息：在你授权后，T1 会读取和监听本机短信，用于识别 12368 或法院相关短信，生成送达任务、审核任务和其他待办。
2. 法院送达链接参数：当短信或手动输入的链接包含 qdbh、sdbh、sdsin 时，T1 会调用法院送达接口获取文书列表。
3. 文书和 PDF：你下载或系统自动解析传票时，PDF 会保存在本机 App 私有目录，用于查看和提取传票中的案号、被传唤人、应到时间、应到处所等信息。
4. 头像和设置：你自定义的头像、短信监听开关、显示大小、筛选设置、隐私政策同意状态等会保存在本机。
5. AI 问答内容：你主动向 AI 提问时，问题内容以及你选择发送的任务摘要会发送到你配置的 AI 服务，用于生成回答。
6. 软件更新信息：T1 通过你配置的更新清单地址检测版本、下载更新包并展示更新提示，过程中会读取设备、网络和应用版本相关信息以完成更新检测。
7. 文件下载与存储：你下载的法院文书、传票 PDF 以及软件更新包保存在本机 App 私有目录，用于本机查看与安装。

二、权限使用说明
1. 读取短信权限：用于补扫历史法院短信并生成任务。
2. 接收短信权限：用于在新短信到达时自动生成任务（含 app 在后台/被杀时的捕获提醒）。
3. 通知权限：用于在存在未处理任务或收到法院短信时显示提醒。
4. 网络权限：用于法院送达接口解析、PDF 下载、AI 问答和软件更新。
5. 安装应用权限：仅用于软件更新包下载完成后跳转系统安装确认页；是否安装由你在系统界面确认。
6. 图片选择：仅在你自定义头像时使用，头像保存在本机 App 私有目录。

三、信息保存与共享
1. 法院任务、短信摘要和设置默认保存在本机 App 私有数据库中；PDF 和头像保存在本机 App 私有目录。
2. T1 不会主动将本机保存的法院任务、短信正文或 PDF 上传到任何服务器。
3. 以下场景会发生必要的网络传输：法院链接解析、PDF 下载、AI 问答、软件更新检测。
4. AI 问答内容由你主动发起；发起前请自行确认不包含不应提交的敏感材料。

四、你的控制权
1. 你可以在设置中关闭短信监听。
2. 你可以在设置中「清除数据并退出」，清空本地任务、PDF、头像和设置。
3. 你可以不授权短信/文件权限；未授权时相应功能不可用，但不影响其它功能。
4. 你可以不使用 AI 问答；不主动提问时，不会发送 AI 问答内容。

五、安全说明
请注意，手机系统备份、截图、复制、分享、Root、调试环境或第三方输入法可能带来额外风险，请自行管理设备安全。

六、未成年人
T1 面向律师或办案辅助场景，不面向未成年人提供专门服务。

七、政策更新
如隐私政策发生重要变化，T1 会在应用内提示你重新阅读并确认。

八、联系我们
如需反馈隐私相关问题，请通过应用发布页面或项目维护渠道联系开发者。''';

const String _permission = '''T1 权限说明

1. 读取短信
用途：补扫历史 12368 或法院相关短信，生成送达、审核和其他待办。
触发：开启短信监听、首次同步或下拉刷新时。

2. 接收短信
用途：新短信到达时自动识别法院短信并生成任务。
触发：系统收到短信广播时。

3. 通知
用途：存在未处理任务时显示常驻提醒；收到重点文书时提示用户处理。
触发：任务状态变化、后台补扫或新短信生成任务后。

4. 网络
用途：解析法院送达链接、下载 PDF 文书、调用 AI 问答、检测和下载软件更新。
触发：用户解析链接、后台处理法院短信、用户提问 AI、用户或系统检测更新时。

5. 图片选择
用途：设置自定义头像。
触发：用户在设置中点击头像并选择图片时。

6. 安装应用
用途：软件更新包下载完成后，按系统流程安装新版本。
触发：用户确认安装更新包时。''';

const String _thirdParty = '''T1 第三方 SDK 清单

1. AI 服务接口
用途：根据用户主动提交的问题或任务摘要生成辅助回答。
可能处理的信息：用户输入内容、用户主动发送的任务摘要、接口请求状态。
说明：不主动上传本地任务或 PDF；只有用户提问或点击「问 AI」时才发送相关文本。

2. 软件自助更新
用途：版本检测、更新包下载与安装流程。
可能处理的信息：设备、网络状态、应用版本、下载状态等更新所需信息。

如后续接入企业微信、钉钉、微信或统计分析 SDK，应在发布前同步更新本清单、隐私政策和应用市场材料。''';
