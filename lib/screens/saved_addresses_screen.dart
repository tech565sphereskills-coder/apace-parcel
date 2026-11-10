import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/saved_address.dart';
import '../services/mock_state.dart';

class SavedAddressesScreen extends StatefulWidget {
  final bool selectMode;
  final ValueChanged<SavedAddress>? onSelect;

  const SavedAddressesScreen({
    super.key,
    this.selectMode = false,
    this.onSelect,
  });

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  void _showAddAddressDialog() {
    final titleController = TextEditingController();
    final streetController = TextEditingController();
    final landmarkController = TextEditingController();
    final contactNameController = TextEditingController();
    final contactPhoneController = TextEditingController(text: '+234 ');
    String selectedTag = 'home';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add Saved Location',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        _buildTagOption('home', 'Home', Icons.home_rounded, selectedTag, (t) {
                          setSheetState(() => selectedTag = t);
                        }),
                        const SizedBox(width: 10),
                        _buildTagOption('work', 'Work', Icons.work_rounded, selectedTag, (t) {
                          setSheetState(() => selectedTag = t);
                        }),
                        const SizedBox(width: 10),
                        _buildTagOption('other', 'Other', Icons.location_on_rounded, selectedTag, (t) {
                          setSheetState(() => selectedTag = t);
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(titleController, 'Place Name (e.g. Home Lekki, Boutique Ikeja)', Icons.bookmark_border_rounded),
                    const SizedBox(height: 12),
                    _buildTextField(streetController, 'Full Street Address', Icons.location_city_rounded),
                    const SizedBox(height: 12),
                    _buildTextField(landmarkController, 'Nearest Landmark / Bus Stop', Icons.flag_outlined),
                    const SizedBox(height: 12),
                    _buildTextField(contactNameController, 'Contact Person at Location', Icons.person_outline_rounded),
                    const SizedBox(height: 12),
                    _buildTextField(contactPhoneController, 'Contact Phone Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (titleController.text.trim().isEmpty || streetController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter at least a place name and address.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          final newAddress = SavedAddress(
                            id: 'addr-${DateTime.now().millisecondsSinceEpoch}',
                            title: titleController.text.trim(),
                            street: streetController.text.trim(),
                            landmark: landmarkController.text.trim().isEmpty ? 'Direct on street' : landmarkController.text.trim(),
                            contactName: contactNameController.text.trim().isEmpty ? 'Self' : contactNameController.text.trim(),
                            contactPhone: contactPhoneController.text.trim(),
                            tag: selectedTag,
                          );

                          AppState.instance.addAddress(newAddress);
                          Navigator.pop(dialogCtx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Saved "${newAddress.title}" successfully.'),
                              backgroundColor: AppColors.nairaGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Save Address', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTagOption(String tag, String label, IconData icon, String currentTag, ValueChanged<String> onSelect) {
    final isSelected = tag == currentTag;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(tag),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryOrange : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? AppColors.primaryOrange : AppColors.textSecondary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.primaryOrange : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.selectMode ? 'Select Saved Address' : 'Saved Locations',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryOrange, size: 24),
            onPressed: _showAddAddressDialog,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (context, _) {
          final addresses = AppState.instance.savedAddresses;

          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF7ED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bookmark_border_rounded, size: 48, color: AppColors.primaryOrange),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Saved Places Yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Save your home, office, or frequent client stores for 1-tap dispatch.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showAddAddressDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add First Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: addresses.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final addr = addresses[index];
              return _buildAddressCard(addr);
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _showAddAddressDialog,
              icon: const Icon(Icons.add_location_alt_outlined, color: AppColors.primaryOrange),
              label: const Text('Add New Address', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(SavedAddress addr) {
    IconData icon;
    Color iconColor;

    switch (addr.tag) {
      case 'home':
        icon = Icons.home_rounded;
        iconColor = const Color(0xFF3B82F6);
        break;
      case 'work':
        icon = Icons.work_rounded;
        iconColor = const Color(0xFF8B5CF6);
        break;
      default:
        icon = Icons.storefront_rounded;
        iconColor = AppColors.primaryOrange;
    }

    return InkWell(
      onTap: widget.selectMode
          ? () {
              if (widget.onSelect != null) {
                widget.onSelect!(addr);
              }
              Navigator.pop(context, addr);
            }
          : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        addr.title,
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
                          addr.tag.toUpperCase(),
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    addr.street,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Landmark: ${addr.landmark}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${addr.contactName} (${addr.contactPhone})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!widget.selectMode)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                onPressed: () {
                  AppState.instance.removeAddress(addr.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removed "${addr.title}" from saved addresses.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            if (widget.selectMode)
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 8),
                child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primaryOrange),
              ),
          ],
        ),
      ),
    );
  }
}

