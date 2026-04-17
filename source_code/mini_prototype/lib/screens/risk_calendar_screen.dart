import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class RiskCalendarScreen extends StatefulWidget {
  const RiskCalendarScreen({super.key});

  @override
  State<RiskCalendarScreen> createState() => _RiskCalendarScreenState();
}

class _RiskCalendarScreenState extends State<RiskCalendarScreen> {
  DateTime? _selectedDay;
  bool _isLoading = true;
  String _zone = '';
  Map<int, double> _dayRiskMap = {};
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = ApiService();
      final workerId = await api.loadWorkerId();
      if (workerId != null) {
        final workerData = await api.getWorker(workerId);
        if (workerData != null && workerData['zones'] is List && (workerData['zones'] as List).isNotEmpty) {
          _zone = (workerData['zones'] as List).first.toString();
        }
      }

      if (_zone.isNotEmpty) {
        final riskData = await api.getRiskCalendar(_zone);
        if (riskData != null) {
          final days = (riskData['days'] ?? riskData['calendar']) as List<dynamic>?;
          if (days != null) {
            for (int i = 0; i < days.length; i++) {
              final entry = days[i] as Map<String, dynamic>;
              final dateStr = entry['date'] as String?;
              final risk = (entry['risk_score'] as num?)?.toDouble() ??
                  (entry['risk'] as num?)?.toDouble() ?? 0.1;
              if (dateStr != null) {
                final date = DateTime.tryParse(dateStr);
                if (date != null) {
                  _dayRiskMap[date.day] = risk;
                }
              } else {
                final date = DateTime.now().add(Duration(days: i));
                _dayRiskMap[date.day] = risk;
              }
            }
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Risk Calendar'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.insights_rounded, color: AppTheme.primaryBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _zone.isNotEmpty
                                    ? '${_monthName(_currentMonth.month)} ${_currentMonth.year} \u2022 $_zone'
                                    : '${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                _dayRiskMap.isNotEmpty
                                    ? 'AI-powered forecast from IMD + historical data'
                                    : 'No risk data available for this zone',
                                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: _buildDayHeaders(),
                  ),

                  Container(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: _buildCalendarGrid(),
                  ),
                  const SizedBox(height: 16),

                  if (_selectedDay != null) ...[
                    _buildDayDetail(),
                    const SizedBox(height: 16),
                  ],

                  _buildLegend(),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withAlpha(12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primaryBlue.withAlpha(30)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.primaryBlue, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Risk scores update daily using real-time IMD weather data and 5 years of historical rainfall patterns for your zones.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.primaryBlue,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _monthName(int month) {
    const names = ['', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
    return names[month];
  }

  Widget _buildDayHeaders() {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Row(
      children: days.map((d) {
        return Expanded(
          child: Center(
            child: Text(
              d,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = _currentMonth;
    final startWeekday = firstDay.weekday % 7;
    final daysInMonth = DateTime(firstDay.year, firstDay.month + 1, 0).day;
    final today = DateTime.now();

    final cells = <Widget>[];

    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(firstDay.year, firstDay.month, day);
      final risk = _dayRiskMap[day] ?? 0.1;
      final isSelected = _selectedDay != null &&
          _selectedDay!.day == day &&
          _selectedDay!.month == firstDay.month;
      final isToday = day == today.day && firstDay.month == today.month && firstDay.year == today.year;
      final color = AppTheme.riskColor(risk);

      cells.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDay = date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withAlpha(180), color],
              ),
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: AppTheme.primaryBlue, width: 2.5)
                  : isToday
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withAlpha(80),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : [
                      BoxShadow(
                        color: color.withAlpha(40),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (isToday)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.0,
      children: cells,
    );
  }

  Widget _buildDayDetail() {
    final risk = _dayRiskMap[_selectedDay!.day] ?? 0.1;
    final label = AppTheme.riskLabel(risk);
    final color = AppTheme.riskColor(risk);

    String detail;
    String triggerType;
    if (risk >= 0.75) {
      detail = 'High chance of heavy rainfall or extreme conditions. Payout triggers very likely. Stay safe and let Delisure handle the rest.';
      triggerType = 'Heavy Rainfall expected';
    } else if (risk >= 0.5) {
      detail = 'Moderate risk of weather disruptions. Some disruptions possible during peak hours. Your coverage will activate automatically if thresholds are breached.';
      triggerType = 'Possible rain showers';
    } else if (risk >= 0.25) {
      detail = 'Mild weather fluctuations expected. Low probability of payout triggers. Good conditions for deliveries.';
      triggerType = 'Partly cloudy';
    } else {
      detail = 'Clear conditions forecast. Very low risk of disruptions. Excellent earning potential today.';
      triggerType = 'Clear skies';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_monthName(_selectedDay!.month)} ${_selectedDay!.day}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$label Risk \u2022 ${(risk * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            triggerType,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Risk Levels',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildLegendItem(AppTheme.riskLow, 'Low', '0-25%')),
              Expanded(child: _buildLegendItem(AppTheme.riskMedium, 'Medium', '25-50%')),
              Expanded(child: _buildLegendItem(AppTheme.riskHigh, 'High', '50-75%')),
              Expanded(child: _buildLegendItem(AppTheme.riskVeryHigh, 'V. High', '75%+')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, String range) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withAlpha(180), color],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        Text(range, style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textSecondary)),
      ],
    );
  }
}
