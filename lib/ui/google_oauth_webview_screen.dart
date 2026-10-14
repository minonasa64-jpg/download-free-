import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/auth_service.dart';

class GoogleOAuthWebViewScreen extends StatefulWidget {
  const GoogleOAuthWebViewScreen({super.key});

  @override
  State<GoogleOAuthWebViewScreen> createState() => _GoogleOAuthWebViewScreenState();
}

class _GoogleOAuthWebViewScreenState extends State<GoogleOAuthWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = '';
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _currentUrl = url;
              });
            }
          },
          onPageFinished: (String url) async {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _currentUrl = url;
              });
            }

            // فحص إذا تمت إعادة التوجيه إلى صفحة الحساب الرسمية أو صفحة النجاح
            if (url.contains('myaccount.google.com') ||
                url.contains('accounts.google.com/b/') ||
                url.contains('google.com/?') ||
                url.contains('oauth/callback') ||
                url.contains('CheckCookie')) {
              _autoDetectAndComplete(url);
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
        ),
      )
      // فتح صفحة تسجيل الدخول الرسمية لـ Google مع اختيار الحسابات
      ..loadRequest(Uri.parse('https://accounts.google.com/ServiceLogin?service=mail&continue=https://myaccount.google.com/'));
  }

  Future<void> _autoDetectAndComplete(String url) async {
    try {
      // محاولة استخراج البريد من الصفحة عبر جافاسكريبت
      final emailResult = await _controller.runJavaScriptReturningResult(
        "document.querySelector('[data-email]') ? document.querySelector('[data-email]').getAttribute('data-email') : ''"
      );
      String detectedEmail = emailResult.toString().replaceAll('"', '').trim();

      if (detectedEmail.isNotEmpty && detectedEmail.contains('@')) {
        final user = await _auth.signInWithGoogle(
          email: detectedEmail,
          displayName: detectedEmail.split('@').first,
          rememberMe: true,
        );
        if (mounted) {
          Navigator.of(context).pop(user);
        }
      }
    } catch (_) {
      // إكمال آمن
    }
  }

  void _manualConfirmAccount() {
    final emailController = TextEditingController();
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (_, __, ___) => const Icon(Icons.account_circle, color: Color(0xFF0066FF)),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'تأكيد ربط حساب Google للاشتراك',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'أدخل أو أكّد بريدك في Google الذي تم اختياره لحفظ اشتراكك ومزامنته سحابياً:',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'بريدك في Google (Gmail)',
                  hintText: 'example@gmail.com',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF0066FF)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسمك في الحساب (اختياري)',
                  hintText: 'الاسم الظاهر',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF0066FF)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  onPressed: () async {
                    final email = emailController.text.trim();
                    final name = nameController.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('يرجى إدخال بريد إلكتروني صالح')),
                      );
                      return;
                    }

                    final user = await _auth.signInWithGoogle(
                      email: email,
                      displayName: name.isNotEmpty ? name : null,
                      rememberMe: true,
                    );

                    if (mounted) {
                      Navigator.pop(ctx); // Close sheet
                      Navigator.of(context).pop(user); // Return to login
                    }
                  },
                  child: const Text(
                    'ربط الحساب وتأكيد تسجيل الدخول',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
              width: 22,
              height: 22,
              errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: Color(0xFF0066FF), size: 28),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تسجيل الدخول باستخدام Google',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'اختر حسابك الرسمي لحفظ الاشتراك والمزامنة',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0066FF)),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFFE2E8F0),
                color: Color(0xFF0066FF),
                minHeight: 3,
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text(
                    'تم اختيار الحساب / تأكيد الربط',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _manualConfirmAccount,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
