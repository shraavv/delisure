import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class CoverageScreen extends StatefulWidget {
  const CoverageScreen({super.key});

  @override
  State<CoverageScreen> createState() => _CoverageScreenState();
}

class _CoverageScreenState extends State<CoverageScreen> {
  bool _coverageActive = false;
  List<Map<String, dynamic>> _triggerThresholds = [];
  bool _isLoading = true;
  bool _isToggling = false;

  String _policyId = '';
  String _policyStatus = 'inactive';
  double _weeklyPremium = 0;
  String _riskTier = 'Standard';
  DateTime _startDate = DateTime.now();
  List<String> _zones = [];
  DateTime _nextDebitDate = DateTime.now();
  int _weeksActive = 0;
  double _totalPremiumsPaid = 0;

  List<Map<String, String>> _premiumBreakdownRows = [];
  double _premiumTotal = 0;
  int _baseFlex = 1;
  int _zoneFlex = 1;
  int _seasonalFlex = 1;

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

      final policiesData = await api.getPolicies(workerId);
      final mlPremium = await api.getMLPremium(workerId);

      if (policiesData != null && policiesData['active'] != null) {
        final active = policiesData['active'];
        _policyId = active['id'] ?? '';
        _policyStatus = active['status'] ?? 'active';
        _weeklyPremium = double.tryParse(active['weekly_premium']?.toString() ?? '') ?? 0;
        _riskTier = active['risk_tier'] ?? 'Standard';
        _startDate = DateTime.tryParse(active['start_date']?.toString() ?? '') ?? DateTime.now();
        _zones = List<String>.from(active['zones'] ?? []);
        _nextDebitDate = DateTime.tryParse(active['next_debit_date']?.toString() ?? '') ?? DateTime.now();
        _weeksActive = int.tryParse(active['weeks_active']?.toString() ?? '') ?? 0;
        _totalPremiumsPaid = double.tryParse(active['total_premiums_paid']?.toString() ?? '') ?? 0;
        _coverageActive = _policyStatus == 'active';
      } else {
        _coverageActive = false;
        _policyStatus = 'inactive';
      }

      if (mlPremium != null) {
        _parsePremiumBreakdown(mlPremium);
      }

