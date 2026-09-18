import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../services/backend_service.dart';
import 'vault_screen.dart';

class CalculatorVaultScreen extends StatefulWidget {
  const CalculatorVaultScreen({super.key});

  @override
  State<CalculatorVaultScreen> createState() => _CalculatorVaultScreenState();
}

class _CalculatorVaultScreenState extends State<CalculatorVaultScreen> {
  final BackendService _backend = BackendService();

  String _display = '0';
  String _expression = '';
  double _num1 = 0;
  double _num2 = 0;
  String _operator = '';
  bool _isNewNumber = true;

  void _onNumberPressed(String number) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_display == '0' || _isNewNumber) {
        _display = number;
        _isNewNumber = false;
      } else {
        if (_display.length < 10) {
          _display += number;
        }
      }
    });
  }

  void _onDotPressed() {
    HapticFeedback.lightImpact();
    if (!_display.contains('.')) {
      setState(() {
        _display += '.';
        _isNewNumber = false;
      });
    }
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _display = '0';
      _expression = '';
      _num1 = 0;
      _num2 = 0;
      _operator = '';
      _isNewNumber = true;
    });
  }

  void _onPlusMinus() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_display != '0') {
        if (_display.startsWith('-')) {
          _display = _display.substring(1);
        } else {
          _display = '-$_display';
        }
      }
    });
  }

  void _onPercent() {
    HapticFeedback.lightImpact();
    setState(() {
      double val = (double.tryParse(_display) ?? 0) / 100;
      _display = val.toString();
    });
  }

  void _onOperatorPressed(String op) {
    HapticFeedback.lightImpact();
    setState(() {
      _num1 = double.tryParse(_display) ?? 0;
      _operator = op;
      _expression = '$_display $op';
      _isNewNumber = true;
    });
  }

  Future<void> _onEqualPressed() async {
    HapticFeedback.mediumImpact();

    // 1. فحص الشفرة السرية للخزنة
    // إذا كان الرقم المدخل في الشاشة 4 أرقام ويطابق رمز PIN
    final candidatePin = _display.replaceAll('.', '').trim();
    if (candidatePin.length == 4) {
      final isPinValid = await _backend.verifyVaultPin(candidatePin);
      if (isPinValid && mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VaultScreen()),
        );
        return;
      }
    }

    // 2. الحساب الرياضي الطبيعي إذا لم تكن شفرة الخزنة
    if (_operator.isEmpty) return;

    _num2 = double.tryParse(_display) ?? 0;
    double result = 0;

    switch (_operator) {
      case '+':
        result = _num1 + _num2;
        break;
      case '-':
        result = _num1 - _num2;
        break;
      case '×':
        result = _num1 * _num2;
        break;
      case '÷':
        result = _num2 != 0 ? _num1 / _num2 : 0;
        break;
    }

    setState(() {
      _expression = '$_num1 $_operator $_num2 =';
      String resStr = result.toString();
      if (resStr.endsWith('.0')) {
        resStr = resStr.substring(0, resStr.length - 2);
      }
      _display = resStr;
      _operator = '';
      _isNewNumber = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'آلة حاسبة',
          style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // شاشة العرض الرياضية
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _expression,
                      style: const TextStyle(color: Colors.white38, fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _display,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // لوحة المفاتيح
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF17171E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  _buildRow(['C', '±', '%', '÷'], [Colors.white24, Colors.white24, Colors.white24, AppColors.cyan]),
                  const SizedBox(height: 12),
                  _buildRow(['7', '8', '9', '×'], [Colors.white10, Colors.white10, Colors.white10, AppColors.cyan]),
                  const SizedBox(height: 12),
                  _buildRow(['4', '5', '6', '-'], [Colors.white10, Colors.white10, Colors.white10, AppColors.cyan]),
                  const SizedBox(height: 12),
                  _buildRow(['1', '2', '3', '+'], [Colors.white10, Colors.white10, Colors.white10, AppColors.cyan]),
                  const SizedBox(height: 12),
                  _buildRow(['0', '.', '='], [Colors.white10, Colors.white10, AppColors.magenta], isLastRow: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> texts, List<Color> colors, {bool isLastRow = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: texts.map((text) {
        final isZero = isLastRow && text == '0';
        final isOp = text == '+' || text == '-' || text == '×' || text == '÷';
        final isEq = text == '=';
        final isSpecial = text == 'C' || text == '±' || text == '%';

        Color btnColor = const Color(0xFF22222E);
        Color txtColor = Colors.white;

        if (isEq) {
          btnColor = AppColors.cyan;
          txtColor = Colors.black;
        } else if (isOp) {
          btnColor = const Color(0xFF2C2C3D);
          txtColor = AppColors.cyan;
        } else if (isSpecial) {
          btnColor = const Color(0xFF2C2C3D);
          txtColor = Colors.white70;
        }

        return Expanded(
          flex: isZero ? 2 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: InkWell(
              onTap: () {
                if (text == 'C') {
                  _onClear();
                } else if (text == '±') {
                  _onPlusMinus();
                } else if (text == '%') {
                  _onPercent();
                } else if (text == '.') {
                  _onDotPressed();
                } else if (isOp) {
                  _onOperatorPressed(text);
                } else if (isEq) {
                  _onEqualPressed();
                } else {
                  _onNumberPressed(text);
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: btnColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  text,
                  style: TextStyle(
                    color: txtColor,
                    fontSize: 24,
                    fontWeight: isEq || isOp ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
