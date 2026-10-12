/// Hands a backup file to the user (share sheet, download...).
/// Swap the implementation without touching the rest of the feature.
abstract class BackupExporter {
  Future<void> shareFile({required String fileName, required String contents});
}
