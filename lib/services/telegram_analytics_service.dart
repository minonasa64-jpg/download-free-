import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

/// خدمة ربط إحصائيات وتنبيهات تطبيق Boykta مع بوت تيليجرام
class TelegramAnalyticsService {
  static final TelegramAnalyticsService _instance = TelegramAnalyticsService._internal();
  factory TelegramAnalyticsService() => _instance;
  TelegramAnalyticsService._internal();

  // بيانات البوت والمسؤول
  static const String botToken = '8992827519:AAHGaDQSoSQU0h6GIsxQBdmS_iFmc5J7qKs';
  static const String adminChatId = '8262706717';
  static const String appVersion = '1.4.2';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  String? _cachedDeviceId;

  /// الحصول على معرّف الجهاز الفريد والمحفوظ محلياً
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString('telegram_device_id');
      if (id == null || id.isEmpty) {
        final random = Random.secure();
        final values = List<int>.generate(8, (i) => random.nextInt(256));
        id = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        await prefs.setString('telegram_device_id', id);
      }
      _cachedDeviceId = id;
      return id;
    } catch (_) {
      return 'dev_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
    }
  }

  /// إرسال رسالة HTML مباشرة إلى البوت وتيليجرام بأمان تام دون تعطيل التطبيق
  Future<bool> sendMessage(String textHtml) async {
    try {
      final url = 'https://api.telegram.org/bot$botToken/sendMessage';
      final response = await _dio.post(
        url,
        data: {
          'chat_id': adminChatId,
          'text': textHtml,
          'parse_mode': 'HTML',
          'disable_web_page_preview': true,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Telegram Notification Silent Skip: $e');
      return false;
    }
  }

  /// فحص وتسجيل فتح التطبيق (مستخدم جديد أول مرة + مستخدم نشط يومياً)
  Future<void> reportAppOpen({String? lang}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await getDeviceId();
      final isFirstInstall = prefs.getBool('tg_is_first_install') ?? true;
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final lastReportedDate = prefs.getString('tg_last_active_date');
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      String osInfo = Platform.operatingSystem;
      try {
        osInfo = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      } catch (_) {}

      // 1. إذا كان تثبيت جديد لأول مرة
      if (isFirstInstall) {
        await prefs.setBool('tg_is_first_install', false);
        await prefs.setString('tg_last_active_date', todayStr);

        final message = StringBuffer()
          ..writeln('🎉 <b>مستخدم جديد قام بتثبيت تطبيق Boykta!</b>')
          ..writeln('━━━━━━━━━━━━━━━━━━━━')
          ..writeln('🆔 <b>معرّف المستخدم:</b> <code>$deviceId</code>')
          ..writeln('📱 <b>نظام التشغيل:</b> $osInfo')
          ..writeln('🌐 <b>اللغة:</b> ${lang ?? "العربية"}')
          ..writeln('🚀 <b>إصدار التطبيق:</b> v$appVersion')
          ..writeln('📅 <b>التاريخ:</b> $todayStr $timeStr')
          ..writeln('━━━━━━━━━━━━━━━━━━━━')
          ..write('✨ <i>إحصائية فورية من تطبيق Boykta Pro</i>');

        await sendMessage(message.toString());
      } 
      // 2. إذا كان مستخدم نشط فتح التطبيق اليوم لأول مرة
      else if (lastReportedDate != todayStr) {
        await prefs.setString('tg_last_active_date', todayStr);

        final message = StringBuffer()
          ..writeln('👤 <b>مستخدم نشط اليوم (Daily Active User)</b>')
          ..writeln('━━━━━━━━━━━━━━━━━━━━')
          ..writeln('🆔 <b>معرّف المستخدم:</b> <code>$deviceId</code>')
          ..writeln('📱 <b>النظام:</b> $osInfo')
          ..writeln('🌐 <b>اللغة:</b> ${lang ?? "العربية"}')
          ..writeln('🚀 <b>إصدار التطبيق:</b> v$appVersion')
          ..writeln('📅 <b>التاريخ:</b> $todayStr $timeStr')
          ..writeln('━━━━━━━━━━━━━━━━━━━━')
          ..write('✨ <i>إحصائيات الاستخدام اليومي</i>');

        await sendMessage(message.toString());
      }
    } catch (e) {
      debugPrint('Telegram reportAppOpen error: $e');
    }
  }

  /// إرسال إشعار عند إتمام تنزيل ملف فيديو أو صوت بنجاح
  Future<void> reportDownloadCompleted({
    required String title,
    required String format,
    String? quality,
    int? sizeBytes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifyDownloads = prefs.getBool('tg_notify_downloads') ?? true;
      if (!notifyDownloads) return;

      final deviceId = await getDeviceId();
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      String sizeStr = '';
      if (sizeBytes != null && sizeBytes > 0) {
        final mb = sizeBytes / (1024 * 1024);
        sizeStr = '\n💾 <b>الحجم:</b> ${mb.toStringAsFixed(1)} ميغابايت';
      }

      final safeTitle = title.replaceAll('<', '').replaceAll('>', '');
      final message = StringBuffer()
        ..writeln('📥 <b>عملية تنزيل ناجحة!</b>')
        ..writeln('━━━━━━━━━━━━━━━━━━━━')
        ..writeln('🎬 <b>الملف:</b> $safeTitle')
        ..writeln('📦 <b>النوع:</b> ${format.toUpperCase()} ${quality != null && quality.isNotEmpty ? "($quality)" : ""}$sizeStr')
        ..writeln('🆔 <b>معرّف الجهاز:</b> <code>$deviceId</code>')
        ..writeln('🕒 <b>التوقيت:</b> $timeStr')
        ..writeln('━━━━━━━━━━━━━━━━━━━━')
        ..write('🚀 <i>تنزيل عبر محرك Boykta Turbo</i>');

      await sendMessage(message.toString());
    } catch (e) {
      debugPrint('Telegram reportDownloadCompleted error: $e');
    }
  }
}
