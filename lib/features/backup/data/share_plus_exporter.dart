import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../domain/backup_exporter.dart';

/// Opens the system share sheet with the backup as a .json file.
class SharePlusExporter implements BackupExporter {
  @override
  Future<void> shareFile({required String fileName, required String contents}) async {
    final bytes = Uint8List.fromList(utf8.encode(contents));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/json', name: fileName)],
        fileNameOverrides: [fileName],
        subject: 'TickApp backup',
      ),
    );
  }
}
