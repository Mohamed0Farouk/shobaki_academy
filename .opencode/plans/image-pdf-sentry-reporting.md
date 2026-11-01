# Report image/PDF load failures to Sentry + fix SSL handshake on affected devices

## Context

- This is a **Flutter** app (GetX, Supabase, Syncfusion PDF viewer, sentry_flutter 9.30.0).
- Images (`Image.network` via `ImageUtils.networkWithFallback`, `ZoomableImage`) and PDFs (`SfPdfViewer.network`, `http.Client().get` for downloads) all go through **Dart's `HttpClient`**, which validates TLS strictly.
- Videos use WebView2 / FFmpeg (native TLS stacks) → they work on devices where images/PDFs fail with `HandshakeException` (enterprise proxy / antivirus MITM with private root CA).
- Current working tree (`lib/main.dart`) has an unfinished attempt: `MyHttpOverrides` (trust-all certs) added, Sentry init uncommented — but the **Sentry import is still commented** (won't compile), `HttpOverrides.global` is set **after** `runApp` already started, and `runApp` is called **twice**.
- Image failures are silently swallowed by `errorBuilder` placeholders; PDF failures leave an **infinite loading spinner** (no `onDocumentLoadFailed` handler). Nothing is reported to Sentry anywhere in `lib/`.

**Decisions (user-confirmed):**
1. Trust-all certificate override on **all platforms**.
2. On failure: **keep the graceful placeholder/error UI** and silently report the exception to Sentry (no crash, no retry button).

## Changes

### 1. `lib/main.dart` — fix Sentry init + TLS override ordering
- Uncomment `import 'package:sentry_flutter/sentry_flutter.dart';` (line 9).
- Move `HttpOverrides.global = MyHttpOverrides();` to **right after** `WidgetsFlutterBinding.ensureInitialized()` — before Supabase/DotEnv/any HTTP client is created. Keep the existing `MyHttpOverrides` trust-all class as-is.
- Remove the second `runApp(const MyApp())` (line 79) — only the `appRunner` inside `SentryFlutter.init` runs the app.
- Keep DSN + `sendDefaultPii`; add `options.environment = kReleaseMode ? 'production' : 'debug';` so events are filterable.

### 2. New `lib/utils/media_error_reporter.dart` — central reporter
- `MediaLoadException` (wraps cause + url + mediaType) so the URL appears in the Sentry event title/body.
- `reportMediaLoadError(Object error, StackTrace? stackTrace, {required String url, required String mediaType})`:
  - In-memory `Set<String>` dedupe per session (same broken thumbnail on many cards → one event).
  - `Sentry.captureException(MediaLoadException(...), stackTrace: stackTrace)`.
  - Wrap in try/catch so reporting never breaks the UI.

### 3. `lib/utils/image_utils.dart` — report in every `errorBuilder`
- `networkWithFallback` errorBuilder (line 26): call reporter (`mediaType: 'image'`), then show existing `_errorPlaceholder`.
- `avatar` errorBuilder (line 118): call reporter (`mediaType: 'avatar'`).
- `cachedNetworkImage` errorBuilder (line 164): call reporter (`mediaType: 'image'`).

### 4. `lib/model/widgets/zoomable_image.dart`
- PhotoView `errorBuilder` (line 55): call reporter (`mediaType: 'zoomable_image'`), keep existing error UI. (Thumbnail already goes through `ImageUtils` → covered.)

### 5. `lib/model/pdf_model.dart` — add `onDocumentLoadFailed` + error state
- Add `onDocumentLoadFailed` to `SfPdfViewer.network` → report (`mediaType: 'pdf'`) with `details.error` / `details.stackTrace`.
- Add `_loadFailed` RxBool: on failure set it, clear `_isLoadingPdf` → replace the infinite spinner with a simple error placeholder (icon + "تعذر تحميل الملف"). No retry button (per decision).

### 6. `lib/controller/book_controller.dart`
- In `downloadPdf` catch (line 50): call reporter (`mediaType: 'pdf_download'`, `url: url`) before showing the existing snackbar.

## Verification
- `flutter analyze` — no new errors (current tree won't compile until the import is restored; this fixes it).
- `flutter build windows --debug` (or `flutter build apk --debug`) to confirm the app compiles end-to-end.
- Manual smoke check: open a book PDF and a card grid; if a URL is unreachable, the placeholder appears and a `MediaLoadException` event shows up in Sentry (test in debug environment).

## Notes / out of scope
- `lib/model/card_model.dart:120` builds `PdfModel()` with no URL (falls back to a w3.org dummy PDF) — separate pre-existing bug, not touched here.
- The trust-all override is intentionally insecure (user decision); it disables certificate validation app-wide, including API traffic.
