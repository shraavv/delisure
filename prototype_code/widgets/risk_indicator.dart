import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class RiskIndicator extends StatelessWidget {
  final double score;
  final bool showLabel;
  final double size;

  const RiskIndicator({
    super.key,
    required this.score,
    this.showLabel = true,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.riskColor(score);
    final label = AppTheme.riskLabel(score);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(76),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ],
    );
  }
}

class RiskBar extends StatelessWidget {
  final double score;
  final double height;
  final double width;

  const RiskBar({
    super.key,
    required this.score,
    this.height = 40,
    this.width = 20,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.riskColor(score);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height * score,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
