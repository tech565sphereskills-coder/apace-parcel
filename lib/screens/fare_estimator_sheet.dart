import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'send_package_screen.dart';

class FareEstimatorSheet extends StatefulWidget {
  const FareEstimatorSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FareEstimatorSheet(),
    );
  }

  @override
  State<FareEstimatorSheet> createState() => _FareEstimatorSheetState();
}

class _FareEstimatorSheetState extends State<FareEstimatorSheet> {
  final List<String> _locations = [
    'Lekki Phase 1, Lagos',
    'Victoria Island, Lagos',
    'Yaba / Tejuosho, Lagos',
    'Ikeja (Allen / GRA), Lagos',
    'Surulere, Lagos',
    'Ikoyi, Lagos',
    'Ajah / Sangotedo, Lagos',
    'Festac Town, Lagos',
    'Wuse 2, Abuja',
    'Garki, Abuja',
    'Maitama, Abuja',
  ];

  late String _origin;
  late String _destination;
  String _selectedFleet = 'Bike Dispatch';

  @override
  void initState() {
    super.initState();
    _origin = _locations[0];
    _destination = _locations[2];
  }

  double _calculateDistance() {
    if (_origin == _destination) return 3.5;
    if (_origin.contains('Abuja') && !_destination.contains('Abuja')) return 740.0;
    if (!_origin.contains('Abuja') && _destination.contains('Abuja')) return 740.0;
    if (_origin.contains('Abuja') && _destination.contains('Abuja')) return 12.0;

    int hash = (_origin.hashCode ^ _destination.hashCode).abs();
    return 8.0 + (hash % 220) / 10.0;
  }

  double _getFleetPrice(String fleet, double distance) {
    bool isInterstate = distance > 100;
    switch (fleet) {
      case 'Car Delivery':
        return isInterstate ? 35000.0 : (3200.0 + distance * 120);
      case 'Mini-Van Cargo':
        return isInterstate ? 65000.0 : (9000.0 + distance * 220);
      case 'Interstate Express':
        return isInterstate ? 14500.0 : 8500.0;
      case 'Bike Dispatch':
      default:
        return isInterstate ? 8500.0 : (1600.0 + distance * 70);
    }
  }

  String _formatNaira(double val) {
    return '₦${val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _getEta(String fleet, double distance) {
    if (distance > 100) return '24 - 48 Hours';
    switch (fleet) {
      case 'Bike Dispatch':
        return '${(15 + distance * 1.5).toInt()} - ${(25 + distance * 1.8).toInt()} mins';
      case 'Car Delivery':
        return '${(25 + distance * 2.0).toInt()} - ${(40 + distance * 2.5).toInt()} mins';
      case 'Mini-Van Cargo':
        return '${(35 + distance * 2.2).toInt()} - ${(55 + distance * 3.0).toInt()} mins';
      default:
        return 'Same Day';
    }
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistance();
    final isInterstate = distance > 100;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrangeLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calculate_outlined, color: AppColors.primaryOrange, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instant Fare Calculator',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      Text(
                        'Transparent quotes across all Nigerian routes',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textDark),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildLocationDropdown(
                          label: 'PICKUP ZONE',
                          value: _origin,
                          icon: Icons.trip_origin_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          onChanged: (val) {
                            if (val != null) setState(() => _origin = val);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              Container(width: 2, height: 20, color: const Color(0xFFE2E8F0)),
                              const Spacer(),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    final temp = _origin;
                                    _origin = _destination;
                                    _destination = temp;
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.swap_vert_rounded, size: 16, color: AppColors.textDark),
                                      SizedBox(width: 4),
                                      Text('Swap', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildLocationDropdown(
                          label: 'DELIVERY ZONE',
                          value: _destination,
                          icon: Icons.location_on_rounded,
                          iconColor: AppColors.primaryOrange,
                          onChanged: (val) {
                            if (val != null) setState(() => _destination = val);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.straighten_rounded, size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 10),
                        Text(
                          'Estimated Route Distance: ${distance.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                        ),
                        const Spacer(),
                        if (isInterstate)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'INTERSTATE',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Available Fleet & Price Quotes',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 12),

                  _buildFleetCard(
                    title: 'Bike Dispatch',
                    subtitle: 'Quick document & parcel dispatch (< 10kg)',
                    icon: Icons.two_wheeler_rounded,
                    price: _getFleetPrice('Bike Dispatch', distance),
                    eta: _getEta('Bike Dispatch', distance),
                    color: const Color(0xFFF97316),
                  ),
                  const SizedBox(height: 10),

                  _buildFleetCard(
                    title: 'Car Delivery',
                    subtitle: 'Fragile, cakes, multiple bags & packages',
                    icon: Icons.directions_car_rounded,
                    price: _getFleetPrice('Car Delivery', distance),
                    eta: _getEta('Car Delivery', distance),
                    color: const Color(0xFF3B82F6),
                  ),
                  const SizedBox(height: 10),

                  _buildFleetCard(
                    title: 'Mini-Van Cargo',
                    subtitle: 'Bulk business goods, electronics, cartons',
                    icon: Icons.local_shipping_rounded,
                    price: _getFleetPrice('Mini-Van Cargo', distance),
                    eta: _getEta('Mini-Van Cargo', distance),
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 10),

                  _buildFleetCard(
                    title: 'Interstate Express',
                    subtitle: 'Nationwide dispatch with verified logistics hubs',
                    icon: Icons.alt_route_rounded,
                    price: _getFleetPrice('Interstate Express', distance),
                    eta: _getEta('Interstate Express', distance),
                    color: const Color(0xFF8B5CF6),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedFleet,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      Text(
                        _formatNaira(_getFleetPrice(_selectedFleet, distance)),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SendPackageScreen(
                          initialServiceType: _selectedFleet,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Book This Fleet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDropdown({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: value,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textDark),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  items: _locations.map((loc) {
                    return DropdownMenuItem<String>(
                      value: loc,
                      child: Text(loc, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFleetCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required double price,
    required String eta,
    required Color color,
  }) {
    final isSelected = _selectedFleet == title;

    return InkWell(
      onTap: () => setState(() => _selectedFleet = title),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : const Color(0xFFF1F5F9),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [const BoxShadow(color: Color(0x14DE5416), blurRadius: 10, offset: Offset(0, 4))]
              : [const BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          eta,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatNaira(price),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isSelected ? AppColors.primaryOrange : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

