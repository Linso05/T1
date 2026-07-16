import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_state_store.dart';
import '../data/court_delivery_client.dart';
import '../data/court_document_downloader.dart';
import '../data/court_task_store.dart';
import '../data/court_task_sync_service.dart';
import '../data/sms_importer.dart';
import '../platform/notification_service.dart';
import '../platform/sms_reader.dart';

/// 聚合全部数据层服务，App 启动时一次性异步初始化，再通过 Riverpod 注入。
class AppServices {
  AppServices({
    required this.store,
    required this.appState,
    required this.smsImporter,
    required this.deliveryClient,
    required this.downloader,
    required this.sync,
    required this.smsReader,
    required this.notifications,
  });

  final CourtTaskStore store;
  final AppStateStore appState;
  final SmsImporter smsImporter;
  final CourtDeliveryClient deliveryClient;
  final CourtDocumentDownloader downloader;
  final CourtTaskSyncService sync;
  final SmsReader smsReader;
  final NotificationService notifications;

  static Future<AppServices> create({SmsReader? smsReader}) async {
    final store = await CourtTaskStore.create();
    final appState = await AppStateStore.create();
    final reader = smsReader ?? MethodChannelSmsReader();
    final smsImporter = SmsImporter(store, reader);
    final deliveryClient = CourtDeliveryClient();
    final downloader = CourtDocumentDownloader(store.pdfDir);
    final sync = CourtTaskSyncService(
      store: store,
      smsImporter: smsImporter,
      deliveryClient: deliveryClient,
      downloader: downloader,
    );
    return AppServices(
      store: store,
      appState: appState,
      smsImporter: smsImporter,
      deliveryClient: deliveryClient,
      downloader: downloader,
      sync: sync,
      smsReader: reader,
      notifications: NotificationService(),
    );
  }
}

/// 在 main() 里用 overrideWithValue 注入真实实例。
final appServicesProvider = Provider<AppServices>(
    (ref) => throw UnimplementedError('appServicesProvider 必须在 main 里 override'));
