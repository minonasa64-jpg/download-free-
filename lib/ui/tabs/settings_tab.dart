import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/backend_service.dart';
import '../../services/biometric_service.dart';
import '../../services/ad_service.dart';
import '../../core/theme_service.dart';
import '../../services/data_usage_service.dart';
import '../vault_screen.dart';
import '../web_share_screen.dart';
import '../sheets/theme_station_sheet.dart';
import '../sheets/data_usage_sheet.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final BackendService _backend = BackendService();
  String _downloadPath = 'مسار Boykta العام';
  bool _completeNotif = true;
  bool _wifiOnly = false;
  bool _biometricEnabled = false;
  bool _hasVaultPin = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final dl = await _backend.getDownloadSettings();
    final notif = await _backend.getNotificationSettings();
    final bioEnabled = await BiometricService().isBiometricEnabled();
    final hasPin = await _backend.isVaultPinSet();

    if (mounted) {
      setState(() {
        _downloadPath = dl['download_path'] ?? 'مسار Boykta العام';
        _wifiOnly = dl['wifi_only'] ?? false;
        _completeNotif = notif['n_comp'] ?? true;
        _biometricEnabled = bioEnabled;
        _hasVaultPin = hasPin;
      });
    }
  }

  Future<void> _updateDownload(String key, dynamic value) async {
    await _backend.updateDownloadSetting(key, value);
    _loadSettings();
  }

  Future<void> _updateNotification(String key, bool value) async {
    await _backend.updateNotificationSetting(key, value);
    _loadSettings();
  }

  void _openVault() async {
    final hasPin = await _backend.isVaultPinSet();
    if (!mounted) return;
    if (!hasPin) {
      _showSetVaultPinDialog();
      return;
    }

    if (_biometricEnabled) {
      final authenticated = await BiometricService().authenticate(
        reason: 'تأكيد البصمة للدخول الفوري إلى الخزنة الآمنة',
      );
      if (authenticated && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen()));
        return;
      }
    }

    if (mounted) {
      _showEnterVaultPinDialog();
    }
  }

  void _showSetDecoyPinDialog() {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.security_update_warning_rounded, color: AppColors.orange, size: 24),
            const SizedBox(width: 8),
            const Text('رمز الخزنة الوهمية (Decoy)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إذا أجبرت على فتح الخزنة، أدخل هذا الرمز ليفتح خزنة وهمية فارغة ونظيفة تماماً دون كشف ملفاتك الحقيقية.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '••••',
                hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 8),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () async {
              final pin = pinCtrl.text.trim();
              if (pin.length == 4) {
                await _backend.setDecoyPin(pin);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تفعيل رمز الخزنة الوهمية بنجاح 🛡️'),
                      backgroundColor: AppColors.cyan,
                    ),
                  );
                }
              }
            },
            child: const Text('حفظ الرمز', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSetVaultPinDialog({bool isChanging = false}) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: AppColors.cyan, size: 24),
            const SizedBox(width: 8),
            Text(
              isChanging ? 'تغيير رمز PIN' : _backend.t('set_pin'),
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isChanging ? 'أدخل رمز PIN جديداً مكوناً من 4 أرقام' : _backend.t('vault_desc'),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '••••',
                hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 8),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
            onPressed: () async {
              if (pinCtrl.text.trim().length == 4) {
                await _backend.setVaultPin(pinCtrl.text.trim());
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() => _hasVaultPin = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isChanging ? 'تم تحديث رمز PIN بنجاح 🔒' : _backend.t('pin_set_success')),
                      backgroundColor: AppColors.cyan.withOpacity(0.9),
                    ),
                  );
                  if (!isChanging) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen()));
                  }
                }
              }
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEnterVaultPinDialog() {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.cyan, size: 24),
            const SizedBox(width: 8),
            Text(_backend.t('enter_pin'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '••••',
                hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 8),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
            onPressed: () async {
              final enteredPin = pinCtrl.text.trim();
              final isDecoy = await _backend.isDecoyPin(enteredPin);
              if (isDecoy) {
                if (mounted) {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen(isDecoy: true)));
                }
                return;
              }

              final isCorrect = await _backend.verifyVaultPin(enteredPin);
              if (isCorrect) {
                if (mounted) {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen()));
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_backend.t('wrong_pin')), backgroundColor: AppColors.orange),
                  );
                }
              }
            },
            child: const Text('دخول', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceLight.withOpacity(0.4) : Colors.black.withOpacity(0.04);
    final textColor = isDark ? AppColors.textPrimary : Colors.black87;
    final subtitleColor = isDark ? AppColors.textMuted : Colors.black54;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 160, top: 15),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            child: Text(
              _backend.t('settings'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // قسم الخزنة والخصوصية
          _buildSectionHeader('الخصوصية والأمان'),
          _buildGlassTile(
            context,
            icon: Icons.shield_rounded,
            title: _backend.t('vault'),
            subtitle: _backend.t('vault_desc'),
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.cyan, size: 16),
            onTap: _openVault,
          ),
          if (_hasVaultPin) ...[
            _buildGlassTile(
              context,
              icon: Icons.password_rounded,
              title: 'تغيير رمز PIN للخزنة',
              subtitle: 'تعيين رمز حماية سري جديد للخزنة',
              textColor: textColor,
              subtitleColor: subtitleColor,
              surfaceColor: surfaceColor,
              trailing: const Icon(Icons.edit_rounded, color: AppColors.cyan, size: 18),
              onTap: () => _showSetVaultPinDialog(isChanging: true),
            ),
            _buildGlassTile(
              context,
              icon: Icons.security_update_warning_rounded,
              title: _backend.t('decoy_pin'),
              subtitle: _backend.t('decoy_pin_desc'),
              textColor: textColor,
              subtitleColor: subtitleColor,
              surfaceColor: surfaceColor,
              trailing: const Icon(Icons.edit_rounded, color: AppColors.orange, size: 18),
              onTap: _showSetDecoyPinDialog,
            ),
          ],
          _buildGlassTile(
            context,
            icon: Icons.fingerprint_rounded,
            title: 'فتح الخزنة بالبصمة (Biometrics)',
            subtitle: 'استخدام بصمة الإصبع أو الوجه لفتح الخزنة بسرعة وأمان',
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            trailing: Switch(
              value: _biometricEnabled,
              activeColor: AppColors.cyan,
              onChanged: (val) async {
                if (val) {
                  final supported = await BiometricService().isBiometricSupported();
                  if (!supported) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('جهازك لا يدعم المصادقة البيومترية أو لم يتم تعيين بصمة بعد'),
                          backgroundColor: AppColors.orange,
                        ),
                      );
                    }
                    return;
                  }
                  final auth = await BiometricService().authenticate(reason: 'تأكيد البصمة لتفعيلها للخزنة');
                  if (!auth) return;
                }
                await BiometricService().setBiometricEnabled(val);
                setState(() => _biometricEnabled = val);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val ? 'تم تفعيل فتح الخزنة بالبصمة 👆' : 'تم تعطيل البصمة للخزنة'),
                      backgroundColor: AppColors.cyan,
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 15),

          // قسم إعدادات التنزيل والسرعة
          _buildSectionHeader(_backend.t('dl_settings')),
          _buildGlassTile(
            context,
            icon: Icons.bolt_rounded,
            title: 'التحميل التوربو فائق السرعة (Turbo Multi-Threading)',
            subtitle: 'يعمل دائماً بأقصى طاقة مسارات متزامنة (16 مسار) لتسريع التنزيل لأقصى حد ممكن',
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            trailing: const Icon(Icons.flash_on_rounded, color: AppColors.cyan, size: 22),
          ),
          _buildGlassTile(
            context,
            icon: Icons.folder_open_rounded,
            title: 'مسار حفظ التنزيلات',
            subtitle: _downloadPath,
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.cyan, size: 16),
            onTap: () => _showStoragePathDialog(context),
          ),
          _buildGlassTile(
            context,
            icon: Icons.wifi_rounded,
            title: _backend.t('wifi_only'),
            subtitle: _backend.t('wifi_only_desc'),
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            trailing: Switch(
              value: _wifiOnly,
              activeColor: AppColors.cyan,
              onChanged: (val) => _updateDownload('wifi_only', val),
            ),
          ),
          _buildGlassTile(
            context,
            icon: Icons.replay_circle_filled_rounded,
            title: _backend.t('auto_retry_active'),
            subtitle: 'استئناف التحميل تلقائياً عند انقطاع الاتصال',
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            trailing: const Icon(Icons.check_circle_rounded, color: AppColors.cyan, size: 20),
          ),
          const SizedBox(height: 15),

          // قسم الإشعارات والمظهر
          _buildSectionHeader(_backend.t('general')),
          _buildGlassTile(
            context,
            icon: Icons.color_lens_rounded,
            title: _backend.t('theme_station'),
            subtitle: '${ThemeService().currentTheme.value.nameAr} • ${_backend.t('theme_station_desc')}',
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.cyan, size: 16),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ThemeStationSheet(),
              );
            },
          ),
          _buildGlassTile(
            context,
            icon: Icons.data_usage_rounded,
            title: _backend.t('data_usage'),
            subtitle: _backend.t('data_usage_desc'),
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.cyan, size: 16),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const DataUsageSheet(),
              );
            },
          ),
          _buildGlassTile(
            context,
            icon: Icons.language_rounded,
            title: _backend.t('language'),
            subtitle: _backend.langNotifier.value == 'ar'
                ? 'العربية 🇸🇦'
                : (_backend.langNotifier.value == 'en'
                    ? 'English 🇺🇸'
                    : (_backend.langNotifier.value == 'fr'
                        ? 'Français 🇫🇷'
                        : (_backend.langNotifier.value == 'es'
                            ? 'Español 🇪🇸'
                            : (_backend.langNotifier.value == 'tr'
                                ? 'Türkçe 🇹🇷'
                                : (_backend.langNotifier.value == 'de'
                                    ? 'Deutsch 🇩🇪'
                                    : 'Русский 🇷🇺'))))),
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.cyan, size: 16),
            onTap: () => _showLanguageDialog(context),
          ),
          _buildGlassTile(
            context,
            icon: Icons.notifications_active_rounded,
            title: _backend.t('notif'),
            subtitle: 'إشعار عند اكتمال التنزيل',
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            trailing: Switch(
              value: _completeNotif,
              activeColor: AppColors.cyan,
              onChanged: (val) => _updateNotification('n_comp', val),
            ),
          ),
          const SizedBox(height: 15),

          // قسم الصيانة والأدوات
          _buildSectionHeader(_backend.t('storage_maintenance')),
          _buildGlassTile(
            context,
            icon: Icons.cleaning_services_rounded,
            title: _backend.t('clear_cache_title'),
            subtitle: _backend.t('clear_cache_desc'),
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            trailing: const Icon(Icons.delete_sweep_rounded, color: AppColors.cyan, size: 20),
            onTap: _clearCache,
          ),
          _buildGlassTile(
            context,
            icon: Icons.wifi_tethering_rounded,
            title: _backend.t('web_share'),
            subtitle: _backend.t('web_share_desc'),
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.cyan, size: 16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WebShareScreen()));
            },
          ),
          const SizedBox(height: 15),

          _buildSectionHeader(_backend.t('more_tools')),
          _buildGlassTile(
            context,
            icon: Icons.info_outline_rounded,
            title: _backend.t('about'),
            subtitle: 'Boykta Pro v1.3.9 (إصدار متكامل فائق السرعة بدقة 1080p FHD)',
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.cyan,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildGlassTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subtitleColor,
    required Color surfaceColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: ListTile(
              onTap: onTap,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.cyan, size: 22),
              ),
              title: Text(title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 12)) : null,
              trailing: trailing ?? Icon(Icons.arrow_forward_ios_rounded, color: subtitleColor, size: 14),
            ),
          ),
        ),
      ),
    );
  }

  void _clearCache() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.cyan),
      ),
    );

    final freedMb = await _backend.clearTempCache();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            freedMb > 0
                ? 'تم تنظيف التخزين المؤقت وتحرير ${freedMb.toStringAsFixed(1)} MB بنجاح! 🧹'
                : 'التخزين المؤقت نظيف بالفعل، لا توجد ملفات معلقة ✨',
          ),
          backgroundColor: AppColors.cyan,
        ),
      );
    }
  }

  void _showStoragePathDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pathController = TextEditingController(text: _downloadPath);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('مسار حفظ التنزيلات', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPathOption(
                ctx,
                title: 'مجلد Boykta الافتراضي للفيديوهات',
                path: '/storage/emulated/0/Movies/Boykta',
                isDark: isDark,
              ),
              _buildPathOption(
                ctx,
                title: 'مجلد التنزيلات العام Download',
                path: '/storage/emulated/0/Download/Boykta',
                isDark: isDark,
              ),
              _buildPathOption(
                ctx,
                title: 'مجلد الموسيقى والصوتيات Music',
                path: '/storage/emulated/0/Music/Boykta',
                isDark: isDark,
              ),
              const Divider(height: 20),
              Text('أو أدخل مساراً مخصصاً:', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: pathController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '/storage/emulated/0/...',
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
            onPressed: () {
              final newPath = pathController.text.trim();
              if (newPath.isNotEmpty) {
                _updateDownload('download_path', newPath);
              }
              Navigator.pop(ctx);
            },
            child: const Text('تطبيق', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPathOption(BuildContext ctx, {required String title, required String path, required bool isDark}) {
    final isSelected = _downloadPath == path;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(path, style: const TextStyle(color: AppColors.cyan, fontSize: 11)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.cyan, size: 18) : null,
      onTap: () {
        _updateDownload('download_path', path);
        Navigator.pop(ctx);
      },
    );
  }

  void _showThemeDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_backend.t('theme'), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('داكن (Dark Mode)', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              trailing: _backend.themeNotifier.value == ThemeMode.dark ? const Icon(Icons.check_circle_rounded, color: AppColors.cyan) : null,
              onTap: () async {
                await _backend.changeTheme('dark');
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('فاتح (Light Mode)', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              trailing: _backend.themeNotifier.value == ThemeMode.light ? const Icon(Icons.check_circle_rounded, color: AppColors.cyan) : null,
              onTap: () async {
                await _backend.changeTheme('light');
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languages = [
      {'code': 'ar', 'name': 'العربية (Arabic)', 'flag': '🇸🇦'},
      {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
      {'code': 'fr', 'name': 'Français (French)', 'flag': '🇫🇷'},
      {'code': 'es', 'name': 'Español (Spanish)', 'flag': '🇪🇸'},
      {'code': 'tr', 'name': 'Türkçe (Turkish)', 'flag': '🇹🇷'},
      {'code': 'de', 'name': 'Deutsch (German)', 'flag': '🇩🇪'},
      {'code': 'ru', 'name': 'Русский (Russian)', 'flag': '🇷🇺'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_backend.t('language'), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: languages.length,
            separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.06), height: 1),
            itemBuilder: (context, index) {
              final item = languages[index];
              final code = item['code']!;
              final isSelected = _backend.langNotifier.value == code;
              return ListTile(
                leading: Text(item['flag']!, style: const TextStyle(fontSize: 22)),
                title: Text(
                  item['name']!,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.cyan) : null,
                onTap: () async {
                  await _backend.changeLanguage(code);
                  if (mounted) Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.cyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.download_rounded, color: AppColors.cyan, size: 24),
            ),
            const SizedBox(width: 10),
            Text('Boykta Pro', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإصدار 1.3.5', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'تطبيق تنزيل ومشاهدة الوسائط بأعلى جودة مع دعم التوربو المتعدد، دمج الصوت والصورة بدون فقد، الخزنة المشفرة، والمشاركة عبر الشبكة المحلية.',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
