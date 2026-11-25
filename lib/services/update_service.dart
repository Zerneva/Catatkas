import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

class UpdateService {
  static const String _repoOwner = 'Zerneva';
  static const String _repoName = 'Catatkas';
  static const String _latestReleaseUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  /// Mengambil versi aplikasi saat ini dari platform.
  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '1.0.0';
    }
  }

  /// Mengecek apakah ada rilis terbaru di GitHub Releases.
  /// Mengembalikan [UpdateInfo] jika ada versi lebih baru, atau `null` jika sudah terbaru / gagal.
  static Future<UpdateInfo?> fetchLatestUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();
      final response = await http
          .get(
            Uri.parse(_latestReleaseUrl),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawTag = (data['tag_name'] as String? ?? '').trim();
      final latestVersion = rawTag.startsWith('v') || rawTag.startsWith('V')
          ? rawTag.substring(1)
          : rawTag;

      if (latestVersion.isEmpty || !_isNewerVersion(currentVersion, latestVersion)) {
        return null;
      }

      // Cari file .apk di assets rilis, fallback ke halaman rilis GitHub
      String downloadUrl = data['html_url'] as String? ??
          'https://github.com/$_repoOwner/$_repoName/releases/latest';
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          final url = asset['browser_download_url'] as String?;
          if (name.endsWith('.apk') && url != null && url.isNotEmpty) {
            downloadUrl = url;
            break;
          }
        }
      }

      final notes = (data['body'] as String? ?? '').trim();

      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        releaseNotes: notes.isEmpty
            ? 'Pembaruan aplikasi Catat Kas tersedia dengan perbaikan dan peningkatan performa.'
            : notes,
        downloadUrl: downloadUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// Membandingkan versi semantik (misal: "1.0.0" vs "1.0.1").
  static bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('+').first.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latestParts = latest.split('+').first.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;

    for (var i = 0; i < maxLen; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final l = i < latestParts.length ? latestParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Mengecek pembaruan dan menampilkan dialog jika tersedia.
  static Future<void> checkForUpdate(
    BuildContext context, {
    bool showNoUpdateMessage = false,
  }) async {
    final update = await fetchLatestUpdate();
    if (!context.mounted) return;

    if (update == null) {
      if (showNoUpdateMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aplikasi Catat Kas sudah versi terbaru.')),
        );
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update_rounded, color: AppColors.secondary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Pembaruan Tersedia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.piutangSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'v${update.currentVersion}  →  v${update.latestVersion}',
                style: const TextStyle(
                  color: AppColors.piutang,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Text(
                  update.releaseNotes,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nanti Saja'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse(update.downloadUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Unduh Pembaruan'),
          ),
        ],
      ),
    );
  }
}
