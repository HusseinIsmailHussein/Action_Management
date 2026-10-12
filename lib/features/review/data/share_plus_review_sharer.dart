import 'package:share_plus/share_plus.dart';
import '../domain/review_sharer.dart';

/// Opens the system share sheet with the review as text.
class SharePlusReviewSharer implements ReviewSharer {
  @override
  Future<void> shareText({required String subject, required String text}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}
