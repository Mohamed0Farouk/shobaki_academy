import 'package:sentry_flutter/sentry_flutter.dart';

/// Exception wrapper so the failing media URL and type are visible in the
/// Sentry event title / stack, e.g.:
/// `MediaLoadException(image): https://cdn.example.com/thumb.jpg — HandshakeException`
class MediaLoadException implements Exception {
  final String mediaType;
  final String url;
  final Object cause;

  const MediaLoadException({
    required this.mediaType,
    required this.url,
    required this.cause,
  });

  @override
  String toString() => 'MediaLoadException($mediaType): $url — $cause';
}

/// Session-level dedupe so the same failing URL (e.g. one broken thumbnail
/// reused across many cards) is only reported once.
final Set<String> _reportedMediaKeys = <String>{};

/// Reports a failed image/pdf load to Sentry without ever throwing.
///
/// Call this from `errorBuilder` / `onDocumentLoadFailed` / catch blocks,
/// then show the graceful placeholder UI as usual.
void reportMediaLoadError(
  Object error,
  StackTrace? stackTrace, {
  required String url,
  required String mediaType,
}) {
  final key = '$mediaType|$url';
  if (!_reportedMediaKeys.add(key)) return;

  Sentry.captureException(
    MediaLoadException(mediaType: mediaType, url: url, cause: error),
    stackTrace: stackTrace,
  ).ignore(); // Never let error reporting break the UI.
}
