// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:googleapis/androidpublisher/v3.dart' as publisher;
import 'package:googleapis_auth/auth_io.dart' as auth;

/// Google Play Release Automation Tool for Deresegn
///
/// This script:
/// 1. Increments the build number (and optionally version name) in pubspec.yaml.
/// 2. Builds a signed release Android App Bundle (AAB).
/// 3. Uploads the .aab to Google Play via the Android Publisher API v3.
///
/// Run:
///   dart run tool/release.dart [options]
///
/// Example:
///   dart run tool/release.dart --track=internal
///   dart run tool/release.dart --bump=patch --track=production
///   dart run tool/release.dart --dry-run
void main(List<String> args) async {
  final config = ReleaseConfig.parse(args);

  if (config.showHelp) {
    ReleaseConfig.printHelp();
    return;
  }

  printHeader('Google Play Release Automation');
  print('Configuration:');
  print('  Track:         ${config.track}');
  print('  Bump Type:     ${config.bumpType}');
  print('  Dry Run:       ${config.dryRun ? "YES (No changes will be committed)" : "NO"}');
  print('  Skip Build:    ${config.skipBuild ? "YES" : "NO"}');
  print('  Skip Upload:   ${config.skipUpload ? "YES" : "NO"}');
  print('  Release Notes: ${config.releaseNotes}');
  print('');

  // 1. Resolve Project Root & Files
  final projectDir = Directory.current;
  final pubspecFile = File('${projectDir.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    printError('pubspec.yaml not found in current directory: ${projectDir.path}');
    exit(1);
  }

  // 2. Resolve Package Name (Application ID)
  final packageName = config.packageNameOverride ?? resolvePackageName(projectDir);
  printSuccess('Package Name: $packageName');

  // 3. Version Bumping
  final currentVersionStr = readPubspecVersion(pubspecFile);
  final parsedVersion = VersionInfo.parse(currentVersionStr);
  final newVersion = parsedVersion.bump(config.bumpType, config.customVersion);

  print('Current Version: ${parsedVersion.raw}');
  if (config.bumpType == BumpType.none && config.customVersion == null) {
    print('Keeping existing version: ${parsedVersion.raw}');
  } else {
    printSuccess('New Version:     ${newVersion.raw}');
  }

  if (!config.dryRun && (config.bumpType != BumpType.none || config.customVersion != null)) {
    updatePubspecVersion(pubspecFile, newVersion.raw);
    printSuccess('Updated pubspec.yaml with version: ${newVersion.raw}');
  }

  // 4. Flutter Build AppBundle
  final aabPath = '${projectDir.path}/build/app/outputs/bundle/release/app-release.aab';
  if (!config.skipBuild) {
    if (config.dryRun) {
      printStep('[DRY RUN] Would execute: flutter build appbundle --release');
    } else {
      printStep('Building Release App Bundle (flutter build appbundle --release)...');
      final buildSuccess = await runFlutterBuild(projectDir);
      if (!buildSuccess) {
        printError('Flutter build failed. Aborting release.');
        exit(1);
      }
      printSuccess('App bundle successfully generated at:\n  $aabPath');
    }
  } else {
    printStep('Skipping build (--skip-build). Using existing bundle.');
  }

  // 5. Upload to Google Play Console
  if (!config.skipUpload) {
    final keyFile = resolveKeyFile(projectDir, config.keyPath);
    if (config.dryRun) {
      if (keyFile == null || !keyFile.existsSync()) {
        printStep('[DRY RUN] Key file: Not found yet (expected at android/play-service-account.json or via --key)');
      } else {
        printSuccess('Key file located: ${keyFile.path}');
      }
      printStep('[DRY RUN] Would upload $aabPath to Google Play (track: ${config.track}).');
      printSuccess('Dry run finished successfully. No files were changed and no builds were uploaded.');
      return;
    }

    if (keyFile == null || !keyFile.existsSync()) {
      printError(
        'Service account key file not found!\n'
        'Please save your Google Cloud service account JSON credentials to:\n'
        '  ${projectDir.path}/android/play-service-account.json\n'
        'or pass --key=<path/to/key.json>.\n\n'
        'See tool/README.md for instructions on generating this key.',
      );
      exit(1);
    }

    final aabFile = File(aabPath);
    if (!aabFile.existsSync()) {
      printError('Bundle file not found at: $aabPath\nRun without --skip-build first.');
      exit(1);
    }

    printStep('Connecting to Google Play Developer API...');
    const maxRetries = 3;
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        await uploadToPlayStore(
          keyFile: keyFile,
          packageName: packageName,
          aabFile: aabFile,
          trackName: config.track,
          versionCode: newVersion.buildNumber,
          releaseName: newVersion.raw,
          releaseNotes: config.releaseNotes,
          isDraft: config.draft,
        );
        break;
      } catch (e) {
        if (attempt >= maxRetries) {
          rethrow;
        }
        printError('Upload attempt $attempt failed ($e). Retrying in 5 seconds...');
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  } else {
    printStep('Skipping upload (--skip-upload).');
  }

  printHeader('Release Process Completed Successfully!');
}

