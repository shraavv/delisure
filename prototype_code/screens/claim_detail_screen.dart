import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/flagged_claim.dart';

class ClaimDetailScreen extends StatelessWidget {
  final FlaggedClaim claim;

  const ClaimDetailScreen({super.key, required this.claim});

  @override
  Widget build(BuildContext context) {
    Color tierColor;
    String tierLabel;
    IconData tierIcon;

    switch (claim.tier) {
      case 'hard_flag':
        tierColor = AppTheme.alertRed;
        tierLabel = 'HARD FLAG';
        tierIcon = Icons.gpp_bad_rounded;
        break;
      case 'soft_hold':
        tierColor = AppTheme.warningOrange;
        tierLabel = 'SOFT HOLD';
        tierIcon = Icons.pause_circle_rounded;
        break;
      default:
        tierColor = AppTheme.successGreen;
        tierLabel = 'CLEAN PASS';
        tierIcon = Icons.check_circle_rounded;
    }

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 12,
                20,
                24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tierColor.withAlpha(15),
                    const Color(0xFF18181B),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.bgElevated,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Claim Detail',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'SHAP Explainability Report',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withAlpha(150)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: tierColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tierColor.withAlpha(60)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tierIcon, color: tierColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              tierLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: tierColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Worker info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: tierColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              claim.workerName.substring(0, 1),
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: tierColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                claim.workerName,
                                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              ),
                              Text(
                                '${claim.workerId} \u2022 ${claim.zone}',
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\u20b9${claim.amount.toInt()}',
                              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            Text(
                              claim.triggerType,
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
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

          // Fraud Score
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tierColor.withAlpha(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fraud Probability Score',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: claim.fraudScore,
                              strokeWidth: 10,
                              backgroundColor: AppTheme.bgElevated,
                              valueColor: AlwaysStoppedAnimation(tierColor),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '${(claim.fraudScore * 100).toInt()}%',
                                style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: tierColor,
                                ),
                              ),
                              Text(
                                tierLabel,
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: tierColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _getTierDescription(claim.tier),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // SHAP Breakdown
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.analytics_rounded, color: AppTheme.primaryBlue, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'SHAP Signal Breakdown',
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'SHapley Additive exPlanations \u2014 individual signal contribution to fraud score',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textHint),
                    ),
                    const SizedBox(height: 16),
                    // Table header
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text('Signal', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textHint)),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text('Impact', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textHint), textAlign: TextAlign.center),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text('Direction', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textHint), textAlign: TextAlign.right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(color: AppTheme.dividerColor, height: 1),
                    const SizedBox(height: 4),
                    ...claim.shapSignals.map((signal) => _buildShapRow(signal)),
                    const SizedBox(height: 8),
                    Divider(color: AppTheme.dividerColor, height: 1),
                    const SizedBox(height: 12),
                    // Final score row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Final Fraud Score',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: tierColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${(claim.fraudScore * 100).toInt()}% \u2014 ${tierLabel}',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: tierColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Anti-Spoofing Signals
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.warningOrange.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.security_rounded, color: AppTheme.warningOrange, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Anti-Spoofing Sensor Fusion',
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSensorRow(Icons.gps_fixed_rounded, 'GPS Location', claim.tier == 'clean' ? 'Matches zone' : 'Inconsistent', claim.tier == 'clean'),
                    _buildSensorRow(Icons.cell_tower_rounded, 'Cell Tower', claim.tier == 'hard_flag' ? 'Mismatch detected' : 'Consistent', claim.tier != 'hard_flag'),
                    _buildSensorRow(Icons.speed_rounded, 'Accelerometer', claim.tier == 'soft_hold' ? 'Inconsistent data' : claim.tier == 'hard_flag' ? 'Stationary pattern' : 'Riding pattern', claim.tier == 'clean'),
                    _buildSensorRow(Icons.battery_charging_full_rounded, 'Battery Drain', claim.tier == 'clean' ? 'Active drain' : 'Stable (plugged in)', claim.tier == 'clean'),
                    _buildSensorRow(Icons.history_rounded, 'Mobility History', claim.tier == 'clean' ? 'Regular zone visitor' : 'Anomalous', claim.tier == 'clean'),
                    _buildSensorRow(Icons.touch_app_rounded, 'App Interaction', claim.tier == 'hard_flag' ? 'Automated pattern' : 'Human pattern', claim.tier != 'hard_flag'),
                  ],
                ),
              ),
            ),
          ),

          // Worker appeal text (for soft hold / hard flag)
          if (claim.tier != 'clean')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withAlpha(10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryBlue.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.message_rounded, color: AppTheme.primaryBlue, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Worker-Facing Message',
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        claim.tier == 'hard_flag'
                            ? '"We need to verify a few details before processing your payout. This usually takes under 24 hours. You won\'t lose your claim."'
                            : '"We detected some signal issues \u2014 possibly due to network conditions in your area. Your payout has been partially processed. Tap here to request a full review."',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Never shows raw score. Never uses the word "fraud".',
                        style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Action buttons
          if (claim.status == 'pending_review')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Claim ${claim.id} approved \u2014 payout released'),
                              backgroundColor: AppTheme.successGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text('Approve & Release', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Claim ${claim.id} escalated to manual review'),
                              backgroundColor: AppTheme.warningOrange,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        },
                        icon: const Icon(Icons.escalator_warning_rounded, size: 18),
                        label: Text('Escalate', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.warningOrange,
                          side: BorderSide(color: AppTheme.warningOrange),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Compliance export button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('IRDAI compliance PDF exported'),
                      backgroundColor: AppTheme.primaryBlue,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: Text('Export IRDAI Compliance PDF', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: BorderSide(color: AppTheme.borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildShapRow(ShapSignal signal) {
    final isFraud = signal.direction == 'toward_fraud';
    final color = isFraud ? AppTheme.alertRed : AppTheme.successGreen;
    final percentage = (signal.contribution * 100).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              signal.signal,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textPrimary),
            ),
          ),
          SizedBox(
            width: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: signal.contribution,
                      backgroundColor: AppTheme.bgElevated,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${isFraud ? '+' : '-'}$percentage%',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  isFraud ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    isFraud ? 'Fraud' : 'Clean',
                    style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorRow(IconData icon, String label, String status, bool isGood) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isGood ? AppTheme.successGreen : AppTheme.alertRed).withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: isGood ? AppTheme.successGreen : AppTheme.alertRed),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isGood ? AppTheme.successGreen : AppTheme.alertRed).withAlpha(15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isGood ? AppTheme.successGreen : AppTheme.alertRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTierDescription(String tier) {
    switch (tier) {
      case 'hard_flag':
        return 'Multiple high-confidence fraud signals detected.\nPayout withheld pending manual review.';
      case 'soft_hold':
        return 'One or two signals inconsistent. Payout held max 4 hours.\nIf ambiguous, auto-approves at 50%.';
      default:
        return 'All signals consistent. Payout released within 2 hours.\nWorker experienced no unusual delay.';
    }
  }
}
