/// Canonical tag form: no leading '#', lowercase, spaces become '-'.
/// Returns '' for blank input.
String normalizeTag(String raw) => raw
    .trim()
    .replaceFirst(RegExp(r'^#+'), '')
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), '-');
