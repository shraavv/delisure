import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifyTriggers = true;
  bool _notifyPayouts = true;
  bool _notifyWeeklyReport = true;
  bool _notifyRiskAlerts = false;

  @override
  Widget build(BuildContext context) {
    final worker = MockData.currentWorker;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Profile header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 16,
                20,
                28,
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
                children: [
                  // Avatar
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Center(
                      child: Text(
                        'A',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    worker.name,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      worker.swiggyPartnerId,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withAlpha(180),
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    worker.phone,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withAlpha(130),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: worker.zones.map((zone) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withAlpha(20)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_rounded, size: 12, color: AppTheme.primaryBlue),
                            const SizedBox(width: 4),
                            Text(
                              zone,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withAlpha(200),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          // Coverage Summary
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Coverage Summary',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor.withAlpha(80)),
              ),
              child: Column(
                children: [
                  _buildStatRow('Weeks Active', '${MockData.weeksActive} weeks'),
                  _buildStatRow('Total Premiums Paid', '\u20b9${_formatINR(MockData.totalPremiumsPaid)}'),
                  _buildStatRow('Total Payouts Received', '\u20b9${_formatINR(MockData.totalPayoutsReceived)}'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(color: AppTheme.dividerColor),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net Benefit',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '+\u20b9${_formatINR(MockData.netBenefit)}',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          // Premium History
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Premium History',
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
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final entry = MockData.premiumHistory[index];
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.successGreen,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry['week'],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy').format(entry['date']),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\u20b9${(entry['amount'] as double).toInt()}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: MockData.premiumHistory.length,
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          // Notifications
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Notifications',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor.withAlpha(80)),
              ),
              child: Column(
                children: [
                  _buildToggle('Trigger Alerts', 'Get notified when a disruption starts', _notifyTriggers, (v) => setState(() => _notifyTriggers = v)),
                  _buildToggle('Payout Updates', 'Notifications when money is credited', _notifyPayouts, (v) => setState(() => _notifyPayouts = v)),
                  _buildToggle('Weekly Report', 'Coverage summary every Monday', _notifyWeeklyReport, (v) => setState(() => _notifyWeeklyReport = v)),
                  _buildToggle('Risk Forecasts', 'Daily risk predictions for your zones', _notifyRiskAlerts, (v) => setState(() => _notifyRiskAlerts = v)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          // Admin Dashboard
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pushNamed(context, '/admin');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.warningOrange.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.admin_panel_settings_rounded, color: AppTheme.warningOrange, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Admin Dashboard',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Insurer panel \u2022 Fraud detection \u2022 SHAP explainability',
                                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.alertRed.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '3 flags',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.alertRed),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          // Refer a rider
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue.withAlpha(18),
                    AppTheme.primaryBlue.withAlpha(8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryBlue.withAlpha(50)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.people_alt_rounded, color: AppTheme.primaryBlue, size: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Refer a Rider',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Earn 1 week free coverage for every rider who signs up!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => HapticFeedback.lightImpact(),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share Invite Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: const Color(0xFF09090B),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'delisure v1.0.0',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textHint),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatINR(double amount) {
    return amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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

  Widget _buildToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary,
      )),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
      value: value,
      onChanged: (v) {
        HapticFeedback.selectionClick();
        onChanged(v);
      },
      activeColor: AppTheme.primaryBlue,
      dense: true,
    );
  }
}
