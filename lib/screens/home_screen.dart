import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/mock_state.dart';
import 'orders_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'send_package_screen.dart';
import 'order_tracking_screen.dart';
import 'guest_track_sheet.dart';
import 'fare_estimator_sheet.dart';
import 'kyc_verification_sheet.dart';
import 'rider_mode_screen.dart';
import '../widgets/custom_bottom_navbar.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBottomNavIndex = 0;
  bool _hideHomeBalance = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _currentBottomNavIndex,
        children: [
          _buildHomeTab(),
          const OrdersScreen(),
          const WalletScreen(),
          ProfileScreen(onLogout: widget.onLogout),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          return CustomBottomNavBar(
            currentIndex: _currentBottomNavIndex,
            hasActiveOrder: AppState.instance.activeOrder != null,
            onTap: (index) => setState(() => _currentBottomNavIndex = index),
          );
        },
      ),
    );
  }

  Widget _buildHomeTab() {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;
        final activeOrder = state.activeOrder;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 21,
                            backgroundColor: AppColors.primaryOrangeLight,
                            child: Text(
                              state.userFullName
                                  .trim()
                                  .split(' ')
                                  .where((p) => p.isNotEmpty)
                                  .take(2)
                                  .map((p) => p[0].toUpperCase())
                                  .join(),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryOrange),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Good day, ${state.userFullName.trim().split(' ').first} 👋',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Ready to send parcels across Nigeria?',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RiderModeScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.two_wheeler_rounded, size: 13, color: AppColors.primaryOrange),
                                SizedBox(width: 4),
                                Text('Rider Mode', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.location_on_rounded, size: 13, color: AppColors.primaryOrange),
                              SizedBox(width: 3),
                              Text('Lagos', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0F172A),
                        Color(0xFF1E293B),
                        Color(0xFF0B132B),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Color(0x28000000), blurRadius: 16, offset: Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'APACE',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Naira Wallet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _currentBottomNavIndex = 2),
                            child: Row(
                              children: const [
                                Text('Manage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryOrangeLight)),
                                SizedBox(width: 2),
                                Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primaryOrangeLight),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Available Balance', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => setState(() => _hideHomeBalance = !_hideHomeBalance),
                                    child: Icon(
                                      _hideHomeBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: const Color(0xFF94A3B8),
                                      size: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _hideHomeBalance ? '₦ ••••••••' : state.formattedWalletBalance,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                              ),
                            ],
                          ),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: state.kycTier >= 2 ? const Color(0x1E10B981) : const Color(0x1EF59E0B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: state.kycTier >= 2 ? const Color(0x3210B981) : const Color(0x32F59E0B),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    state.kycTier >= 3
                                        ? Icons.workspace_premium_rounded
                                        : (state.kycTier >= 2 ? Icons.shield_rounded : Icons.info_outline_rounded),
                                    size: 11,
                                    color: state.kycTier >= 3
                                        ? const Color(0xFFE879F9)
                                        : (state.kycTier >= 2 ? const Color(0xFF34D399) : const Color(0xFFFBBF24)),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    state.kycTierBadgeLabel,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: state.kycTier >= 3
                                          ? const Color(0xFFE879F9)
                                          : (state.kycTier >= 2 ? const Color(0xFF34D399) : const Color(0xFFFBBF24)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF334155), height: 1),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SendPackageScreen()),
                                );
                              },
                              icon: const Icon(Icons.send_rounded, size: 15, color: Colors.white),
                              label: const Text('Send Package', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryOrange,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() => _currentBottomNavIndex = 2),
                              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                              label: const Text('Top Up', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF475569)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => const GuestTrackSheet(),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.search_rounded, color: AppColors.textMuted, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Track package by tracking ID (e.g. AP-9042)',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ),
                        Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryOrange, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                InkWell(
                  onTap: () => FareEstimatorSheet.show(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.calculate_outlined, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Instant Fare Calculator',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Calculate & compare route prices across all fleets',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: const Text(
                            'Check Rates',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryOrange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text('Choose Service', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildServiceCard(
                        'Instant Bike',
                        'Beats Lagos Traffic',
                        'From ₦2,200',
                        Icons.two_wheeler_rounded,
                        const Color(0xFFDE5416),
                        'Bike Dispatch',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildServiceCard(
                        'Express Car',
                        'Delicate & Cakes',
                        'From ₦4,500',
                        Icons.directions_car_rounded,
                        const Color(0xFF2563EB),
                        'Car Delivery',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildServiceCard(
                        'Mini-Van / Bus',
                        'Bulky Goods & Cargo',
                        'From ₦12,000',
                        Icons.airport_shuttle_rounded,
                        const Color(0xFF059669),
                        'Mini-Van Cargo',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildServiceCard(
                        'Interstate Waybill',
                        'Lagos to All States',
                        'From ₦7,500',
                        Icons.route_rounded,
                        const Color(0xFF7C3AED),
                        'Interstate',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                if (activeOrder != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Active Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.circle, size: 8, color: AppColors.nairaGreen),
                            SizedBox(width: 5),
                            Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.nairaGreen)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => OrderTrackingScreen(order: activeOrder)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0CDE5416), blurRadius: 14, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryOrangeLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.sports_motorsports_rounded, color: AppColors.primaryOrange, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(activeOrder.riderName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                      Text('Rider • ${activeOrder.riderVehicle.split('•').first.trim()}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ],
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => OrderTrackingScreen(order: activeOrder)),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryOrange,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                child: const Text('Track Live', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Heading to: ${activeOrder.dropoffAddress}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text('ETA 18m', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.nairaGreen)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  _buildNoActiveDeliveryCard(),
                  const SizedBox(height: 24),
                ],

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF97316),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.percent_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('20% Off Next 3 Deliveries', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF9A3412))),
                            SizedBox(height: 2),
                            Text('Use code APACE20 on checkout. Valid for Lagos & Abuja dispatches.', style: TextStyle(fontSize: 11, color: Color(0xFFC2410C))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceCard(String title, String desc, String price, IconData icon, Color color, String serviceType) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SendPackageScreen(initialServiceType: serviceType)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(price, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoActiveDeliveryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryOrange, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Active Deliveries',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
                SizedBox(height: 3),
                Text(
                  'Book a dispatch rider to track packages live with handover OTP.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SendPackageScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Book', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
