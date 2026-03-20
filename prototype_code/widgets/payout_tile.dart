import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/payout.dart';
import '../theme/app_theme.dart';

class PayoutTile extends StatefulWidget {
  final Payout payout;
  final String triggerType;
  final String zone;

  const PayoutTile({
    super.key,
    required this.payout,
    this.triggerType = 'rainfall',
    this.zone = '',
  });

  @override
  State<PayoutTile> createState() => _PayoutTileState();
}

class _PayoutTileState extends State<PayoutTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  IconData get _triggerIcon {
    switch (widget.triggerType) {
      case 'rainfall':
        return Icons.water_drop_rounded;
      case 'cyclone':
        return Icons.cyclone_rounded;
      case 'heat':
        return Icons.thermostat_rounded;
      case 'aqi':
        return Icons.air_rounded;
      case 'bandh':
        return Icons.block_rounded;
      case 'election':
        return Icons.how_to_vote_rounded;
      case 'outage':
        return Icons.power_off_rounded;
      case 'traffic':
        return Icons.traffic_rounded;
      case 'order_collapse':
        return Icons.trending_down_rounded;
      case 'platform_outage':
        return Icons.cloud_off_rounded;
      default:
        return Icons.warning_rounded;
    }
  }

  Color get _triggerColor {
    switch (widget.triggerType) {
      case 'rainfall':
        return const Color(0xFF1565C0);
      case 'cyclone':
        return const Color(0xFF0D47A1);
      case 'heat':
        return AppTheme.warningOrange;
      case 'aqi':
        return const Color(0xFF6A1B9A);
      case 'bandh':
        return AppTheme.alertRed;
      case 'election':
        return const Color(0xFF4527A0);
      case 'outage':
        return const Color(0xFF546E7A);
      case 'traffic':
        return const Color(0xFF78909C);
      case 'order_collapse':
        return const Color(0xFF8D6E63);
      case 'platform_outage':
        return const Color(0xFF37474F);
      default:
        return AppTheme.textSecondary;
    }
  }

  String get _triggerLabel {
    switch (widget.triggerType) {
      case 'rainfall':
        return 'Heavy Rain';
      case 'cyclone':
        return 'Cyclone';
      case 'heat':
        return 'Extreme Heat';
      case 'aqi':
        return 'AQI Spike';
      case 'bandh':
        return 'Bandh/Curfew';
      case 'election':
        return 'Election Day';
      case 'outage':
        return 'Power Outage';
      case 'traffic':
        return 'Traffic Paralysis';
      case 'order_collapse':
        return 'Order Collapse';
      case 'platform_outage':
        return 'Platform Outage';
      default:
        return 'Event';
    }
  }

  Color get _statusColor {
    switch (widget.payout.status) {
      case 'credited':
        return AppTheme.successGreen;
      case 'processing':
        return AppTheme.accentAmber;
      case 'pending':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = widget.payout.status == 'processing';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: isProcessing
            ? Border.all(color: AppTheme.warningOrange.withAlpha(40), width: 1)
            : Border.all(color: AppTheme.borderColor.withAlpha(60), width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    // Icon with colored bg
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _triggerColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_triggerIcon, color: _triggerColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    // Amount + details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '\u20b9${widget.payout.amount.toInt()}',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.successGreen,
                                ),
                              ),
                              if (isProcessing) ...[
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation(AppTheme.accentAmber),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                _triggerLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _triggerColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.zone.isNotEmpty) ...[
                                Text(
                                  '  \u2022  ${widget.zone}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Right side: status + date
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.payout.status.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM, h:mm a').format(widget.payout.timestamp),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.textHint,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                // Expandable breakdown
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgElevated,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.payout.breakdown,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