      final thresholdsData = await api.getTriggerThresholds();
      if (thresholdsData != null) {
        _triggerThresholds = [];
        final iconMap = {
          'rainfall': 'water_drop',
          'heat': 'thermostat',
          'aqi': 'air',
          'bandh': 'block',
          'outage': 'power_off',
          'flood': 'water_drop',
        };
        thresholdsData.forEach((key, val) {
          if (val is Map<String, dynamic>) {
            _triggerThresholds.add({
              'type': val['label'] ?? key,
              'threshold': val['value'] != null ? '${val['value']} ${val['unit'] ?? ''}' : 'Event-based',
              'description': val['minDuration'] != null ? 'Min duration: ${val['minDuration']} hours' : 'Automatic detection',
              'icon': iconMap[key] ?? 'warning',
            });
          }
        });
      }
    } catch (_) {
      _useMockData();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _useMockData() {
    _coverageActive = false;
    _policyStatus = 'inactive';
    _premiumBreakdownRows = [];
    if (mounted) setState(() => _isLoading = false);
  }

  void _parsePremiumBreakdown(Map<String, dynamic> mlData) {
    final breakdown = mlData['breakdown'];
    if (breakdown is! Map) {
      _premiumBreakdownRows = [];
      return;
    }

    final rows = <Map<String, String>>[];
    final baseAmount = double.tryParse(breakdown['base_amount_inr']?.toString() ?? '') ?? 29;
    final baseTier = breakdown['base_tier']?.toString() ?? 'standard';
    final zoneRisk = breakdown['zone_risk_label']?.toString() ?? 'standard';
    final monsoon = double.tryParse(breakdown['monsoon_multiplier']?.toString() ?? '1') ?? 1.0;
    final loyalty = double.tryParse(breakdown['loyalty_discount_pct']?.toString() ?? '0') ?? 0;
    final flood = breakdown['flood_surcharge_applied'] == true;

    rows.add({'label': 'Base rate ($baseTier)', 'value': '\u20b9${baseAmount.toInt()}'});
    if (zoneRisk == 'high') {
      rows.add({'label': 'Zone risk (high)', 'value': '+\u20b920'});
    } else if (zoneRisk == 'standard') {
      rows.add({'label': 'Zone risk (standard)', 'value': '+\u20b910'});
    }
    if (monsoon > 1.0) {
      rows.add({'label': 'Monsoon loading (${monsoon}x)', 'value': '+30%'});
    }
    if (flood) {
      rows.add({'label': 'Flood zone surcharge', 'value': '+8%'});
    }
    if (loyalty > 0) {
      rows.add({'label': 'Loyalty discount', 'value': '-${loyalty.toStringAsFixed(1)}%'});
    }

    if (rows.isNotEmpty) {
      _premiumBreakdownRows = rows;
    } else {
      _premiumBreakdownRows = [];
      return;
    }

    final total = double.tryParse(mlData['premium_amount_inr']?.toString() ?? '') ?? _weeklyPremium;
    _premiumTotal = total;

    _baseFlex = baseAmount.toInt().clamp(1, 50);
    _zoneFlex = (zoneRisk == 'high' ? 20 : zoneRisk == 'standard' ? 10 : 0).clamp(1, 50);
    _seasonalFlex = (monsoon > 1 ? 15 : 5).clamp(1, 50);
  }

  Future<void> _toggleCoverage(bool val) async {
    if (_isToggling) return;
    setState(() => _isToggling = true);

    try {
      final api = ApiService();
      Map<String, dynamic>? result;
      if (val) {
        result = await api.resumePolicy(_policyId);
      } else {
        result = await api.pausePolicy(_policyId);
      }
      if (result != null) {
        setState(() => _coverageActive = val);
        await _loadData();
      } else {
        setState(() => _coverageActive = val);
      }
    } catch (_) {
      setState(() => _coverageActive = val);
    }
    if (mounted) setState(() => _isToggling = false);
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

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
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
                  colors: [Color(0xFF0F0F14), Color(0xFF18181B)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coverage Details',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withAlpha(18)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Policy #${_policyId.toUpperCase()}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white.withAlpha(140),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _coverageActive ? AppTheme.successGreen : AppTheme.alertRed,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _coverageActive ? 'ACTIVE' : 'PAUSED',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '\u20b9${_weeklyPremium.toInt()}/week',
                                      style: GoogleFonts.poppins(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$_riskTier Tier \u2022 Since ${DateFormat('dd MMM yy').format(_startDate)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white.withAlpha(160),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(10),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 18, color: Colors.white.withAlpha(180)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Next debit',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: Colors.white.withAlpha(120),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd MMM').format(_nextDebitDate),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Covered Zones',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 10)),
          SliverList(
            delegate: SliverChildListDelegate(
              _zones.map((zone) => _buildZoneTile(zone)).toList(),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What We Cover',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Automatic payout when these conditions are met in your zones',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 10)),
          SliverList(
            delegate: SliverChildListDelegate(
              _triggerThresholds.map((t) => _buildThresholdTile(t)).toList(),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Premium Breakdown',
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _buildPremiumBreakdown(),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _coverageActive
                        ? AppTheme.successGreen.withAlpha(40)
                        : AppTheme.alertRed.withAlpha(40),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_coverageActive ? AppTheme.successGreen : AppTheme.alertRed).withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _coverageActive ? Icons.shield_rounded : Icons.shield_outlined,
                        color: _coverageActive ? AppTheme.successGreen : AppTheme.alertRed,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _coverageActive ? 'Coverage Active' : 'Coverage Paused',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            _coverageActive
                                ? 'Toggle to pause weekly deductions'
                                : 'Resume to reactivate coverage',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _isToggling
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch(
                            value: _coverageActive,
                            onChanged: (val) {
                              HapticFeedback.mediumImpact();
                              _toggleCoverage(val);
                            },
                            activeColor: AppTheme.primaryBlue,
                          ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _buildZoneTile(String zone) {
    final tier = _riskTier;
    final color = tier.toLowerCase() == 'high' ? AppTheme.riskHigh
        : tier.toLowerCase() == 'low' ? AppTheme.riskLow
        : AppTheme.riskMedium;
    final detail = 'Covered zone';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_rounded, color: AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  detail,
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$tier Risk',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdTile(Map<String, dynamic> threshold) {
    final iconMap = {
      'water_drop': Icons.water_drop_rounded,
      'thermostat': Icons.thermostat_rounded,
      'air': Icons.air_rounded,
      'block': Icons.block_rounded,
      'power_off': Icons.power_off_rounded,
      'cloud_off': Icons.cloud_off_rounded,
      'traffic': Icons.traffic_rounded,
      'trending_down': Icons.trending_down_rounded,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              iconMap[threshold['icon']] ?? Icons.warning_rounded,
              color: AppTheme.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  threshold['type'],
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    threshold['threshold'],
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warningOrange,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  threshold['description'],
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBreakdown() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withAlpha(80)),
      ),
      child: Column(
        children: [
          ..._premiumBreakdownRows.map((row) => _buildRow(row['label']!, row['value']!)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AppTheme.dividerColor),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Premium',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '\u20b9${_premiumTotal.toInt()}',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(flex: _baseFlex, child: Container(height: 8, color: AppTheme.primaryBlue)),
                Expanded(flex: _zoneFlex, child: Container(height: 8, color: AppTheme.warningOrange)),
                Expanded(flex: _seasonalFlex, child: Container(height: 8, color: AppTheme.riskMedium)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendDot(AppTheme.primaryBlue, 'Base'),
              const SizedBox(width: 16),
              _buildLegendDot(AppTheme.warningOrange, 'Zone adj.'),
              const SizedBox(width: 16),
              _buildLegendDot(AppTheme.riskMedium, 'Seasonal'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value, style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          )),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}
