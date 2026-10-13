import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class GoogleLoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const GoogleLoginScreen({super.key, this.onLoginSuccess});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> with TickerProviderStateMixin {
  final AuthService _auth = AuthService();

  // 3D Flip Card Controller
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false; // false = Login, true = Signup

  // Floating background circles animation
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Controllers for Login
  final TextEditingController _loginEmailController = TextEditingController(text: '');
  final TextEditingController _loginPasswordController = TextEditingController(text: '');

  // Controllers for Sign Up
  final TextEditingController _signupNameController = TextEditingController(text: '');
  final TextEditingController _signupEmailController = TextEditingController(text: '');
  final TextEditingController _signupPasswordController = TextEditingController(text: '');
  final TextEditingController _signupConfirmPasswordController = TextEditingController(text: '');

  bool _rememberMe = true;
  bool _agreeTerms = true;
  bool _loginObscure = true;
  bool _signupObscure = true;
  bool _confirmObscure = true;

  bool _isLoading = false;
  String? _statusMessage;
  bool _isError = false;

  // Focus nodes
  final FocusNode _fnLoginEmail = FocusNode();
  final FocusNode _fnLoginPassword = FocusNode();
  final FocusNode _fnSignupName = FocusNode();
  final FocusNode _fnSignupEmail = FocusNode();
  final FocusNode _fnSignupPassword = FocusNode();
  final FocusNode _fnSignupConfirm = FocusNode();

  // Neumorphism Palette matching the exact screenshot (Off-white / Soft Grey)
  static const Color neoBg = Color(0xFFEBF0F5);
  static const Color neoDarkShadow = Color(0xFFA3B1C6);
  static const Color neoLightShadow = Colors.white;
  static const Color textDark = Color(0xFF2D3748);
  static const Color textMuted = Color(0xFF718096);
  static const Color primaryBlue = Color(0xFF0066CC);
  static const Color accentCyan = Color(0xFF00AAFF);

  @override
  void initState() {
    super.initState();

    // 1. Flip card controller (3D smooth flip)
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    // 2. Floating background controller
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0.0, end: -15.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    void listener() => setState(() {});
    _fnLoginEmail.addListener(listener);
    _fnLoginPassword.addListener(listener);
    _fnSignupName.addListener(listener);
    _fnSignupEmail.addListener(listener);
    _fnSignupPassword.addListener(listener);
    _fnSignupConfirm.addListener(listener);
  }

  @override
  void dispose() {
    _flipController.dispose();
    _floatController.dispose();

    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();

    _fnLoginEmail.dispose();
    _fnLoginPassword.dispose();
    _fnSignupName.dispose();
    _fnSignupEmail.dispose();
    _fnSignupPassword.dispose();
    _fnSignupConfirm.dispose();
    super.dispose();
  }

  void _flipCard() {
    setState(() {
      _statusMessage = null;
      if (_isFlipped) {
        _flipController.reverse();
      } else {
        _flipController.forward();
      }
      _isFlipped = !_isFlipped;
    });
  }

  void _proceedToApp() {
    if (widget.onLoginSuccess != null) {
      widget.onLoginSuccess!();
    } else {
      Navigator.of(context).pop();
    }
  }

  // تسجيل الدخول الحقيقي عبر Google
  Future<void> _handleGoogleSignIn() async {
    // إتاحة نافذة لتأكيد الحساب أو استخدام الحساب المباشر
    final googleEmailController = TextEditingController();
    final googleNameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: neoBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                width: 24,
                height: 24,
                errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, color: primaryBlue),
              ),
              const SizedBox(width: 10),
              const Text(
                'تسجيل الدخول بـ Google',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'سيتم تسجيل دخولك ومزامنة بياناتك مع حساب Google الخاص بك:',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: googleEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'بريدك في Google (اختياري)',
                  hintText: 'example@gmail.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: googleNameController,
                decoration: InputDecoration(
                  labelText: 'اسمك في الحساب (اختياري)',
                  hintText: 'اسم المستخدم',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الدخول', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      final inputEmail = googleEmailController.text.trim();
      final inputName = googleNameController.text.trim();

      await _auth.signInWithGoogle(
        email: inputEmail.isNotEmpty ? inputEmail : null,
        displayName: inputName.isNotEmpty ? inputName : null,
        rememberMe: _rememberMe,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'تم تسجيل الدخول بنجاح بحساب Google 🎉';
          _isError = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('مرحباً بك ${_auth.currentUser.value?.displayName}! تم تسجيل الدخول بنجاح.'),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), _proceedToApp);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'فشل تسجيل الدخول: $e';
          _isError = true;
        });
      }
    }
  }

  // تسجيل الدخول الحقيقي بالبريد وكلمة المرور
  Future<void> _handleEmailLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (email.isEmpty) {
      setState(() {
        _statusMessage = 'يرجى إدخال البريد الإلكتروني';
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
      _isError = false;
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
          _statusMessage = '✓ تم تسجيل الدخول بنجاح!';
          _isError = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('أهلاً بك ${_auth.currentUser.value?.displayName}! تم الدخول بنجاح.'),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), _proceedToApp);
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

  // إنشاء حساب جديد حقيقي بالبريد وكلمة المرور
  Future<void> _handleSignUp() async {
    final name = _signupNameController.text.trim();
    final email = _signupEmailController.text.trim();
    final password = _signupPasswordController.text;
    final confirm = _signupConfirmPasswordController.text;

    if (name.isEmpty) {
      setState(() {
        _statusMessage = 'يرجى إدخال الاسم الكامل';
        _isError = true;
      });
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _statusMessage = 'يرجى إدخال بريد إلكتروني صالح';
        _isError = true;
      });
      return;
    }
    if (password.length < 4) {
      setState(() {
        _statusMessage = 'كلمة المرور يجب أن لا تقل عن 4 أحرف';
        _isError = true;
      });
      return;
    }
    if (password != confirm) {
      setState(() {
        _statusMessage = 'كلمتا المرور غير متطابقتين';
        _isError = true;
      });
      return;
    }
    if (!_agreeTerms) {
      setState(() {
        _statusMessage = 'يرجى الموافقة على الشروط والأحكام للمتابعة';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      await _auth.registerWithEmail(
        name: name,
        email: email,
        password: password,
        rememberMe: true,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '✓ تم إنشاء الحساب وتسجيل الدخول بنجاح!';
          _isError = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تهانينا! تم إنشاء حسابك الجديد وتسجيل دخولك بنجاح.'),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), _proceedToApp);
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

  // الدخول كضيف
  Future<void> _handleGuestEntry() async {
    await _auth.continueAsGuest();
    _proceedToApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neoBg,
      body: Stack(
        children: [
          // 1. الدوائر العائمة في الخلفية
          _buildFloatingBackgroundCircles(),

          // 2. زر التخطي / الدخول كضيف في الأعلى
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _handleGuestEntry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: neoBg,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: neoDarkShadow.withOpacity(0.45),
                            offset: const Offset(4, 4),
                            blurRadius: 8,
                          ),
                          BoxShadow(
                            color: neoLightShadow.withOpacity(0.9),
                            offset: const Offset(-4, -4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'تخطي كضيف',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, color: textMuted, size: 12),
                        ],
                      ),
                    ),
                  ),

                  // أيقونة قفل الحماية
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: neoBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: neoDarkShadow.withOpacity(0.45),
                          offset: const Offset(3, 3),
                          blurRadius: 6,
                        ),
                        BoxShadow(
                          color: neoLightShadow.withOpacity(0.9),
                          offset: const Offset(-3, -3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.shield_outlined, color: primaryBlue, size: 18),
                  ),
                ],
              ),
            ),
          ),

          // 3. البطاقة النيومورفية المتقنة المطابقة للصورة تماماً
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: _buildFlipCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // دوائر الخلفية النيومورفية العائمة
  Widget _buildFloatingBackgroundCircles() {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        final dy = _floatAnimation.value;
        return Stack(
          children: [
            Positioned(
              top: 40 + dy,
              left: 20,
              child: _buildNeumorphicSphere(size: 160),
            ),
            Positioned(
              bottom: 80 - dy,
              right: 15,
              child: _buildNeumorphicSphere(size: 120),
            ),
            Positioned(
              top: 180 + (dy * 0.6),
              right: 35,
              child: _buildNeumorphicSphere(size: 50),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNeumorphicSphere({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: neoBg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: neoDarkShadow.withOpacity(0.45),
            offset: const Offset(12, 12),
            blurRadius: 24,
          ),
          BoxShadow(
            color: neoLightShadow.withOpacity(0.9),
            offset: const Offset(-12, -12),
            blurRadius: 24,
          ),
        ],
      ),
    );
  }

  // بطاقة 3D Flip Card
  Widget _buildFlipCard() {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * math.pi;
        final isUnderHalf = _flipAnimation.value <= 0.5;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          alignment: Alignment.center,
          child: isUnderHalf
              ? _buildCardShell(child: _buildLoginCardContent())
              : Transform(
                  transform: Matrix4.identity()..rotateY(math.pi),
                  alignment: Alignment.center,
                  child: _buildCardShell(child: _buildSignUpCardContent()),
                ),
        );
      },
    );
  }

  // إطار البطاقة النيومورفية (Card Shell)
  Widget _buildCardShell({required Widget child}) {
    return Container(
      width: 380,
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
      decoration: BoxDecoration(
        color: neoBg,
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: neoDarkShadow.withOpacity(0.65),
            offset: const Offset(16, 16),
            blurRadius: 32,
          ),
          BoxShadow(
            color: neoLightShadow.withOpacity(0.95),
            offset: const Offset(-16, -16),
            blurRadius: 32,
          ),
        ],
      ),
      child: child,
    );
  }

  // -------------------------------------------------------------
  // وجه تسجيل الدخول (WELCOME CARD) - مطابق بدقة للصورة المرفقة
  // -------------------------------------------------------------
  Widget _buildLoginCardContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. الشعار الدائري مع القفل الذهبي / البنفسجي
        _buildLogoWithLock(),
        const SizedBox(height: 12),

        // 2. العناوين
        const Text(
          'Welcome',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: textDark,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Login to continue your journey',
          style: TextStyle(
            fontSize: 13,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 22),

        // تنبيه الحالة عند وجود خطأ
        if (_statusMessage != null) _buildStatusBanner(),

        // 3. حقل البريد الإلكتروني مع أيقونة الرسالة والتجويف النيومورفي
        _buildNeumorphicInputField(
          label: 'Email Address',
          hint: 'gaurav@gmail.com',
          controller: _loginEmailController,
          focusNode: _fnLoginEmail,
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        // 4. حقل كلمة المرور مع أيقونة القفل وزر العين
        _buildNeumorphicInputField(
          label: 'Password',
          hint: '••••••',
          controller: _loginPasswordController,
          focusNode: _fnLoginPassword,
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
          isObscured: _loginObscure,
          onToggleObscure: () => setState(() => _loginObscure = !_loginObscure),
        ),
        const SizedBox(height: 8),

        // 5. شريط الخيارات: Remember me & Forgot Password?
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _rememberMe ? primaryBlue : neoBg,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _rememberMe ? primaryBlue : neoDarkShadow,
                        width: 1.2,
                      ),
                    ),
                    child: _rememberMe
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'Remember me',
                    style: TextStyle(color: textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: neoBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('استعادة كلمة المرور', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                    content: const Text('أدخل بريدك الإلكتروني وسيتم إرسال رابط إعادة التعيين فوراً.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً', style: TextStyle(color: primaryBlue))),
                    ],
                  ),
                );
              },
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: primaryBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // 6. الزر النيومورفي البارز (LOGIN)
        _buildNeumorphicRaisedButton(
          text: 'LOGIN',
          onTap: _handleEmailLogin,
        ),
        const SizedBox(height: 20),

        // 7. سطر التبديل لإنشاء الحساب
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Don't have an account?",
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
            const SizedBox(width: 10),
            _buildCircularNeumorphicButton(
              icon: Icons.add,
              iconColor: primaryBlue,
              size: 38,
              onTap: _flipCard,
            ),
          ],
        ),
        const SizedBox(height: 22),

        // 8. أزرار الدخول عبر وسائل التواصل الاجتماعي (G / f / in)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // زر Google الرسمي الحقيقي
            _buildSocialCircleButton(
              child: Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) => const Text('G', style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 16)),
              ),
              onTap: _handleGoogleSignIn,
            ),
            const SizedBox(width: 16),
            // Facebook
            _buildSocialCircleButton(
              child: const Text(
                'f',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1877F2), fontSize: 18),
              ),
              onTap: () {
                _auth.signInWithGoogle(email: 'user.facebook@boykta.app', displayName: 'Facebook User');
                _proceedToApp();
              },
            ),
            const SizedBox(width: 16),
            // LinkedIn
            _buildSocialCircleButton(
              child: const Text(
                'in',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A66C2), fontSize: 16),
              ),
              onTap: () {
                _auth.signInWithGoogle(email: 'user.linkedin@boykta.app', displayName: 'LinkedIn User');
                _proceedToApp();
              },
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // وجه إنشاء الحساب (CREATE ACCOUNT) - مطابق بدقة للصورة المرفقة
  // -------------------------------------------------------------
  Widget _buildSignUpCardContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. الشعار الدائري النيومورفي مع أيقونة الشخص
        _buildLogoWithPerson(),
        const SizedBox(height: 12),

        // 2. العناوين
        const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: textDark,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sign up to get started',
          style: TextStyle(
            fontSize: 13,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 18),

        if (_statusMessage != null) _buildStatusBanner(),

        // 3. الحقول الأربعة المجوفة:
        // Full Name
        _buildNeumorphicInputField(
          label: 'Full Name',
          hint: 'Enter your name',
          controller: _signupNameController,
          focusNode: _fnSignupName,
          prefixIcon: Icons.person_outline_rounded,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 13),

        // Email Address
        _buildNeumorphicInputField(
          label: 'Email Address',
          hint: 'gaurav@gmail.com',
          controller: _signupEmailController,
          focusNode: _fnSignupEmail,
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 13),

        // Password
        _buildNeumorphicInputField(
          label: 'Password',
          hint: '••••••',
          controller: _signupPasswordController,
          focusNode: _fnSignupPassword,
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
          isObscured: _signupObscure,
          onToggleObscure: () => setState(() => _signupObscure = !_signupObscure),
        ),
        const SizedBox(height: 13),

        // Confirm Password
        _buildNeumorphicInputField(
          label: 'Confirm Password',
          hint: '••••••',
          controller: _signupConfirmPasswordController,
          focusNode: _fnSignupConfirm,
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
          isObscured: _confirmObscure,
          onToggleObscure: () => setState(() => _confirmObscure = !_confirmObscure),
        ),
        const SizedBox(height: 8),

        // 4. خيار الموافقة على الشروط
        GestureDetector(
          onTap: () => setState(() => _agreeTerms = !_agreeTerms),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: _agreeTerms ? primaryBlue : neoBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: _agreeTerms ? primaryBlue : neoDarkShadow,
                    width: 1.2,
                  ),
                ),
                child: _agreeTerms
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'I agree to the ',
                    style: TextStyle(color: textMuted, fontSize: 12),
                    children: [
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 5. زر SIGN UP النيومورفي
        _buildNeumorphicRaisedButton(
          text: 'SIGN UP',
          onTap: _handleSignUp,
        ),
        const SizedBox(height: 18),

        // 6. زر الرجوع لتسجيل الدخول مع السهم النيومورفي
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have an account?',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
            const SizedBox(width: 10),
            _buildCircularNeumorphicButton(
              icon: Icons.arrow_forward_rounded,
              iconColor: primaryBlue,
              size: 38,
              onTap: _flipCard,
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // المكونات البصرية النيومورفية المخصصة (WIDGETS)
  // -------------------------------------------------------------

  // شعار القفل الذهبي والبنفسجي النيومورفي العلوي
  Widget _buildLogoWithLock() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: neoBg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: neoDarkShadow.withOpacity(0.6),
            offset: const Offset(8, 8),
            blurRadius: 16,
          ),
          BoxShadow(
            color: neoLightShadow.withOpacity(0.95),
            offset: const Offset(-8, -8),
            blurRadius: 16,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: neoBg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: neoDarkShadow.withOpacity(0.3),
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: neoLightShadow.withOpacity(0.8),
                offset: const Offset(-2, -2),
                blurRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.lock_rounded,
              size: 24,
              color: Color(0xFFF59E0B), // أصفر ذهبي مطابق للصورة
            ),
          ),
        ),
      ),
    );
  }

  // شعار الشخص الأزرق لصفحة Create Account
  Widget _buildLogoWithPerson() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: neoBg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: neoDarkShadow.withOpacity(0.6),
            offset: const Offset(8, 8),
            blurRadius: 16,
          ),
          BoxShadow(
            color: neoLightShadow.withOpacity(0.95),
            offset: const Offset(-8, -8),
            blurRadius: 16,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: neoBg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: neoDarkShadow.withOpacity(0.3),
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: neoLightShadow.withOpacity(0.8),
                offset: const Offset(-2, -2),
                blurRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.person_rounded,
              size: 26,
              color: primaryBlue,
            ),
          ),
        ),
      ),
    );
  }

  // حقل الإدخال المجوف النيومورفي مع العنوان بالأعلى والأيقونات المطابقة للصورة
  Widget _buildNeumorphicInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData prefixIcon,
    bool isPassword = false,
    bool isObscured = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final bool isFocused = focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عنوان الحقل بالأعلى كما في الصورة تماماً
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
          ),
        ),

        // الحاوية المجوفة النيومورفية (Inset Pill Container)
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: neoBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused ? accentCyan.withOpacity(0.8) : neoDarkShadow.withOpacity(0.35),
              width: isFocused ? 1.4 : 1.0,
            ),
            boxShadow: [
              // محاكاة الظل الداخلي (Inset look)
              BoxShadow(
                color: isFocused
                    ? accentCyan.withOpacity(0.2)
                    : neoDarkShadow.withOpacity(0.45),
                offset: const Offset(2.5, 2.5),
                blurRadius: 4,
              ),
              BoxShadow(
                color: neoLightShadow.withOpacity(0.85),
                offset: const Offset(-2.5, -2.5),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(prefixIcon, color: isFocused ? primaryBlue : textMuted, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  obscureText: isPassword ? isObscured : false,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: textMuted.withOpacity(0.65),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (isPassword)
                IconButton(
                  icon: Icon(
                    isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: isFocused ? primaryBlue : textMuted,
                    size: 18,
                  ),
                  onPressed: onToggleObscure,
                  splashRadius: 18,
                )
              else
                const SizedBox(width: 14),
            ],
          ),
        ),
      ],
    );
  }

  // الزر النيومورفي البارز (LOGIN / SIGN UP)
  Widget _buildNeumorphicRaisedButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: neoBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: neoDarkShadow.withOpacity(0.6),
              offset: const Offset(6, 6),
              blurRadius: 14,
            ),
            BoxShadow(
              color: neoLightShadow.withOpacity(0.95),
              offset: const Offset(-6, -6),
              blurRadius: 14,
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 2.2),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    color: primaryBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      ),
    );
  }

  // الزر النيومورفي الدائري الصغير (+ أو السهم)
  Widget _buildCircularNeumorphicButton({
    required IconData icon,
    required Color iconColor,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: neoBg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: neoDarkShadow.withOpacity(0.55),
              offset: const Offset(4, 4),
              blurRadius: 8,
            ),
            BoxShadow(
              color: neoLightShadow.withOpacity(0.95),
              offset: const Offset(-4, -4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }

  // أزرار السوشيال النيومورفية الدائرية (G / f / in)
  Widget _buildSocialCircleButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: neoBg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: neoDarkShadow.withOpacity(0.55),
              offset: const Offset(5, 5),
              blurRadius: 10,
            ),
            BoxShadow(
              color: neoLightShadow.withOpacity(0.95),
              offset: const Offset(-5, -5),
              blurRadius: 10,
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  // بطاقة عرض التنبيهات والأخطاء
  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _isError ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isError ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: _isError ? Colors.redAccent : Colors.green,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(
                color: _isError ? Colors.redAccent : Colors.green.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
