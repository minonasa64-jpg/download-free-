import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class GoogleLoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const GoogleLoginScreen({super.key, this.onLoginSuccess});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginAccountItem {
  final String name;
  final String email;
  final String initial;
  final Color avatarBg;

  const _GoogleLoginAccountItem({
    required this.name,
    required this.email,
    required this.initial,
    required this.avatarBg,
  });
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> with TickerProviderStateMixin {
  final AuthService _auth = AuthService();

  // 3D Flip Card Animation Controller
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false; // false = Login, true = Signup

  // Floating background circles animation
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Electric glow sweep animation controller
  late AnimationController _electricController;

  // Controllers for Login
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  // Controllers for Sign Up
  final TextEditingController _signupNameController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupPasswordController = TextEditingController();
  final TextEditingController _signupConfirmPasswordController = TextEditingController();

  bool _rememberMe = true;
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

  // Neumorphism Palette matching the exact reference (Off-white / Soft Grey #e7ebf0)
  static const Color neoBg = Color(0xFFE7EBF0);
  static const Color neoDarkShadow = Color(0xFFA3B1C6);
  static const Color neoLightShadow = Colors.white;
  static const Color textDark = Color(0xFF303943);
  static const Color textMuted = Color(0xFF7C858E);
  static const Color primaryBlue = Color(0xFF087CFF);
  static const Color brandElectric = Color(0xFF00AAFF);

  // Accounts list matching the user's provided official screenshot
  final List<_GoogleLoginAccountItem> _googleAccounts = const [
    _GoogleLoginAccountItem(
      name: 'Mino Nasa',
      email: 'minonasa64@gmail.com',
      initial: 'M',
      avatarBg: Color(0xFFE65100),
    ),
    _GoogleLoginAccountItem(
      name: 'Normal mo',
      email: 'monormal81@gmail.com',
      initial: 'N',
      avatarBg: Color(0xFFC2185B),
    ),
    _GoogleLoginAccountItem(
      name: 'time bird',
      email: 'timebird14082007@gmail.com',
      initial: 't',
      avatarBg: Color(0xFF00796B),
    ),
    _GoogleLoginAccountItem(
      name: 'رابح واضح',
      email: 'wadhrabh09@gmail.com',
      initial: 'J',
      avatarBg: Color(0xFF00838F),
    ),
    _GoogleLoginAccountItem(
      name: 'times birds',
      email: 'timesbirds@gmail.com',
      initial: 't',
      avatarBg: Color(0xFF1976D2),
    ),
    _GoogleLoginAccountItem(
      name: 'نافع واضح',
      email: 'nafwadh616@gmail.com',
      initial: 'ن',
      avatarBg: Color(0xFF0288D1),
    ),
    _GoogleLoginAccountItem(
      name: 'nafea ouadah',
      email: 'nafeaouadah24@gmail.com',
      initial: 'n',
      avatarBg: Color(0xFF6D4C41),
    ),
  ];

  @override
  void initState() {
    super.initState();

    // 1. Flip card controller (3D smooth flip 1s)
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    // 2. Floating background controller
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0.0, end: -18.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // 3. Electric glow rotation controller
    _electricController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

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
    _electricController.dispose();
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

  // --------------------------------------------------------------------------
  // نافذة اختيار حساب Google وشاشة الأذونات مطابقة تماماً للصور المرفقة
  // --------------------------------------------------------------------------
  void _openGoogleAccountPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _GoogleAuthBottomSheet(
          accounts: _googleAccounts,
          onAccountConfirmed: (account) async {
            Navigator.pop(ctx);
            setState(() {
              _isLoading = true;
              _statusMessage = 'تم تسجيل الدخول بنجاح بحساب ${account.name}';
              _isError = false;
            });

            await _auth.signInWithGoogle(
              email: account.email,
              displayName: account.name,
              photoUrl: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(account.name)}&background=00838F&color=fff',
              rememberMe: _rememberMe,
            );

            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              setState(() => _isLoading = false);
              _proceedToApp();
            }
          },
        );
      },
    );
  }

  Future<void> _handleEmailLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = 'يرجى إدخال البريد الإلكتروني وكلمة المرور';
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
          _statusMessage = 'تم تسجيل الدخول بنجاح!';
          _isError = false;
        });
        await Future.delayed(const Duration(milliseconds: 400));
        _proceedToApp();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = e.toString().replaceAll('Exception:', '').trim();
          _isError = true;
        });
      }
    }
  }

  Future<void> _handleEmailSignUp() async {
    final name = _signupNameController.text.trim();
    final email = _signupEmailController.text.trim();
    final password = _signupPasswordController.text.trim();
    final confirm = _signupConfirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() {
        _statusMessage = 'يرجى ملء جميع الحقول المطلوبة';
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

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      await _auth.registerWithEmail(
        name: name,
        email: email,
        password: password,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'تم إنشاء الحساب بنجاح! مرحباً بك';
          _isError = false;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        _proceedToApp();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = e.toString().replaceAll('Exception:', '').trim();
          _isError = true;
        });
      }
    }
  }

  Future<void> _handleGuestEntry() async {
    setState(() => _isLoading = true);
    await _auth.continueAsGuest();
    if (mounted) {
      setState(() => _isLoading = false);
      _proceedToApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: neoBg,
      body: Stack(
        children: [
          // 1. الدوائر النيومورفية العائمة في الخلفية (Floating circles .bg1, .bg2, .bg3)
          _buildFloatingBackgroundCircles(),

          // 2. زر التخطي كضيف وشارة الحماية
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

                  // أيقونة الأمان المشفر
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

          // 3. بطاقة الـ 3D Flip Card النيومورفية الأساسية
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: _buildFlipCard(),
              ),
            ),
          ),

          // مؤشر التحميل العام
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: primaryBlue),
              ),
            ),
        ],
      ),
    );
  }

  // دوائر الخلفية النيومورفية العائمة (.bg1, .bg2, .bg3)
  Widget _buildFloatingBackgroundCircles() {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        final dy = _floatAnimation.value;
        return Stack(
          children: [
            Positioned(
              top: 50 + dy,
              left: 25,
              child: _buildNeumorphicSphere(size: 190),
            ),
            Positioned(
              bottom: 60 - dy,
              right: 25,
              child: _buildNeumorphicSphere(size: 130),
            ),
            Positioned(
              top: 170 + (dy * 0.7),
              right: 60,
              child: _buildNeumorphicSphere(size: 55),
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
            color: neoDarkShadow.withOpacity(0.55),
            offset: const Offset(15, 15),
            blurRadius: 30,
          ),
          BoxShadow(
            color: neoLightShadow.withOpacity(0.9),
            offset: const Offset(-15, -15),
            blurRadius: 30,
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

  // هيكل البطاقة النيومورفية المتقنة (.auth-card)
  Widget _buildCardShell({required Widget child}) {
    return Container(
      width: 400,
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
        color: neoBg,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: neoDarkShadow.withOpacity(0.65),
            offset: const Offset(20, 20),
            blurRadius: 40,
          ),
          BoxShadow(
            color: neoLightShadow.withOpacity(0.95),
            offset: const Offset(-20, -20),
            blurRadius: 40,
          ),
        ],
      ),
      child: child,
    );
  }

  // -------------------------------------------------------------
  // واجهة تسجيل الدخول (WELCOME)
  // -------------------------------------------------------------
  Widget _buildLoginCardContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. الشعار الدائري مع القفل الأزرق (.logo)
        _buildLogoCircle(icon: Icons.lock_outline_rounded),
        const SizedBox(height: 14),

        // 2. العناوين
        const Text(
          'Welcome',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            color: textDark,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Login to continue your journey',
          style: TextStyle(
            fontSize: 13,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 24),

        if (_statusMessage != null) _buildStatusBanner(),

        // 3. حقل Email Address مع التوهج الكهربائي
        _buildElectricInputField(
          label: 'Email Address',
          controller: _loginEmailController,
          focusNode: _fnLoginEmail,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),

        // 4. حقل Password مع التوهج الكهربائي وزر العين
        _buildElectricInputField(
          label: 'Password',
          controller: _loginPasswordController,
          focusNode: _fnLoginPassword,
          isPassword: true,
          isObscured: _loginObscure,
          onToggleObscure: () => setState(() => _loginObscure = !_loginObscure),
        ),
        const SizedBox(height: 12),

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
                    content: const Text('أدخل بريدك الإلكتروني وسيتم إرسال رابط استعادة الحساب فوراً.'),
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
        const SizedBox(height: 24),

        // 6. الزر الرئيسي (.main-btn) LOGIN
        _buildMainButton(
          text: 'Login',
          onTap: _handleEmailLogin,
        ),
        const SizedBox(height: 22),

        // 7. زر التبديل (.switch-area مع .switch-circle)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Don't have an account?",
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
            const SizedBox(width: 12),
            _buildSwitchCircleButton(
              icon: Icons.add,
              onTap: _flipCard,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 8. زر تسجيل الدخول المباشر بحساب Google الرسمي (المطابق للصورة)
        _buildOfficialGoogleButton(),
      ],
    );
  }

  // -------------------------------------------------------------
  // واجهة إنشاء الحساب (CREATE ACCOUNT)
  // -------------------------------------------------------------
  Widget _buildSignUpCardContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. الشعار الدائري مع أيقونة المستخدم (.logo)
        _buildLogoCircle(icon: Icons.person_outline_rounded),
        const SizedBox(height: 14),

        // 2. العناوين
        const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            color: textDark,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Start your journey with us',
          style: TextStyle(
            fontSize: 13,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 20),

        if (_statusMessage != null) _buildStatusBanner(),

        // 3. الحقول الأربعة مع التوهج الكهربائي
        _buildElectricInputField(
          label: 'Full Name',
          controller: _signupNameController,
          focusNode: _fnSignupName,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 14),

        _buildElectricInputField(
          label: 'Email Address',
          controller: _signupEmailController,
          focusNode: _fnSignupEmail,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        _buildElectricInputField(
          label: 'Password',
          controller: _signupPasswordController,
          focusNode: _fnSignupPassword,
          isPassword: true,
          isObscured: _signupObscure,
          onToggleObscure: () => setState(() => _signupObscure = !_signupObscure),
        ),
        const SizedBox(height: 14),

        _buildElectricInputField(
          label: 'Confirm Password',
          controller: _signupConfirmPasswordController,
          focusNode: _fnSignupConfirm,
          isPassword: true,
          isObscured: _confirmObscure,
          onToggleObscure: () => setState(() => _confirmObscure = !_confirmObscure),
        ),
        const SizedBox(height: 22),

        // 4. الزر الرئيسي CREATE ACCOUNT
        _buildMainButton(
          text: 'CREATE ACCOUNT',
          onTap: _handleEmailSignUp,
        ),
        const SizedBox(height: 22),

        // 5. زر التبديل للعودة لتسجيل الدخول
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have an account?',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
            const SizedBox(width: 12),
            _buildSwitchCircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: _flipCard,
            ),
          ],
        ),
      ],
    );
  }

  // الشعار الدائري النيومورفي (.logo)
  Widget _buildLogoCircle({required IconData icon}) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: neoBg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: neoDarkShadow.withOpacity(0.65),
            offset: const Offset(9, 9),
            blurRadius: 18,
          ),
          BoxShadow(
            color: neoLightShadow.withOpacity(0.95),
            offset: const Offset(-9, -9),
            blurRadius: 18,
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: primaryBlue, size: 34),
      ),
    );
  }

  // حقل الإدخال مع التوهج الكهربائي والحدود الدوارة (.input-group, .electric-border, .electric-glow)
  Widget _buildElectricInputField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    bool isPassword = false,
    bool isObscured = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isFocused = focusNode.hasFocus;

    return AnimatedBuilder(
      animation: _electricController,
      builder: (context, child) {
        return Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: brandElectric.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Stack(
            children: [
              // حدود كهربائية دوارة عند التركيز
              if (isFocused)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: SweepGradient(
                        transform: GradientRotation(_electricController.value * 2 * math.pi),
                        colors: const [
                          Colors.transparent,
                          Color(0xFF00EAFF),
                          Color(0xFF00AAFF),
                          Color(0xFF006CFF),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.25, 0.45, 0.65, 1.0],
                      ),
                    ),
                  ),
                ),

              // التجويف الداخلي للنيومورفيزم
              Positioned.fill(
                margin: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                    color: neoBg,
                    borderRadius: BorderRadius.circular(16),
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
                ),
              ),

              // حقل النص والتسمية التفاعلية
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    obscureText: isPassword && isObscured,
                    keyboardType: keyboardType,
                    style: const TextStyle(color: textDark, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      labelText: label,
                      labelStyle: TextStyle(
                        color: isFocused ? primaryBlue : textMuted,
                        fontSize: 14,
                      ),
                      suffixIcon: isPassword
                          ? IconButton(
                              icon: Icon(
                                isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: textMuted,
                                size: 20,
                              ),
                              onPressed: onToggleObscure,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // الزر النيومورفي الرئيسي (.main-btn)
  Widget _buildMainButton({required String text, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          color: neoBg,
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: neoDarkShadow.withOpacity(0.65),
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
          child: Text(
            text,
            style: const TextStyle(
              color: primaryBlue,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }

  // الزر الدائري للتبديل (.switch-circle)
  Widget _buildSwitchCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: neoBg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: neoDarkShadow.withOpacity(0.65),
              offset: const Offset(7, 7),
              blurRadius: 14,
            ),
            BoxShadow(
              color: neoLightShadow.withOpacity(0.95),
              offset: const Offset(-7, -7),
              blurRadius: 14,
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, color: primaryBlue, size: 22),
        ),
      ),
    );
  }

  // زر تسجيل الدخول الرسمي عبر Google (يفتح الشاشة المطابقة للصور المرفقة)
  Widget _buildOfficialGoogleButton() {
    return GestureDetector(
      onTap: _openGoogleAccountPickerSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: neoBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: neoDarkShadow.withOpacity(0.55),
              offset: const Offset(6, 6),
              blurRadius: 12,
            ),
            BoxShadow(
              color: neoLightShadow.withOpacity(0.95),
              offset: const Offset(-6, -6),
              blurRadius: 12,
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
              errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, color: primaryBlue, size: 26),
            ),
            const SizedBox(width: 10),
            const Text(
              'تسجيل الدخول باستخدام Google',
              style: TextStyle(
                color: textDark,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _isError ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isError ? Colors.red.shade300 : Colors.green.shade300,
        ),
      ),
      child: Text(
        _statusMessage!,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _isError ? Colors.red.shade800 : Colors.green.shade800,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================================
// شاشات Google الرسمية (اختيار حساب + منح الأذونات) المطابقة للصور المرفقة بدقة 100%
// ============================================================================
class _GoogleAuthBottomSheet extends StatefulWidget {
  final List<_GoogleLoginAccountItem> accounts;
  final ValueChanged<_GoogleLoginAccountItem> onAccountConfirmed;

  const _GoogleAuthBottomSheet({
    required this.accounts,
    required this.onAccountConfirmed,
  });

  @override
  State<_GoogleAuthBottomSheet> createState() => _GoogleAuthBottomSheetState();
}

class _GoogleAuthBottomSheetState extends State<_GoogleAuthBottomSheet> {
  // 0 = شاشة اختيار الحساب (Screenshot 1)
  // 1 = شاشة الأذونات والموافقة (Screenshot 2)
  int _step = 0;
  _GoogleLoginAccountItem? _selectedAccount;

  // ألوان Google الرسمية للوضع الليلي
  static const Color googleDarkBg = Color(0xFF131314);
  static const Color googleSurfaceDark = Color(0xFF1E1F20);
  static const Color googleBorderDark = Color(0xFF3C4043);
  static const Color googleBlue = Color(0xFF8AB4F8);

  void _onSelectAccount(_GoogleLoginAccountItem account) {
    setState(() {
      _selectedAccount = account;
      _step = 1;
    });
  }

  void _showAddCustomAccountDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: googleSurfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('إضافة حساب Google آخر', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'example@gmail.com',
                hintStyle: TextStyle(color: Colors.white30),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'اسم المستخدم',
                hintStyle: TextStyle(color: Colors.white30),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: googleBlue),
            onPressed: () {
              final email = emailCtrl.text.trim();
              final name = nameCtrl.text.trim();
              if (email.isNotEmpty && email.contains('@')) {
                Navigator.pop(ctx);
                _onSelectAccount(_GoogleLoginAccountItem(
                  name: name.isNotEmpty ? name : email.split('@').first,
                  email: email,
                  initial: email[0].toUpperCase(),
                  avatarBg: const Color(0xFF00796B),
                ));
              }
            },
            child: const Text('متابعة', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: googleDarkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مقبض النافذة العلوي
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // محتوى الشاشة التفاعلي
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  child: _step == 0 ? _buildStep1AccountChooser() : _buildStep2ConsentScreen(),
                ),
              ),

              // روابط التذييل الرسمية (العربية • المساعدة • الخصوصية • البنود)
              _buildGoogleFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // الشاشة الأولى: اختيار حساب (مطابقة تماماً للصورة 1)
  // -------------------------------------------------------------
  Widget _buildStep1AccountChooser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // الرأسية: شعار Google وشعار Boykta Pro
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                  width: 22,
                  height: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'تسجيل الدخول باستخدام Google',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // أيقونة تطبيق Boykta Pro في مربع تيل/سماوي
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF00838F),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // العنوان الكبير
        const Text(
          'اختيار حساب',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),

        // المتابعة إلى Boykta Pro
        const Text(
          'المتابعة إلى Boykta Pro',
          style: TextStyle(
            color: googleBlue,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),

        // قائمة الحسابات المطابقة للصورة المرفقة
        Container(
          decoration: BoxDecoration(
            color: googleDarkBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (int i = 0; i < widget.accounts.length; i++) ...[
                _buildAccountListItem(widget.accounts[i]),
                if (i < widget.accounts.length - 1)
                  const Divider(color: Color(0xFF2B2C2F), height: 1),
              ],

              const Divider(color: Color(0xFF2B2C2F), height: 1),

              // خيار إضافة حساب آخر
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2B2C2F),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white70, size: 20),
                ),
                title: const Text(
                  'استخدام حساب آخر',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: _showAddCustomAccountDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // عنصر حساب في القائمة
  Widget _buildAccountListItem(_GoogleLoginAccountItem account) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      onTap: () => _onSelectAccount(account),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: account.avatarBg,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            account.initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
      title: Text(
        account.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        account.email,
        style: const TextStyle(
          color: Color(0xFF9AA0A6),
          fontSize: 12.5,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // الشاشة الثانية: شاشة الأذونات والموافقة (مطابقة تماماً للصورة 2)
  // -------------------------------------------------------------
  Widget _buildStep2ConsentScreen() {
    final account = _selectedAccount!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // شعار Boykta Pro في الأعلى
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00838F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // العنوان: تسجيل الدخول إلى "Boykta Pro"
        const Text(
          'تسجيل الدخول إلى',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          '"Boykta Pro"',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // كبسولة الحساب المختار (قابلة للضغط للرجوع لاختيار حساب آخر)
        GestureDetector(
          onTap: () => setState(() => _step = 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: googleSurfaceDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: googleBorderDark),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_drop_down, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  account.email,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: account.avatarBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      account.initial,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),

        // نص إشعار الإذن
        const Text(
          'ستسمح Google بوصول Boykta Pro إلى هذه المعلومات عنك',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),

        // العنصر الأول: الاسم وصورة الملف الشخصي
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.account_circle_outlined, color: Colors.white70, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'الاسم وصورة الملف الشخصي',
                    style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // العنصر الثاني: عنوان البريد الإلكتروني
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.mail_outline_rounded, color: Colors.white70, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.email,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'عنوان البريد الإلكتروني',
                    style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // النصوص التوضيحية وسياسة الخصوصية
        const Text(
          'يُرجى مراجعة سياسة الخصوصية وبنود الخدمة لدى Boykta Pro للتعرّف على طريقة Boykta Pro في معالجة بياناتك وحمايتها.',
          style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'لإجراء التغييرات في أي وقت، يُرجى الانتقال إلى حسابك على Google.',
          style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 12),
        ),
        const SizedBox(height: 8),
        const Text(
          'مزيد من المعلومات حول ميزة "تسجيل الدخول باستخدام حساب Google"',
          style: TextStyle(color: googleBlue, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 28),

        // الأزرار: [ متابعة ] و [ إلغاء ] كبسولية جانب إلى جانب
        Row(
          children: [
            // زر المتابعة
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: googleSurfaceDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  side: const BorderSide(color: googleBorderDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => widget.onAccountConfirmed(account),
                child: const Text(
                  'متابعة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // زر الإلغاء
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: googleBorderDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => setState(() => _step = 0),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // تذييل الصفحة الرسمي
  Widget _buildGoogleFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      border: const Border(top: BorderSide(color: Color(0xFF242526))),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('العربية', style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 12)),
              Icon(Icons.arrow_drop_down, color: Color(0xFF9AA0A6), size: 16),
            ],
          ),
          Row(
            children: [
              Text('المساعدة', style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 12)),
              SizedBox(width: 16),
              Text('الخصوصية', style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 12)),
              SizedBox(width: 16),
              Text('البنود', style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
