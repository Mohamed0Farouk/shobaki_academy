/// Pure helpers for the per-platform forced-update check.
///
/// `application_manfist.platforms_versions` is a jsonb map keyed by platform
/// (`Platform.operatingSystem`), each entry carrying the version that platform
/// is required to be on and an optional multi-line changelog. Everything
/// parseable lives here so it can be tested without a Flutter binding.
library;

/// Parses a platform key lookup, tolerating case differences: the column is
/// hand-edited, so `Windows` vs `windows` must not silently disable the
/// update check.
String _canonicalPlatformKey(String platform) => platform.trim().toLowerCase();

/// Whether the installed [current] version satisfies the [required] platform
/// version, i.e. `current >= required`.
///
/// Segments are compared numerically after padding the shorter list with
/// zeros (`1.2` equals `1.2.0`). Anything unparsable counts as satisfying the
/// requirement, because a malformed dashboard value must never lock students
/// out of the app.
bool isVersionAtLeast(String current, String required) {
  try {
    final currentParts = current.split('.').map(int.parse).toList();
    final requiredParts = required.split('.').map(int.parse).toList();

    while (currentParts.length < requiredParts.length) {
      currentParts.add(0);
    }
    while (requiredParts.length < currentParts.length) {
      requiredParts.add(0);
    }

    for (var i = 0; i < currentParts.length; i++) {
      if (currentParts[i] > requiredParts[i]) return true;
      if (currentParts[i] < requiredParts[i]) return false;
    }
    return true;
  } catch (_) {
    return true;
  }
}

/// The forced-update data for a single platform inside
/// `application_manfist.platforms_versions`.
class PlatformVersionEntry {
  const PlatformVersionEntry({required this.version, this.whatsNew});

  /// The version this platform is required to run.
  final String version;

  /// Multi-line "what's new" text shown under the (fixed) update message.
  /// Null when the dashboard has not filled one in for this platform.
  final String? whatsNew;
}

/// Extracts this platform's entry from the `platforms_versions` jsonb map.
///
/// Returns `null` when the column is missing/not a map, the platform has no
/// entry, or the entry has no usable version - in every one of those cases
/// there is nothing to force.
PlatformVersionEntry? parsePlatformVersionEntry(
  Object? raw, {
  required String platform,
}) {
  if (raw is! Map) return null;

  final wanted = _canonicalPlatformKey(platform);
  for (final candidate in raw.entries) {
    if (candidate.key is! String) continue;
    if (_canonicalPlatformKey(candidate.key as String) != wanted) continue;
    if (candidate.value is! Map) return null;

    final entry = candidate.value as Map;
    final version = entry['version']?.toString().trim() ?? '';
    if (version.isEmpty) return null;

    final whatsNew = entry['whats_new']?.toString().trim() ?? '';
    return PlatformVersionEntry(
      version: version,
      whatsNew: whatsNew.isEmpty ? null : whatsNew,
    );
  }
  return null;
}
