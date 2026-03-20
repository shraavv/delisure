import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../widgets/payout_tile.dart';

class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Rainfall', 'Cyclone', 'Heat', 'AQI', 'Bandh', 'Outage', 'Traffic'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: Column(
        children: [
          // Header with summary
          Container(
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
                colors: [Color(0xFF0A1F12), Color(0xFF0D2B18), Color(0xFF103520)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Total Payouts',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '\u20b93,690',
                  style: GoogleFonts.poppins(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withAlpha(15)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryStat(
                          'Premiums Paid',
                          '\u20b91,176',
                          Icons.arrow_upward_rounded,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: Colors.white.withAlpha(20),
                      ),
                      Expanded(
                        child: _buildSummaryStat(
                          'Net Benefit',
                          '+\u20b92,514',
                          Icons.trending_up_rounded,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: Colors.white.withAlpha(20),
                      ),
                      Expanded(
                        child: _buildSummaryStat(
                          'Claims',
                          '${MockData.allPayouts.length}',
                          Icons.receipt_long_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _filters.map((filter) {
                final selected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                    backgroundColor: AppTheme.bgElevated,
                    selectedColor: AppTheme.primaryBlue.withAlpha(25),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                    ),
                    checkmarkColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: selected ? AppTheme.primaryBlue.withAlpha(80) : AppTheme.borderColor,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Payout list
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _filteredPayouts().length,
              itemBuilder: (context, index) {
                final payout = _filteredPayouts()[index];
                final trigger = _findTrigger(payout.triggerEventId);
                return PayoutTile(
                  payout: payout,
                  triggerType: trigger?.type ?? 'rainfall',
                  zone: trigger?.zone ?? '',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.white.withAlpha(120)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.white.withAlpha(150),
          ),
        ),
      ],
    );
  }

  List<dynamic> _filteredPayouts() {
    final all = MockData.allPayouts;
    if (_selectedFilter == 'All') return all;
    return all.where((p) {
      final trigger = _findTrigger(p.triggerEventId);
      if (trigger == null) return false;
      final type = trigger.type.toString().toLowerCase();
      return type == _selectedFilter.toLowerCase();
    }).toList();
  }

  dynamic _findTrigger(String triggerEventId) {
    if (MockData.activeTrigger.id == triggerEventId) return MockData.activeTrigger;
    try {
      return MockData.pastTriggers.firstWhere((t) => t.id == triggerEventId);
    } catch (_) {
      return null;
    }
  }
}
