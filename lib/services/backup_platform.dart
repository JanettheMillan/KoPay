import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_service.dart';

/// Acceso a archivos del teléfono para el respaldo: elegir un CSV y
/// compartir el XLSX.
///
/// Las pruebas reemplazan [instance] por una versión en memoria, porque
/// los selectores del sistema no existen en `flutter test`.
abstract class BackupPlatform {
  static BackupPlatform instance = DeviceBackupPlatform();

  /// Abre el selector y devuelve el contenido del CSV elegido, o `null`
  /// si el usuario lo cierra sin elegir. Lanza [FileTooLargeException]
  /// si pesa más de [BackupService.maxCsvBytes].
  Future<Uint8List?> pickCsv();

  /// Guarda [bytes] como [fileName] y abre la hoja de compartir. Cerrarla
  /// sin compartir no es un error.
  Future<void> shareXlsx(Uint8List bytes, String fileName);
}

class FileTooLargeException implements Exception {
  const FileTooLargeException();
}

/// Implementación real con `file_picker`, `path_provider` y `share_plus`.
class DeviceBackupPlatform implements BackupPlatform {
  @override
  Future<Uint8List?> pickCsv() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null) return null;
    final length = await file.length();
    if (length != null && length > BackupService.maxCsvBytes) {
      throw const FileTooLargeException();
    }
    return file.readAsBytes();
  }

  @override
  Future<void> shareXlsx(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: fileName,
      ),
    );
  }
}
