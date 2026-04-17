import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _analytics = {};
  List<Map<String, dynamic>> _fraudChecks = [];
  List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _triggers = [];
  List<Map<String, dynamic>> _pendingPayouts = [];
  List<Map<String, dynamic>> _appeals = [];
  Map<String, dynamic> _mlMetrics = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getAdminStats().catchError((_) => null),
        _api.getAdminAnalytics().catchError((_) => null),
        _api.getFraudChecks().catchError((_) => null),
        _api.getAllWorkers().catchError((_) => null),
        _api.getAllTriggerHistory().catchError((_) => null),
        _api.getPendingPayouts().catchError((_) => null),
        _api.getAdminAppeals().catchError((_) => null),
        _api.getMLModelMetrics().catchError((_) => null),
      ]);

      final stats = results[0];
      final analytics = results[1];
      final fraud = results[2];
      final workers = results[3];
      final triggers = results[4];
      final pending = results[5];
      final appeals = results[6];
      final mlMetrics = results[7];

      if (stats != null) _stats = stats;
      if (mlMetrics != null) _mlMetrics = mlMetrics;
      if (analytics != null) _analytics = analytics;
      if (fraud != null && fraud['fraudChecks'] != null) {
        _fraudChecks = List<Map<String, dynamic>>.from(fraud['fraudChecks']);
      }
      if (workers != null && workers['workers'] != null) {
        _workers = List<Map<String, dynamic>>.from(workers['workers']);
      }
      if (triggers != null && triggers['events'] != null) {
        _triggers = List<Map<String, dynamic>>.from(triggers['events']);
      }
      if (pending != null && pending['pendingPayouts'] != null) {
        _pendingPayouts = List<Map<String, dynamic>>.from(pending['pendingPayouts']);
      }
      if (appeals != null && appeals['appeals'] != null) {
        _appeals = List<Map<String, dynamic>>.from(appeals['appeals']);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showSnack(String msg, {Color? color}) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildKeyStats()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppTheme.primaryBlue,
                indicatorWeight: 2.5,
                labelColor: AppTheme.primaryBlue,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: [
                  const Tab(text: 'Analytics'),
                  Tab(text: 'Pending (${_pendingPayouts.length})'),
                  Tab(text: 'Appeals (${_appeals.where((a) => a['status'] == 'open').length})'),
                  const Tab(text: 'Fraud Checks'),
                  const Tab(text: 'Workers'),
                  const Tab(text: 'Triggers'),
                ],
              ),
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildAnalyticsTab(),
                  _buildPendingPayoutsTab(),
                  _buildAppealsTab(),
                  _buildFraudChecksTab(),
                  _buildWorkersTab(),
                  _buildTriggersTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F0F14), Color(0xFF18181B)],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await _api.adminLogout();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: AppTheme.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin Console',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Delisure Insurer Panel',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withAlpha(150))),
              ],
            ),
          ),
          _headerIconButton(
            icon: Icons.file_download_outlined,
            tooltip: 'Export compliance audit',
            onTap: _exportAuditPdf,
          ),
          const SizedBox(width: 8),
          _headerIconButton(
            icon: Icons.bug_report_outlined,
            tooltip: 'Simulate GPS spoof (demo)',
            onTap: _showSpoofDialog,
          ),
          const SizedBox(width: 8),
          _headerIconButton(
            icon: Icons.gavel_outlined,
            tooltip: 'Simulate held claim (demo)',
            onTap: _simulateHeldClaim,
          ),
          const SizedBox(width: 8),
          _headerIconButton(
            icon: _isLoading ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
            tooltip: 'Refresh',
            onTap: () { HapticFeedback.lightImpact(); _loadData(); },
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppTheme.bgElevated, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppTheme.textPrimary, size: 18),
        ),
      ),
    );
  }

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

  Future<void> _exportAuditPdf() async {
    _showSnack('Downloading compliance audit…');
    try {
      final uri = Uri.parse(_api.auditReportUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        _showSnack('Download failed (${res.statusCode})', color: Colors.red.shade700);
        return;
      }
      final dir = await _publicOutputDir();
      final file = File('${dir.path}/delisure-audit-${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(res.bodyBytes);

      bool opened = false;
      try {
        final r = await OpenFilex.open(file.path, type: 'application/pdf');
        opened = r.type == ResultType.done;
      } catch (_) {}

      if (!mounted) return;
      if (opened) {
        _showSnack('Audit saved (${(res.bodyBytes.length / 1024).toStringAsFixed(1)} KB) — ${file.path}',
            color: AppTheme.successGreen);
      } else {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.bgCard,
            title: Text('Audit saved',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PDF downloaded (${(res.bodyBytes.length / 1024).toStringAsFixed(1)} KB).',
                    style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                SelectableText(file.path,
                    style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 11)),
                const SizedBox(height: 8),
                Text('Open Files app → Android → data → com.delisure.app → files → Documents',
                    style: GoogleFonts.inter(color: AppTheme.textHint, fontSize: 10)),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Export failed: $e', color: Colors.red.shade700);
    }
  }

  Future<void> _confirmPayoutAction(Map<String, dynamic> p, {required bool approve}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text(approve ? 'Approve payout?' : 'Reject payout?',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Worker', '${p['worker_name']} (${p['worker_id']})'),
            _kv('Trigger', '${p['trigger_type']} · ${p['zone']}'),
            _kv('Amount', '₹${p['amount']}'),
            _kv('Risk Score', '${(_toDouble(p['fraud_score']) * 100).toStringAsFixed(0)}%'),
            const SizedBox(height: 8),
            Text(
              approve
                ? 'This will credit ₹${p['amount']} to the worker\'s UPI.'
                : 'This will reject the claim. Worker can still appeal.',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? AppTheme.successGreen : AppTheme.alertRed,
              foregroundColor: Colors.white,
            ),
            child: Text(approve ? 'Yes, credit' : 'Yes, reject'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    if (approve) {
      final res = await _api.approvePayout(p['id']);
      if (!mounted) return;
      if (res != null) {
        final rzp = res['razorpay'];
        if (rzp != null) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppTheme.bgCard,
              title: Row(children: [
                const Icon(Icons.check_circle, color: AppTheme.successGreen),
                const SizedBox(width: 8),
                Text('Payout Credited',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Razorpay (test mode) gateway trail:',
                      style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 10),
                  _kv('Order ID',   rzp['orderId'].toString()),
                  _kv('Payout ID',  rzp['payoutId'].toString()),
                  _kv('Status',     rzp['status'].toString().toUpperCase()),
                  _kv('UTR',        rzp['utr'].toString()),
                  _kv('Amount',     '₹${p['amount']}'),
                  _kv('UPI',        p['worker_upi'] ?? '—'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        } else {
          _showSnack('Approved — ₹${p['amount']} credited via UPI',
              color: AppTheme.successGreen);
        }
      } else {
        _showSnack('Approval failed', color: Colors.red.shade700);
      }
    } else {
      final res = await _api.rejectPayout(p['id']);
      if (!mounted) return;
      if (res != null) {
        _showSnack('Payout rejected', color: AppTheme.alertRed);
      } else {
        _showSnack('Rejection failed', color: Colors.red.shade700);
      }
    }
    await _loadData();
  }

  Future<void> _simulateHeldClaim() async {
    if (_workers.isEmpty) {
      _showSnack('Load workers first');
      return;
    }
    final worker = _workers.first;
    final zones = (worker['zones'] is List && (worker['zones'] as List).isNotEmpty)
        ? (worker['zones'] as List).first.toString()
        : 'velachery';
    _showSnack('Simulating flagged claim for ${worker['name']}…');
    final result = await _api.simulateTrigger(
      type: 'rainfall',
      zone: zones,
      intensity: 18,
      durationHours: 2,
      startHour: 19,
      forceReview: true,
    );
    if (!mounted) return;
    if (result['error'] != null) {
      _showSnack('Simulation failed: ${result['error']}', color: Colors.red.shade700);
      return;
    }
    _showSnack('Flagged claim created — check Pending tab', color: AppTheme.warningOrange);
    await _loadData();
    _tabController.animateTo(1);
  }

  Future<void> _showSpoofDialog() async {
    if (_workers.isEmpty) {
      _showSnack('No workers to simulate on. Register or load workers first.');
      return;
    }
    String selectedWorker = _workers.first['id'];
    String selectedZone = (_workers.first['zones'] is List && (_workers.first['zones'] as List).isNotEmpty)
        ? (_workers.first['zones'] as List).first.toString()
        : 'velachery';
    String selectedScenario = 'gps_distance';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: Text('Simulate GPS Spoof', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Feed adversarial signals to the fraud model.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedWorker,
                  isExpanded: true,
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Worker', border: OutlineInputBorder()),
                  items: _workers
                      .map((w) => DropdownMenuItem<String>(
                            value: w['id'] as String,
                            child: Text(
                              '${w['name']} (${w['id']})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setSt(() {
                      selectedWorker = v;
                      final w = _workers.firstWhere((x) => x['id'] == v);
                      if (w['zones'] is List && (w['zones'] as List).isNotEmpty) {
                        selectedZone = (w['zones'] as List).first.toString();
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: selectedZone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Zone', border: OutlineInputBorder()),
                  onChanged: (v) => selectedZone = v,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedScenario,
                  isExpanded: true,
                  dropdownColor: AppTheme.bgCard,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Spoof scenario', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'gps_distance', child: Text('GPS Distance Anomaly')),
                    DropdownMenuItem(value: 'activity_paradox', child: Text('Activity Paradox')),
                    DropdownMenuItem(value: 'rapid_fire', child: Text('Rapid-Fire Claims')),
                    DropdownMenuItem(value: 'frequency_outlier', child: Text('Frequency Outlier')),
                    DropdownMenuItem(value: 'coordinated', child: Text('Coordinated Attack (multi-signal)')),
                  ],
                  onChanged: (v) => setSt(() => selectedScenario = v ?? 'gps_distance'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _runSpoof(selectedWorker, selectedZone, selectedScenario);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              child: const Text('Run'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runSpoof(String workerId, String zone, String scenario) async {
    _showSnack('Running spoof scenario…');
    final result = await _api.simulateSpoof(workerId, zone, scenario);
    if (!mounted) return;

    if (result['error'] != null) {
      _showSnack('Error: ${result['error']}', color: Colors.red.shade700);
      return;
    }

    final verdict = result['verdict'] ?? {};
    final fraud = result['fraudResult'] ?? {};
    final caught = verdict['caught'] == true;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Row(
          children: [
            Icon(caught ? Icons.shield : Icons.warning, color: caught ? AppTheme.successGreen : AppTheme.alertRed),
            const SizedBox(width: 8),
            Text(caught ? 'Spoof Caught' : 'Spoof Passed',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result['description'] ?? '', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              _kv('Scenario', (result['scenario'] ?? '').toString()),
              _kv('Risk Score', '${(_toDouble(fraud['risk_score']) * 100).toStringAsFixed(0)}%'),
              _kv('Recommendation', (fraud['recommendation'] ?? '').toString().toUpperCase()),
              _kv('Verdict', verdict['action']?.toString() ?? ''),
              const SizedBox(height: 8),
              if (fraud['flags'] is List && (fraud['flags'] as List).isNotEmpty) ...[
                Text('Flags:', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ...(fraud['flags'] as List).map((f) =>
                    Text('  • $f', style: GoogleFonts.inter(color: AppTheme.alertRed, fontSize: 12))),
              ],
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(k, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary))),
            Expanded(child: Text(v, style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500))),
          ],
        ),
      );

  Widget _buildKeyStats() {
    final int totalWorkers = _stats['totalWorkers'] ?? 0;
    final int activePolicies = _stats['activePolicies'] ?? 0;
    final double lossRatio = _toDouble(_analytics['lossRatioPct']);
    final int predictedClaims = _analytics['predictedNextWeekClaims'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          _statCard('Workers', '$totalWorkers', Icons.people, AppTheme.primaryBlue),
          _statCard('Active Policies', '$activePolicies', Icons.shield, AppTheme.successGreen),
          _statCard('Loss Ratio', '${lossRatio.toStringAsFixed(1)}%', Icons.trending_up,
              lossRatio > 80 ? AppTheme.alertRed : lossRatio > 50 ? AppTheme.warningOrange : AppTheme.successGreen),
          _statCard('Predicted Claims (next wk)', '$predictedClaims', Icons.auto_graph, AppTheme.warningOrange),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accent.withAlpha(30), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis),
                Text(value,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // ANALYTICS TAB
  // ──────────────────────────────────────────────────────────────────
  Widget _buildAnalyticsTab() {
    final weekly = List<Map<String, dynamic>>.from(_analytics['weeklyTrend'] ?? []);
    final typeBreakdown = List<Map<String, dynamic>>.from(_analytics['triggerTypeBreakdown'] ?? []);
    final zones = List<Map<String, dynamic>>.from(_analytics['zoneBreakdown'] ?? []);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Weekly Claim Flow (8 weeks)'),
          _stackedWeeklyChart(weekly),
          const SizedBox(height: 24),
          _sectionTitle('Claims by Trigger Type (30d)'),
          _triggerTypePie(typeBreakdown),
          const SizedBox(height: 16),
          ...typeBreakdown.map(_triggerTypeRow),
          if (typeBreakdown.isEmpty) _emptyState('No claims in the last 30 days'),
          const SizedBox(height: 24),
          _sectionTitle('Zone Activity (30d)'),
          ...zones.map(_zoneRow),
          if (zones.isEmpty) _emptyState('No triggered events in the last 30 days'),
          const SizedBox(height: 24),
          _sectionTitle('Fraud Summary'),
          _fraudSummaryBox(),
          const SizedBox(height: 24),
          _sectionTitle('ML Model Precision'),
          _modelMetricsPanel(),
          const SizedBox(height: 24),
          _sectionTitle('Payment Gateway'),
          _razorpayBadge(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _razorpayBadge() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1E3F), Color(0xFF13294B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3395FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Razorpay',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('TEST MODE',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warningOrange)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('UPI instant credit via RazorpayX',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Every approved claim creates a real Razorpay order + payout in test mode. '
              'Order IDs (order_*) and payout IDs (pout_*) are traceable in each claim\'s details.',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              _badgeChip('Orders ✓', AppTheme.successGreen),
              const SizedBox(width: 6),
              _badgeChip('Payouts ✓', AppTheme.successGreen),
              const SizedBox(width: 6),
              _badgeChip('Webhooks ✓', AppTheme.successGreen),
              const SizedBox(width: 6),
              _badgeChip('HMAC-SHA256 ✓', AppTheme.successGreen),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText('Key: rzp_test_delisure2026',
              style: GoogleFonts.robotoMono(fontSize: 10, color: AppTheme.textHint)),
        ],
      ),
    );
  }

  Widget _badgeChip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w600, color: c)),
      );

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
      );

  Widget _emptyState(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(child: Text(msg, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textHint))),
      );

  Widget _stackedWeeklyChart(List<Map<String, dynamic>> weekly) {
    if (weekly.isEmpty) return _emptyState('No weekly data yet');
    double maxClaims = 0;
    for (final w in weekly) {
      final c = _toInt(w['claims']) +
                _toInt(w['pending']) +
                _toInt(w['blocked']);
      if (c > maxClaims) maxClaims = c.toDouble();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxClaims > 0 ? maxClaims * 1.3 : 5,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.borderColor, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}',
                          style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textHint)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= weekly.length) return const SizedBox();
                        final label = (weekly[i]['week'] as String).substring(5);
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textHint)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < weekly.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: (_toDouble(weekly[i]['claims']) +
                              _toDouble(weekly[i]['pending']) +
                              _toDouble(weekly[i]['blocked'])).toDouble(),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        rodStackItems: [
                          BarChartRodStackItem(
                            0,
                            _toDouble(weekly[i]['claims']).toDouble(),
                            AppTheme.successGreen,
                          ),
                          BarChartRodStackItem(
                            _toDouble(weekly[i]['claims']).toDouble(),
                            (_toDouble(weekly[i]['claims']) + _toDouble(weekly[i]['pending'])).toDouble(),
                            AppTheme.warningOrange,
                          ),
                          BarChartRodStackItem(
                            (_toDouble(weekly[i]['claims']) + _toDouble(weekly[i]['pending'])).toDouble(),
                            (_toDouble(weekly[i]['claims']) +
                                  _toDouble(weekly[i]['pending']) +
                                  _toDouble(weekly[i]['blocked']))
                                .toDouble(),
                            AppTheme.alertRed,
                          ),
                        ],
                      ),
                    ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _trendLegend('Credited', AppTheme.successGreen),
              _trendLegend('Pending', AppTheme.warningOrange),
              _trendLegend('Blocked', AppTheme.alertRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _triggerTypePie(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox.shrink();
    final colors = [
      AppTheme.primaryBlue,
      AppTheme.warningOrange,
      AppTheme.successGreen,
      AppTheme.alertRed,
      const Color(0xFF60A5FA),
      const Color(0xFFA78BFA),
      const Color(0xFF2DD4BF),
      const Color(0xFFFB7185),
    ];
    final total = data.fold<double>(0, (s, r) => s + _toDouble(r['total']));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 32,
                sections: [
                  for (int i = 0; i < data.length; i++)
                    PieChartSectionData(
                      color: colors[i % colors.length],
                      value: _toDouble(data[i]['total']),
                      title: '${((_toDouble(data[i]['total']) / (total == 0 ? 1 : total)) * 100).toStringAsFixed(0)}%',
                      titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                      radius: 44,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < data.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${data[i]['type']}',
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textPrimary)),
                        ),
                        Text('₹${NumberFormat('#,##0').format(_toDouble(data[i]['total']))}',
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
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

  Widget _modelMetricsPanel() {
    if (_mlMetrics.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty, color: AppTheme.textSecondary, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('ML metrics unavailable — is the ML service running?',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary))),
          ],
        ),
      );
    }

    final fraud = _mlMetrics['fraud_model'] ?? {};
    final premium = _mlMetrics['premium_model'] ?? {};
    final thresholds = _mlMetrics['thresholds'] ?? {};

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryBlue.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.shield_outlined, color: AppTheme.primaryBlue, size: 18),
                const SizedBox(width: 8),
                Text('Fraud Detection — Isolation Forest',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
              const SizedBox(height: 12),
              _metricBar('Precision',    (fraud['precision'] ?? 0).toDouble(), AppTheme.successGreen),
              _metricBar('Recall',       (fraud['recall'] ?? 0).toDouble(), AppTheme.primaryBlue),
              _metricBar('F1 Score',     (fraud['f1_score'] ?? 0).toDouble(), AppTheme.warningOrange),
              _metricBar('Accuracy',     (fraud['accuracy'] ?? 0).toDouble(), Colors.purpleAccent),
              _metricBar('False Pos Rate', (fraud['false_positive_rate'] ?? 0).toDouble(),
                         AppTheme.alertRed, invert: true),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 4, children: [
                _metricChip('TP: ${fraud['true_positives'] ?? 0}', AppTheme.successGreen),
                _metricChip('TN: ${fraud['true_negatives'] ?? 0}', AppTheme.primaryBlue),
                _metricChip('FP: ${fraud['false_positives'] ?? 0}', AppTheme.warningOrange),
                _metricChip('FN: ${fraud['false_negatives'] ?? 0}', AppTheme.alertRed),
                _metricChip('Trees: ${fraud['n_estimators'] ?? 0}', AppTheme.textSecondary),
              ]),
              const SizedBox(height: 8),
              Text(
                'Thresholds — approve < ${thresholds['approve_below']}  ·  review ${(thresholds['review_between'] as List?)?.join('–') ?? '—'}  ·  block ≥ ${thresholds['block_above']}',
                style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textHint),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warningOrange.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.trending_up, color: AppTheme.warningOrange, size: 18),
                const SizedBox(width: 8),
                Text('Premium Pricing — XGBoost Regressor',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _metricTile('MAE', '₹${premium['mae_inr'] ?? '—'}')),
                Expanded(child: _metricTile('RMSE', '₹${premium['rmse_inr'] ?? '—'}')),
                Expanded(child: _metricTile('R²', '${premium['r2_score'] ?? '—'}')),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 4, children: [
                _metricChip('Train: ${premium['train_samples'] ?? 0}', AppTheme.primaryBlue),
                _metricChip('Test: ${premium['test_samples'] ?? 0}', AppTheme.textSecondary),
                _metricChip('Trees: ${premium['n_estimators'] ?? 0}', AppTheme.textSecondary),
                _metricChip('Depth: ${premium['max_depth'] ?? 0}', AppTheme.textSecondary),
                _metricChip('Features: ${premium['feature_count'] ?? 0}', AppTheme.textSecondary),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricBar(String label, double value, Color color, {bool invert = false}) {
    final displayValue = invert ? 1 - value : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary))),
              Text('${(value * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: displayValue.clamp(0, 1),
              backgroundColor: AppTheme.bgElevated,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Text(text,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _metricTile(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      );

  Widget _weeklyTrendChart(List<Map<String, dynamic>> weekly) {
    if (weekly.isEmpty) return _emptyState('No weekly data yet');
    final maxVal = weekly
        .map((w) => _toDouble(w['credited']))
        .fold<double>(0, (prev, v) => v > prev ? v : prev);
    final formatter = NumberFormat('#,##0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2 + 100,
                gridData: FlGridData(show: true, drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.borderColor, strokeWidth: 0.5)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, _) => Text('₹${formatter.format(v)}',
                          style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textHint)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= weekly.length) return const SizedBox();
                        final label = (weekly[i]['week'] as String).substring(5);
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textHint)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < weekly.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: _toDouble(weekly[i]['credited']),
                        color: AppTheme.primaryBlue,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _trendLegend('Credited', AppTheme.primaryBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trendLegend(String label, Color color) => Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      );

  Widget _triggerTypeRow(Map<String, dynamic> row) {
    final total = _toDouble(row['total']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(_triggerIcon(row['type']), color: _triggerColor(row['type']), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((row['type'] ?? '').toString().toUpperCase(),
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                Text('${row['count']} claim(s)',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text('₹${NumberFormat('#,##0').format(total)}',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
        ],
      ),
    );
  }

  Widget _zoneRow(Map<String, dynamic> row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Expanded(child: Text(row['zone']?.toString() ?? '-', style: GoogleFonts.inter(fontSize: 13, color: Colors.white))),
          Text('${row['triggers']} triggers',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.warningOrange)),
          const SizedBox(width: 10),
          Text('₹${NumberFormat('#,##0').format(_toDouble(row['payouts']))}',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _fraudSummaryBox() {
    final fs = _analytics['fraudStats'] ?? {};
    final flagged = fs['flaggedCount'] ?? 0;
    final total = fs['totalChecks'] ?? 0;
    final avg = (fs['avgRiskScore'] ?? '0.000').toString();
    final rate = (fs['flagRate'] ?? '0.0').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _fraudCell('Checks (30d)', '$total', AppTheme.primaryBlue)),
            Expanded(child: _fraudCell('Flagged', '$flagged', AppTheme.alertRed)),
            Expanded(child: _fraudCell('Flag Rate', '$rate%', AppTheme.warningOrange)),
            Expanded(child: _fraudCell('Avg Risk', avg, AppTheme.textPrimary)),
          ]),
        ],
      ),
    );
  }

  Widget _fraudCell(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      );

  // ──────────────────────────────────────────────────────────────────
  // PENDING TAB
  // ──────────────────────────────────────────────────────────────────
  Widget _buildPendingPayoutsTab() {
    if (_pendingPayouts.isEmpty) return _emptyState('No payouts awaiting review');
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingPayouts.length,
        itemBuilder: (_, i) => _pendingPayoutCard(_pendingPayouts[i]),
      ),
    );
  }

  Widget _pendingPayoutCard(Map<String, dynamic> p) {
    final fraudScore = _toDouble(p['fraud_score']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningOrange.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['worker_name'] ?? '-',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('${p['trigger_type']} · ${p['zone']}',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Text('₹${p['amount']}',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.warningOrange)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.alertRed.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Risk ${(fraudScore * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.alertRed)),
              ),
              if (p['upi_id'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('UPI: ${p['upi_id']}',
                      style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.primaryBlue)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmPayoutAction(p, approve: false),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.alertRed),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmPayoutAction(p, approve: true),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // APPEALS TAB
  // ──────────────────────────────────────────────────────────────────
  Widget _buildAppealsTab() {
    if (_appeals.isEmpty) return _emptyState('No worker appeals yet');
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _appeals.length,
        itemBuilder: (_, i) => _appealCard(_appeals[i]),
      ),
    );
  }

  Widget _appealCard(Map<String, dynamic> a) {
    final status = (a['status'] ?? 'open').toString();
    final isOpen = status == 'open';
    final statusColor = status == 'resolved_approved'
        ? AppTheme.successGreen
        : status == 'resolved_rejected'
            ? AppTheme.alertRed
            : AppTheme.warningOrange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['worker_name'] ?? '-',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('${a['trigger_type'] ?? '-'} · ${a['zone'] ?? '-'} · ₹${a['amount'] ?? '-'}',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status.replaceAll('_', ' ').toUpperCase(),
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.bgElevated, borderRadius: BorderRadius.circular(8)),
            child: Text('"${a['reason'] ?? ''}"',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textPrimary, fontStyle: FontStyle.italic)),
          ),
          if (a['admin_notes'] != null && (a['admin_notes'] as String).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Admin note: ${a['admin_notes']}',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textHint)),
          ],
          if (isOpen) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await _api.rejectAppeal(a['id']);
                      _showSnack('Appeal rejected');
                      await _loadData();
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.alertRed),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _api.approveAppeal(a['id']);
                      _showSnack('Appeal approved, payout credited', color: AppTheme.successGreen);
                      await _loadData();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen, foregroundColor: Colors.white),
                    child: const Text('Approve & Credit'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // FRAUD CHECKS TAB
  // ──────────────────────────────────────────────────────────────────
  Widget _buildFraudChecksTab() {
    if (_fraudChecks.isEmpty) return _emptyState('No fraud checks recorded');
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _fraudChecks.length,
        itemBuilder: (_, i) => _fraudCheckRow(_fraudChecks[i]),
      ),
    );
  }

  Widget _fraudCheckRow(Map<String, dynamic> fc) {
    final score = _toDouble(fc['risk_score']);
    final rec = (fc['recommendation'] ?? 'approve').toString();
    final color = rec == 'block' ? AppTheme.alertRed : rec == 'review' ? AppTheme.warningOrange : AppTheme.successGreen;
    final flags = (fc['flags'] is List)
        ? List<String>.from((fc['flags'] as List).map((e) => e.toString()))
        : <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fc['worker_name'] ?? '-',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('${fc['trigger_type'] ?? '-'} · ${fc['zone'] ?? '-'}',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${(score * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
                  Text(rec.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ],
          ),
          if (flags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: flags.map(_flagChip).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _flagChip(String flag) {
    final meta = _flagMeta(flag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: meta.color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: meta.color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 11, color: meta.color),
          const SizedBox(width: 4),
          Text(meta.label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: meta.color,
              )),
        ],
      ),
    );
  }

  _FlagMeta _flagMeta(String flag) {
    final f = flag.toLowerCase();
    if (f.contains('stationary')) {
      return _FlagMeta(Icons.motion_photos_off, 'Device stationary', AppTheme.alertRed);
    }
    if (f.contains('charging')) {
      return _FlagMeta(Icons.battery_charging_full, 'Plugged in', AppTheme.alertRed);
    }
    if (f.contains('wifi')) {
      return _FlagMeta(Icons.wifi, 'On WiFi', AppTheme.warningOrange);
    }
    if (f.contains('zone_density')) {
      return _FlagMeta(Icons.groups, 'Zone density spike', AppTheme.alertRed);
    }
    if (f.contains('isolation forest') || f.contains('anomaly')) {
      return _FlagMeta(Icons.psychology, 'ML anomaly', AppTheme.alertRed);
    }
    if (f.contains('rapid') || f.contains('since last claim')) {
      return _FlagMeta(Icons.bolt, 'Rapid-fire claim', AppTheme.warningOrange);
    }
    if (f.contains('no_device_signals')) {
      return _FlagMeta(Icons.sensors_off, 'No sensor data', AppTheme.textSecondary);
    }
    if (f.contains('demo_force_review')) {
      return _FlagMeta(Icons.science, 'Demo: forced review', AppTheme.primaryBlue);
    }
    if (f.contains('demo_force_block')) {
      return _FlagMeta(Icons.science, 'Demo: forced block', AppTheme.alertRed);
    }
    if (f.contains('gps')) {
      return _FlagMeta(Icons.location_off, 'GPS anomaly', AppTheme.alertRed);
    }
    if (f.contains('activity') || f.contains('deliveries')) {
      return _FlagMeta(Icons.motorcycle, 'Activity paradox', AppTheme.alertRed);
    }
    if (f.contains('frequency')) {
      return _FlagMeta(Icons.repeat, 'Frequency outlier', AppTheme.warningOrange);
    }
    // Truncate long flag text
    final short = flag.length > 32 ? '${flag.substring(0, 32)}…' : flag;
    return _FlagMeta(Icons.flag_outlined, short, AppTheme.textSecondary);
  }

  // ──────────────────────────────────────────────────────────────────
  // WORKERS TAB
  // ──────────────────────────────────────────────────────────────────
  Widget _buildWorkersTab() {
    if (_workers.isEmpty) return _emptyState('No workers registered');
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _workers.length,
        itemBuilder: (_, i) => _workerCard(_workers[i]),
      ),
    );
  }

  Widget _workerCard(Map<String, dynamic> w) {
    final tier = (w['risk_tier'] ?? 'standard').toString();
    final tierColor = tier == 'high' ? AppTheme.alertRed : tier == 'low' ? AppTheme.successGreen : AppTheme.warningOrange;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: tierColor.withAlpha(40),
                child: Text((w['name'] ?? '?').toString()[0].toUpperCase(),
                    style: GoogleFonts.poppins(color: tierColor, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w['name'] ?? '-',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('${w['partner_id']} · ${w['id']}',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: tierColor.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                child: Text(tier.toUpperCase(),
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: tierColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _miniStat('Claims', '${w['total_claims'] ?? 0}'),
              _miniStat('Payouts', '₹${w['total_payouts'] ?? 0}'),
              _miniStat('Premium', '₹${w['weekly_premium'] ?? '-'}/wk'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
          Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      );

  // ──────────────────────────────────────────────────────────────────
  // TRIGGERS TAB
  // ──────────────────────────────────────────────────────────────────
  Widget _buildTriggersTab() {
    if (_triggers.isEmpty) return _emptyState('No trigger events');
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _triggers.length,
        itemBuilder: (_, i) => _triggerCard(_triggers[i]),
      ),
    );
  }

  Widget _triggerCard(Map<String, dynamic> t) {
    final isActive = t['is_active'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isActive ? AppTheme.alertRed.withAlpha(100) : AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(_triggerIcon(t['type']), color: _triggerColor(t['type']), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${(t['type'] ?? '-').toString().toUpperCase()} · ${t['zone'] ?? '-'}',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('${t['intensity'] ?? '-'} ${t['unit'] ?? ''} · ${t['duration_hours'] ?? '-'}hrs',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.alertRed.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('LIVE',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.alertRed)),
            ),
        ],
      ),
    );
  }

  IconData _triggerIcon(dynamic type) {
    switch ((type ?? '').toString()) {
      case 'rainfall':
      case 'flood':
        return Icons.water_drop_outlined;
      case 'heat':
        return Icons.wb_sunny_outlined;
      case 'aqi':
        return Icons.cloud_outlined;
      case 'bandh':
      case 'election':
        return Icons.block_outlined;
      case 'outage':
      case 'platform_outage':
        return Icons.power_off_outlined;
      case 'traffic':
        return Icons.traffic_outlined;
      default:
        return Icons.warning_amber_outlined;
    }
  }

  Color _triggerColor(dynamic type) {
    switch ((type ?? '').toString()) {
      case 'rainfall':
      case 'flood':
        return AppTheme.primaryBlue;
      case 'heat':
        return AppTheme.warningOrange;
      case 'aqi':
        return Colors.grey;
      case 'bandh':
      case 'election':
        return AppTheme.alertRed;
      case 'outage':
      case 'platform_outage':
        return AppTheme.textSecondary;
      case 'traffic':
        return AppTheme.warningOrange;
      default:
        return AppTheme.primaryBlue;
    }
  }
}

class _FlagMeta {
  final IconData icon;
  final String label;
  final Color color;
  _FlagMeta(this.icon, this.label, this.color);
}
