import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_colors.dart';
import '../../services/backend_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final BackendService _backend = BackendService();
  
  bool _downloadViaMobile = true;
  String _downloadPath = '/storage/emulated/0/Download';
  int _maxTasks = 4;
  String _speedLimit = 'غير محدود';
  
  bool _progressNotif = true;
  bool _completeNotif = true;
  
  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    final dlSettings = await _backend.getDownloadSettings();
    final notifSettings = await _backend.getNotificationSettings();
    
    if (mounted) {
      setState(() {
        _downloadViaMobile = dlSettings['downloadMobile'];
        _downloadPath = dlSettings['download_path'];
        _maxTasks = dlSettings['max_tasks'];
        _speedLimit = dlSettings['speed_limit'];
        _progressNotif = notifSettings['n_prog']!;
        _completeNotif = notifSettings['n_comp']!;
      });
    }
  }

  Future<void> _updateNotification(String key, bool value) async {
    await _backend.updateNotificationSetting(key, value);
    setState(() {
      if (key == 'n_prog') _progressNotif = value;
      if (key == 'n_comp') _completeNotif = value;
    });
  }

  Future<void> _updateDownload(String key, dynamic value) async {
    await _backend.updateDownloadSetting(key, value);
    setState(() {
      if (key == 'downloadMobile') _downloadViaMobile = value;
      if (key == 'max_tasks') _maxTasks = value;
      if (key == 'speed_limit') _speedLimit = value;
      if (key == 'download_path') _downloadPath = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    // تحديد الألوان بناءً على السمة الحالية
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimary : Colors.black87;
    final subtitleColor = isDark ? AppColors.textMuted : Colors.black54;
    final surfaceColor = isDark ? AppColors.surfaceLight.withOpacity(0.4) : Colors.white.withOpacity(0.7);

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 120, top: 10), 
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            child: Text(
              '${_backend.t('settings')} ⚙️',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),

          _buildSectionHeader(_backend.t('dl_settings')),
          _buildGlassTile(
            context,
            icon: Icons.folder_rounded,
            title: _backend.t('downloaded'),
            subtitle: _downloadPath,
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            onTap: () => _showStoragePathDialog(context),
          ),

          const SizedBox(height: 15),

          _buildSectionHeader(_backend.t('general')),
          _buildGlassTile(
            context,
            icon: Icons.dark_mode_rounded,
            title: _backend.t('theme'),
            subtitle: _backend.themeNotifier.value == ThemeMode.dark ? 'Dark Mode' : 'Light Mode',
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            onTap: () => _showThemeDialog(context),
          ),
          _buildGlassTile(
            context,
            icon: Icons.language_rounded,
            title: _backend.t('language'),
            subtitle: _backend.langNotifier.value == 'ar' ? 'العربية' : (_backend.langNotifier.value == 'en' ? 'English' : 'Français'),
            textColor: textColor,
            subtitleColor: subtitleColor,
            surfaceColor: surfaceColor,
            onTap: () => _showLanguageDialog(context),
          ),
          _buildGlassTile(
            context,
            icon: Icons.notifications_active_rounded,
            title: _backend.t('notif'),
            subtitle: '',
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

          _buildSectionHeader(_backend.t('more_tools')),
          _buildGlassTile(
            context,
            icon: Icons.info_outline_rounded,
            title: _backend.t('about'),
            subtitle: '1.0.0',
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
      applicationName: 'Boykta',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(15)),
        child: const Icon(Icons.download, color: Colors.white, size: 30),
      ),
      children: [
        const SizedBox(height: 10),
        const Text('تطبيق Boykta هو أداة احترافية لتحميل الفيديوهات والمقاطع الصوتية بسرعة وكفاءة عالية.'),
      ],
    );
  }
}