/// Enum for semantic/build version bumping
enum BumpType { build, patch, minor, major, none }

/// Represents version info e.g. 1.0.0+1
class VersionInfo {
  final int major;
  final int minor;
  final int patch;
  final int buildNumber;
  final String raw;

  VersionInfo({
    required this.major,
    required this.minor,
    required this.patch,
    required this.buildNumber,
    required this.raw,
  });

  static VersionInfo parse(String raw) {
    final regex = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$');
    final match = regex.firstMatch(raw.trim());
    if (match == null) {
      throw FormatException('Cannot parse version format: "$raw". Expected format "x.y.z+n"');
    }
    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    final patch = int.parse(match.group(3)!);
    final buildNumber = match.group(4) != null ? int.parse(match.group(4)!) : 1;
    return VersionInfo(
      major: major,
      minor: minor,
      patch: patch,
      buildNumber: buildNumber,
      raw: raw.trim(),
    );
  }

  VersionInfo bump(BumpType type, String? custom) {
    if (custom != null) {
      return VersionInfo.parse(custom);
    }
    switch (type) {
      case BumpType.build:
        final nextBuild = buildNumber + 1;
        return VersionInfo(
          major: major,
          minor: minor,
          patch: patch,
          buildNumber: nextBuild,
          raw: '$major.$minor.$patch+$nextBuild',
        );
      case BumpType.patch:
        final nextPatch = patch + 1;
        final nextBuild = buildNumber + 1;
        return VersionInfo(
          major: major,
          minor: minor,
          patch: nextPatch,
          buildNumber: nextBuild,
          raw: '$major.$minor.$nextPatch+$nextBuild',
        );
      case BumpType.minor:
        final nextMinor = minor + 1;
        final nextBuild = buildNumber + 1;
        return VersionInfo(
          major: major,
          minor: nextMinor,
          patch: 0,
          buildNumber: nextBuild,
          raw: '$major.$nextMinor.0+$nextBuild',
        );
      case BumpType.major:
        final nextMajor = major + 1;
        final nextBuild = buildNumber + 1;
        return VersionInfo(
          major: nextMajor,
          minor: 0,
          patch: 0,
          buildNumber: nextBuild,
          raw: '$nextMajor.0.0+$nextBuild',
        );
      case BumpType.none:
        return this;
    }
  }
}

/// Reads the current version string from pubspec.yaml
String readPubspecVersion(File pubspecFile) {
  final content = pubspecFile.readAsStringSync();
  final versionRegex = RegExp(r'^version:\s*([^\r\n#]+)', multiLine: true);
  final match = versionRegex.firstMatch(content);
  if (match == null) {
    throw StateError('Could not find "version:" in pubspec.yaml');
  }
  return match.group(1)!.trim();
}

