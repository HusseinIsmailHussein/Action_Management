const kMaxRecentSearches = 8;

/// [current] with [query] moved to the front (case-insensitive duplicates
/// removed), keeping at most [kMaxRecentSearches]. Very short queries are ignored.
List<String> withRecent(List<String> current, String query) {
  final q = query.trim();
  if (q.length < 2) return current;
  return [
    q,
    ...current.where((r) => r.toLowerCase() != q.toLowerCase()),
  ].take(kMaxRecentSearches).toList();
}
