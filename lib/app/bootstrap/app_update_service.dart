import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  final int latestVersionCode;
  final String downloadUrl;
  final bool isMandatory;

  AppUpdateInfo({
    required this.latestVersionCode,
    required this.downloadUrl,
    required this.isMandatory,
  });
}

class AppUpdateService {
  static const _channel = MethodChannel('com.splitex.in.app/install');

  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('app_version')
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final latestVersionCode = data['latestVersionCode'] as int;
      final downloadUrl = data['downloadUrl'] as String;
      final isMandatory = data['isMandatory'] as bool;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.parse(packageInfo.buildNumber);

      if (latestVersionCode > currentVersionCode) {
        return AppUpdateInfo(
          latestVersionCode: latestVersionCode,
          downloadUrl: downloadUrl,
          isMandatory: isMandatory,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> downloadAndInstall(
    String url,
    void Function(double progress) onProgress,
  ) async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/splitex_update.apk';

    // Delete old file if exists to avoid corruption
    final file = File(filePath);
    if (await file.exists()) await file.delete();

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      followRedirects: true,
      maxRedirects: 5,
    ));

    final response = await dio.download(
      url,
      filePath,
      options: Options(
        followRedirects: true,
        maxRedirects: 5,
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Download failed with status: ${response.statusCode}');
    }

    // Verify file was downloaded
    final downloadedFile = File(filePath);
    if (!await downloadedFile.exists() || await downloadedFile.length() < 1024) {
      throw Exception('Download incomplete or file corrupted');
    }

    await _channel.invokeMethod('installApk', {'filePath': filePath});
  }
}
