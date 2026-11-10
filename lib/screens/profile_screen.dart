import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../services/mock_state.dart';
import 'saved_addresses_screen.dart';
import 'kyc_verification_sheet.dart';
import 'rider_mode_screen.dart';
import 'rider_onboarding_sheet.dart';
import 'admin_dashboard_screen.dart';
import '../widgets/transaction_pin_sheet.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile & Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
        ),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          final tier = AppState.instance.kycTier;
          final tierLabel = AppState.instance.kycTierBadgeLabel;
          final dailyLimit = AppState.instance.formattedDailyLimit;
          final fullName = AppState.instance.userFullName;
          final phone = AppState.instance.userPhone;
          final parts = fullName.trim().split(' ').where((p) => p.isNotEmpty).toList();
          final initials = parts.length >= 2
              ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
              : (parts.isNotEmpty ? parts[0][0].toUpperCase() : 'AP');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: AppColors.primaryOrangeLight,
                            child: Text(
                              initials,
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primaryOrange),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.emeraldGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 12, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        fullName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$phone • Lagos, Nigeria',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),

                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const KycVerificationSheet(),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: tier >= 2 ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: tier >= 2 ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tier >= 3
                                    ? Icons.workspace_premium_rounded
                                    : (tier >= 2 ? Icons.verified_user_rounded : Icons.info_outline_rounded),
                                size: 14,
                                color: tier >= 3
                                    ? const Color(0xFF701A75)
                                    : (tier >= 2 ? AppColors.nairaGreen : const Color(0xFF92400E)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$tierLabel (${tier >= 2 ? "NIN Linked" : "Unverified"}) • Manage',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: tier >= 3
                                      ? const Color(0xFF701A75)
                                      : (tier >= 2 ? AppColors.nairaGreen : const Color(0xFF92400E)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.two_wheeler_rounded, color: AppColors.primaryOrange, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Switch to Rider Mode',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Dispatch simulator, daily earnings & OTP verify',
                              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RiderModeScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: const Text('Open', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.whatsappGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Need Help? WhatsApp Support',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1B5E20)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Fast response for delayed riders or queries',
                              style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final waUri = Uri.parse('https://wa.me/2348100002722?text=Hello%20Apace%20Support');
                          if (await canLaunchUrl(waUri)) {
                            await launchUrl(waUri, mode: LaunchMode.externalApplication);
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Apace Official WhatsApp Support: +234 810 000 2722'),
                                backgroundColor: AppColors.whatsappGreen,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.whatsappGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: const Text('Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _buildSettingsSection('Security & Identity Verification', [
                  _buildTile(
                    Icons.verified_user_rounded,
                    'KYC & Daily Dispatch Limits',
                    '$tierLabel • $dailyLimit daily limit',
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const KycVerificationSheet(),
                      );
                    },
                  ),
                  _buildTile(
                    Icons.lock_rounded,
                    'Wallet Transaction PIN',
                    'Set or change 4-digit PIN for withdrawals & payments',
                    onTap: () {
                      TransactionPinSheet.show(
                        context,
                        title: 'Set 4-Digit Transaction PIN',
                        subtitle: 'Choose your secret 4-digit PIN',
                        setupMode: true,
                        onSuccess: (pin) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('4-digit Transaction PIN saved securely!'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  _buildTile(
                    Icons.notifications_none_rounded,
                    'Notification Settings',
                    'WhatsApp, SMS OTP & Push Alerts',
                    onTap: () => _showNotificationSheet(context),
                  ),
                ]),

                const SizedBox(height: 16),

                _buildSettingsSection('Fleet & Operations', [
                  _buildTile(
                    Icons.two_wheeler_rounded,
                    'Become a Verified Fleet Rider',
                    'Submit FRSC license, plate & guarantor docs',
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const RiderOnboardingSheet(),
                      );
                    },
                  ),
                  _buildTile(
                    Icons.admin_panel_settings_outlined,
                    'Admin Operations Console',
                    'Dispute escrow mediation, Fleet KYC & audit trail',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                      );
                    },
                  ),
                ]),

                const SizedBox(height: 16),

                _buildSettingsSection('Preferences & Places', [
                  _buildTile(
                    Icons.bookmark_outline_rounded,
                    'Saved Locations (Home / Office)',
                    'Manage frequent pickup & drop-off places',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SavedAddressesScreen()),
                      );
                    },
                  ),
                ]),

                const SizedBox(height: 16),

                _buildSettingsSection('About & Legal', [
                  _buildTile(
                    Icons.description_outlined,
                    'Terms of Service & Carriage Rights',
                    'Nigerian courier liability, Escrow COD & dispute rules',
                    onTap: () => _showLegalSheet(
                      context,
                      'Terms of Service & Carriage Rights',
                      '1. Carriage & Prohibited Goods: Apace Parcel transports sealed lawful parcels across Nigeria. Flammable materials, illicit substances, and undeclared currency are prohibited.\n\n'
                      '2. Escrow COD Protection: Funds collected via Moniepoint/Paystack Escrow are held securely until the 4-digit buyer release code or confirmed handover OTP is validated.\n\n'
                      '3. Goods-in-Transit Insurance: Insured shipments are covered up to ₦250,000 against transit loss when Proof-of-Delivery disputes are filed within 24 hours.',
                    ),
                  ),
                  _buildTile(
                    Icons.privacy_tip_outlined,
                    'Privacy Policy',
                    'NDPR data protection, KYC encryption & retention',
                    onTap: () => _showLegalSheet(
                      context,
                      'NDPR Privacy Policy',
                      'Apace Parcel complies with the Nigeria Data Protection Act (NDPA). NIN and BVN checks are tokenized via Dojah/Prembly, masked in API responses, and never sold to third parties.\n\n'
                      'Real-time GPS coordinates are retained only for active delivery routing, 150m arrival triggers, and anti-spoofing audit trails. Account deletion anonymizes all personal identifiers immediately.',
                    ),
                  ),
                  _buildTile(Icons.info_outline_rounded, 'App Version', 'v1.0.0 (Apace Parcel NG)'),
                  _buildTile(
                    Icons.delete_forever_outlined,
                    'Close & Delete Account',
                    'Permanently deactivate account and clear personal data',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (dlgCtx) => AlertDialog(
                          title: const Text('Close Apace Account?'),
                          content: const Text(
                            'Your account will be permanently closed and personal identifiers removed. Remaining wallet balances over ₦100 must be withdrawn first.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dlgCtx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(dlgCtx);
                                final err = await AppState.instance.deleteAccount();
                                if (!context.mounted) return;
                                if (err != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }
                                onLogout();
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                              child: const Text('Delete Account', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ]),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                    label: const Text('Log Out', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: const Color(0xFFFEF2F2),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 14, bottom: 6),
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8)),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  void _showNotificationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FutureBuilder<List<Map<String, dynamic>>>(
        future: AppState.instance.fetchNotificationHistory(),
        builder: (modalCtx, snapshot) {
          final history = snapshot.data ?? [];
          return AnimatedBuilder(
            animation: AppState.instance,
            builder: (context, _) => Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Notification Preferences', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(modalCtx)),
                      ],
                    ),
                    SwitchListTile(
                      title: const Text('WhatsApp Dispatch Updates', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Waybill status & Escrow release alerts'),
                      value: AppState.instance.notifyWhatsapp,
                      activeThumbColor: AppColors.primaryOrange,
                      onChanged: (v) => AppState.instance.updateNotificationPreferences(notifyWhatsapp: v),
                    ),
                    SwitchListTile(
                      title: const Text('Termii SMS OTP & Arrival', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Fallback DND SMS for delivery PINs'),
                      value: AppState.instance.notifySms,
                      activeThumbColor: AppColors.primaryOrange,
                      onChanged: (v) => AppState.instance.updateNotificationPreferences(notifySms: v),
                    ),
                    SwitchListTile(
                      title: const Text('Live Push Notifications (FCM)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Real-time rider arrival & auction alerts'),
                      value: AppState.instance.notifyPush,
                      activeThumbColor: AppColors.primaryOrange,
                      onChanged: (v) => AppState.instance.updateNotificationPreferences(notifyPush: v),
                    ),
                    if (history.isNotEmpty) ...[
                      const Divider(height: 20),
                      const Text('Recent Alerts & Pushes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      for (final item in history.take(4))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.notifications_active_outlined, size: 18, color: AppColors.primaryOrange),
                          title: Text(item['title']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          subtitle: Text(item['body']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLegalSheet(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(height: 16),
              Text(content, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, String? subtitle, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textDark, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)) : null,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
      onTap: onTap ?? () {},
      dense: true,
    );
  }
}
