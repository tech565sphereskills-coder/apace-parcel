import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../services/mock_state.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_checkbox.dart';

class SignUpSheet extends StatefulWidget {
  final VoidCallback? onSwitchToLogin;
  final VoidCallback? onRegistered;

  const SignUpSheet({super.key, this.onSwitchToLogin, this.onRegistered});

  @override
  State<SignUpSheet> createState() => _SignUpSheetState();
}

class _SignUpSheetState extends State<SignUpSheet> {
  int _currentStep = 1;
  final _nameController = TextEditingController();
  final _emailPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _ninController = TextEditingController(text: '2948 1029 384');

  bool _agreeTerms = true;
  bool _isLoading = false;
  String _selectedMethod = 'NIN';
  bool _isVerifyingNin = false;
  String _nimcStatusText = '';
  bool _isNinVerified = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailPhoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ninController.dispose();
    super.dispose();
  }

  void _proceedToKycStep() {
    if (_nameController.text.trim().isEmpty ||
        _emailPhoneController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _currentStep = 2);
  }

  Future<void> _submitRegistration({String? verifiedNin}) async {
    setState(() => _isLoading = true);
    final rawIdent = _emailPhoneController.text.trim();
    final isEmail = rawIdent.contains('@');
    final phone = isEmail
        ? '+23480${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}'
        : rawIdent;
    final email = isEmail ? rawIdent : null;

    final err = await AppState.instance.register(
      fullName: _nameController.text.trim(),
      phone: phone,
      email: email,
      password: _passwordController.text,
      ninNumber: verifiedNin,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (widget.onRegistered != null) {
      widget.onRegistered!();
    } else {
      Navigator.pop(context);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          verifiedNin != null
              ? 'Registration complete! Tier 2 Verified with ₦500,000 daily limit.'
              : 'Welcome to Apace Parcel! You are currently on Tier 1 (₦50,000 daily limit).',
        ),
        backgroundColor: const Color(0xFF15803D),
      ),
    );
  }

  void _completeAsTier1() {
    _submitRegistration();
  }

  void _verifyNinWithNimc() {
    final cleanInput = _ninController.text.replaceAll(' ', '');
    if (cleanInput.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an 11-digit NIN or BVN number'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingNin = true;
      _nimcStatusText = 'Connecting to NIMC Verification Gateway...';
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _nimcStatusText = 'Validating 11-Digit Identity Record...');
    });

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _nimcStatusText = 'Matching Records with National Registry...');
    });

    Future.delayed(const Duration(milliseconds: 2700), () {
      if (!mounted) return;
      AppState.instance.upgradeToTier2(_ninController.text);
      setState(() {
        _isVerifyingNin = false;
        _isNinVerified = true;
      });
    });
  }

  void _finishVerifiedRegistration() {
    _submitRegistration(verifiedNin: _ninController.text.replaceAll(' ', ''));
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
      child: SingleChildScrollView(
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
            const SizedBox(height: 18),

            Row(
              children: [
                _buildStepIndicator(1, 'Account', _currentStep >= 1, _currentStep == 1),
                Expanded(
                  child: Container(
                    height: 2,
                    color: _currentStep >= 2 ? AppColors.primaryOrange : const Color(0xFFE2E8F0),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                _buildStepIndicator(2, 'Identity (KYC)', _currentStep >= 2, _currentStep == 2),
              ],
            ),
            const SizedBox(height: 20),

            if (_currentStep == 1) ...[
              _buildStep1Fields(),
            ] else ...[
              _buildStep2Kyc(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepNum, String title, bool isReached, bool isActive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryOrange
                : (isReached ? const Color(0xFF059669) : const Color(0xFFE2E8F0)),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isReached && !isActive
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$stepNum',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isActive ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? AppColors.textDark : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1Fields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create Account', style: AppStyles.headingLarge.copyWith(fontSize: 24)),
        const SizedBox(height: 6),
        Text(
          'Sign up now to start sending and tracking parcels instantly.',
          style: AppStyles.subtitle,
        ),
        const SizedBox(height: 20),

        CustomTextField(
          controller: _nameController,
          hintText: 'Full Name',
          leadingIcon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 14),

        CustomTextField(
          controller: _emailPhoneController,
          hintText: 'Email or Nigerian Phone (+234)',
          leadingIcon: Icons.phone_android_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        CustomTextField(
          controller: _passwordController,
          hintText: 'Password',
          leadingIcon: Icons.lock_outline_rounded,
          isPassword: true,
        ),
        const SizedBox(height: 14),

        CustomTextField(
          controller: _confirmPasswordController,
          hintText: 'Confirm Password',
          leadingIcon: Icons.lock_outline_rounded,
          isPassword: true,
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            CustomCircleCheckbox(
              value: _agreeTerms,
              onChanged: (val) => setState(() => _agreeTerms = val),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'I agree to Terms of Service and Privacy Policy',
                style: AppStyles.subtitle.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _proceedToKycStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: const Text('Continue to Identity Check', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: _completeAsTier1,
            child: const Text(
              'Skip KYC & Continue as Tier 1 Basic (₦50k Limit)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Center(
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
              widget.onSwitchToLogin?.call();
            },
            child: RichText(
              text: TextSpan(
                text: 'Already have an account? ',
                style: AppStyles.subtitle,
                children: [
                  TextSpan(
                    text: 'Log In',
                    style: AppStyles.linkTextBold.copyWith(
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Kyc() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Verify Your Identity', style: AppStyles.headingLarge.copyWith(fontSize: 22)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Tier 2 Upgrade',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Instant NIMC lookup unlocks a ₦500,000 daily limit and dedicated Moniepoint MFB wallet account.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),

        if (!_isNinVerified) ...[
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMethod = 'NIN'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedMethod == 'NIN' ? AppColors.primaryOrangeLight : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedMethod == 'NIN' ? AppColors.primaryOrange : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'NIN (National ID)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _selectedMethod == 'NIN' ? AppColors.primaryOrange : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMethod = 'BVN'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedMethod == 'BVN' ? AppColors.primaryOrangeLight : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedMethod == 'BVN' ? AppColors.primaryOrange : Colors.transparent,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'BVN (Bank ID)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _selectedMethod == 'BVN' ? AppColors.primaryOrange : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _ninController,
            keyboardType: TextInputType.number,
            maxLength: 14,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.5),
            decoration: InputDecoration(
              counterText: '',
              prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primaryOrange),
              hintText: 'e.g. 2948 1029 384',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2)),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              ActionChip(
                backgroundColor: const Color(0xFFF1F5F9),
                avatar: const Icon(Icons.touch_app_rounded, size: 14, color: AppColors.primaryOrange),
                label: const Text('Use Sample Demo NIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                onPressed: () {
                  setState(() => _ninController.text = '2948 1029 384');
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (_isVerifyingNin) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _nimcStatusText,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isVerifyingNin ? null : _verifyNinWithNimc,
              icon: const Icon(Icons.shield_rounded, size: 18),
              label: Text(_isVerifyingNin ? 'Verifying with NIMC...' : 'Verify Now (Instant Tier 2)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'NIMC Record Verified Successfully',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Name: ${_nameController.text.trim().isNotEmpty ? _nameController.text : "Michael Ogundimu"}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 3),
                Text(
                  'NIN: ${_ninController.text}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tier 2 active: ₦500,000 daily limit, Moniepoint account enabled, high-value delivery insurance active.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _finishVerifiedRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF15803D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Complete & Start Sending', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ],

        const SizedBox(height: 14),

        Center(
          child: TextButton(
            onPressed: _completeAsTier1,
            child: const Text(
              'Skip for now (I will verify later in settings)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ),
        ),
      ],
    );
  }
}
