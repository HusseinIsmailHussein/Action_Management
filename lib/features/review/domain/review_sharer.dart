/// Hands review text to the user (share sheet...). Swap the implementation
/// without touching the review screen.
abstract class ReviewSharer {
  Future<void> shareText({required String subject, required String text});
}
