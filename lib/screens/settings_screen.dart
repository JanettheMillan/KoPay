import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../providers/category_provider.dart';
import '../providers/income_provider.dart';
import '../providers/movement_provider.dart';
import '../providers/settings_provider.dart';
import '../services/backup_platform.dart';
import '../services/backup_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_strings.dart';
import '../utils/format_utils.dart';
import '../widgets/ui_kit.dart';

/// Ajustes: moneda e idioma (HU-24, HU-25), exportar XLSX e importar
/// CSV (HU-26, HU-27) y borrar datos (HU-28).
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

  // ── Respaldo (HU-26, HU-27) ─────────────────────────────────

  /// Base para importar. Las pruebas la inyectan con un
  /// `Provider<DatabaseHelper>`; en la app es la única instancia.
  static DatabaseHelper _database(BuildContext context) =>
      Provider.of<DatabaseHelper?>(context, listen: false) ??
      DatabaseHelper.instance;

  Future<void> _export(BuildContext context) async {
    final s = AppStrings.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final movements = context.read<MovementProvider?>()?.movements ?? const [];
    final incomes = context.read<IncomeProvider?>()?.incomes ?? const [];
    try {
      final bytes = BackupService.buildXlsx(movements, incomes);
      await BackupPlatform.instance.shareXlsx(
        bytes,
        BackupService.fileName(DateTime.now()),
      );
      if (movements.isEmpty && incomes.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(s.exportEmpty)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.exportError)));
    }
  }

  Future<void> _import(BuildContext context) async {
    final s = AppStrings.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final movements = context.read<MovementProvider?>();
    final incomes = context.read<IncomeProvider?>();
    final categories = context.read<CategoryProvider?>();
    final db = _database(context);

    Uint8List? bytes;
    try {
      bytes = await BackupPlatform.instance.pickCsv();
    } on FileTooLargeException {
      messenger.showSnackBar(SnackBar(content: Text(s.importTooLarge)));
      return;
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.importError)));
      return;
    }
    if (bytes == null || !context.mounted) return;

    final result = BackupService.parseCsvBytes(bytes);
    if (!result.isValid) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('import-invalid'),
          backgroundColor: AppColors.surface,
          title: Text(
            s.importInvalidTitle,
            style: TextStyle(color: AppColors.text, fontSize: 17),
          ),
          content: SingleChildScrollView(
            child: Text(
              result.errorSummary(),
              key: const Key('import-errors'),
              style: TextStyle(color: AppColors.text2, fontSize: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(s.close),
            ),
          ],
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          s.importConfirmTitle,
          style: TextStyle(color: AppColors.text, fontSize: 17),
        ),
        content: Text(
          AppStrings.fill(s.importConfirmBody, [
            movements?.movements.length ?? 0,
            incomes?.incomes.length ?? 0,
            result.movements.length,
            result.incomes.length,
          ]),
          key: const Key('import-confirm-body'),
          style: TextStyle(color: AppColors.text2, fontSize: 14),
        ),
        actions: [
          TextButton(
            key: const Key('import-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            key: const Key('import-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(s.replace),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await db.replaceFinancialData(result.movements, result.incomes);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.importError)));
      return;
    }

    // Las categorías nuevas del archivo se agregan al selector; las que
    // ya existen se dejan como están.
    if (categories != null) {
      for (final name in result.categories) {
        if (categories.validate(name) == null) await categories.add(name);
      }
    }
    await movements?.load();
    await incomes?.load();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.fill(s.importDone, [
            result.movements.length,
            result.incomes.length,
          ]),
        ),
      ),
    );
  }

  /// Pide confirmación y borra movimientos, ingresos, tarjetas y deudas
  /// (HU-28). Cancelar no toca nada; si el borrado falla, se avisa y la
  /// transacción deja los datos como estaban.
  Future<void> _deleteData(BuildContext context) async {
    final s = AppStrings.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final db =
        Provider.of<DatabaseHelper?>(context, listen: false) ??
        DatabaseHelper.instance;
    final movements = context.read<MovementProvider?>();
    final incomes = context.read<IncomeProvider?>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          s.deleteDataTitle,
          style: TextStyle(color: AppColors.text, fontSize: 17),
        ),
        content: Text(
          s.deleteDataBody,
          style: TextStyle(color: AppColors.text2, fontSize: 14),
        ),
        actions: [
          TextButton(
            key: const Key('delete-data-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            key: const Key('delete-data-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await db.deleteFinancialData();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.deleteDataError)));
      return;
    }
    // Las listas se vuelven a leer para que Movimientos quede vacío sin
    // reiniciar la app.
    try {
      await movements?.load();
      await incomes?.load();
    } catch (_) {
      // Los datos ya se borraron; la siguiente carga mostrará el vacío.
    }
    messenger.showSnackBar(SnackBar(content: Text(s.dataDeleted)));
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
            _SectionLabel(s.preferences),
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
            const SizedBox(height: 28),
            _SectionLabel(s.dataSection),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _SettingRow(
                    key: const Key('settings-export'),
                    icon: Icons.file_download_outlined,
                    label: s.exportXlsx,
                    value: 'XLSX',
                    onTap: () => _export(context),
                  ),
                  Divider(height: 1, indent: 56, color: AppColors.hair),
                  _SettingRow(
                    key: const Key('settings-import'),
                    icon: Icons.file_upload_outlined,
                    label: s.importCsv,
                    value: 'CSV',
                    onTap: () => _import(context),
                  ),
                  Divider(height: 1, indent: 56, color: AppColors.hair),
                  _SettingRow(
                    key: const Key('settings-delete-data'),
                    icon: Icons.delete_outline_rounded,
                    label: s.deleteData,
                    value: '',
                    color: AppColors.red,
                    onTap: () => _deleteData(context),
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

/// Título pequeño en mayúsculas sobre cada grupo de Ajustes.
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.text3,
          letterSpacing: 1.2,
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

  /// Color de icono y nombre para acciones, por ejemplo la destructiva
  /// en rojo.
  final Color? color;

  const _SettingRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.color,
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
              Icon(icon, color: color ?? AppColors.text2, size: 22),
              const SizedBox(width: 18),
              // Flexible: en pantallas angostas o con letra grande el
              // nombre se recorta en vez de desbordar la fila.
              Flexible(
                flex: 2,
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    color: color ?? AppColors.text,
                  ),
                ),
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
