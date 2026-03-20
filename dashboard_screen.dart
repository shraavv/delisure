import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../widgets/coverage_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/trigger_alert_card.dart';
import '../widgets/payout_tile.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Gradient header
          SliverToBoxAdapter(child: _buildHeader(context)),

          // Active Alert
          SliverToBoxAdapter(
            child: TriggerAlertCard(
              trigger: MockData.activeTrigger,
              payoutAmount: 420,
            ),
          ),

          // Coverage Card
          SliverToBoxAdapter(
            child: CoverageCard(policy: MockData.activePolicy),
          ),

          // Quick Stats
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
                children: const [
                  StatCard(
                    icon: Icons.shield_rounded,
                    label: 'Total Protected',
                    value: '\u20b93,690',
                    gradient: [Color(0xFF0D3B21), Color(0xFF155E35)],
                  ),
                  SizedBox(width: 10),
                  StatCard(
                    icon: Icons.calendar_month_rounded,
                    label: 'This Month',
                    value: '\u20b91,330',
                    gradient: [Color(0xFF2D2412), Color(0xFF4A3B1D)],
                  ),
                  SizedBox(width: 10),
                  StatCard(
                    icon: Icons.location_on_rounded,
                    label: 'Active Zones',
                    value: '3',
                    gradient: [Color(0xFF2D1F0A), Color(0xFF4A3415)],
                  ),
                ],
              ),
            ),
          ),

          // How it works — onboarding reminder
          SliverToBoxAdapter(child: _buildHowItWorks()),

          // Recent Payouts header
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
                    '${MockData.allPayouts.length} total',
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

          // Payout tiles
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= 3) return null;
                final payout = MockData.payouts[index];
                final trigger = _findTrigger(payout.triggerEventId);
                return PayoutTile(
                  payout: payout,
                  triggerType: trigger?.type ?? 'rainfall',
                  zone: trigger?.zone ?? '',
                );
              },
              childCount: 3,
            ),
          ),

          // Risk Forecast
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: _buildRiskForecast(context),
            ),
          ),

          // Spacer at bottom so FAB doesn't cover content
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
      floatingActionButton: _buildDemoFab(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                    'A',
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
                        Text(
                          'Hey Arjun',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('\ud83d\udc4b',
                            style: TextStyle(fontSize: 20)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.successGreen.withAlpha(60)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ACTIVE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.successGreen,
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
              border: Border.all(
                  color: AppTheme.borderColor.withAlpha(120)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildHeaderStat(
                    'Avg Weekly',
                    '\u20b95,250',
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
                    '\u20b949/wk',
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
                    '+\u20b92,514',
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
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
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
          Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
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
                    child: Icon(Icons.insights_rounded,
                        color: AppTheme.riskHigh, size: 18),
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
                onTap: () =>
                    Navigator.pushNamed(context, '/risk-calendar'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
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
            'Velachery zone \u2022 Based on IMD + historical data',
            style:
                GoogleFonts.inter(fontSize: 11, color: AppTheme.textHint),
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
                      final risk =
                          MockData.next7DaysRisk[group.x.toInt()];
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
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 &&
                            idx < MockData.next7DaysLabels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              MockData.next7DaysLabels[idx],
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
                  MockData.next7DaysRisk.length,
                  (i) {
                    final risk = MockData.next7DaysRisk[i];
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
        style:
            GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.borderColor),
      ),
    );
  }

  // ─── FIX: DraggableScrollableSheet + SingleChildScrollView ───────────────
  void _showSimulateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.bgSecondary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            // Bottom padding accounts for system nav bar so last item
            // is never hidden behind it
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
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
                      child: Icon(Icons.bolt_rounded,
                          color: AppTheme.textSecondary, size: 24),
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
                          'Trigger a demo disruption event',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
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
                  'Velachery Zone \u2022 18mm/hr \u2022 Dinner rush',
                  '\u20b9420 payout',
                  const Color(0xFF1565C0),
                ),
                _buildSimOption(
                  context,
                  Icons.thermostat_rounded,
                  'Extreme Heat',
                  'Adyar Zone \u2022 46\u00b0C \u2022 Afternoon',
                  '\u20b9250 payout',
                  AppTheme.warningOrange,
                ),
                _buildSimOption(
                  context,
                  Icons.air_rounded,
                  'AQI Spike',
                  'Chennai-wide \u2022 AQI 342 \u2022 5 hours',
                  '\u20b9180 payout',
                  const Color(0xFF6A1B9A),
                ),
                _buildSimOption(
                  context,
                  Icons.block_rounded,
                  'Bandh / Curfew',
                  'Chennai \u2022 State-declared \u2022 Full day',
                  '\u20b9780 payout',
                  AppTheme.alertRed,
                ),
                _buildSimOption(
                  context,
                  Icons.traffic_rounded,
                  'Traffic Paralysis',
                  'Velachery \u2022 Avg speed <8km/h \u2022 90 min',
                  '\u20b9250 payout',
                  const Color(0xFF546E7A),
                ),
                _buildSimOption(
                  context,
                  Icons.power_off_rounded,
                  'Grid Power Outage',
                  'Velachery \u2022 TANGEDCO \u2022 4+ hours',
                  '\u20b9255 payout',
                  const Color(0xFF78909C),
                ),
                _buildSimOption(
                  context,
                  Icons.how_to_vote_rounded,
                  'Election Day',
                  'Chennai \u2022 EC published schedule',
                  '\u20b9315 payout',
                  const Color(0xFF4527A0),
                ),
                _buildSimOption(
                  context,
                  Icons.trending_down_rounded,
                  'Order Volume Collapse',
                  'Adyar \u2022 Orders -72% \u2022 3 hours',
                  '\u20b9320 payout',
                  const Color(0xFF8D6E63),
                ),
                _buildSimOption(
                  context,
                  Icons.cloud_off_rounded,
                  'Platform Outage',
                  'Chennai-wide \u2022 Swiggy app errors \u2022 2.5 hrs',
                  '\u20b9200 payout',
                  const Color(0xFF37474F),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Tap any event to see how delisure responds automatically',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textHint,
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

  Widget _buildSimOption(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String payout,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.heavyImpact();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: const Color(0xFF09090B), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$title triggered! $payout processing...',
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 3),
              ),
            );
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
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
    if (MockData.activeTrigger.id == triggerEventId) {
      return MockData.activeTrigger;
    }
    try {
      return MockData.pastTriggers.firstWhere((t) => t.id == triggerEventId);
    } catch (_) {
      return null;
    }
  }
}