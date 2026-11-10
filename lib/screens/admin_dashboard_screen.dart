import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_client.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  String? _errorText;
  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _disputes = [];
  List<Map<String, dynamic>> _riders = [];
  List<Map<String, dynamic>> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final res = await Future.wait([
        ApiClient.instance.dio.get('/admin/overview'),
        ApiClient.instance.dio.get('/admin/disputes'),
        ApiClient.instance.dio.get('/admin/riders'),
        ApiClient.instance.dio.get('/admin/audit-logs'),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = res[0].data is Map ? Map<String, dynamic>.from(res[0].data) : {};
        _disputes = res[1].data is List
            ? List<Map<String, dynamic>>.from(
                (res[1].data as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
              )
            : [];
        _riders = res[2].data is List
            ? List<Map<String, dynamic>>.from(
                (res[2].data as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
              )
            : [];
        _auditLogs = res[3].data is List
            ? List<Map<String, dynamic>>.from(
                (res[3].data as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
              )
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = ApiClient.extractError(e);
      });
    }
  }

  Future<void> _resolveDispute(String disputeId, String resolution) async {
    try {
      await ApiClient.instance.dio.patch('/admin/disputes/$disputeId/resolve', data: {
        'resolution': resolution,
        'notes': 'Reviewed & finalized from Admin Console',
      });
      await _loadAdminData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.extractError(e)), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _approveRider(String userId, String status) async {
    try {
      await ApiClient.instance.dio.patch('/admin/riders/$userId/approve', data: {'status': status});
      await _loadAdminData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.extractError(e)), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          title: const Text('Admin Operations Center', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadAdminData),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.primaryOrange,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'Disputes'),
              Tab(text: 'Fleet KYC'),
              Tab(text: 'Audit Logs'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
            : (_errorText != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.admin_panel_settings_rounded, size: 48, color: AppColors.primaryOrange),
                          const SizedBox(height: 12),
                          const Text(
                            'Admin Role Required',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorText!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      _buildOverviewStrip(),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildDisputesTab(),
                            _buildRidersTab(),
                            _buildAuditTab(),
                          ],
                        ),
                      ),
                    ],
                  )),
      ),
    );
  }

  Widget _buildOverviewStrip() {
    return Container(
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: Row(
        children: [
          _metric('Users', '${_overview['totalUsers'] ?? 0}'),
          _metric('Orders', '${_overview['totalOrders'] ?? 0}'),
          _metric('Disputes', '${_overview['openDisputes'] ?? 0}'),
          _metric('Escrow/Float', '₦${((_overview['totalWalletLiabilityNgn'] as num?) ?? 0).toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  Widget _metric(String label, String val) {
    return Expanded(
      child: Column(
        children: [
          Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textDark)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDisputesTab() {
    if (_disputes.isEmpty) {
      return const Center(child: Text('No disputes logged yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _disputes.length,
      itemBuilder: (_, i) {
        final d = _disputes[i];
        final isOpen = d['status'] == 'OPEN' || d['status'] == 'INVESTIGATING';
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(d['reason']?.toString() ?? 'Dispute', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Chip(label: Text(d['status']?.toString() ?? 'OPEN', style: const TextStyle(fontSize: 11))),
                  ],
                ),
                Text(d['description']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (isOpen) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _resolveDispute(d['id'].toString(), 'RESOLVED_REFUND'),
                          child: const Text('Refund Buyer'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _resolveDispute(d['id'].toString(), 'RESOLVED_RELEASE'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldGreen, foregroundColor: Colors.white),
                          child: const Text('Release Merchant'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRidersTab() {
    if (_riders.isEmpty) {
      return const Center(child: Text('No riders registered yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _riders.length,
      itemBuilder: (_, i) {
        final r = _riders[i];
        final u = r['user'] is Map ? r['user'] as Map : {};
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            title: Text(u['fullName']?.toString() ?? 'Rider', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${r['vehicleType']} • ${r['plateNumber']} • ${r['approvalStatus']}'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => _approveRider(r['userId'].toString(), v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'APPROVED', child: Text('Approve Rider')),
                PopupMenuItem(value: 'REJECTED', child: Text('Reject Rider')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuditTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _auditLogs.length,
      itemBuilder: (_, i) {
        final log = _auditLogs[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.security_rounded, size: 18, color: AppColors.primaryOrange),
          title: Text(log['action']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          subtitle: Text('${log['resource']} • ${log['createdAt']}', style: const TextStyle(fontSize: 11)),
        );
      },
    );
  }
}

