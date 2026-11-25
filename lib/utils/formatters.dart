import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _idrFormat = NumberFormat.decimalPattern('id_ID');

  static String rupiah(
    int amount, {
    bool masked = false,
    bool showPlus = false,
    bool showMinus = false,
    bool compact = false,
  }) {
    if (masked) {
      return 'Rp •••••••';
    }
    final absVal = amount.abs();
    String prefix = '';
    if (showPlus && amount > 0) prefix = '+ ';
    if (showMinus && amount < 0) prefix = '- ';

    if (compact) {
      if (absVal >= 1000000) {
        final millions = absVal / 1000000;
        final formatted = millions.toStringAsFixed(millions % 1 == 0 ? 0 : 2).replaceAll('.', ',');
        return '${prefix}Rp ${formatted}Jt';
      }
      if (absVal >= 1000) {
        final thousands = (absVal / 1000).round();
        return '${prefix}Rp ${thousands}rb';
      }
    }

    return '${prefix}Rp ${_idrFormat.format(absVal)}';
  }

  static String rupiahSigned(int amount, {bool masked = false}) {
    if (masked) return 'Rp •••••••';
    if (amount > 0) return '+ Rp ${_idrFormat.format(amount)}';
    if (amount < 0) return '- Rp ${_idrFormat.format(amount.abs())}';
    return 'Rp 0';
  }

  /// Plain number string without Rp prefix, for text field display.
  static String rupiahPlain(int amount) {
    if (amount <= 0) return '';
    return _idrFormat.format(amount);
  }

  static const _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static const _monthsLong = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  static const _daysLong = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];

  static String shortDate(DateTime dt) {
    return '${dt.day} ${_monthsShort[dt.month - 1]} ${dt.year}';
  }

  static String dayMonth(DateTime dt) {
    return '${dt.day} ${_monthsShort[dt.month - 1]}';
  }

  static String fullIndonesianDate(DateTime dt) {
    final dayName = _daysLong[dt.weekday - 1];
    final monthName = _monthsLong[dt.month - 1];
    return '$dayName, ${dt.day} $monthName ${dt.year}';
  }

  static String timeWib(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm WIB';
  }

  static String relativeGroupLabel(DateTime dt, DateTime now) {
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Hari Ini • ${shortDate(dt)}';
    if (diff == 1) return 'Kemarin • ${shortDate(dt)}';
    if (diff <= 7) return 'Minggu Ini • ${shortDate(dt)}';
    return shortDate(dt);
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static Future<bool> launchWhatsApp({
    required String phone,
    required String message,
  }) async {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return false;
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    } else if (digits.startsWith('8')) {
      digits = '62$digits';
    }

    final encodedMsg = Uri.encodeComponent(message);

    // 1. Coba deep link native WhatsApp (whatsapp://send?phone=...&text=...)
    final nativeUri = Uri.parse('whatsapp://send?phone=$digits&text=$encodedMsg');
    try {
      if (await canLaunchUrl(nativeUri)) {
        return await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // 2. Fallback ke URL wa.me
    final webUri = Uri.parse('https://wa.me/$digits?text=$encodedMsg');
    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        return await launchUrl(webUri, mode: LaunchMode.platformDefault);
      } catch (_) {
        return false;
      }
    }
  }
}
