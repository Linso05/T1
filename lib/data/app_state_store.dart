import 't1_database.dart';

/// 设置 key/value 存储封装，对照 Kotlin `data/AppStateStore.kt`。
class AppStateStore {
  AppStateStore(this._db);
  final T1Database _db;

  static Future<AppStateStore> create() async =>
      AppStateStore(await T1Database.instance());

  Future<String> getString(String key, [String defaultValue = '']) =>
      _db.getString(key, defaultValue);
  Future<void> putString(String key, String value) =>
      _db.putString(key, value);
  Future<bool> getBoolean(String key, [bool defaultValue = false]) =>
      _db.getBoolean(key, defaultValue);
  Future<void> putBoolean(String key, bool value) =>
      _db.putBoolean(key, value);
  Future<void> clear() => _db.clearAppState();
}

/// 设置项 key 常量（与 L2 保持一致，便于将来数据互通）。
class AppStateKeys {
  AppStateKeys._();
  static const smsMonitoringEnabled = 'sms_monitoring_enabled';
  static const lawyerName = 'lawyer_name';
  static const privacyAccepted = 'privacy_policy_accepted';
  static const privacyVersion = 'privacy_policy_version';
  static const permissionsOnboarded = 'permissions_onboarded';
  static const workbenchOpenMode = 'workbench_open_mode';
  static const displayDensity = 'display_density';
  static const avatarPath = 'avatar_path';
  // 高级配置（凭据，仅存本地，不进仓库）
  static const aiEndpoint = 'ai_endpoint';
  static const aiModel = 'ai_model';
  static const aiApiKey = 'ai_api_key';
  static const updateManifestUrl = 'update_manifest_url';
}

/// 高级配置默认值（与 L2 BuildConfig 默认一致）。
class AppConfigDefaults {
  AppConfigDefaults._();
  static const aiEndpoint = 'https://api.fengying.xin/v1/responses';
  static const aiModel = 'gpt-5.5';
}
