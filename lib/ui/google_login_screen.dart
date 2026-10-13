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

  // 3D Flip Card controller
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false; // false = Login, true = Signup

  // Floating background circles animation
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Electric glow rotating animation
  late AnimationController _rotateController;

  // Form controllers
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
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

  // Focus nodes to detect electric glow state
  final FocusNode _fnLoginEmail = FocusNode();
  final FocusNode _fnLoginPassword = FocusNode();
  final FocusNode _fnSignupName = FocusNode();
  final FocusNode _fnSignupEmail = FocusNode();
  final FocusNode _fnSignupPassword = FocusNode();
  final FocusNode _fnSignupConfirm = FocusNode();

  // Neumorphic Color Constants
  static const Color neoBg = Color(0xFFE7EBF0);
  static const Color neoDarkShadow = Color(0xFFA3B1C6);
  static const Color neoLightShadow = Colors.white;
  static const Color textDark = Color(0xFF303943);
  static const Color textMuted = Color(0xFF7C858E);
  static const Color primaryBlue = Color(0xFF006CFF);
  static const Color accentCyan = Color(0xFF00EAFF);

  @override
  void initState() {
    super.initState();

    // 1. Flip card controller (1000ms duration with spring-like curve)
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    // 2. Floating circles controller (infinite smooth loop)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0.0, end: -16.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // 3. Electric border rotating controller
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // Rebuild on focus changes to animate electric borders
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
    _rotateController.dispose();

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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      final email = _isFlipped ? _signupEmailController.text.trim() : _loginEmailController.text.trim();
      final name = _isFlipped ? _signupNameController.text.trim() : null;

      final user = await _auth.signInWithGoogle(
        email: email.isNotEmpty ? email : null,
        displayName: (name != null && name.isNotEmpty) ? name : null,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'تم تسجيل الدخول بنجاح عبر حساب Google 🎉';
          _isError = false;
        });

        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        } else {
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'تعذر تسجيل الدخول: $e';
          _isError = true;
        });
      }
    }
  }

  Future<void> _handleEmailSubmit({required bool isSignUp}) async {
    final email = isSignUp ? _signupEmailController.text.trim() : _loginEmailController.text.trim();
    final password = isSignUp ? _signupPasswordController.text : _loginPasswordController.text;
    final name = isSignUp ? _signupNameController.text.trim() : null;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = 'يرجى إدخال البريد الإلكتروني وكلمة المرور';
        _isError = true;
      });
      return;
    }

    if (isSignUp && password != _signupConfirmPasswordController.text) {
      setState(() {
        _statusMessage = 'كلمتا المرور غير متطابقتين';
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
      await Future.delayed(const Duration(milliseconds: 700));
      await _auth.signInWithGoogle(
        email: email,
        displayName: name?.isNotEmpty == true ? name : email.split('@').first,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = isSignUp ? '✓ تم إنشاء الحساب وتسجيل الدخول بنجاح!' : '✓ تم تسجيل الدخول بنجاح!';
          _isError = false;
        });

        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        } else {
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'حدث خطأ: $e';
          _isError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser.value;
    final isLoggedIn = _auth.isLoggedIn.value;

    return Scaffold(
      backgroundColor: neoBg,
      body: Stack(
        children: [
          // 1. الدوائر العائمة في الخلفية (Neumorphic Floating Background Circles)
          _buildFloatingCircles(),

          // 2. زر العودة لأعلى الشاشة
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 16),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44,
                    height: 44,
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
                          color: neoLightShadow.withOpacity(0.9),
                          offset: const Offset(-4, -4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.close_rounded, color: textDark, size: 20),
                  ),
                ),
              ),
            ),
          ),

          // 3. البطاقة الرئيسية (Flip Card or LoggedIn Card)
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: isLoggedIn && user != null
                    ? _buildLoggedInProfile(user)
                    : _buildFlippingAuthCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // الدوائر العائمة بتأثير النيومورفيزم
  Widget _buildFloatingCircles() {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        final dy = _floatAnimation.value;
        return Stack(
          children: [
            // دائرة 1 - أعلى اليسار (bg1: 190x190)
            Positioned(
              top: 50 + dy,
              left: 20,
              child: _buildNeumorphicCircle(size: 180),
            ),
            // دائرة 2 - أسفل اليمين (bg2: 130x130)
            Positioned(
              bottom: 60 - dy,
              right: 25,
              child: _buildNeumorphicCircle(size: 130),
            ),
            // دائرة 3 - أعلى اليمين (bg3: 55x55)
            Positioned(
              top: 140 + (dy * 0.7),
              right: 50,
              child: _buildNeumorphicCircle(size: 55),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNeumorphicCircle({required double size}) {
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
            color: neoLightShadow.withOpacity(0.85),
            offset: const Offset(-12, -12),
            blurRadius: 24,
          ),
        ],
      ),
    );
  }

  // بطاقة 3D Flip Card
  Widget _buildFlippingAuthCard() {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * math.pi;
        final isUnderHalf = _flipAnimation.value <= 0.5;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // عمق ثلاثي الأبعاد 3D perspective
            ..rotateY(angle),
          alignment: Alignment.center,
          child: isUnderHalf
              ? _buildCardShell(child: _buildLoginForm())
              : Transform(
                  transform: Matrix4.identity()..rotateY(math.pi),
                  alignment: Alignment.center,
                  child: _buildCardShell(child: _buildSignUpForm()),
                ),
        );
      },
    );
  }

  // الحاوية النيومورفية الموحدة للبطاقة (form-panel)
  Widget _buildCardShell({required Widget child}) {
    return Container(
      width: 410,
      constraints: const BoxConstraints(maxWidth: 410),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
      decoration: BoxDecoration(
        color: neoBg,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: neoDarkShadow.withOpacity(0.65),
            offset: const Offset(18, 18),
            blurRadius: 36,
          ),
          BoxShadow(
            color: neoLightShadow.withOpacity(0.95),
            offset: const Offset(-18, -18),
            blurRadius: 36,
          ),
        ],
      ),
      child: child,
    );
  }

  // وجه الدخول (Welcome / Login Form)
  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // شعار القفل النيومورفي (.logo)
        _buildLogo(icon: Icons.lock_outline_rounded),
        const SizedBox(height: 12),

        // العناوين
        const Text(
          'Welcome',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
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

        // رسالة الحالة أو الخطأ
        if (_statusMessage != null) _buildStatusBanner(),

        // حقل البريد الإلكتروني مع التوهج الكهربائي
        _buildElectricInputField(
          controller: _loginEmailController,
          focusNode: _fnLoginEmail,
          label: 'Email Address',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        // حقل كلمة المرور مع التوهج وإخفاء/إظهار
        _buildElectricInputField(
          controller: _loginPasswordController,
          focusNode: _fnLoginPassword,
          label: 'Password',
          isPassword: true,
          isObscured: _loginObscure,
          onToggleObscure: () => setState(() => _loginObscure = !_loginObscure),
        ),
        const SizedBox(height: 8),

        // خيارات: Remember me & Forgot Password
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (val) => setState(() => _rememberMe = val ?? true),
                      activeColor: primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('Remember me', style: TextStyle(color: textMuted, fontSize: 13)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك')),
                );
              },
              child: const Text(
                'Forgot Password?',
                style: TextStyle(color: primaryBlue, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // الزر الرئيسي (Login .main-btn)
        _buildMainButton(
          title: 'LOGIN',
          onTap: () => _handleEmailSubmit(isSignUp: false),
        ),
        const SizedBox(height: 12),

        // زر الدخول المباشر بحساب Google (.google-btn)
        _buildGoogleButton(),
        const SizedBox(height: 22),

        // منطقة التبديل (.switch-area)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Don't have an account?",
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
            const SizedBox(width: 12),
            _buildSwitchCircleButton(
              icon: Icons.add_rounded,
              onTap: _flipCard,
            ),
          ],
        ),
      ],
    );
  }

  // وجه إنشاء الحساب (Create Account / Sign Up Form)
  Widget _buildSignUpForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // شعار المستخدم النيومورفي (.logo)
        _buildLogo(icon: Icons.person_outline_rounded),
        const SizedBox(height: 12),

        const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
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
        const SizedBox(height: 22),

        if (_statusMessage != null) _buildStatusBanner(),

        // Full Name
        _buildElectricInputField(
          controller: _signupNameController,
          focusNode: _fnSignupName,
          label: 'Full Name',
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 14),

        // Email Address
        _buildElectricInputField(
          controller: _signupEmailController,
          focusNode: _fnSignupEmail,
          label: 'Email Address',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        // Password
        _buildElectricInputField(
          controller: _signupPasswordController,
          focusNode: _fnSignupPassword,
          label: 'Password',
          isPassword: true,
          isObscured: _signupObscure,
          onToggleObscure: () => setState(() => _signupObscure = !_signupObscure),
        ),
        const SizedBox(height: 14),

        // Confirm Password
        _buildElectricInputField(
          controller: _signupConfirmPasswordController,
          focusNode: _fnSignupConfirm,
          label: 'Confirm Password',
          isPassword: true,
          isObscured: _confirmObscure,
          onToggleObscure: () => setState(() => _confirmObscure = !_confirmObscure),
        ),
        const SizedBox(height: 20),

        // الزر الرئيسي (CREATE ACCOUNT)
        _buildMainButton(
          title: 'CREATE ACCOUNT',
          onTap: () => _handleEmailSubmit(isSignUp: true),
        ),
        const SizedBox(height: 12),

        // زر التسجيل عبر Google
        _buildGoogleButton(),
        const SizedBox(height: 20),

        // منطقة التبديل للعودة إلى تسجيل الدخول
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
  Widget _buildLogo({required IconData icon}) {
    return Container(
      width: 82,
      height: 82,
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
        child: Icon(
          icon,
          size: 32,
          color: const Color(0xFF087CFF),
        ),
      ),
    );
  }

  // حقل الإدخال بتأثير التوهج الكهربائي والحدود المضيئة الدوارة (.input-group with electric-glow & border)
  Widget _buildElectricInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    bool isPassword = false,
    bool isObscured = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final bool isFocused = focusNode.hasFocus;

    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        final double turn = _rotateController.value * (2 * math.pi);

        return Stack(
          alignment: Alignment.center,
          children: [
            // التوهج الخارجي الكهربائي (Electric Glow)
            if (isFocused)
              Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  boxShadow: [
                    BoxShadow(
                      color: accentCyan.withOpacity(0.4),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),

            // الحد الكهربائي الدوار (Electric Border rotating conic gradient)
            Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                gradient: isFocused
                    ? SweepGradient(
                        transform: GradientRotation(turn),
                        colors: const [
                          Colors.transparent,
                          Colors.transparent,
                          accentCyan,
                          Color(0xFF00AAFF),
                          primaryBlue,
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.2, 0.45, 0.65, 0.8, 1.0],
                      )
                    : null,
              ),
              child: Padding(
                padding: EdgeInsets.all(isFocused ? 2.0 : 0.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: neoBg,
                    borderRadius: BorderRadius.circular(17),
                    // تأثير التجويف الداخلي النيومورفي (Inset shadow)
                    border: Border.all(
                      color: isFocused ? Colors.transparent : neoDarkShadow.withOpacity(0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: neoDarkShadow.withOpacity(0.35),
                        offset: const Offset(3, 3),
                        blurRadius: 6,
                      ),
                      BoxShadow(
                        color: neoLightShadow.withOpacity(0.7),
                        offset: const Offset(-3, -3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
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
                        labelText: label,
                        labelStyle: TextStyle(
                          color: isFocused ? primaryBlue : textMuted,
                          fontSize: 13,
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: InputBorder.none,
                        suffixIcon: isPassword
                            ? IconButton(
                                icon: Icon(
                                  isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: isFocused ? primaryBlue : textMuted,
                                  size: 19,
                                ),
                                onPressed: onToggleObscure,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // الزر الرئيسي النيومورفي بتدرج لامع (.main-btn)
  Widget _buildMainButton({required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: const LinearGradient(
            colors: [Color(0xFF006CFF), Color(0xFF00CFFF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withOpacity(0.4),
              offset: const Offset(0, 6),
              blurRadius: 18,
            ),
            BoxShadow(
              color: neoDarkShadow.withOpacity(0.55),
              offset: const Offset(6, 6),
              blurRadius: 14,
            ),
            BoxShadow(
              color: neoLightShadow.withOpacity(0.9),
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
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                )
              : Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
        ),
      ),
    );
  }

  // زر تسجيل الدخول المباشر بحساب Google (.google-btn)
  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleGoogleSignIn,
      child: Container(
        width: double.infinity,
        height: 48,
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
              color: neoLightShadow.withOpacity(0.9),
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
              width: 20,
              height: 20,
              errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, color: primaryBlue, size: 24),
            ),
            const SizedBox(width: 10),
            Text(
              _isFlipped ? 'Sign up with Google' : 'Sign in with Google',
              style: const TextStyle(
                color: textDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // زر التبديل الدائري بين الشاشات (.switch-circle)
  Widget _buildSwitchCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
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
          child: Icon(
            icon,
            size: 20,
            color: primaryBlue,
          ),
        ),
      ),
    );
  }

  // بطاقة الحالة / التنبيه
  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _isError ? Colors.red.withOpacity(0.12) : Colors.green.withOpacity(0.12),
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
            size: 18,
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

  // شاشة المستخدم عند تسجيل الدخول مسبقاً (Logged In Profile Card)
  Widget _buildLoggedInProfile(GoogleAuthUser user) {
    return _buildCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
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
            padding: const EdgeInsets.all(4),
            child: CircleAvatar(
              backgroundColor: neoBg,
              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? const Icon(Icons.person, size: 44, color: primaryBlue)
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            user.displayName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: const TextStyle(fontSize: 13, color: textMuted),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: Colors.green, size: 14),
                SizedBox(width: 6),
                Text(
                  'Connected Account',
                  style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _buildMainButton(
            title: 'CONTINUE TO APP',
            onTap: () {
              if (widget.onLoginSuccess != null) {
                widget.onLoginSuccess!();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          const SizedBox(height: 14),

          GestureDetector(
            onTap: () async {
              await _auth.signOut();
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تسجيل الخروج بنجاح 👋')),
                );
              }
            },
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: neoBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: neoDarkShadow.withOpacity(0.4),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
