import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/trigger_event.dart';
import '../theme/app_theme.dart';

class TriggerAlertCard extends StatefulWidget {
  final TriggerEvent trigger;
  final double? payoutAmount;

  const TriggerAlertCard({
    super.key,
    required this.trigger,
    this.payoutAmount,
  });

  @override
  State<TriggerAlertCard> createState() => _TriggerAlertCardState();
}

class _TriggerAlertCardState extends State<TriggerAlertCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.alertRed.withAlpha(30 + (_pulse.value * 30).toInt()),
              width: 1,
            ),
          ),
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
                        color: AppTheme.alertRed.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.water_drop_rounded,
                        color: AppTheme.alertRed,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Heavy Rain Alert',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.alertRed,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 12, color: AppTheme.textHint),
                              const SizedBox(width: 2),
                              Text(
                                '${widget.trigger.zone} Zone',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                '  \u2022  ${widget.trigger.intensity.toInt()}mm/hr',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.alertRed.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.alertRed.withAlpha(40)),
                      ),
                      child: Text(
                        'LIVE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.alertRed,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.payoutAmount != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withAlpha(10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.successGreen.withAlpha(25)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppTheme.successGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payout processing',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              '\u20b9${widget.payoutAmount!.toInt()} incoming',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.successGreen,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation(
                              AppTheme.successGreen.withAlpha(80),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dinner rush window (7-10:30 PM) \u2022 70% income replacement',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
