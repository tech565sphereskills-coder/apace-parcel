import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../services/mock_state.dart';
import '../widgets/custom_text_field.dart';

class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({super.key});

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final TextEditingController _phoneController = TextEditingController(text: '+2348145550192');
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool _isLoading = false;
  int _step = 1;
  String? _devOtpHint;

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    setState(() => _isLoading = true);
    final res = await AppState.instance.sendOtp(phone, 'RESET_PASSWORD');
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      setState(() {
        _step = 2;
        _devOtpHint = res['devOtp']?.toString();
        if (_devOtpHint != null) {
          _otpController.text = _devOtpHint!;
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Unable to send OTP'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _submitReset() async {
    if (_otpController.text.trim().length != 6 || _newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter 6-digit OTP and password (min 6 characters)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final err = await AppState.instance.resetPassword(
      phone: _phoneController.text.trim(),
      code: _otpController.text.trim(),
      newPassword: _newPasswordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _step = 3);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_step == 1) ...[
            Text('Reset Password', style: AppStyles.headingLarge.copyWith(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              'Enter your registered Nigerian phone number to receive a 6-digit SMS OTP via Termii.',
              style: AppStyles.subtitle,
            ),
            const SizedBox(height: 22),
            CustomTextField(
              controller: _phoneController,
              hintText: '+2348145550192',
              leadingIcon: Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text('Send SMS OTP', style: AppStyles.buttonText),
              ),
            ),
          ] else if (_step == 2) ...[
            Text('Enter OTP & New Password', style: AppStyles.headingLarge.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              _devOtpHint != null
                  ? 'Sandbox OTP delivered: $_devOtpHint'
                  : 'Enter the 6-digit code sent to ${_phoneController.text}.',
              style: AppStyles.subtitle,
            ),
            const SizedBox(height: 18),
            CustomTextField(
              controller: _otpController,
              hintText: '6-digit SMS OTP',
              leadingIcon: Icons.sms_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _newPasswordController,
              hintText: 'New Password (min 6 chars)',
              leadingIcon: Icons.lock_outline_rounded,
              isPassword: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text('Confirm Reset', style: AppStyles.buttonText),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 48),
                  ),
                  const SizedBox(height: 18),
                  Text('Password Updated!', style: AppStyles.headingLarge.copyWith(fontSize: 20)),
                  const SizedBox(height: 8),
                  Text(
                    'Your password has been reset securely. All previous sessions were revoked.',
                    textAlign: TextAlign.center,
                    style: AppStyles.subtitle,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: Text('Back to Login', style: AppStyles.buttonText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
