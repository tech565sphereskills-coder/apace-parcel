import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../services/mock_state.dart';
import 'send_package_screen.dart';
import 'kyc_verification_sheet.dart';
import '../widgets/transaction_pin_sheet.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _hideBalance = false;
  String _selectedTxnFilter = 'All';
  final _amountController = TextEditingController(text: '5000');

  final List<String> _nigerianBanks = [
    'Access Bank',
    'Guaranty Trust Bank (GTBank)',
    'Zenith Bank',
    'United Bank for Africa (UBA)',
    'First Bank of Nigeria',
    'Moniepoint MFB',
    'Kuda Bank',
    'OPay',
    'PalmPay',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _copyAccountNumber() {
    Clipboard.setData(ClipboardData(text: AppState.instance.virtualAccountNumber.replaceAll(' ', '')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Moniepoint account number copied to clipboard!'),
        backgroundColor: AppColors.nairaGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showFundWalletModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String selectedChannel = 'moniepoint';

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 28,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Fund Apace Wallet',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const Text(
                      'Zero transaction fees • Instant deposit to your balance',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      child: Row(
                        children: [
                          const Text('₦', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark),
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [1000, 2000, 5000, 10000, 20000, 50000].map((amt) {
                          final isCurrent = _amountController.text == '$amt';
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('₦${amt.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'),
                              selected: isCurrent,
                              onSelected: (_) {
                                setSheetState(() {
                                  _amountController.text = '$amt';
                                });
                              },
                              selectedColor: AppColors.primaryOrangeLight,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isCurrent ? AppColors.primaryOrange : AppColors.textDark,
                              ),
                              side: BorderSide(
                                color: isCurrent ? AppColors.primaryOrange : const Color(0xFFE2E8F0),
                              ),
                              backgroundColor: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text('Select Payment Channel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    const SizedBox(height: 10),

                    _buildPaymentChannelTile(
                      id: 'moniepoint',
                      selectedId: selectedChannel,
                      title: 'Direct Bank Transfer',
                      subtitle: 'Auto-credited instantly via Moniepoint MFB',
                      icon: Icons.account_balance_rounded,
                      color: const Color(0xFF1E40AF),
                      onTap: () => setSheetState(() => selectedChannel = 'moniepoint'),
                    ),
                    const SizedBox(height: 8),

                    _buildPaymentChannelTile(
                      id: 'paystack',
                      selectedId: selectedChannel,
                      title: 'Debit Card (Paystack)',
                      subtitle: 'Mastercard, Visa, Verve & Bank app',
                      icon: Icons.credit_card_rounded,
                      color: const Color(0xFF0D9488),
                      onTap: () => setSheetState(() => selectedChannel = 'paystack'),
                    ),
                    const SizedBox(height: 8),

                    _buildPaymentChannelTile(
                      id: 'ussd',
                      selectedId: selectedChannel,
                      title: 'USSD Banking',
                      subtitle: 'Dial *737#, *894#, *901# on your phone',
                      icon: Icons.phone_android_rounded,
                      color: AppColors.primaryOrange,
                      onTap: () => setSheetState(() => selectedChannel = 'ussd'),
                    ),

                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final amt = double.tryParse(_amountController.text.trim()) ?? 5000.0;
                          if (amt <= 0) return;

                          String method;
                          if (selectedChannel == 'moniepoint') {
                            method = 'Moniepoint Instant Transfer';
                          } else if (selectedChannel == 'paystack') {
                            method = 'Debit Card (Paystack)';
                            final sheetNav = Navigator.of(sheetCtx);
                            if (sheetCtx.mounted) sheetNav.pop();
                            await _showPaystackCheckoutSheet(amt);
                            return;
                          } else {
                            method = 'USSD Banking';
                          }

                          final sheetNav = Navigator.of(sheetCtx);
                          final messenger = ScaffoldMessenger.of(context);
                          final err = await AppState.instance.fundWalletLive(amt, method);
                          if (sheetCtx.mounted) sheetNav.pop();

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                err ?? 'Successfully deposited ₦${amt.toStringAsFixed(0)} via $method!',
                              ),
                              backgroundColor: err != null ? Colors.redAccent : AppColors.nairaGreen,
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
                        child: const Text('Proceed to Deposit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
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

  Future<void> _showPaystackCheckoutSheet(double amount) async {
    final cardNumberCtrl = TextEditingController(text: '5399 8344 1092 4081');
    final expiryCtrl = TextEditingController(text: '09/28');
    final cvvCtrl = TextEditingController(text: '408');
    bool charging = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 22,
            right: 22,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0BA4DB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'PAYSTACK',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Secured Card Checkout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(modalCtx)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Paying ₦${amount.toStringAsFixed(0)} into Apace Naira Wallet',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cardNumberCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Card Number',
                  prefixIcon: const Icon(Icons.credit_card_rounded, color: Color(0xFF0BA4DB)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: expiryCtrl,
                      decoration: InputDecoration(
                        labelText: 'Expiry (MM/YY)',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: cvvCtrl,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: charging
                      ? null
                      : () async {
                          setModalState(() => charging = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(modalCtx);
                          final err = await AppState.instance.fundWalletLive(
                            amount,
                            'Debit Card (Paystack)',
                          );
                          if (modalCtx.mounted) nav.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                err ?? 'Paystack Verified: ₦${amount.toStringAsFixed(0)} added to Wallet!',
                              ),
                              backgroundColor: err != null ? Colors.redAccent : AppColors.nairaGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0BA4DB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: charging
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Pay ₦${amount.toStringAsFixed(0)} Now',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWithdrawModal() {
    final withdrawAmountController = TextEditingController(text: '5000');
    final accountNumController = TextEditingController(text: '0123456789');
    String selectedBank = _nigerianBanks[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 28,
              ),
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
                        const Text(
                          'Withdraw to Bank Account',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const Text(
                      'Funds arrive in your Nigerian bank in seconds',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedBank,
                          isExpanded: true,
                          items: _nigerianBanks.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)))).toList(),
                          onChanged: (val) {
                            if (val != null) setSheetState(() => selectedBank = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: accountNumController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      decoration: InputDecoration(
                        labelText: '10-Digit NUBAN Account Number',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: withdrawAmountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textDark),
                      decoration: InputDecoration(
                        prefixText: '₦ ',
                        labelText: 'Withdrawal Amount',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          final amt = double.tryParse(withdrawAmountController.text.trim()) ?? 0.0;
                          if (amt <= 0) return;
                          if (AppState.instance.walletBalance < amt) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Insufficient wallet balance for this withdrawal.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          TransactionPinSheet.show(
                            context,
                            title: 'Authorize Bank Withdrawal',
                            subtitle: 'Enter 4-digit PIN to transfer to $selectedBank',
                            amount: amt,
                            onSuccess: (pin) async {
                              final dlgNav = Navigator.of(dialogCtx);
                              final messenger = ScaffoldMessenger.of(context);
                              final err = await AppState.instance.withdrawFundsLive(
                                amt,
                                selectedBank,
                                accountNumController.text.trim(),
                                pin,
                              );
                              if (err == null) {
                                if (dialogCtx.mounted) dlgNav.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Transferred ₦${amt.toStringAsFixed(0)} to $selectedBank (${accountNumController.text}) successfully!'),
                                    backgroundColor: AppColors.nairaGreen,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(err),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Confirm Withdrawal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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

  void _showVirtualAccountDetailsModal() {
    final state = AppState.instance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_rounded, color: Color(0xFF1D4ED8), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Virtual Bank Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildAccountDetailRow('BANK NAME', state.virtualBankName),
                    const Divider(height: 18),
                    _buildAccountDetailRow('ACCOUNT NUMBER', state.virtualAccountNumber, isHighlight: true),
                    const Divider(height: 18),
                    _buildAccountDetailRow('BENEFICIARY NAME', state.virtualAccountName),
                    const Divider(height: 18),
                    _buildAccountDetailRow('DEPOSIT SETTLEMENT', 'Instant Auto-Credit (Zero Fee)'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  _copyAccountNumber();
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                label: const Text('Copy Account Number', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTransactionReceipt(WalletTransaction txn) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, 8)),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: txn.isCredit ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              txn.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: txn.isCredit ? AppColors.nairaGreen : AppColors.primaryOrange,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Transaction Receipt',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          txn.formattedAmount,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: txn.isCredit ? AppColors.nairaGreen : AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'SUCCESSFUL',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.nairaGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  _buildReceiptRow('Transaction Type', txn.title),
                  const SizedBox(height: 10),
                  _buildReceiptRow('Reference ID', txn.id),
                  const SizedBox(height: 10),
                  _buildReceiptRow('Description', txn.subtitle),
                  const SizedBox(height: 10),
                  _buildReceiptRow('Channel / Provider', 'Moniepoint MFB / Paystack NG'),
                  const SizedBox(height: 10),
                  _buildReceiptRow('Date & Time', '${txn.date.day}/${txn.date.month}/${txn.date.year} • ${txn.date.hour}:${txn.date.minute.toString().padLeft(2, '0')}'),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: 'APACE RECEIPT: ${txn.id}\n'
                            'Amount: ${txn.formattedAmount}\n'
                            'Type: ${txn.title}\n'
                            'Desc: ${txn.subtitle}\n'
                            'Status: SUCCESSFUL',
                      ));
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaction reference copied to clipboard!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textDark),
                    label: const Text('Copy Reference ID', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountDetailRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 17 : 13,
            fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w700,
            color: isHighlight ? AppColors.primaryOrange : AppColors.textDark,
            letterSpacing: isHighlight ? 1.0 : 0,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentChannelTile({
    required String id,
    required String selectedId,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSelected = id == selectedId;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primaryOrange : const Color(0xFFCBD5E1),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, _) {
        final state = AppState.instance;

        final allTransactions = state.transactions;
        final filteredTransactions = allTransactions.where((t) {
          if (_selectedTxnFilter == 'Top-Ups') return t.isCredit;
          if (_selectedTxnFilter == 'Dispatches') return !t.isCredit && t.category == 'dispatch';
          if (_selectedTxnFilter == 'Tips') return !t.isCredit && t.category == 'tip';
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Apace Naira Wallet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_rounded, color: AppColors.textDark),
                onPressed: _showVirtualAccountDetailsModal,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                _buildFintechDebitCard(state),

                const SizedBox(height: 22),

                _buildQuickActionsGrid(),

                const SizedBox(height: 24),

                _buildMoniepointAccountCard(state),

                const SizedBox(height: 26),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Transaction Activity',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                    ),
                    Text(
                      '${filteredTransactions.length} Items',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Top-Ups', 'Dispatches', 'Tips'].map((filter) {
                      final isSelected = _selectedTxnFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedTxnFilter = filter),
                          selectedColor: AppColors.primaryOrange,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.textDark,
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: isSelected ? AppColors.primaryOrange : const Color(0xFFE2E8F0)),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 14),

                if (filteredTransactions.isEmpty)
                  _buildEmptyTransactionState()
                else
                  for (final txn in filteredTransactions) ...[
                    _buildTransactionItem(txn),
                  ],

                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFintechDebitCard(AppState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
          BoxShadow(
            color: Color(0x32000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'APACE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Logistics Wallet',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Row(
                children: const [
                  Icon(Icons.wifi_rounded, color: Color(0xFFCBD5E1), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'NGN',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFCBD5E1)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Total Balance',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _hideBalance = !_hideBalance),
                        child: Icon(
                          _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF94A3B8),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _hideBalance ? '₦ ••••••••' : state.formattedWalletBalance,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              Container(
                width: 38,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Container(
                    width: 26,
                    height: 18,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF78350F), width: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DEDICATED ACCOUNT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        state.virtualAccountNumber,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _copyAccountNumber,
                        child: const Icon(Icons.copy_rounded, color: AppColors.primaryOrangeLight, size: 14),
                      ),
                    ],
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
                    color: AppState.instance.kycTier >= 2 ? const Color(0x1E10B981) : const Color(0x1EF59E0B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppState.instance.kycTier >= 2 ? const Color(0x3210B981) : const Color(0x32F59E0B),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppState.instance.kycTier >= 3
                            ? Icons.workspace_premium_rounded
                            : (AppState.instance.kycTier >= 2 ? Icons.shield_rounded : Icons.info_outline_rounded),
                        size: 12,
                        color: AppState.instance.kycTier >= 3
                            ? const Color(0xFFE879F9)
                            : (AppState.instance.kycTier >= 2 ? const Color(0xFF34D399) : const Color(0xFFFBBF24)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${AppState.instance.kycTierBadgeLabel} • ${AppState.instance.formattedDailyLimit}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppState.instance.kycTier >= 3
                              ? const Color(0xFFE879F9)
                              : (AppState.instance.kycTier >= 2 ? const Color(0xFF34D399) : const Color(0xFFFBBF24)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: 'Top Up',
            icon: Icons.add_rounded,
            color: AppColors.primaryOrange,
            bgColor: const Color(0xFFFFF7ED),
            onTap: _showFundWalletModal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            label: 'Send Parcel',
            icon: Icons.send_rounded,
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SendPackageScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            label: 'Withdraw',
            icon: Icons.arrow_outward_rounded,
            color: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
            onTap: _showWithdrawModal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            label: 'Bank Info',
            icon: Icons.account_balance_rounded,
            color: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
            onTap: _showVirtualAccountDetailsModal,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoniepointAccountCard(AppState state) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: Color(0xFF1E40AF), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.virtualBankName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      const Text(
                        'Automated Instant Deposit Account',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: _copyAccountNumber,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.copy_rounded, size: 13, color: AppColors.primaryOrange),
                      SizedBox(width: 4),
                      Text('Copy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryOrange)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ACCOUNT NUMBER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(
                    state.virtualAccountNumber,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark, letterSpacing: 1),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('ACCOUNT NAME', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(
                    state.virtualAccountName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: const [
                Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFF59E0B)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Transfers to this account credit your wallet automatically in 3-10 seconds.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactionState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 36, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Transactions in this filter',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your deposits, dispatch charges, and tips will show here.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(WalletTransaction txn) {
    IconData icon;
    Color iconColor;
    Color bgColor;

    if (txn.isCredit) {
      icon = Icons.arrow_downward_rounded;
      iconColor = AppColors.nairaGreen;
      bgColor = const Color(0xFFECFDF5);
    } else if (txn.category == 'tip') {
      icon = Icons.favorite_rounded;
      iconColor = const Color(0xFFEC4899);
      bgColor = const Color(0xFFFDF2F8);
    } else if (txn.category == 'withdrawal') {
      icon = Icons.arrow_outward_rounded;
      iconColor = const Color(0xFF6B7280);
      bgColor = const Color(0xFFF3F4F6);
    } else {
      icon = Icons.local_shipping_rounded;
      iconColor = AppColors.primaryOrange;
      bgColor = const Color(0xFFFFF7ED);
    }

    return InkWell(
      onTap: () => _showTransactionReceipt(txn),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    txn.subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  txn.formattedAmount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: txn.isCredit ? AppColors.nairaGreen : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Completed',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