/// Updates the version string in pubspec.yaml while keeping all other lines and comments intact
void updatePubspecVersion(File pubspecFile, String newVersion) {
  final content = pubspecFile.readAsStringSync();
  final versionRegex = RegExp(r'^version:\s*[^\r\n#]+', multiLine: true);
  final updatedContent = content.replaceFirst(versionRegex, 'version: $newVersion');
  pubspecFile.writeAsStringSync(updatedContent);
}

/// Resolves the Android package name (applicationId or namespace) from build.gradle.kts or build.gradle
String resolvePackageName(Directory projectDir) {
  final gradleKts = File('${projectDir.path}/android/app/build.gradle.kts');
  final gradleGroovy = File('${projectDir.path}/android/app/build.gradle');

  for (final file in [gradleKts, gradleGroovy]) {
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      // Look for applicationId = "..." or applicationId '...'
      final appIdMatch = RegExp(r'''applicationId\s*=?\s*["']([^"']+)["']''').firstMatch(content);
      if (appIdMatch != null) return appIdMatch.group(1)!;

      // Look for namespace = "..." or namespace '...'
      final nsMatch = RegExp(r'''namespace\s*=?\s*["']([^"']+)["']''').firstMatch(content);
      if (nsMatch != null) return nsMatch.group(1)!;
    }
  }

  // Default fallback for Deresegn
  return 'com.eims.deresegn';
}

/// Resolves the Service Account Key file
File? resolveKeyFile(Directory projectDir, String? specifiedPath) {
  if (specifiedPath != null) {
    final file = File(specifiedPath);
    if (file.existsSync()) return file;
    // Relative to project dir
    final relFile = File('${projectDir.path}/$specifiedPath');
    if (relFile.existsSync()) return relFile;
    return file;
  }

  // Search common default locations
  final candidates = [
    '${projectDir.path}/android/play-service-account.json',
    '${projectDir.path}/play-service-account.json',
    '${projectDir.path}/secrets/play-service-account.json',
    '${projectDir.path}/service-account.json',
    '${projectDir.path}/android/service-account.json',
  ];

  for (final candidate in candidates) {
    final file = File(candidate);
    if (file.existsSync()) return file;
  }
  return null;
}

/// Runs `flutter build appbundle --release`
Future<bool> runFlutterBuild(Directory projectDir) async {
  final isWindows = Platform.isWindows;
  final executable = isWindows ? 'flutter.bat' : 'flutter';

  final process = await Process.start(
    executable,
    ['build', 'appbundle', '--release'],
    workingDirectory: projectDir.path,
    runInShell: true,
  );

  // Stream process output live to console
  process.stdout.transform(utf8.decoder).listen(stdout.write);
  process.stderr.transform(utf8.decoder).listen(stderr.write);

  final exitCode = await process.exitCode;
  return exitCode == 0;
}

