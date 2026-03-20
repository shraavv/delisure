import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import 'claim_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildPlatformStats()),
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
                tabs: const [
                  Tab(text: 'Flagged Claims'),
                  Tab(text: 'NLP Confidence'),
                  Tab(text: 'Workers'),
                  Tab(text: 'Micro-Zones'),
                  Tab(text: 'Churn Risk'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildFlaggedClaimsTab(),
            _buildNlpConfidenceTab(),
            _buildWorkersTab(),
            _buildMicroZonesTab(),
            _buildChurnTab(),
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
                  'Admin Dashboard',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'delisure Insurer Panel',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withAlpha(150)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.alertRed.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.alertRed.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.alertRed, size: 14),
                const SizedBox(width: 4),
                Text(
                  '3 flags',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.alertRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformStats() {
    final stats = MockData.platformStats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              _buildMiniStat('Active Workers', '${stats['totalWorkers']}', Icons.people_alt_rounded, AppTheme.primaryBlue),
              const SizedBox(width: 10),
              _buildMiniStat('Policies', '${stats['activePolicies']}', Icons.shield_rounded, AppTheme.successGreen),
              const SizedBox(width: 10),
              _buildMiniStat('Claims/wk', '${stats['claimsThisWeek']}', Icons.receipt_long_rounded, AppTheme.warningOrange),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMiniStat('Payouts Today', '\u20b91.4L', Icons.account_balance_wallet_rounded, AppTheme.successGreen),
              const SizedBox(width: 10),
              _buildMiniStat('Flag Rate', '${stats['fraudFlagRate']}%', Icons.flag_rounded, AppTheme.alertRed),
              const SizedBox(width: 10),
              _buildMiniStat('Avg Claim', '${stats['avgClaimTime']}', Icons.timer_rounded, AppTheme.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 6),
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
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Flagged Claims ──────────────────────────────────────────

  Widget _buildFlaggedClaimsTab() {
    final claims = MockData.flaggedClaims;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: claims.length,
      itemBuilder: (context, index) {
        final claim = claims[index];
        return _buildClaimCard(claim);
      },
    );
  }

  Widget _buildClaimCard(dynamic claim) {
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tierColor.withAlpha(60)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClaimDetailScreen(claim: claim),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tierColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(tierIcon, color: tierColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            claim.workerName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '${claim.zone} \u2022 ${claim.triggerType} \u2022 ${claim.workerId}',
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: tierColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tierLabel,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: tierColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\u20b9${claim.amount.toInt()}',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Fraud score bar
                Row(
                  children: [
                    Text(
                      'Fraud Score',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: claim.fraudScore,
                          backgroundColor: AppTheme.bgElevated,
                          valueColor: AlwaysStoppedAnimation(tierColor),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${(claim.fraudScore * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tierColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Top SHAP signals preview
                ...claim.shapSignals.take(3).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        s.direction == 'toward_fraud'
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 12,
                        color: s.direction == 'toward_fraud'
                            ? AppTheme.alertRed
                            : AppTheme.successGreen,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.signal,
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${s.direction == 'toward_fraud' ? '+' : '-'}${(s.contribution * 100).toInt()}%',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: s.direction == 'toward_fraud'
                              ? AppTheme.alertRed
                              : AppTheme.successGreen,
                        ),
                      ),
                    ],
                  ),
                )),
                if (claim.status == 'pending_review') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Claim ${claim.id} approved'),
                                backgroundColor: AppTheme.successGreen,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: Text('Approve', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.successGreen,
                            side: BorderSide(color: AppTheme.successGreen.withAlpha(100)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Claim ${claim.id} escalated'),
                                backgroundColor: AppTheme.warningOrange,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          },
                          icon: const Icon(Icons.escalator_warning_rounded, size: 16),
                          label: Text('Escalate', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.warningOrange,
                            side: BorderSide(color: AppTheme.warningOrange.withAlpha(100)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (claim.status == 'auto_approved') ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'AUTO-APPROVED \u2022 Payout credited',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab 2: NLP Confidence Log ──────────────────────────────────────

  Widget _buildNlpConfidenceTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildSectionNote(
          'BERT Civic Disruption Classifier',
          'Confidence thresholds: \u22650.85 auto-trigger \u2022 0.60\u20130.84 held 2hrs \u2022 <0.60 withheld',
        ),
        const SizedBox(height: 12),
        ...MockData.nlpConfidenceLog.map((entry) => _buildNlpCard(entry)),
        const SizedBox(height: 20),
        _buildSectionNote(
          'Earnings Imputation Cross-Check',
          'XGBoost regression validates declared earnings against peer data (Module 3)',
        ),
        const SizedBox(height: 12),
        ...MockData.earningsImputation.map((entry) => _buildImputationCard(entry)),
      ],
    );
  }

  Widget _buildSectionNote(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.primaryBlue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue)),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNlpCard(Map<String, dynamic> entry) {
    final confidence = entry['confidence'] as double;
    Color confColor;
    if (confidence >= 0.85) {
      confColor = AppTheme.successGreen;
    } else if (confidence >= 0.60) {
      confColor = AppTheme.warningOrange;
    } else {
      confColor = AppTheme.alertRed;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry['event'],
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: confColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(confidence * 100).toInt()}%',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: confColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(entry['date'], style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textHint)),
          const SizedBox(height: 8),
          // Confidence bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence,
              backgroundColor: AppTheme.bgElevated,
              valueColor: AlwaysStoppedAnimation(confColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                confidence >= 0.60 ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                size: 14,
                color: confColor,
              ),
              const SizedBox(width: 6),
              Text(
                entry['action'],
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: confColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: (entry['sources'] as List).map((source) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  source,
                  style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildImputationCard(Map<String, dynamic> entry) {
    final isFlagged = entry['status'] == 'flagged';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFlagged ? AppTheme.alertRed.withAlpha(60) : AppTheme.borderColor.withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isFlagged ? AppTheme.alertRed : AppTheme.successGreen).withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                entry['workerName'].toString().substring(0, 1),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isFlagged ? AppTheme.alertRed : AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry['workerName'], style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Text(
                  'Declared: \u20b9${entry['declared']} \u2022 Imputed: \u20b9${entry['imputed']}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry['deviation']}%',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isFlagged ? AppTheme.alertRed : AppTheme.successGreen,
                ),
              ),
              Text(
                'deviation',
                style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Workers ─────────────────────────────────────────────────

  Widget _buildWorkersTab() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: MockData.adminWorkers.length,
      itemBuilder: (context, index) {
        final w = MockData.adminWorkers[index];
        final fraudScore = w['fraudScore'] as double;
        final churnRisk = w['churnRisk'] as double;

        Color statusColor;
        switch (w['status']) {
          case 'hard_flag':
            statusColor = AppTheme.alertRed;
            break;
          case 'soft_hold':
            statusColor = AppTheme.warningOrange;
            break;
          default:
            statusColor = AppTheme.successGreen;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderColor.withAlpha(60)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        w['name'].toString().substring(0, 1),
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(w['name'], style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                w['status'].toString().toUpperCase().replaceAll('_', ' '),
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${w['zone']} \u2022 ${w['id']} \u2022 ${w['weeksActive']}wks active',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${w['claims']}',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 2),
                  Text('claims', style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textHint)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fraud Score', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textHint)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: fraudScore,
                            backgroundColor: AppTheme.bgElevated,
                            valueColor: AlwaysStoppedAnimation(statusColor),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(fraudScore * 100).toInt()}%',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Churn Risk', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textHint)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: churnRisk,
                            backgroundColor: AppTheme.bgElevated,
                            valueColor: AlwaysStoppedAnimation(
                              churnRisk > 0.6 ? AppTheme.alertRed : churnRisk > 0.3 ? AppTheme.warningOrange : AppTheme.successGreen,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(churnRisk * 100).toInt()}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: churnRisk > 0.6 ? AppTheme.alertRed : churnRisk > 0.3 ? AppTheme.warningOrange : AppTheme.successGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 4: Micro-Zones ─────────────────────────────────────────────

  Widget _buildMicroZonesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildSectionNote(
          'DBSCAN Spatial Clustering (Module 8)',
          'Sub-ward micro-zones learned from GPS + claims data. Re-prices workers in high-risk street clusters.',
        ),
        const SizedBox(height: 12),
        ...MockData.microZoneClusters.map((cluster) => _buildMicroZoneCard(cluster)),
      ],
    );
  }

  Widget _buildMicroZoneCard(Map<String, dynamic> cluster) {
    final multiplier = cluster['riskMultiplier'] as double;
    Color densityColor;
    switch (cluster['claimDensity']) {
      case 'Very High':
        densityColor = AppTheme.alertRed;
        break;
      case 'High':
        densityColor = AppTheme.riskHigh;
        break;
      default:
        densityColor = AppTheme.warningOrange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: densityColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: densityColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.map_rounded, color: densityColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cluster['cluster'],
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: densityColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${multiplier}x risk',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: densityColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: (cluster['streets'] as List).map((street) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined, size: 11, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(street, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            cluster['note'],
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textHint, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  // ── Tab 5: Churn Risk ──────────────────────────────────────────────

  Widget _buildChurnTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildSectionNote(
          'Churn Prediction (Module 7)',
          'Logistic regression on engagement, premium delta, claim history. Proactive retention within 2 weeks.',
        ),
        const SizedBox(height: 12),
        ...MockData.churnAlerts.map((alert) => _buildChurnCard(alert)),
      ],
    );
  }

  Widget _buildChurnCard(Map<String, dynamic> alert) {
    final prob = alert['churnProbability'] as double;
    final color = prob > 0.7 ? AppTheme.alertRed : prob > 0.5 ? AppTheme.warningOrange : AppTheme.riskMedium;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    alert['workerName'].toString().substring(0, 1),
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert['workerName'], style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    Text('${alert['zone']} \u2022 ${alert['workerId']}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(prob * 100).toInt()}%',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why:',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textHint),
                ),
                Text(
                  alert['reason'],
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.successGreen.withAlpha(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggested message:',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.successGreen),
                ),
                const SizedBox(height: 2),
                Text(
                  alert['suggestedAction'],
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Retention message sent to ${alert['workerName']}'),
                    backgroundColor: AppTheme.successGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded, size: 14),
              label: Text('Send Retention Message', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                side: BorderSide(color: AppTheme.primaryBlue.withAlpha(80)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
