import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _partnerIdController = TextEditingController(text: 'SWG-CHN-28491');
  final _otpController = TextEditingController();
  final Set<String> _selectedZones = {'Velachery', 'Adyar', 'Thiruvanmallur'};

  @override
  void dispose() {
    _pageController.dispose();
    _partnerIdController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.shield, color: AppTheme.primaryBlue, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'delisure',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const Spacer(),
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: Text(
                        'Back',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                ],
              ),
            ),

            // Page indicator dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return Container(
                  width: _currentPage == i ? 28 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppTheme.primaryBlue
                        : const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildPartnerIdPage(),
                  _buildOtpPage(),
                  _buildZonesPage(),
                  _buildRiskProfilePage(),
                  _buildUpiPage(),
                ],
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: const Color(0xFF09090B),
                  ),
                  child: Text(
                    _currentPage == 4 ? 'Start Coverage' : 'Continue',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerIdPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter your Swiggy\nPartner ID',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find this in your Swiggy Delivery Partner app under Profile.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _partnerIdController,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Swiggy Partner ID',
              prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
              ),
              filled: true,
              fillColor: AppTheme.bgInput,
              labelStyle: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.primaryBlue.withAlpha(30),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryBlue.withAlpha(180), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'We use this to verify your delivery activity and calculate your risk profile.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.primaryBlue.withAlpha(200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verify with\nAadhaar OTP',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ve sent a 6-digit OTP to your Aadhaar-linked mobile number.',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 12,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '------',
              hintStyle: TextStyle(color: AppTheme.textHint),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
              ),
              filled: true,
              fillColor: AppTheme.bgInput,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text(
                'Resend OTP',
                style: GoogleFonts.inter(color: AppTheme.primaryBlue),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.successGreen.withAlpha(30),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: AppTheme.successGreen.withAlpha(200), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your data is encrypted and used only for identity verification.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.successGreen.withAlpha(200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZonesPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select your\ndelivery zones',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the zones where you regularly deliver. Coverage applies to these areas.',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: MockData.chennaiZones.map((zone) {
                final selected = _selectedZones.contains(zone);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primaryBlue.withAlpha(15)
                        : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primaryBlue
                          : AppTheme.borderColor,
                      width: selected ? 1.5 : 0.5,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: selected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedZones.add(zone);
                        } else {
                          _selectedZones.remove(zone);
                        }
                      });
                    },
                    title: Text(
                      zone,
                      style: GoogleFonts.inter(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    secondary: Icon(
                      Icons.location_on,
                      color: selected ? AppTheme.primaryBlue : AppTheme.textHint,
                    ),
                    activeColor: AppTheme.primaryBlue,
                    checkColor: const Color(0xFF09090B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskProfilePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your AI\nrisk profile',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Based on your delivery data, zones, and historical weather patterns.',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            // Premium card - dark with gold accent
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.bgElevated,
                    const Color(0xFF1A1A1F),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryBlue.withAlpha(50),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Your Weekly Premium',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.primaryBlue.withAlpha(180),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\u20b949/week',
                    style: GoogleFonts.poppins(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withAlpha(40),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      'STANDARD TIER',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlue,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Breakdown
            Text(
              'Premium Breakdown',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildBreakdownRow('Base rate (Standard)', '\u20b939'),
            _buildBreakdownRow('Zone risk adjustment (3 zones)', '+\u20b97'),
            _buildBreakdownRow('Activity bonus discount', '-\u20b92'),
            _buildBreakdownRow('Monsoon season loading', '+\u20b95'),
            Divider(height: 24, color: AppTheme.dividerColor),
            _buildBreakdownRow('Total weekly premium', '\u20b949', bold: true),
            const SizedBox(height: 24),
            // Coverage includes
            Text(
              'Coverage Includes',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildCoverageItem(Icons.water_drop, 'Heavy Rainfall'),
            _buildCoverageItem(Icons.thermostat, 'Extreme Heat'),
            _buildCoverageItem(Icons.air, 'Poor Air Quality'),
            _buildCoverageItem(Icons.block, 'Bandh / Strike'),
            _buildCoverageItem(Icons.power_off, 'Power Outage'),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverageItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryBlue),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildUpiPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set up UPI\nauto-debit',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\u20b949 will be debited weekly via UPI auto-pay. Cancel anytime.',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          // GPay simulation - dark card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor, width: 0.5),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.bgInput,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderColor, width: 0.5),
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          color: Color(0xFF4285F4),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Google Pay',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'UPI Auto-pay mandate',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.successGreen,
                        size: 24,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildMandateRow('Amount', '\u20b949/week'),
                _buildMandateRow('Frequency', 'Weekly (Monday)'),
                _buildMandateRow('Max debit', '\u20b949'),
                _buildMandateRow('Valid till', '05 Jan 2027'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.successGreen.withAlpha(30),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user, color: AppTheme.successGreen.withAlpha(200), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'IRDAI regulated. Cancel anytime from your UPI app.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.successGreen.withAlpha(200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMandateRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
