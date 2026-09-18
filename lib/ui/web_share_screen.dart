import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_colors.dart';
import '../services/backend_service.dart';
import '../services/web_share_server.dart';

class WebShareScreen extends StatefulWidget {
  const WebShareScreen({super.key});

  @override
  State<WebShareScreen> createState() => _WebShareScreenState();
}

class _WebShareScreenState extends State<WebShareScreen> {
  final WebShareServer _server = WebShareServer();
  final BackendService _backend = BackendService();
  String? _localIp;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _initServer();
  }

  Future<void> _initServer() async {
    final ip = await _server.getLocalIpAddress();
    if (mounted) {
      setState(() {
        _localIp = ip;
      });
    }
  }

  String get _serverUrl {
    final ip = _localIp ?? '127.0.0.1';
    return 'http://$ip:${_server.port}';
  }

  Future<void> _toggleServer(bool value) async {
    setState(() => _isStarting = true);
    if (value) {
      await _initServer();
      await _server.startServer();
    } else {
      await _server.stopServer();
    }
    if (mounted) {
      setState(() => _isStarting = false);
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: _serverUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ رابط المشاركة إلى الحافظة 📋'),
        backgroundColor: AppColors.cyan,
      ),
    );
  }

  void _shareUrl() {
    Share.share(
      'تصفح وحمّل فيديوهات وصوتيات Boykta Pro على جهاز الكمبيوتر عبر الرابط التالي: $_serverUrl',
      subject: 'رابط مشاركة ملفات Boykta Pro',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.wifi_tethering_rounded, color: AppColors.cyan, size: 22),
            SizedBox(width: 8),
            Text(
              'مشاركة الملفات عبر الـ Wi-Fi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // كرت الحالة الرئيسي
              ValueListenableBuilder<bool>(
                valueListenable: _server.isRunningNotifier,
                builder: (context, isRunning, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isRunning
                                ? [AppColors.cyan.withOpacity(0.18), AppColors.magenta.withOpacity(0.12)]
                                : [AppColors.surfaceLight.withOpacity(0.5), AppColors.surface.withOpacity(0.5)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isRunning ? AppColors.cyan.withOpacity(0.5) : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isRunning ? AppColors.cyan.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                border: Border.all(
                                  color: isRunning ? AppColors.cyan : Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                isRunning ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                                size: 36,
                                color: isRunning ? AppColors.cyan : Colors.white38,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              isRunning ? 'الخادم المحلي يعمل بنشاط 🟢' : 'الخادم متوقف حالياً ⚪',
                              style: TextStyle(
                                color: isRunning ? AppColors.cyan : Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isRunning
                                  ? 'يمكنك الآن الدخول من أي جهاز متصل بنفس شبكة الـ Wi-Fi'
                                  : 'قم بتشغيل الخادم لبدء مشاركة وتنزيل الملفات على الكمبيوتر',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                            const SizedBox(height: 18),
                            _isStarting
                                ? const CircularProgressIndicator(color: AppColors.cyan)
                                : SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'تشغيل خادم الـ Wi-Fi',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    value: isRunning,
                                    activeColor: AppColors.cyan,
                                    onChanged: _toggleServer,
                                  ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              // كرت عنوان الرابط المباشر
              ValueListenableBuilder<bool>(
                valueListenable: _server.isRunningNotifier,
                builder: (context, isRunning, _) {
                  if (!isRunning) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.computer_rounded, color: AppColors.cyan, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'رابط الدخول من الكمبيوتر:',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _serverUrl,
                                  style: const TextStyle(
                                    color: AppColors.cyan,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: AppColors.cyan, size: 20),
                                onPressed: _copyUrl,
                                tooltip: 'نسخ',
                              ),
                              IconButton(
                                icon: const Icon(Icons.share_rounded, color: Colors.white70, size: 20),
                                onPressed: _shareUrl,
                                tooltip: 'مشاركة',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              // كرت خطوات الاستخدام
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📌 كيفية الاتصال السريع:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    _buildStep('1', 'تأكد أن الهاتف وجهاز الكمبيوتر متصلان بنفس شبكة الـ Wi-Fi المنزلية.'),
                    const SizedBox(height: 10),
                    _buildStep('2', 'افتح متصفح الويب على الكمبيوتر (Chrome أو Edge أو Firefox أو Safari).'),
                    const SizedBox(height: 10),
                    _buildStep('3', 'اكتب الرابط المعروض أعلاه في شريط العنوان واضغط Enter.'),
                    const SizedBox(height: 10),
                    _buildStep('4', 'ستظهر لك صفحة فورية تتيح لك تشغيل وتحميل جميع فيديوهاتك وصوتياتك بأقصى سرعة!'),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // سجل العمليات المباشرة
              ValueListenableBuilder<List<String>>(
                valueListenable: _server.logsNotifier,
                builder: (context, logs, _) {
                  if (logs.isEmpty) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.terminal_rounded, color: Colors.greenAccent, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'سجل النشاط المباشر',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...logs.take(5).map((log) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                log,
                                style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
                              ),
                            )),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.cyan.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.cyan.withOpacity(0.4)),
          ),
          alignment: Alignment.center,
          child: Text(
            num,
            style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}
