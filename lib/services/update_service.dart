// lib/services/update_service.dart

import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';

final ApiClient apiClient = ApiClient();

/// Checks for updates and shows a dialog if a new version is available.
/// IMPORTANT: You must pass the BuildContext to show the popup!
Future<void> checkAndUpdate(BuildContext context) async {
  try {
    // 1. Get current app version
    final packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;

    // 2. Fetch server version (Update this URL to your actual PHP file URL)
    final response = await apiClient.get(endpoint: 'getAppVersion.php');

    // 3. Parse the JSON response from your PHP script
    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'];

      String latestVersion = data['latest_version'];
      String apkUrl = data['apk_url'];
      String releaseNotes =
          data['release_notes'] ?? "Bug fixes and performance improvements.";
      bool isMandatory = data['is_mandatory'] ?? false;

      // 4. Compare versions
      if (currentVersion != latestVersion) {
        // Show the update dialog to the user!
        _showUpdateDialog(
          context,
          latestVersion,
          releaseNotes,
          apkUrl,
          isMandatory,
        );
      }
    }
  } catch (e) {
    print("Update check failed: $e");
    // Silently fail so the app still opens normally if the server is down
  }
}

/// Shows a popup dialog with the update details
void _showUpdateDialog(
  BuildContext context,
  String newVersion,
  String notes,
  String apkUrl,
  bool isMandatory,
) {
  showDialog(
    context: context,
    barrierDismissible:
        !isMandatory, // If mandatory, user CANNOT close it by tapping outside
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text("New Update Available"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Version: $newVersion",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "What's new:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(notes),
          ],
        ),
        actions: [
          // Only show the "Later" button if the update is NOT mandatory
          if (!isMandatory)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Later"),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Close the info dialog
              _downloadAndInstall(context, apkUrl); // Start downloading
            },
            child: const Text("Update Now"),
          ),
        ],
      );
    },
  );
}

/// Downloads the APK and triggers the Android installer
Future<void> _downloadAndInstall(BuildContext context, String url) async {
  // 1. Show a loading screen while the APK downloads
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Downloading update..."),
          ],
        ),
      );
    },
  );

  try {
    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/update.apk';

    // 2. Download the APK
    await Dio().download(url, savePath);

    // 3. Close the loading dialog
    if (context.mounted) Navigator.of(context).pop();

    // 4. Trigger Android Installer
    OpenFile.open(savePath, type: "application/vnd.android.package-archive");
  } catch (e) {
    // Close loading dialog if it's still open
    if (context.mounted) Navigator.of(context).pop();

    // Show an error message to the user
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed. Please try again.")),
      );
    }
  }
}