/// Uploads the AAB to Google Play Console with live progress
Future<void> uploadToPlayStore({
  required File keyFile,
  required String packageName,
  required File aabFile,
  required String trackName,
  required int versionCode,
  required String releaseName,
  required String releaseNotes,
  required bool isDraft,
}) async {
  final jsonString = keyFile.readAsStringSync();
  final credentials = auth.ServiceAccountCredentials.fromJson(jsonString);

  final fileLength = await aabFile.length();
  final mb = (fileLength / (1024 * 1024)).toStringAsFixed(2);
  printStep('Preparing to upload AAB ($mb MB) to Google Play...');

  final progressBar = _ProgressBar(totalBytes: fileLength);
  final progressClient = _ProgressHttpClient(
    http.Client(),
    progressBar: progressBar,
  );

  final client = await auth.clientViaServiceAccount(
    credentials,
    [publisher.AndroidPublisherApi.androidpublisherScope],
    baseClient: progressClient,
  );

  String? createdEditId;
  try {
    final api = publisher.AndroidPublisherApi(client);

    // 1. Create a new edit
    printStep('Creating Google Play App Edit for "$packageName"...');
    final appEdit = await api.edits.insert(publisher.AppEdit(), packageName);
    final editId = appEdit.id;
    if (editId == null) {
      throw StateError('Failed to create an app edit. Edit ID returned was null.');
    }
    createdEditId = editId;
    printSuccess('Created Edit ID: $editId');

    // 2. Upload the AAB bundle
    printStep('Uploading AAB ($mb MB) to Google Play with real-time progress...');
    final mediaStream = publisher.Media(
      aabFile.openRead(),
      fileLength,
      contentType: 'application/octet-stream',
    );

    final bundle = await api.edits.bundles.upload(
      packageName,
      editId,
      uploadMedia: mediaStream,
      uploadOptions: publisher.ResumableUploadOptions(numberOfAttempts: 5),
    );

    progressBar.complete();

    final uploadedVersionCode = bundle.versionCode ?? versionCode;
    printSuccess('Uploaded AAB successfully! Version Code: $uploadedVersionCode');

    // 3. Assign release to track
    printStep('Assigning release to track "$trackName"...');
    final releaseStatus = isDraft ? 'draft' : 'completed';

    final trackRelease = publisher.TrackRelease(
      name: releaseName,
      versionCodes: ['$uploadedVersionCode'],
      status: releaseStatus,
      releaseNotes: [
        publisher.LocalizedText(
          language: 'en-US',
          text: releaseNotes,
        ),
      ],
    );

    final track = publisher.Track(
      track: trackName,
      releases: [trackRelease],
    );

    await api.edits.tracks.update(track, packageName, editId, trackName);
    printSuccess('Assigned version code $uploadedVersionCode to track "$trackName" (status: $releaseStatus)');

    // 4. Commit edit
    printStep('Committing the edit to Google Play...');
    await api.edits.commit(packageName, editId);
    printSuccess('Google Play edit committed successfully! Release is now live on "$trackName" track.');
  } catch (e) {
    if (createdEditId != null) {
      try {
        final api = publisher.AndroidPublisherApi(client);
        await api.edits.delete(packageName, createdEditId);
      } catch (_) {}
    }
    rethrow;
  } finally {
    client.close();
  }
}

/// HTTP Client that intercepts resumable upload PUT requests to report progress
class _ProgressHttpClient extends http.BaseClient {
  final http.Client _inner;
  final _ProgressBar progressBar;

  _ProgressHttpClient(this._inner, {required this.progressBar});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final contentRange = request.headers['content-range'];
    if (request.method == 'PUT' && contentRange != null) {
      final rangeMatch = RegExp(r'bytes\s+(\d+)-(\d+)').firstMatch(contentRange);
      if (rangeMatch != null) {
        final chunkStart = int.parse(rangeMatch.group(1)!);
        var chunkSent = 0;

        final originalStream = request.finalize();
        final trackedStream = originalStream.transform<List<int>>(
          StreamTransformer.fromHandlers(
            handleData: (chunk, sink) {
              sink.add(chunk);
              chunkSent += chunk.length;
              progressBar.update(chunkStart + chunkSent);
            },
          ),
        );

        final trackedRequest = _StreamRequest(request, trackedStream);
        return _inner.send(trackedRequest);
      }
    }

    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Custom BaseRequest that wraps a transformed byte stream while preserving original headers
class _StreamRequest extends http.BaseRequest {
  final http.ByteStream _byteStream;

  _StreamRequest(http.BaseRequest original, Stream<List<int>> stream)
      : _byteStream = http.ByteStream(stream),
        super(original.method, original.url) {
    headers.addAll(original.headers);
    contentLength = original.contentLength;
    followRedirects = original.followRedirects;
    maxRedirects = original.maxRedirects;
    persistentConnection = original.persistentConnection;
  }

  @override
  http.ByteStream finalize() {
    super.finalize();
    return _byteStream;
  }
}

/// Visual and percentage progress bar tracker
class _ProgressBar {
  final int totalBytes;
  final Stopwatch _stopwatch = Stopwatch();
  DateTime _lastRenderTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastLoggedPercentage = -10;
  final bool _isTerminal;
  bool _isCompleted = false;

