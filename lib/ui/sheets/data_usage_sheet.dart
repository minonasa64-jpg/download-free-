import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/theme_service.dart';
import '../../services/backend_service.dart';
import '../../services/data_usage_service.dart';

class DataUsageSheet extends StatelessWidget {
  const DataUsageSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = BackendService();
    final dataUsage = DataUsageService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ThemeService().currentTheme.value.primary;

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 32, left: 20, right: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101018) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? primaryColor.withOpacity(0.2) : Colors.black12,
        ),
      ),
      child: ValueListenableBuilder<DataUsageStats>(
        valueListenable: dataUsage.statsNotifier,
        builder: (context, stats, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.data_usage_rounded, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          backend.t('data_usage'),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          backend.t('data_usage_desc'),
                          style: TextStyle(
                            color: isDark ? AppColors.textMuted : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'تصفير العداد',
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 20),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: isDark ? AppColors.surface : Colors.white,
                          title: const Text('تصفير إحصائيات البيانات؟'),
                          content: const Text('سيتم إعادة ضبط عدادات التنزيل والتوفير إلى الصفر.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('تصفير', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await dataUsage.resetStats();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // بطاقات الأرقام الكبرى
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      isDark: isDark,
                      title: backend.t('today_usage'),
                      value: stats.todayFormatted,
                      icon: Icons.today_rounded,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      isDark: isDark,
                      title: backend.t('total_usage'),
                      value: stats.totalFormatted,
                      icon: Icons.cloud_download_rounded,
                      color: AppColors.magenta,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // بطاقة التوفير الذكي
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF10B981).withOpacity(0.18),
                      primaryColor.withOpacity(0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.eco_rounded, color: Colors.black, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            backend.t('saved_data'),
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stats.savedFormatted,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'تم توفيرها بفضل استخراج الصوت المباشر والتحميل الذكي فائق الضغط',
                            style: TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // تفاصيل عدد الملفات المنزلة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181824) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCountItem(
                      icon: Icons.videocam_rounded,
                      color: primaryColor,
                      label: 'فيديوهات مكتملة',
                      count: '${stats.totalVideosCount}',
                      isDark: isDark,
                    ),
                    Container(width: 1, height: 30, color: Colors.white12),
                    _buildCountItem(
                      icon: Icons.music_note_rounded,
                      color: AppColors.magenta,
                      label: 'ملفات صوت وموسيقى',
                      count: '${stats.totalAudiosCount}',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required bool isDark,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181824) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? AppColors.textMuted : Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountItem({
    required IconData icon,
    required Color color,
    required String label,
    required String count,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: isDark ? AppColors.textMuted : Colors.black54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
