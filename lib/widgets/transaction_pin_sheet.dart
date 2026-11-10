import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../services/mock_state.dart';

class TransactionPinSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final double? amount;
  final bool setupMode;
  final Function(String pin) onSuccess;

  const TransactionPinSheet({
    super.key,
    this.title = 'Enter Transaction PIN',
    this.subtitle = 'Authorize this transaction securely',
    this.amount,
    this.setupMode = false,
    required this.onSuccess,
  });

  static Future<bool?> show(
    BuildContext context, {
    String title = 'Enter Transaction PIN',
    String subtitle = 'Authorize this transaction securely',
    double? amount,
    bool setupMode = false,
    required Function(String pin) onSuccess,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionPinSheet(
        title: title,
        subtitle: subtitle,
        amount: amount,
        setupMode: setupMode,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<TransactionPinSheet> createState() => _TransactionPinSheetState();
}

class _TransactionPinSheetState extends State<TransactionPinSheet>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String? _errorMessage;
  bool _isProcessing = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPressed(String value) {
    if (_isProcessing) return;
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += value;
        _errorMessage = null;
      });
      if (_enteredPin.length == 4) {
        _verifyEnteredPin();
      }
    }
  }

  void _onBackspace() {
    if (_isProcessing || _enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _triggerBiometric() async {
    if (_isProcessing || widget.setupMode) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    bool authenticated = false;
    if (!kIsWeb) {
      try {
        final canCheck = await _localAuth.canCheckBiometrics;
        final isSupported = await _localAuth.isDeviceSupported();
        if (canCheck && isSupported) {
          authenticated = await _localAuth.authenticate(
            localizedReason: widget.subtitle,
            options: const AuthenticationOptions(
              biometricOnly: false,
              stickyAuth: true,
            ),
          );
        }
      } catch (_) {
        authenticated = false;
      }
    }

    if (!mounted) return;

    if (authenticated || kIsWeb) {
      final err = await mockState.verifyPinLive(mockState.transactionPin);
      if (!mounted) return;
      if (err == null) {
        widget.onSuccess(mockState.transactionPin);
        Navigator.pop(context, true);
        return;
      }
    }

    setState(() {
      _isProcessing = false;
      _errorMessage = 'Biometric unavailable. Please enter your 4-digit PIN.';
    });
  }

  Future<void> _verifyEnteredPin() async {
    setState(() {
      _isProcessing = true;
    });

    String? errorMsg;
    if (widget.setupMode) {
      errorMsg = await mockState.setupPinLive(_enteredPin);
    } else {
      errorMsg = await mockState.verifyPinLive(_enteredPin);
    }

    if (!mounted) return;

    if (errorMsg == null) {
      final confirmedPin = _enteredPin;
      widget.onSuccess(confirmedPin);
      Navigator.pop(context, true);
    } else {
      _shakeController.forward(from: 0.0);
      setState(() {
        _isProcessing = false;
        _enteredPin = '';
        _errorMessage = errorMsg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Color(0xFF10B981),
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF94A3B8),
              fontSize: 13,
            ),
          ),
          if (widget.amount != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                '₦${widget.amount!.toStringAsFixed(0).replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    )}',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF10B981),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? const Color(0xFF10B981) : Colors.transparent,
                        border: Border.all(
                          color: isFilled
                              ? const Color(0xFF10B981)
                              : Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          _buildNumericKeypad(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF64748B), size: 13),
              const SizedBox(width: 5),
              Text(
                'Secured by Apace Shield • Moniepoint MFB Protected',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumericKeypad() {
    return Column(
      children: [
        _buildKeyRow(['1', '2', '3']),
        const SizedBox(height: 14),
        _buildKeyRow(['4', '5', '6']),
        const SizedBox(height: 14),
        _buildKeyRow(['7', '8', '9']),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSpecialKey(
              icon: Icons.fingerprint_rounded,
              color: widget.setupMode ? Colors.white24 : const Color(0xFF10B981),
              onTap: _triggerBiometric,
            ),
            _buildNumberKey('0'),
            _buildSpecialKey(
              icon: Icons.backspace_outlined,
              color: Colors.white70,
              onTap: _onBackspace,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildNumberKey(key)).toList(),
    );
  }

  Widget _buildNumberKey(String number) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPressed(number),
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 72,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 72,
          height: 60,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }
}
