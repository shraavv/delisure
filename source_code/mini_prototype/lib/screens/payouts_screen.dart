import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/payout.dart';
import '../widgets/payout_tile.dart';
import '../services/api_service.dart';

class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Rainfall', 'Cyclone', 'Heat', 'AQI', 'Bandh', 'Outage', 'Traffic'];

  bool _isLoading = true;

  List<_PayoutEntry> _allPayouts = [];
  double _totalPaidOut = 0;
  double _totalPremiumsPaid = 0;
  int _payoutCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = ApiService();
      String? workerId = await api.loadWorkerId();
      if (workerId == null) {
        _useMockData();
        return;
      }

      final payoutsData = await api.getPayouts(workerId);

      if (payoutsData != null && payoutsData['payouts'] != null) {
        final List<dynamic> apiPayouts = payoutsData['payouts'];
        _totalPaidOut = double.tryParse(payoutsData['totalPaidOut']?.toString() ?? '0') ?? 0;
        _payoutCount = int.tryParse(payoutsData['count']?.toString() ?? '') ?? apiPayouts.length;

        _allPayouts = apiPayouts.map((p) {
          return _PayoutEntry(
            payout: Payout(
              id: p['id'] ?? '',
              workerId: p['worker_id'] ?? '',
              triggerEventId: p['trigger_event_id'] ?? '',
              amount: double.tryParse(p['amount']?.toString() ?? '0') ?? 0,
              status: p['status'] ?? 'credited',
              timestamp: DateTime.tryParse(p['created_at']?.toString() ?? '') ?? DateTime.now(),
              breakdown: p['breakdown'] ?? '',
            ),
            triggerType: p['trigger_type'] ?? 'rainfall',
            zone: p['zone'] ?? '',
          );
        }).toList();

        final policiesData = await api.getPolicies(workerId);
        if (policiesData != null && policiesData['active'] != null) {
          _totalPremiumsPaid = double.tryParse(policiesData['active']['total_premiums_paid']?.toString() ?? '') ?? 0;
        }
      } else {
        _useMockData();
        return;
      }
    } catch (_) {
      _useMockData();
      return;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _useMockData() {
    _allPayouts = [];
    _totalPaidOut = 0;
    _totalPremiumsPaid = 0;
    _payoutCount = 0;
    if (mounted) setState(() => _isLoading = false);
  }

  List<_PayoutEntry> _filteredPayouts() {
    if (_selectedFilter == 'All') return _allPayouts;
    return _allPayouts.where((entry) {
      final type = entry.triggerType.toLowerCase();
      return type == _selectedFilter.toLowerCase();
    }).toList();
  }

  String _formatINR(double amount) {
    return amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.bgLight,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final netBenefit = _totalPaidOut - _totalPremiumsPaid;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 16,
              20,
              24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A1F12), Color(0xFF0D2B18), Color(0xFF103520)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Total Payouts',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '\u20b9${_formatINR(_totalPaidOut)}',
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withAlpha(15)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryStat(
                          'Premiums Paid',
                          '\u20b9${_formatINR(_totalPremiumsPaid)}',
                          Icons.arrow_upward_rounded,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: Colors.white.withAlpha(20),
                      ),
                      Expanded(
                        child: _buildSummaryStat(
                          'Net Benefit',
                          '${netBenefit >= 0 ? '+' : ''}\u20b9${_formatINR(netBenefit.abs())}',
                          Icons.trending_up_rounded,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: Colors.white.withAlpha(20),
                      ),
                      Expanded(
                        child: _buildSummaryStat(
                          'Claims',
                          '$_payoutCount',
                          Icons.receipt_long_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _filters.map((filter) {
                final selected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                    backgroundColor: AppTheme.bgElevated,
                    selectedColor: AppTheme.primaryBlue.withAlpha(25),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                    ),
                    checkmarkColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: selected ? AppTheme.primaryBlue.withAlpha(80) : AppTheme.borderColor,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _filteredPayouts().isEmpty
                ? Center(
                    child: Text(
                      'No payouts for this filter',
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _filteredPayouts().length,
                    itemBuilder: (context, index) {
                      final entry = _filteredPayouts()[index];
                      final canAppeal = entry.payout.status == 'pending_review' ||
                                        entry.payout.status == 'failed';
                      final isCredited = entry.payout.status == 'credited';
                      return Stack(
                        children: [
                          PayoutTile(
                            payout: entry.payout,
                            triggerType: entry.triggerType,
                            zone: entry.zone,
                          ),
                          if (canAppeal)
                            Positioned(
                              top: 14,
                              right: 14,
                              child: _smallBadge(
                                icon: Icons.gavel_outlined,
                                label: 'Appeal',
                                color: AppTheme.primaryBlue,
                                onTap: () => _openAppealDialog(entry.payout),
                              ),
                            ),
                          if (isCredited)
                            Positioned(
                              top: 14,
                              right: 14,
                              child: _smallBadge(
                                icon: Icons.receipt_long_outlined,
                                label: 'Invoice',
                                color: AppTheme.successGreen,
                                onTap: () => _downloadInvoice(entry.payout),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _smallBadge({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withAlpha(100)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    )),
              ],
            ),
          ),
        ),
      );

  Future<Directory> _publicOutputDir() async {
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final docs = Directory('${ext.path}/Documents');
        if (!await docs.exists()) await docs.create(recursive: true);
        return docs;
      }
    }
    return getApplicationDocumentsDirectory();
  }

  Future<void> _downloadInvoice(Payout payout) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Generating invoice…'), behavior: SnackBarBehavior.floating),
    );
    try {
      final api = ApiService();
      final url = Uri.parse(api.invoicePdfUrl(payout.id));
      final res = await http.get(url, headers: {'x-api-key': 'delisure-demo-key-2026'}).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        messenger.showSnackBar(
          SnackBar(content: Text('Invoice failed (${res.statusCode})'), backgroundColor: Colors.red.shade700),
        );
        return;
      }
      final dir = await _publicOutputDir();
      final file = File('${dir.path}/delisure-invoice-${payout.id}.pdf');
      await file.writeAsBytes(res.bodyBytes);
      bool opened = false;
      try {
        final r = await OpenFilex.open(file.path, type: 'application/pdf');
        opened = r.type == ResultType.done;
      } catch (_) {}
      if (!mounted) return;
      if (opened) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Invoice saved (${(res.bodyBytes.length / 1024).toStringAsFixed(1)} KB) — ${file.path}'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: Text('Invoice saved',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PDF saved to:', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                SelectableText(file.path, style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 11)),
                const SizedBox(height: 8),
                Text('Tip: open your Files app → Android → data → com.delisure.app → files → Documents',
                    style: GoogleFonts.inter(color: AppTheme.textHint, fontSize: 10)),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Invoice error: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _openAppealDialog(Payout payout) async {
    final reasonController = TextEditingController();
    final api = ApiService();
    final workerId = await api.loadWorkerId();
    if (workerId == null || !mounted) return;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Request Review',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Our system flagged this claim for review. Tell us what happened — an operator will look into it and you won\'t lose your claim.',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'I was riding during the downpour but my phone lost GPS…',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.textHint),
                filled: true,
                fillColor: AppTheme.bgInput,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (submitted != true) return;
    final reason = reasonController.text.trim();
    if (reason.length < 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please provide at least 10 characters'),
            backgroundColor: Colors.red.shade700),
      );
      return;
    }

    final result = await api.submitAppeal(payout.id, workerId, reason);
    if (!mounted) return;
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']), backgroundColor: Colors.red.shade700),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Appeal submitted — expect a response within 24 hours'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.white.withAlpha(120)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white.withAlpha(150),
          ),
        ),
      ],
    );
  }
}

class _PayoutEntry {
  final Payout payout;
  final String triggerType;
  final String zone;

  _PayoutEntry({
    required this.payout,
    required this.triggerType,
    required this.zone,
  });
}
