import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import '../widgets/ui_kit.dart';

/// Ajustes: moneda e idioma (HU-24, HU-25).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _chooseCurrency(BuildContext context) async {
    final settings = context.read<SettingsProvider?>();
    if (settings == null) return;
    final s = AppStrings.read(context);
    final picked = await showKopaySheet<String>(
      context,
      _OptionSheet(
        title: s.currency,
        keyPrefix: 'currency',
        selected: settings.currency,
        options: {
          for (final code in FormatUtils.currencySymbols.keys)
            code:
                '${FormatUtils.currencySymbols[code]}  $code · '
                '${s.currencyNames[code]}',
        },
      ),
    );
    if (picked == null || !context.mounted) return;
    await _save(context, () => settings.setCurrency(picked));
  }

  Future<void> _chooseLanguage(BuildContext context) async {
    final settings = context.read<SettingsProvider?>();
    if (settings == null) return;
    final s = AppStrings.read(context);
    final picked = await showKopaySheet<String>(
      context,
      _OptionSheet(
        title: s.language,
        keyPrefix: 'language',
        selected: settings.language,
        options: {
          for (final code in FormatUtils.languages)
            code: s.languageNames[code]!,
        },
      ),
    );
    if (picked == null || !context.mounted) return;
    await _save(context, () => settings.setLanguage(picked));
  }

  Future<void> _save(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = AppStrings.read(context).settingsSaveError;
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final settings = context.watch<SettingsProvider?>();
    final currency = settings?.currency ?? FormatUtils.currency;
    final language = settings?.language ?? FormatUtils.language;

    return ColoredBox(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              s.settingsTitle,
              key: const Key('settings-title'),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                s.preferences,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text3,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _SettingRow(
                    key: const Key('settings-currency'),
                    icon: Icons.payments_outlined,
                    label: s.currency,
                    value: '${FormatUtils.currencySymbols[currency]} $currency',
                    onTap: () => _chooseCurrency(context),
                  ),
                  Divider(height: 1, indent: 56, color: AppColors.hair),
                  _SettingRow(
                    key: const Key('settings-language'),
                    icon: Icons.language_rounded,
                    label: s.language,
                    value: s.languageNames[language]!,
                    onTap: () => _chooseLanguage(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.text2, size: 22),
              const SizedBox(width: 18),
              Text(
                label,
                style: TextStyle(fontSize: 15, color: AppColors.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: AppColors.text2),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.text3,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista de opciones con la elegida marcada; devuelve el código tocado.
class _OptionSheet extends StatelessWidget {
  final String title;
  final String keyPrefix;
  final String selected;
  final Map<String, String> options;

  const _OptionSheet({
    required this.title,
    required this.keyPrefix,
    required this.selected,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return KopaySheet(
      title: title,
      child: Column(
        children: [
          for (final entry in options.entries)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('$keyPrefix-${entry.key}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(entry.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 15,
                            color: entry.key == selected
                                ? AppColors.green
                                : AppColors.text,
                          ),
                        ),
                      ),
                      if (entry.key == selected)
                        Icon(
                          Icons.check_rounded,
                          color: AppColors.green,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
