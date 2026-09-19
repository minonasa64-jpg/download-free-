import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/backend_service.dart';
import '../../services/biometric_service.dart';
import '../vault_screen.dart';
import '../calculator_vault_screen.dart';
import '../web_share_screen.dart';

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
  bool _calculatorDisguise = false;
  bool _biometricEnabled = false;
  bool _multiThreadDownload = true;
  int _downloadThreads = 8;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final dl = await _backend.getDownloadSettings();
    final notif = await _backend.getNotificationSettings();
    final mt = await _backend.isMultiThreadDownloadEnabled();
    final th = await _backend.getDownloadThreads();
    if (mounted) {
      setState(() {
        _downloadPath = dl['download_path'] ?? 'مسار Boykta العام';
        _wifiOnly = dl['wifi_only'] ?? false;
        _completeNotif = notif['n_comp'] ?? true;
        _multiThreadDownload = mt;
        _downloadThreads = th;
      });
    }
    final disguise = await _backend.isCalculatorDisguiseEnabled();
    if (mounted) {
      final bioEnabled = await BiometricService().isBiometricEnabled();
      setState(() {
        _calculatorDisguise = disguise;
        _biometricEnabled = bioEnabled;
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
    if (_calculatorDisguise) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CalculatorVaultScreen()),
      );
      return;
    }

    final hasPin = await _backend.isVaultPinSet();
    if (!mounted) return;
    if (!hasPin) {
      _showSetVaultPinDialog();
    } else {
      _showEnterVaultPinDialog();
    }
  }

  void _showSetVaultPinDialog() {
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
            Text(_backend.t('set_pin'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_backend.t('vault_desc'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_backend.t('pin_set_success')), backgroundColor: AppColors.cyan.withOpacity(0.9)),
                  );
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen()));
                }
              }
            },
            child: const Text('حفظ والدخول', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              final isCorrect = await _backend.verifyVaultPin(pinCtrl.text.trim());
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
        padding: const EdgeInsets.only(bottom: 120, top: 15),
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
          _buildGlassTile(
            context,
            icon: Icons.calculate_outlined,
            title: 'تمويه الخزنة كآلة حاسبة',
            subtitle: 'إظهار آلة حاسبة حقيقية تفتح الخزنة تلقائياً عند كتابة رمز PIN والضغط على =',
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            trailing: Switch(
              value: _calculatorDisguise,
              activeColor: AppColors.cyan,
              onChanged: (val) async {
                await _backend.setCalculatorDisguise(val);
                setState(() => _calculatorDisguise = val);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val ? 'تم تفعيل تمويه الآلة الحاسبة 🧮' : 'تم إلغاء تفعيل تمويه الخزنة'),
                      backgroundColor: AppColors.cyan,
                    ),
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 15),
          _buildSectionHeader(_backend.t('dl_settings')),
          
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
            icon: Icons.folder_open_rounded,
            title: 'مسار التنزيل',
            subtitle: _downloadPath,
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            onTap: () => _showStoragePathDialog(context),
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
          _buildSectionHeader(_backend.t('general')),
          
          _buildGlassTile(
            context,
            icon: Icons.palette_outlined,
            title: _backend.t('theme'),
            subtitle: _backend.themeNotifier.value == ThemeMode.dark ? 'داكن' : 'فاتح',
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            onTap: () => _showThemeDialog(context),
          ),
          
          _buildGlassTile(
            context,
            icon: Icons.language_rounded,
            title: _backend.t('language'),
            subtitle: _backend.langNotifier.value.toUpperCase(),
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
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
          _buildSectionHeader('أدوات ومشاركة سريعة'),
          _buildGlassTile(
            context,
            icon: Icons.wifi_tethering_rounded,
            title: 'خادم المشاركة عبر الـ Wi-Fi',
            subtitle: 'مشاركة الملفات وتنزيلها مباشرة إلى الكمبيوتر بدون كابل عبر المتصفح',
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
            subtitle: 'Boykta Pro v1.2.0',
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

  void _showStoragePathDialog(BuildContext context) {
    final TextEditingController pathController = TextEditingController(text: _downloadPath);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('تغيير مسار التنزيل', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: TextField(
          controller: pathController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: const InputDecoration(focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.cyan))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
            onPressed: () {
              _updateDownload('download_path', pathController.text);
              Navigator.pop(context);
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_backend.t('theme'), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('داكن (Dark Mode)', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              trailing: _backend.themeNotifier.value == ThemeMode.dark ? const Icon(Icons.check, color: AppColors.cyan) : null,
              onTap: () async {
                await _backend.changeTheme('dark');
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('فاتح (Light Mode)', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              trailing: _backend.themeNotifier.value == ThemeMode.light ? const Icon(Icons.check, color: AppColors.cyan) : null,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_backend.t('language'), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('العربية', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              trailing: _backend.langNotifier.value == 'ar' ? const Icon(Icons.check, color: AppColors.cyan) : null,
              onTap: () async {
                await _backend.changeLanguage('ar');
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('English', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              trailing: _backend.langNotifier.value == 'en' ? const Icon(Icons.check, color: AppColors.cyan) : null,
              onTap: () async {
                await _backend.changeLanguage('en');
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Français', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              trailing: _backend.langNotifier.value == 'fr' ? const Icon(Icons.check, color: AppColors.cyan) : null,
              onTap: () async {
                await _backend.changeLanguage('fr');
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Boykta Pro',
      applicationVersion: '1.2.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(15)),
        child: const Icon(Icons.download, color: Colors.white, size: 30),
      ),
      children: const [
        SizedBox(height: 10),
        Text('تطبيق Boykta Pro هو أداة احترافية ومتكاملة لتحميل الفيديوهات والمقاطع الصوتية بأعلى جودة.'),
        SizedBox(height: 6),
        Text('الميزات: مشغل يوتيوب متقدم، استخراج MP3، خزنة آمنة برمز PIN، استئناف تلقائي للتحميل.'),
      ],
    );
  }
}
