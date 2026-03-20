import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';

class CoverageScreen extends StatefulWidget {
  const CoverageScreen({super.key});

  @override
  State<CoverageScreen> createState() => _CoverageScreenState();
}

class _CoverageScreenState extends State<CoverageScreen> {
  bool _coverageActive = true;

  @override
  Widget build(BuildContext context) {
    final policy = MockData.activePolicy;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Custom App Bar
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
                  // Policy card
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
                              'Policy #${policy.id.toUpperCase()}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white.withAlpha(140),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.successGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'ACTIVE',
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
                                  Text(
                                    '\u20b9${policy.weeklyPremium.toInt()}/week',
                                    style: GoogleFonts.poppins(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${policy.riskTier} Tier \u2022 Since ${DateFormat('dd MMM yy').format(policy.startDate)}',
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
                                    DateFormat('dd MMM').format(policy.nextDebitDate),
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

          // Covered Zones
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
              policy.zones.map((zone) => _buildZoneTile(zone)).toList(),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          // Trigger Thresholds
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
              MockData.triggerThresholds.map((t) => _buildThresholdTile(t)).toList(),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          // Premium Breakdown
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

          // Pause/Resume
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
                    Switch(
                      value: _coverageActive,
                      onChanged: (val) {
                        HapticFeedback.mediumImpact();
                        setState(() => _coverageActive = val);
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
    final riskTiers = {
      'Velachery': ('High', AppTheme.riskHigh, '14 events/yr'),
      'Adyar': ('Medium', AppTheme.riskMedium, '8 events/yr'),
      'Thiruvanmallur': ('Low', AppTheme.riskLow, '6 events/yr'),
    };
    final (tier, color, detail) = riskTiers[zone] ?? ('Medium', AppTheme.riskMedium, '');

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
          _buildRow('Base rate (Standard)', '\u20b939'),
          _buildRow('Zone risk adjustment (3 zones)', '+\u20b97'),
          _buildRow('Activity bonus discount', '-\u20b92'),
          _buildRow('Monsoon season loading', '+\u20b95'),
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
                '\u20b949',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Visual bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(flex: 39, child: Container(height: 8, color: AppTheme.primaryBlue)),
                Expanded(flex: 7, child: Container(height: 8, color: AppTheme.warningOrange)),
                Expanded(flex: 5, child: Container(height: 8, color: AppTheme.riskMedium)),
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
