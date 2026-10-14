import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'google_oauth_webview_screen.dart';

class GoogleLoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const GoogleLoginScreen({super.key, this.onLoginSuccess});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  final AuthService _auth = AuthService();

  // Tab: 0 = Sign In, 1 = Sign Up
  int _activeTab = 0;

  // Controllers for Sign In
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  // Controllers for Sign Up
  final TextEditingController _signupNameController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupPasswordController = TextEditingController();
  final TextEditingController _signupConfirmPasswordController = TextEditingController();

  bool _rememberMe = true;
  bool _agreeTerms = true;
  bool _loginObscure = true;
  bool _signupObscure = true;
  bool _confirmObscure = true;

  bool _isLoading = false;
  String? _statusMessage;
  bool _isError = false;

  // Modern Web Palette (Crisp White + Electric Blue)
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color hoverBlue = Color(0xFF1D4ED8);
  static const Color backgroundWhite = Colors.white;
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color borderGrey = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    super.dispose();
  }

  void _proceedToApp() {
    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!();
    } else {
      Navigator.of(context).pop();
    }
  }

  // فتح نافذة اختيار حساب Google (Google One Tap Modal) مثل المواقع العالمية
  void _openGoogleAccountPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 25,
                offset: Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // مقبض النافذة
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

              // رأسية Google الرسمية (مثل Google One Tap تماماً في المواقع)
              Row(
                children: [
                  Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                    width: 26,
                    height: 26,
                    errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: primaryBlue, size: 28),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تسجيل الدخول باستخدام Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        Text(
                          'إلى تطبيق Boykta Pro لحفظ الاشتراك وسجل التحميلات',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: textMuted, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: borderGrey),
              const SizedBox(height: 16),

              const Text(
                'اختر حساباً للمتابعة:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 12),

              // الحساب الرئيسي المكتشف (حساب المستخدم الرسمي)
              _buildAccountTile(
                name: 'nafea ouadah',
                email: 'nafeawoudah24@gmail.com',
                initial: 'N',
                badge: 'الحساب النشط',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _loginWithGoogleDirect('nafeawoudah24@gmail.com', 'nafea ouadah');
                },
              ),
              const SizedBox(height: 10),

              // خيار إضافة حساب Google آخر بسهولة
              _buildActionTile(
                icon: Icons.person_add_alt_1_rounded,
                title: 'استخدام حساب Google آخر',
                subtitle: 'أدخل بريدك الإلكتروني الخاص بـ Gmail للاشتراك',
                onTap: () {
                  Navigator.pop(ctx);
                  _openCustomGmailDialog();
                },
              ),
              const SizedBox(height: 10),

              // خيار فتح صفحة Google الرسمية في المتصفح المدمج
              _buildActionTile(
                icon: Icons.language_rounded,
                title: 'فتح موقع Google الرسمي للمصادقة',
                subtitle: 'تسجيل الدخول المباشر عبر خوادم Google الرسمية',
                onTap: () async {
                  Navigator.pop(ctx);
                  final user = await Navigator.push<GoogleAuthUser>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GoogleOAuthWebViewScreen(),
                      fullscreenDialog: true,
                    ),
                  );
                  if (user != null && mounted) {
                    _proceedToApp();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // بطاقة حساب Google
  Widget _buildAccountTile({
    required String name,
    required String email,
    required String initial,
    required String badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderGrey),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: primaryBlue,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(fontSize: 12, color: textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
          ],
        ),
      ),
    );
  }

  // بطاقة إجراء إضافي
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderGrey),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryBlue, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
          ],
        ),
      ),
    );
  }

  // حوار إدخال حساب Gmail مخصص
  void _openCustomGmailDialog() {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
              width: 22,
              height: 22,
              errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: primaryBlue),
            ),
            const SizedBox(width: 8),
            const Text(
              'إضافة حساب Google',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل بريدك الرسمي في Google لربطه بالاشتراك:',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'اسمك (اختياري)',
                hintText: 'مثلاً: محمد علي',
                filled: true,
                fillColor: surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderGrey)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني (Gmail)*',
                hintText: 'user@gmail.com',
                filled: true,
                fillColor: surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderGrey)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final em = emailCtrl.text.trim();
              final nm = nameCtrl.text.trim();
              if (em.isEmpty || !em.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال بريد إلكتروني صحيح')),
                );
                return;
              }
              Navigator.pop(ctx);
              await _loginWithGoogleDirect(em, nm.isNotEmpty ? nm : em.split('@').first);
            },
            child: const Text('تأكيد وتسجيل الدخول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // إكمال تسجيل الدخول بحساب Google المختار
  Future<void> _loginWithGoogleDirect(String email, String displayName) async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final user = await _auth.signInWithGoogle(
        email: email,
        displayName: displayName,
        rememberMe: _rememberMe,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.emerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'مرحباً بك ${user.displayName}! تم تسجيل دخولك وربط حسابك بنجاح.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );

        Future.delayed(const Duration(milliseconds: 400), _proceedToApp);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = e.toString();
          _isError = true;
        });
      }
    }
  }

  // تسجيل الدخول العادي بالبريد
  Future<void> _handleEmailLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _statusMessage = 'يرجى إدخال بريد إلكتروني صالح';
        _isError = true;
      });
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _statusMessage = 'يرجى إدخال كلمة المرور';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      await _auth.signInWithEmail(
        email: email,
        password: password,
        rememberMe: _rememberMe,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _proceedToApp();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = e.toString();
          _isError = true;
        });
      }
    }
  }

  // إنشاء حساب جديد بالبريد
  Future<void> _handleSignUp() async {
    final name = _signupNameController.text.trim();
    final email = _signupEmailController.text.trim();
    final password = _signupPasswordController.text;
    final confirm = _signupConfirmPasswordController.text;

    if (name.isEmpty) {
      setState(() {
        _statusMessage = 'يرجى إدخال اسمك الكامل';
        _isError = true;
      });
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _statusMessage = 'يرجى إدخال بريد إلكتروني صحيح';
        _isError = true;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _statusMessage = 'كلمة المرور يجب أن لا تقل عن 6 أحرف';
        _isError = true;
      });
      return;
    }
    if (password != confirm) {
      setState(() {
        _statusMessage = 'كلمات المرور غير متطابقة';
        _isError = true;
      });
      return;
    }
    if (!_agreeTerms) {
      setState(() {
        _statusMessage = 'يرجى الموافقة على شروط الخدمة وسياسة الخصوصية';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      await _auth.registerWithEmail(
        name: name,
        email: email,
        password: password,
        rememberMe: _rememberMe,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _proceedToApp();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = e.toString();
          _isError = true;
        });
      }
    }
  }

  // الدخول السريع كزائر
  Future<void> _handleGuestLogin() async {
    setState(() => _isLoading = true);
    await _auth.signInAsGuest();
    if (mounted) {
      setState(() => _isLoading = false);
      _proceedToApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundWhite,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // شعار التطبيق والعنوان الرأسي (تصميم ويب حديث وعصري)
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [primaryBlue, Color(0xFF38BDF8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.28),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.download_for_offline_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Boykta Pro',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'سجّل دخولك لحفظ اشتراكك وسجل التحميلات السحابية',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // زر Google الرئيسي الرسمي (على طريقة المواقع الكبرى بنقرة واحدة)
                  _buildGoogleWebButton(),

                  const SizedBox(height: 22),

                  // فاصل: أو بالبريد الإلكتروني
                  Row(
                    children: [
                      const Expanded(child: Divider(color: borderGrey, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'أو بالبريد الإلكتروني',
                          style: TextStyle(fontSize: 12, color: textMuted.withOpacity(0.85), fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Expanded(child: Divider(color: borderGrey, thickness: 1)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // التبويب الحديث (تسجيل الدخول / إنشاء حساب)
                  _buildSegmentedTab(),

                  const SizedBox(height: 20),

                  // رسالة التنبيه إن وجدت
                  if (_statusMessage != null) _buildStatusBanner(),

                  // نموذج تسجيل الدخول أو إنشاء حساب
                  if (_activeTab == 0) _buildLoginForm() else _buildSignUpForm(),

                  const SizedBox(height: 24),

                  // تخطي كزائر
                  Center(
                    child: TextButton.icon(
                      onPressed: _isLoading ? null : _handleGuestLogin,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16, color: textMuted),
                      label: const Text(
                        'المتابعة كزائر مؤقتاً وتخطي التسجيل',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // شارة الحماية والأمان
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: Colors.emerald.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'حماية وتشفير 100% متوافق مع نظام الاشتراكات',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.emerald.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // زر Google الرسمي بنمط الويب
  Widget _buildGoogleWebButton() {
    return InkWell(
      onTap: _isLoading ? null : _openGoogleAccountPickerSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderGrey, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
              width: 22,
              height: 22,
              errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: primaryBlue, size: 26),
            ),
            const SizedBox(width: 12),
            const Text(
              'المتابعة باستخدام Google',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textDark,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'فوري وسهل',
                style: TextStyle(
                  fontSize: 10,
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // التبويب الحديث (تسجيل الدخول / إنشاء حساب)
  Widget _buildSegmentedTab() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderGrey),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _activeTab = 0;
                _statusMessage = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _activeTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'تسجيل الدخول',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _activeTab == 0 ? primaryBlue : textMuted,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _activeTab = 1;
                _statusMessage = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _activeTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'حساب جديد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _activeTab == 1 ? primaryBlue : textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // نموذج تسجيل الدخول
  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _loginEmailController,
          label: 'البريد الإلكتروني',
          hint: 'name@example.com',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _loginPasswordController,
          label: 'كلمة المرور',
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          isObscured: _loginObscure,
          onToggleObscure: () => setState(() => _loginObscure = !_loginObscure),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (v) => setState(() => _rememberMe = v ?? true),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('تذكرني دائماً', style: TextStyle(fontSize: 12, color: textDark)),
              ],
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يمكنك تسجيل الدخول مباشرة عبر Google لتجاوز كلمة المرور.')),
                );
              },
              child: const Text('نسيت كلمة المرور؟', style: TextStyle(fontSize: 12, color: primaryBlue, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildPrimaryButton(
          text: 'تسجيل الدخول',
          onTap: _handleEmailLogin,
        ),
      ],
    );
  }

  // نموذج إنشاء الحساب
  Widget _buildSignUpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          controller: _signupNameController,
          label: 'الاسم الكامل',
          hint: 'مثلاً: نافع وضاح',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _signupEmailController,
          label: 'البريد الإلكتروني',
          hint: 'name@example.com',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _signupPasswordController,
          label: 'كلمة المرور (6 أحرف فأكثر)',
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          isObscured: _signupObscure,
          onToggleObscure: () => setState(() => _signupObscure = !_signupObscure),
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _signupConfirmPasswordController,
          label: 'تأكيد كلمة المرور',
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          isObscured: _confirmObscure,
          onToggleObscure: () => setState(() => _confirmObscure = !_confirmObscure),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _agreeTerms,
                activeColor: primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (v) => setState(() => _agreeTerms = v ?? true),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'أوافق على شروط الخدمة وسياسة الخصوصية للاشتراك',
                style: TextStyle(fontSize: 11, color: textDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildPrimaryButton(
          text: 'إنشاء الحساب مجاناً',
          onTap: _handleSignUp,
        ),
      ],
    );
  }

  // حقل إدخال بتصميم ويب عصري
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isObscured = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderGrey),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(icon, color: textMuted, size: 19),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: isPassword && isObscured,
                  keyboardType: keyboardType,
                  style: const TextStyle(fontSize: 14, color: textDark),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(fontSize: 13, color: textMuted.withOpacity(0.6)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              if (isPassword)
                IconButton(
                  icon: Icon(
                    isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: textMuted,
                    size: 19,
                  ),
                  onPressed: onToggleObscure,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // الزر الرئيسي
  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
    );
  }

  // رسالة الحالة والأخطاء
  Widget _buildStatusBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _isError ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _isError ? Colors.red.shade200 : Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(
            _isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 18,
            color: _isError ? Colors.red.shade700 : Colors.green.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(
                fontSize: 12,
                color: _isError ? Colors.red.shade800 : Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
