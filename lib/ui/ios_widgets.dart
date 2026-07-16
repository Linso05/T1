import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_state_store.dart';
import '../state/app_services.dart';
import 'formatters.dart' show FocusedTagStyle;

class IosPalette {
  IosPalette._();

  static const bg = Color(0xFFF2F2F7);
  static const secondaryBg = Color(0xFFFFFFFF);
  static const grouped = Color(0xFFF9F9FB);
  static const separator = Color(0xFFE5E5EA);
  static const label = Color(0xFF111111);
  static const secondaryLabel = Color(0xFF6E6E73);
  static const tertiaryLabel = Color(0xFFAEAEB2);
  static const blue = CupertinoColors.systemBlue;
  static const red = CupertinoColors.systemRed;
  static const orange = CupertinoColors.systemOrange;
  static const redBg = Color(0xFFFFF1F0);
  static const orangeBg = Color(0xFFFFF7E8);
}

Text iosNavTitle(String text) {
  return Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      inherit: false,
      fontFamily: 'CupertinoSystemText',
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: IosPalette.label,
      decoration: TextDecoration.none,
    ),
  );
}

enum IosDisplayDensity {
  compact('小', 0.90, 0.88),
  regular('中', 1.0, 1.0),
  comfortable('大', 1.10, 1.14);

  const IosDisplayDensity(this.label, this.textScale, this.spaceScale);
  final String label;
  final double textScale;
  final double spaceScale;

  static IosDisplayDensity fromCode(String code) =>
      IosDisplayDensity.values.firstWhere(
        (e) => e.name == code,
        orElse: () => IosDisplayDensity.regular,
      );
}

class IosDensityController extends Notifier<IosDisplayDensity> {
  @override
  IosDisplayDensity build() {
    Future.microtask(_load);
    return IosDisplayDensity.regular;
  }

  Future<void> _load() async {
    final store = ref.read(appServicesProvider).appState;
    final code = await store.getString(
      AppStateKeys.displayDensity,
      IosDisplayDensity.regular.name,
    );
    state = IosDisplayDensity.fromCode(code);
  }

  Future<void> setDensity(IosDisplayDensity density) async {
    state = density;
    await ref
        .read(appServicesProvider)
        .appState
        .putString(AppStateKeys.displayDensity, density.name);
  }
}

final iosDensityProvider =
    NotifierProvider<IosDensityController, IosDisplayDensity>(
        IosDensityController.new);

extension IosDensityX on WidgetRef {
  IosDisplayDensity get iosDensity => watch(iosDensityProvider);
}

double iosFont(WidgetRef ref, double size) =>
    size * ref.watch(iosDensityProvider).textScale;

double iosSpace(WidgetRef ref, double size) =>
    size * ref.watch(iosDensityProvider).spaceScale;

class IosSection extends StatelessWidget {
  const IosSection({
    super.key,
    this.header,
    required this.children,
  });

  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      backgroundColor: IosPalette.bg,
      header: header == null
          ? null
          : Text(
              header!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: IosPalette.secondaryLabel,
              ),
            ),
      children: children,
    );
  }
}

class IosActionRow extends StatelessWidget {
  const IosActionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final titleColor = destructive ? IosPalette.red : IosPalette.label;
    return CupertinoListTile.notched(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: IosPalette.secondaryLabel,
              ),
            ),
      trailing: trailing ??
          (onTap == null
              ? null
              : const CupertinoListTileChevron()),
      onTap: onTap,
    );
  }
}

class IosChip extends StatelessWidget {
  const IosChip({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: const Size(30, 30),
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? IosPalette.blue : IosPalette.secondaryBg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? IosPalette.blue : IosPalette.separator,
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? CupertinoColors.white : IosPalette.secondaryLabel,
          ),
        ),
      ),
    );
  }
}

class IosTag extends StatelessWidget {
  const IosTag(this.text, {super.key, this.style = FocusedTagStyle.normal});

  final String text;
  final FocusedTagStyle style;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (style) {
      FocusedTagStyle.solid => (IosPalette.blue, CupertinoColors.white),
      FocusedTagStyle.danger => (IosPalette.redBg, IosPalette.red),
      FocusedTagStyle.amber => (IosPalette.orangeBg, IosPalette.orange),
      FocusedTagStyle.muted => (IosPalette.grouped, IosPalette.tertiaryLabel),
      FocusedTagStyle.normal => (IosPalette.grouped, IosPalette.secondaryLabel),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class IosEmptyState extends StatelessWidget {
  const IosEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = CupertinoIcons.tray,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: IosPalette.tertiaryLabel),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: IosPalette.secondaryLabel,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: IosPalette.tertiaryLabel,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> showIosConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  bool destructive = false,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result == true;
}