  _ProgressBar({required this.totalBytes})
      : _isTerminal = stdout.hasTerminal {
    _stopwatch.start();
  }

  void update(int currentBytes) {
    if (_isCompleted) return;
    if (currentBytes > totalBytes) currentBytes = totalBytes;

    final now = DateTime.now();
    // Throttle interactive terminal renders to ~100ms
    if (_isTerminal &&
        now.difference(_lastRenderTime).inMilliseconds < 100 &&
        currentBytes < totalBytes) {
      return;
    }
    _lastRenderTime = now;

    final elapsedMs = _stopwatch.elapsedMilliseconds;
    final percent = totalBytes > 0 ? (currentBytes / totalBytes) : 0.0;
    final percentInt = (percent * 100).toInt();

    final speedBytesPerSec =
        elapsedMs > 0 ? (currentBytes / (elapsedMs / 1000.0)) : 0.0;
    final speedMb = speedBytesPerSec / (1024 * 1024);

    final remainingBytes = totalBytes - currentBytes;
    final etaSec =
        speedBytesPerSec > 0 ? (remainingBytes / speedBytesPerSec).round() : 0;
    final etaStr = _formatDuration(etaSec);

    final currentMb = (currentBytes / (1024 * 1024)).toStringAsFixed(2);
    final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(2);

    if (_isTerminal) {
      const barWidth = 28;
      final filled = (percent * barWidth).round().clamp(0, barWidth);
      final empty = barWidth - filled;
      final bar = '█' * filled + '░' * empty;
      final percentStr = (percent * 100).toStringAsFixed(1).padLeft(5);

      final line =
          '\r  [$bar] $percentStr% ($currentMb / $totalMb MB) ${speedMb.toStringAsFixed(2)} MB/s, ETA: $etaStr';
      stdout.write(line);
    } else {
      // In non-interactive environment (CI, log files), emit milestone lines
      if (percentInt >= _lastLoggedPercentage + 10 || currentBytes >= totalBytes) {
        _lastLoggedPercentage = (percentInt ~/ 10) * 10;
        final percentStr = (percent * 100).toStringAsFixed(1);
        stdout.writeln(
            '  [Upload Progress] $percentStr% ($currentMb / $totalMb MB) - ${speedMb.toStringAsFixed(2)} MB/s (ETA: $etaStr)');
      }
    }
  }

  void complete() {
    if (_isCompleted) return;
    _isCompleted = true;
    _stopwatch.stop();

    if (_isTerminal) {
      stdout.writeln();
    }

    final elapsedSec = (_stopwatch.elapsedMilliseconds / 1000.0).toStringAsFixed(1);
    final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(2);
    final avgSpeed = (_stopwatch.elapsedMilliseconds > 0)
        ? ((totalBytes / (1024 * 1024)) / (_stopwatch.elapsedMilliseconds / 1000.0)).toStringAsFixed(2)
        : '0.00';
    printSuccess('Uploaded $totalMb MB in ${elapsedSec}s (avg $avgSpeed MB/s)');
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      return '${m}m ${s}s';
    }
    return '${s}s';
  }
}

/// CLI Configuration and Flag Parser
class ReleaseConfig {
  final String track;
  final BumpType bumpType;
  final String? customVersion;
  final String? keyPath;
  final String? packageNameOverride;
  final String releaseNotes;
  final bool dryRun;
  final bool skipBuild;
  final bool skipUpload;
  final bool draft;
  final bool showHelp;

  ReleaseConfig({
    required this.track,
    required this.bumpType,
    required this.customVersion,
    required this.keyPath,
    required this.packageNameOverride,
    required this.releaseNotes,
    required this.dryRun,
    required this.skipBuild,
    required this.skipUpload,
    required this.draft,
    required this.showHelp,
  });

