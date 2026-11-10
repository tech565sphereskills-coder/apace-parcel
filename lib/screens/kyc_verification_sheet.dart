import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/mock_state.dart';

class KycVerificationSheet extends StatefulWidget {
  final bool initialTier3Focus;

  const KycVerificationSheet({super.key, this.initialTier3Focus = false});

  @override
  State<KycVerificationSheet> createState() => _KycVerificationSheetState();
}

class _KycVerificationSheetState extends State<KycVerificationSheet> {
  final _ninController = TextEditingController(text: '2948 1029 384');
  String _selectedMethod = 'NIN';
  bool _isVerifying = false;
  String _verificationStepText = '';

  bool _isScanningFace = false;
  int _livenessStep = 0;
  Timer? _livenessTimer;

  @override
  void dispose() {
    _ninController.dispose();
    _livenessTimer?.cancel();
    super.dispose();
  }

  Future<void> _runNimcVerification() async {
    final cleanInput = _ninController.text.replaceAll(' ', '');
    if (cleanInput.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 11-digit NIN or BVN'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _verificationStepText = 'Connecting to NIMC secure gateway...';
    });

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _verificationStepText = 'Querying National Identity Database...';
    });

    final err = await AppState.instance.verifyIdentityLive(_selectedMethod, _ninController.text);
    if (!mounted) return;

    setState(() {
      _isVerifying = false;
      _verificationStepText = '';
    });

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('NIMC Identity Verified! Tier 2 Approved (₦500,000 daily limit).'),
        backgroundColor: Color(0xFF15803D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startFacialLiveness() {
    setState(() {
      _isScanningFace = true;
      _livenessStep = 1;
    });

    _livenessTimer?.cancel();
    _livenessTimer = Timer.periodic(const Duration(milliseconds: 1100), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_livenessStep < 3) {
        setState(() => _livenessStep++);
      } else {
        timer.cancel();
        final err = await AppState.instance.verifyLivenessLive();
        if (!mounted) return;
        setState(() {
          _isScanningFace = false;
          _livenessStep = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              err ?? 'Biometric Liveness Confirmed! Tier 3 Activated (₦5,000,000 Limit).',
            ),
            backgroundColor: err != null ? Colors.redAccent : const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final currentTier = AppState.instance.kycTier;
        final dailyLimit = AppState.instance.formattedDailyLimit;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: AppColors.nairaGreen, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Identity & KYC Verification',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'CBN Tier Guidelines • Safe Nigerian Deliveries',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                _buildTierProgressionCards(currentTier, dailyLimit),

                const SizedBox(height: 20),

                if (_isScanningFace) ...[
                  _buildFacialLivenessView(),
                ] else if (currentTier == 1) ...[
                  _buildNinBvnVerificationForm(),
                ] else if (currentTier == 2) ...[
                  _buildVerifiedNinCard(),
                  const SizedBox(height: 16),
                  _buildTier3UpgradePrompt(),
                ] else ...[
                  _buildTier3CompletedCard(),
                ],

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTierProgressionCards(int currentTier, String currentDailyLimit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR CURRENT STATUS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: currentTier >= 2 ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      currentTier >= 2 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 13,
                      color: currentTier >= 2 ? const Color(0xFF166534) : const Color(0xFF92400E),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tier $currentTier Active',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: currentTier >= 2 ? const Color(0xFF166534) : const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                currentDailyLimit,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark),
              ),
              const SizedBox(width: 8),
              const Text(
                '/ day dispatch limit',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              _buildTierStepPill(1, 'Tier 1\nBasic (₦50k)', currentTier >= 1),
              _buildTierConnector(currentTier >= 2),
              _buildTierStepPill(2, 'Tier 2\nNIN (₦500k)', currentTier >= 2),
              _buildTierConnector(currentTier >= 3),
              _buildTierStepPill(3, 'Tier 3\nCargo (₦5M)', currentTier >= 3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierStepPill(int tierNumber, String label, bool isUnlocked) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isUnlocked ? const Color(0xFF059669) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isUnlocked
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$tierNumber',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade600),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isUnlocked ? FontWeight.w700 : FontWeight.w500,
              color: isUnlocked ? AppColors.textDark : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierConnector(bool isPassed) {
    return Container(
      width: 20,
      height: 3,
      color: isPassed ? const Color(0xFF059669) : Colors.grey.shade300,
      margin: const EdgeInsets.only(bottom: 22),
    );
  }

  Widget _buildNinBvnVerificationForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 16),

          Text(
            'Enter 11-Digit $_selectedMethod Number',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),

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

          const SizedBox(height: 16),

          if (_isVerifying) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _verificationStepText,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isVerifying ? null : _runNimcVerification,
              icon: const Icon(Icons.lock_outline_rounded, size: 18),
              label: Text(_isVerifying ? 'Verifying with NIMC...' : 'Verify & Upgrade to Tier 2', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedNinCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF047857),
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: const [
                Icon(Icons.flag_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'FEDERAL REPUBLIC OF NIGERIA • NIMC',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8),
                ),
                Spacer(),
                Icon(Icons.verified_rounded, color: Color(0xFF6EE7B7), size: 18),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Center(
                    child: Icon(Icons.person_rounded, size: 40, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OGUNDIMU, MICHAEL',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'NIN: ${AppState.instance.ninNumber}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'DOB: 14 AUG 1996 • Lagos, NG',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(19)),
            ),
            child: Row(
              children: const [
                Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF15803D)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tier 2 Verified: High-Value Dispatches & Moniepoint MFB Active',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTier3UpgradePrompt() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF9333EA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Upgrade to Tier 3 (₦5,000,000 Daily Limit)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF581C87)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Instant 10-second AI Selfie Liveness scan for bulk and corporate dispatches',
                      style: TextStyle(fontSize: 11, color: Color(0xFF7E22CE)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _startFacialLiveness,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Start Face Liveness Scan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9333EA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacialLivenessView() {
    final prompts = [
      'Position your face in the oval frame',
      'Center face detected. Now slowly blink your eyes...',
      'Great! Now turn your head slightly to the left...',
      'Matching face with NIMC biometric records (100%)...',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI BIOMETRIC LIVENESS SCAN',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: () {
                  _livenessTimer?.cancel();
                  setState(() => _isScanningFace = false);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            width: 180,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: _livenessStep >= 3 ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                width: 3.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.person,
                  size: 130,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                if (_livenessStep < 3)
                  const Positioned(
                    bottom: 20,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                    ),
                  )
                else
                  const Positioned(
                    bottom: 20,
                    child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 32),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              prompts[_livenessStep.clamp(0, prompts.length - 1)],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTier3CompletedCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF4FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0ABFC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF86198F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Tier 3 Elite Merchant Verified',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF701A75)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Biometrics Linked • Unlimited High-Volume Fleet Dispatches',
                      style: TextStyle(fontSize: 11, color: Color(0xFF86198F)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildTier3BenefitChip('₦5M+ Daily Limit'),
              const SizedBox(width: 8),
              _buildTier3BenefitChip('Zero Escrow Hold'),
              const SizedBox(width: 8),
              _buildTier3BenefitChip('Priority Rider Fleet'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTier3BenefitChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE879F9)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF701A75)),
      ),
    );
  }
}
