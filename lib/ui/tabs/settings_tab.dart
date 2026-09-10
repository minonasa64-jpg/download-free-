import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_colors.dart';
import '../../services/backend_service.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = BackendService();

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 120, top: 10), // مسافة لشريط التنقل السفلي
        children: [
          // العنوان العلوي
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

          // قسم التنزيل
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
            subtitle: '/storage/emulated/0/Download',
            onTap: () => _showStoragePathDialog(context),
          ),

          const SizedBox(height: 15),

          // قسم التطبيق
          _buildSectionHeader('التطبيق'),
          _buildGlassTile(
            context,
            icon: Icons.dark_mode_rounded,
            title: 'السمة (Dark Mode)',
            subtitle: 'الوضع الداكن مفعل دائماً لهوية فخمة',
            trailing: Switch(
              value: true,
              activeColor: AppColors.cyan,
              onChanged: (val) {},
            ),
          ),
          _buildGlassTile(
            context,
            icon: Icons.language_rounded,
            title: 'لغة التطبيق',
            subtitle: 'العربية (Arabic)',
            onTap: () => _showLanguageDialog(context, backend),
          ),
          _buildGlassTile(
            context,
            icon: Icons.notifications_active_rounded,
            title: 'الإشعارات',
            subtitle: 'تنبيهات حالة اكتمال التنزيلات',
            trailing: Switch(
              value: true,
              activeColor: AppColors.cyan,
              onChanged: (val) {},
            ),
          ),

          const SizedBox(height: 15),

          // قسم معلومات عن التطبيق (About)
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

  // رأس القسم (Section Header)
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

  // عنصر القائمة بتصميم زجاجي
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

  // نافذة اختيار الجودة
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
              onTap: () => Navigator.pop(context),
            );
          }).toList(),
        ),
      ),
    );
  }

  // نافذة مسار التنزيل
  void _showStoragePathDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('مجلّد التنزيل', style: TextStyle(color: Colors.white)),
        content: const Text(
          'المجلد الحالي الافتراضي:\n/storage/emulated/0/Download',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً', style: TextStyle(color: AppColors.cyan)),
          ),
        ],
      ),
    );
  }

  // نافذة اختيار اللغة
  void _showLanguageDialog(BuildContext context, BackendService backend) {
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
              onTap: () {
                backend.changeLanguage('ar');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('English', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                backend.changeLanguage('en');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Français', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                backend.changeLanguage('fr');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // نافذة حول التطبيق
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