  static ReleaseConfig parse(List<String> args) {
    var track = 'internal';
    var bumpType = BumpType.build;
    String? customVersion;
    String? keyPath;
    String? packageNameOverride;
    var releaseNotes = 'Bug fixes and performance improvements.';
    var dryRun = false;
    var skipBuild = false;
    var skipUpload = false;
    var draft = false;
    var showHelp = false;

    for (final arg in args) {
      if (arg == '--help' || arg == '-h') {
        showHelp = true;
      } else if (arg.startsWith('--track=')) {
        track = arg.substring('--track='.length).trim().toLowerCase();
        if (track == 'closed') track = 'alpha';
        if (track == 'open') track = 'beta';
      } else if (arg.startsWith('--bump=')) {
        final val = arg.substring('--bump='.length).toLowerCase().trim();
        switch (val) {
          case 'patch':
            bumpType = BumpType.patch;
            break;
          case 'minor':
            bumpType = BumpType.minor;
            break;
          case 'major':
            bumpType = BumpType.major;
            break;
          case 'none':
            bumpType = BumpType.none;
            break;
          case 'build':
          default:
            bumpType = BumpType.build;
            break;
        }
      } else if (arg.startsWith('--version=')) {
        customVersion = arg.substring('--version='.length).trim();
      } else if (arg.startsWith('--key=')) {
        keyPath = arg.substring('--key='.length).trim();
      } else if (arg.startsWith('--package-name=')) {
        packageNameOverride = arg.substring('--package-name='.length).trim();
      } else if (arg.startsWith('--notes=')) {
        releaseNotes = arg.substring('--notes='.length).trim();
      } else if (arg == '--dry-run') {
        dryRun = true;
      } else if (arg == '--skip-build') {
        skipBuild = true;
      } else if (arg == '--skip-upload') {
        skipUpload = true;
      } else if (arg == '--draft') {
        draft = true;
      }
    }

    return ReleaseConfig(
      track: track,
      bumpType: bumpType,
      customVersion: customVersion,
      keyPath: keyPath,
      packageNameOverride: packageNameOverride,
      releaseNotes: releaseNotes,
      dryRun: dryRun,
      skipBuild: skipBuild,
      skipUpload: skipUpload,
      draft: draft,
      showHelp: showHelp,
    );
  }

  static void printHelp() {
    print('''
Google Play Release Automation CLI - Deresegn

USAGE:
  dart run tool/release.dart [OPTIONS]

OPTIONS:
  --track=<track>           Target track: internal (default), alpha, beta, production
  --bump=<type>             Version bump type: build (default), patch, minor, major, none
                            - build: 1.0.0+1 -> 1.0.0+2
                            - patch: 1.0.0+1 -> 1.0.1+2
                            - minor: 1.0.0+1 -> 1.1.0+2
                            - major: 1.0.0+1 -> 2.0.0+2
                            - none:  keeps current version
  --version=<x.y.z+n>       Specify an exact version instead of auto-bumping
  --notes="<text>"          Release notes for this version (default: 'Bug fixes and performance improvements.')
  --key=<path>              Path to Google Cloud Service Account JSON key
                            (default: android/play-service-account.json or play-service-account.json)
  --package-name=<id>       Override Android package name (default: auto-detected from build.gradle)
  --dry-run                 Simulate all steps without modifying pubspec.yaml or uploading to Play Store
  --skip-build              Skip flutter build appbundle and use the existing AAB
  --skip-upload             Only increment version and build the AAB without uploading
  --draft                   Upload as a draft release instead of completing immediately
  -h, --help                Show this help message

EXAMPLES:
  # Internal test release with build number increment:
  dart run tool/release.dart

  # Patch release to production:
  dart run tool/release.dart --bump=patch --track=production --notes="MoR tax invoice updates"

  # Test without uploading:
  dart run tool/release.dart --dry-run
''');
  }
}

// Helpers for formatted console output
void printHeader(String title) {
  print('\n════════════════════════════════════════════════════════════════════');
  print('  $title');
  print('════════════════════════════════════════════════════════════════════\n');
}

void printStep(String step) {
  print('🔵 $step');
}

void printSuccess(String message) {
  print('✅ $message');
}

void printError(String error) {
  print('\n❌ ERROR: $error\n');
}
