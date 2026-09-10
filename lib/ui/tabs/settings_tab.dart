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
    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 120, top: 10), 
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            child: Text(
              'الإعدادات ⚙️',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // ==============================
          // قسم التنزيل
          // ==============================
          _buildSectionHeader('التنزيل'),
          _buildGlassTile(
            context,
            icon: Icons.download_rounded,
            title: 'جودة الفيديو الافتراضية',
            subtitle: 'تحديد الجودة المفضلة للتحميل التلقائي',
            onTap: () => _showQualityDialog(context),
          ),
          _buildGlassTile(
            context,
            icon: Icons.folder_rounded,
            title: 'مجلّد التنزيل',
            subtitle: _downloadPath,
            onTap: () => _showStoragePathDialog(context),
          ),
          _buildGlassTile(
            context,
            icon: Icons.network_cell_rounded,
            title: 'التنزيل ببيانات الهاتف',
            subtitle: 'السماح بالتحميل دون واي فاي',
            trailing: Switch(
              value: _downloadViaMobile,
              activeColor: AppColors.cyan,
              onChanged: (val) => _updateDownload('downloadMobile', val),
            ),
          ),

          const SizedBox(height: 15),

          // ==============================
          // قسم التطبيق
          // ==============================
          _buildSectionHeader('التطبيق'),
          _buildGlassTile(
            context,
            icon: Icons.dark_mode_rounded,
            title: 'السمة (Theme)',
            subtitle: _backend.themeNotifier.value == ThemeMode.dark ? 'الوضع الداكن (Dark)' : 'الوضع الفاتح (Light)',
            onTap: () => _showThemeDialog(context),
          ),
          _buildGlassTile(
            context,
            icon: Icons.language_rounded,
            title: 'لغة التطبيق',
            subtitle: _backend.langNotifier.value == 'ar' ? 'العربية' : (_backend.langNotifier.value == 'en' ? 'English' : 'Français'),
            onTap: () => _showLanguageDialog(context),
          ),
          _buildGlassTile(
            context,
            icon: Icons.notifications_active_rounded,
            title: 'إشعارات الاكتمال',
            subtitle: 'تنبيهات حالة اكتمال التنزيلات',
            trailing: Switch(
              value: _completeNotif,
              activeColor: AppColors.cyan,
              onChanged: (val) => _updateNotification('n_comp', val),
            ),
          ),

          const SizedBox(height: 15),

          // ==============================
          // قسم معلومات عن التطبيق (About)
          // ==============================
          _buildSectionHeader('معلومات'),
          _buildGlassTile(
            context,
            icon: Icons.info_outline_rounded,
            title: 'حول التطبيق (About Boykta)',
            subtitle: 'الإصدار 1.0.0',
            onTap: () => _showAboutDialog(context),
          ),
          _buildGlassTile(
            context,
            icon: Icons.share_rounded,
            title: 'مشاركة التطبيق مع أصدقائك',
            subtitle: 'ادعمنا بمشاركة التطبيق',
            onTap: () {
              Share.share('جرب تطبيق Boykta الرائع لتحميل الفيديوهات والمقاطع بكل سهولة 🚀');
            },
          ),
          _buildGlassTile(
            context,
            icon: Icons.cleaning_services_rounded,
            title: 'تنظيف الملفات المؤقتة (Cache)',
            subtitle: 'تفريغ المساحة الزائدة',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تنظيف الملفات المؤقتة بنجاح ✨'),
                  backgroundColor: Colors.green,
                ),
              );
            },
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
              color: AppColors.surfaceLight.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
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
              title: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
            ),
          ),
        ),
      ),
    );
  }

  void _showQualityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('جودة الفيديو الافتراضية', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['1080p (FHD)', '720p (HD)', '480p (SD)'].map((quality) {
            return ListTile(
              title: Text(quality, style: const TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم التغيير إلى $quality')));
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showStoragePathDialog(BuildContext context) {
    final TextEditingController pathController = TextEditingController(text: _downloadPath);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تغيير مسار التنزيل', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: pathController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.cyan)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted)),
          ),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('اختر السمة', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('داكن (Dark Mode)', style: TextStyle(color: AppColors.textPrimary)),
              trailing: _backend.themeNotifier.value == ThemeMode.dark ? const Icon(Icons.check, color: AppColors.cyan) : null,
              onTap: () async {
                await _backend.changeTheme('dark');
                setState(() {});
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('فاتح (Light Mode)', style: TextStyle(color: AppColors.textPrimary)),
              trailing: _backend.themeNotifier.value == ThemeMode.light ? const Icon(Icons.check, color: AppColors.cyan) : null,
              onTap: () async {
                await _backend.changeTheme('light');
                setState(() {});
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('اختر اللغة', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('العربية', style: TextStyle(color: AppColors.textPrimary)),
              trailing: _backend.langNotifier.value == 'ar' ? const Icon(Icons.check, color: AppColors.cyan) : null,
              onTap: () async {
                await _backend.changeLanguage('ar');
                setState(() {});
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English', style: TextStyle(color: AppColors.textPrimary)),
              trailing: _backend.langNotifier.value == 'en' ? const Icon(Icons.check, color: AppColors.cyan) : null,
              onTap: () async {
                await _backend.changeLanguage('en');
                setState(() {});
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Français', style: TextStyle(color: AppColors.textPrimary)),
              trailing: _backend.langNotifier.value == 'fr' ? const Icon(Icons.check, color: AppColors.cyan) : null,
              onTap: () async {
                await _backend.changeLanguage('fr');
                setState(() {});
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
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.download, color: Colors.white, size: 30),
      ),
      children: [
        const SizedBox(height: 10),
        const Text(
          'تطبيق Boykta هو أداة احترافية وفخمة لتحميل الفيديوهات والمقاطع الصوتية بسرعة وكفاءة عالية.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
