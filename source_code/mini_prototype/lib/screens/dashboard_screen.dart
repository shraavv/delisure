import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/device_signals.dart';
import '../models/policy.dart';
import '../models/trigger_event.dart';
import '../models/payout.dart';
import '../widgets/coverage_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/trigger_alert_card.dart';
import '../widgets/payout_tile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;

  String _workerName = '';
  String _workerId = '';
  String _riskTier = 'standard';
  List<String> _zones = [];

  Policy? _policy;
  String _coverageStatus = 'inactive';

  String _totalPayouts = '\u20b90';
  String _thisMonthPayouts = '\u20b90';
  String _activeZones = '0';
  String _weeklyPremium = '\u20b90/wk';
  String _netBenefit = '\u20b90';

  List<Payout> _recentPayouts = [];
  int _totalPayoutCount = 0;

  TriggerEvent? _activeTrigger;
  double? _activeTriggerPayoutAmount;

  List<Map<String, dynamic>> _activeTriggersList = [];

  List<double> _riskData = [];
  List<String> _riskLabels = [];
  String _riskZoneLabel = '';
  String _avgWeeklyEarnings = '\u20b90';

  @override
  void initState() {
    super.initState();
    _loadData();
    DeviceSignalsService().collectAndSend();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final storedId = await _api.loadWorkerId();
      final workerId = storedId ?? _workerId;

      final results = await Future.wait([
        _api.getDashboard(workerId).catchError((_) => null),
        _api.getActiveTriggers().catchError((_) => null),
      ]);

      final dashboardData = results[0] as Map<String, dynamic>?;
      final triggersData = results[1] as Map<String, dynamic>?;

      if (dashboardData != null) {
        _applyDashboardData(dashboardData);
      }

      if (triggersData != null) {
        _applyTriggersData(triggersData);
      }

      final primaryZone = _zones.isNotEmpty ? _zones.first : 'Velachery';
      _riskZoneLabel = '$primaryZone zone';
      try {
        final riskData = await _api.getRiskCalendar(primaryZone);
        if (riskData != null) {
          _applyRiskData(riskData);
        }
      } catch (_) {
      }
    } catch (_) {
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applyDashboardData(Map<String, dynamic> data) {
    final worker = data['worker'] as Map<String, dynamic>?;
    if (worker != null) {
      _workerName = worker['name'] ?? _workerName;
      _workerId = worker['id'] ?? _workerId;
      _riskTier = worker['riskTier'] ?? _riskTier;
      if (worker['zones'] != null) {
        _zones = List<String>.from(worker['zones']);
      }
      final avgEarnings = worker['avgWeeklyEarnings'];
      if (avgEarnings != null) {
        _avgWeeklyEarnings = '\u20b9${_formatNumber((avgEarnings as num).toInt())}';
      }
    }

    final coverage = data['coverage'] as Map<String, dynamic>?;
    if (coverage != null) {
      _coverageStatus = coverage['status'] ?? _coverageStatus;
      final premium = coverage['weeklyPremium'];
      final tier = coverage['tier'] ?? _riskTier;
      final nextDebit = coverage['nextDebitDate'];

      DateTime nextDebitDate = DateTime.now();
      if (nextDebit != null) {
        try {
          nextDebitDate = DateTime.parse(nextDebit);
        } catch (_) {}
      }

      if (_coverageStatus == 'active') {
        _policy = Policy(
          id: '',
          workerId: _workerId,
          status: _coverageStatus,
          weeklyPremium: (premium is num) ? premium.toDouble() : 0,
          riskTier: tier,
          startDate: DateTime.now(),
          zones: _zones,
          nextDebitDate: nextDebitDate,
        );
        _weeklyPremium = '\u20b9${_policy!.weeklyPremium.toInt()}/wk';
      }
    }

    final stats = data['stats'] as Map<String, dynamic>?;
    if (stats != null) {
      final totalPay = stats['totalPayoutsReceived'];
      if (totalPay != null) {
        _totalPayouts = '\u20b9${_formatNumber((totalPay as num).toInt())}';
      }
      final monthPay = stats['thisMonthPayouts'];
      if (monthPay != null) {
        _thisMonthPayouts = '\u20b9${_formatNumber((monthPay as num).toInt())}';
      }
      final zones = stats['activeZones'];
      if (zones != null) {
        _activeZones = zones.toString();
      }
      final net = stats['netBenefit'];
      if (net != null) {
        final netVal = (net as num).toInt();
        _netBenefit = '${netVal >= 0 ? '+' : ''}\u20b9${_formatNumber(netVal.abs())}';
      }
    }

    final recentPayouts = data['recentPayouts'] as List<dynamic>?;
    if (recentPayouts != null && recentPayouts.isNotEmpty) {
      _recentPayouts = recentPayouts.take(3).map((p) {
        final map = p as Map<String, dynamic>;
        return Payout(
          id: map['id'] ?? '',
          workerId: map['worker_id'] ?? _workerId,
          triggerEventId: map['trigger_event_id'] ?? '',
          amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0,
          status: map['status'] ?? 'credited',
          timestamp: _tryParseDate(map['created_at']) ?? DateTime.now(),
          breakdown: map['breakdown'] ?? '',
        );
      }).toList();
      _totalPayoutCount = recentPayouts.length;
    }
  }

  void _applyTriggersData(Map<String, dynamic> data) {
    final triggers = data['activeTriggers'] as List<dynamic>?;
    if (triggers != null && triggers.isNotEmpty) {
      _activeTriggersList = triggers.map((t) => t as Map<String, dynamic>).toList();

      final first = _activeTriggersList.first;
      _activeTrigger = TriggerEvent(
        id: first['id'] ?? '',
        type: first['type'] ?? 'rainfall',
        zone: first['zone'] ?? '',
        startTime: _tryParseDate(first['start_time']) ?? DateTime.now(),
        intensity: double.tryParse(first['intensity']?.toString() ?? '0') ?? 0,
        description: first['description'] ?? '',
        isActive: first['is_active'] ?? true,
      );

      final matchingPayout = _recentPayouts.where(
        (p) => p.triggerEventId == _activeTrigger!.id,
      );
      _activeTriggerPayoutAmount = matchingPayout.isNotEmpty
          ? matchingPayout.first.amount
          : null;
    } else if (triggers != null && triggers.isEmpty) {
      _activeTrigger = null;
      _activeTriggerPayoutAmount = null;
    }
  }

  void _applyRiskData(Map<String, dynamic> data) {
    final calendar = (data['days'] ?? data['calendar']) as List<dynamic>?;
    if (calendar != null && calendar.isNotEmpty) {
      final days = calendar.take(7).toList();
      _riskData = days.map((d) {
        final entry = d as Map<String, dynamic>;
        return (entry['risk_score'] as num?)?.toDouble() ??
            (entry['risk'] as num?)?.toDouble() ??
            (entry['riskScore'] as num?)?.toDouble() ??
            0.0;
      }).toList();

      _riskLabels = [];
      for (int i = 0; i < days.length; i++) {
        if (i == 0) {
          _riskLabels.add('Today');
        } else {
          final entry = days[i] as Map<String, dynamic>;
          final dateStr = entry['date'] as String?;
          if (dateStr != null) {
            try {
              final date = DateTime.parse(dateStr);
              const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              _riskLabels.add(dayNames[date.weekday - 1]);
            } catch (_) {
              _riskLabels.add('Day $i');
            }
          } else {
            _riskLabels.add('Day $i');
          }
        }
      }
    }
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
  }

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primaryBlue,
        backgroundColor: AppTheme.bgCard,
        child: _isLoading ? _buildLoadingShimmer() : _buildContent(),
      ),
      floatingActionButton: _buildDemoFab(context),
    );
  }

  Widget _buildLoadingShimmer() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(4, (i) => _buildShimmerBlock()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerBlock() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withAlpha(60)),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation(AppTheme.textHint.withAlpha(80)),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context)),

        if (_activeTrigger != null)
          SliverToBoxAdapter(
            child: TriggerAlertCard(
              trigger: _activeTrigger!,
              payoutAmount: _activeTriggerPayoutAmount,
            ),
          ),

        if (_policy != null)
          SliverToBoxAdapter(
            child: CoverageCard(policy: _policy!),
          ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text(
              'Quick Stats',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                StatCard(
                  icon: Icons.shield_rounded,
                  label: 'Total Protected',
                  value: _totalPayouts,
                  gradient: const [Color(0xFF0D3B21), Color(0xFF155E35)],
                ),
                const SizedBox(width: 10),
                StatCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'This Month',
                  value: _thisMonthPayouts,
                  gradient: const [Color(0xFF2D2412), Color(0xFF4A3B1D)],
                ),
                const SizedBox(width: 10),
                StatCard(
                  icon: Icons.location_on_rounded,
                  label: 'Active Zones',
                  value: _activeZones,
                  gradient: const [Color(0xFF2D1F0A), Color(0xFF4A3415)],
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: _buildHowItWorks(),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Payouts',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '$_totalPayoutCount total',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= _recentPayouts.length) return null;
              final payout = _recentPayouts[index];
              final trigger = _findTrigger(payout.triggerEventId);
              String triggerType = trigger?.type ?? 'rainfall';
              String zone = trigger?.zone ?? '';

              if (trigger == null && _activeTriggersList.isNotEmpty) {
                final apiTrigger = _activeTriggersList.where(
                  (t) => t['id'] == payout.triggerEventId,
                );
                if (apiTrigger.isNotEmpty) {
                  triggerType = apiTrigger.first['type'] ?? 'rainfall';
                  zone = apiTrigger.first['zone'] ?? '';
                }
              }

              if (trigger == null) {
              }

              return PayoutTile(
                payout: payout,
                triggerType: triggerType,
                zone: zone,
              );
            },
            childCount: _recentPayouts.length,
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: _buildRiskForecast(context),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final initial = _workerName.isNotEmpty ? _workerName[0].toUpperCase() : 'A';
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F0F14),
            Color(0xFF141419),
            Color(0xFF18181B),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Hey $_workerName',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('\ud83d\udc4b', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                    Text(
                      'Your earnings are protected',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _coverageStatus == 'active'
                      ? AppTheme.successGreen.withAlpha(20)
                      : AppTheme.accentAmber.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _coverageStatus == 'active'
                        ? AppTheme.successGreen.withAlpha(60)
                        : AppTheme.accentAmber.withAlpha(60),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _coverageStatus == 'active'
                            ? AppTheme.successGreen
                            : AppTheme.accentAmber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _coverageStatus.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _coverageStatus == 'active'
                            ? AppTheme.successGreen
                            : AppTheme.accentAmber,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor.withAlpha(120)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildHeaderStat(
                    'Avg Weekly',
                    _avgWeeklyEarnings,
                    Icons.trending_up_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppTheme.borderColor.withAlpha(100),
                ),
                Expanded(
                  child: _buildHeaderStat(
                    'Premium',
                    _weeklyPremium,
                    Icons.shield_outlined,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppTheme.borderColor.withAlpha(100),
                ),
                Expanded(
                  child: _buildHeaderStat(
                    'Net Benefit',
                    _netBenefit,
                    Icons.savings_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 16),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white.withAlpha(130),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fully automated protection',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'When rain stops you, we pay you. No claims, no paperwork.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textHint,
          ),
        ],
      ),
    );
  }

  Widget _buildRiskForecast(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withAlpha(80)),
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.riskHigh.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.insights_rounded, color: AppTheme.riskHigh, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '7-Day Risk Forecast',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/risk-calendar'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'View all',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$_riskZoneLabel \u2022 Based on IMD + historical data',
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textHint),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 130,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final idx = group.x.toInt();
                      final risk = idx < _riskData.length ? _riskData[idx] : 0.0;
                      return BarTooltipItem(
                        '${(risk * 100).toInt()}% risk',
                        GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < _riskLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _riskLabels[idx],
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: idx == 0
                                    ? AppTheme.primaryBlue
                                    : AppTheme.textSecondary,
                                fontWeight: idx == 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  _riskData.length,
                  (i) {
                    final risk = _riskData[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: risk,
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppTheme.riskColor(risk).withAlpha(180),
                              AppTheme.riskColor(risk),
                            ],
                          ),
                          width: 28,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: 1.0,
                            color: AppTheme.bgElevated,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        HapticFeedback.mediumImpact();
        _showSimulateSheet(context);
      },
      backgroundColor: AppTheme.bgElevated,
      foregroundColor: AppTheme.textPrimary,
      elevation: 0,
      icon: const Icon(Icons.bolt_rounded, size: 20),
      label: Text(
        'Simulate',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.borderColor),
      ),
    );
  }

  void _showSimulateSheet(BuildContext context) {
    final primaryZone = _zones.isNotEmpty ? _zones.first : 'Chennai';
    final secondaryZone = _zones.length > 1 ? _zones[1] : primaryZone;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.bolt_rounded, color: AppTheme.textSecondary, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulate Event',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _coverageStatus == 'active'
                          ? 'Trigger a demo disruption in your zones'
                          : 'Activate a policy first to receive payouts',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _coverageStatus == 'active' ? AppTheme.textSecondary : AppTheme.warningOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSimOption(
              context,
              Icons.water_drop_rounded,
              'Heavy Rainfall',
              '$primaryZone \u2022 18mm/hr \u2022 Dinner rush',
              'Auto-payout',
              const Color(0xFF1565C0),
              type: 'rainfall',
              zone: primaryZone,
              intensity: 18,
              durationHours: 3,
            ),
            _buildSimOption(
              context,
              Icons.thermostat_rounded,
              'Extreme Heat',
              '$secondaryZone \u2022 46\u00b0C \u2022 Afternoon',
              'Auto-payout',
              AppTheme.warningOrange,
              type: 'heat',
              zone: secondaryZone,
              intensity: 46,
              durationHours: 5,
            ),
            _buildSimOption(
              context,
              Icons.air_rounded,
              'AQI Spike',
              '$primaryZone \u2022 AQI 342 \u2022 5 hours',
              'Auto-payout',
              const Color(0xFF6A1B9A),
              type: 'aqi',
              zone: primaryZone,
              intensity: 342,
              durationHours: 5,
            ),
            _buildSimOption(
              context,
              Icons.block_rounded,
              'Bandh / Curfew',
              '$primaryZone \u2022 State-declared \u2022 Full day',
              'Auto-payout',
              AppTheme.alertRed,
              type: 'bandh',
              zone: primaryZone,
              intensity: 1,
              durationHours: 12,
            ),
            _buildSimOption(
              context,
              Icons.power_off_rounded,
              'Grid Power Outage',
              '$primaryZone \u2022 4+ hours',
              'Auto-payout',
              const Color(0xFF78909C),
              type: 'outage',
              zone: primaryZone,
              intensity: 5,
              durationHours: 4,
            ),
            _buildSimOption(
              context,
              Icons.trending_down_rounded,
              'Order Volume Collapse',
              '$secondaryZone \u2022 Orders -72% \u2022 3 hours',
              'Auto-payout',
              const Color(0xFF8D6E63),
              type: 'order_collapse',
              zone: secondaryZone,
              intensity: 72,
              durationHours: 3,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Text(
                'Tap any event to see how Delisure responds automatically',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textHint,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSimOption(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String payout,
    Color color, {
    required String type,
    required String zone,
    double? intensity,
    double? durationHours,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            HapticFeedback.heavyImpact();
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(context);

            messenger.showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(const Color(0xFF09090B)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Simulating $title...',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF09090B),
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: color,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              ),
            );

            try {
              // Refresh device signals before triggering so fraud layer has fresh data
              await DeviceSignalsService().collectAndSend(force: true);
              final result = await _api.simulateTrigger(
                type: type,
                zone: zone,
                intensity: intensity,
                durationHours: durationHours,
              );

              if (mounted) {
                messenger.hideCurrentSnackBar();

                if (result['error'] != null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: ${result['error']}', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                      backgroundColor: AppTheme.alertRed,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                  return;
                }

                String payoutMsg = 'No matching policies';
                final affectedWorkers = result['affectedWorkers'] ?? 0;
                if (result['payouts'] != null) {
                  final payouts = result['payouts'] as List<dynamic>?;
                  if (payouts != null && payouts.isNotEmpty) {
                    final payoutData = payouts.first;
                    final payoutInfo = payoutData['payout'];
                    if (payoutInfo != null) {
                      final amt = payoutInfo['amount'];
                      if (amt != null) {
                        final status = payoutInfo['status']?.toString() ?? 'processing';
                        final statusLabel = status == 'credited' ? 'auto-approved'
                            : status == 'pending_review' ? 'held for admin review'
                            : status == 'failed' ? 'blocked by fraud check'
                            : 'processing';
                        payoutMsg = '\u20b9${double.tryParse(amt.toString())?.toInt() ?? amt} — $statusLabel';
                      }
                    }
                  } else if (affectedWorkers == 0) {
                    payoutMsg = 'No active policies in $zone — activate coverage first';
                  }
                }

                messenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          affectedWorkers > 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          color: const Color(0xFF09090B),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$title triggered! $payoutMsg',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF09090B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: affectedWorkers > 0 ? color : AppTheme.warningOrange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 4),
                  ),
                );

                _loadData();
              }
            } catch (e) {
              if (mounted) {
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Could not reach server', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                    backgroundColor: AppTheme.alertRed,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    payout,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.successGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  dynamic _findTrigger(String triggerEventId) {
    if (_activeTrigger != null && _activeTrigger!.id == triggerEventId) {
      return _activeTrigger;
    }
    return null;
  }
}
