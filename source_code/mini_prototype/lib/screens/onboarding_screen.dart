import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../services/api_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _partnerIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final Set<String> _selectedZones = {};
  final _upiController = TextEditingController();

  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _aadhaarVerified = false;
  String? _aadhaarError;
  String? _registeredWorkerId;

  List<String> _availableZones = [];
  bool _zonesFetched = false;

  int _premiumAmount = 49;
  String _premiumTier = 'STANDARD TIER';
  List<Map<String, String>> _premiumBreakdown = [];
  bool _premiumFetched = false;

  @override
  void dispose() {
    _pageController.dispose();
    _partnerIdController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _upiController.dispose();
    _aadhaarController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _verifyAadhaar() async {
    final aadhaar = _aadhaarController.text.replaceAll(RegExp(r'[\s\-]'), '');
    if (aadhaar.length != 12) {
      setState(() => _aadhaarError = 'Aadhaar number must be exactly 12 digits');
      return;
    }
    setState(() {
      _isLoading = true;
      _aadhaarError = null;
    });
    try {
      final result = await _apiService.verifyAadhaar(aadhaar);
      if (!mounted) return;
      if (result['valid'] == true) {
        setState(() {
          _aadhaarVerified = true;
          _aadhaarError = null;
        });
        _showSuccess('Aadhaar verified successfully');
      } else {
        setState(() {
          _aadhaarVerified = false;
          _aadhaarError = result['error'] ?? 'Invalid Aadhaar number';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aadhaarError = 'Verification failed. Please try again.';
        _aadhaarVerified = false;
      });
      _showError('Could not reach verification service');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchZones() async {
    if (_zonesFetched) return;
    setState(() => _isLoading = true);
    try {
      final zones = await _apiService.getMonitoredZones();
      if (!mounted) return;
      if (zones.isNotEmpty) {
        setState(() {
          _availableZones = zones;
          _zonesFetched = true;
        });
      } else {
        setState(() {
          _availableZones = List<String>.from(MockData.chennaiZones);
          _zonesFetched = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _availableZones = List<String>.from(MockData.chennaiZones);
        _zonesFetched = true;
      });
      _showError('Could not fetch zones from server. Using default list.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerAndFetchPremium() async {
    if (_premiumFetched) return;
    setState(() => _isLoading = true);
    try {
      final cleanAadhaar = _aadhaarController.text.replaceAll(RegExp(r'[\s\-]'), '');
      final regResult = await _apiService.registerWorker(
        partnerId: _partnerIdController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        zones: _selectedZones.toList(),
        aadhaar: cleanAadhaar,
      );
      if (!mounted) return;

      if (regResult['worker'] != null) {
        _registeredWorkerId = regResult['worker']['id'];
      } else if (regResult['workerId'] != null) {
        _registeredWorkerId = regResult['workerId'];
      }

      if (_registeredWorkerId != null) {
        await _apiService.setWorkerId(_registeredWorkerId!);
      }

      if (_registeredWorkerId == null) {
        _showError(regResult['error']?.toString() ?? 'Registration failed');
        setState(() => _isLoading = false);
        return;
      }

      final premiumData = await _apiService.getMLPremium(_registeredWorkerId!);
      if (!mounted) return;

      if (premiumData != null) {
        final amount = premiumData['premium_amount_inr'] ?? 49;
        setState(() {
          _premiumAmount = (amount is double) ? amount.round() : (amount is int ? amount : 49);
          _premiumTier = (premiumData['risk_tier'] ?? 'STANDARD').toString().toUpperCase().replaceAll('_', ' ') + ' TIER';

          _premiumBreakdown = [];
          final breakdown = premiumData['breakdown'];
          if (breakdown is Map) {
            final base = breakdown['base_amount_inr'];
            final zone = breakdown['zone_risk_label'];
            final monsoon = breakdown['monsoon_multiplier'];
            final loyalty = breakdown['loyalty_discount_pct'];
            final flood = breakdown['flood_surcharge_applied'];

            _premiumBreakdown.add({'label': 'Base rate (${breakdown['base_tier'] ?? 'standard'})', 'value': '\u20b9${base ?? 29}'});
            _premiumBreakdown.add({'label': 'Zone risk ($zone)', 'value': zone == 'high' ? '+\u20b920' : zone == 'standard' ? '+\u20b910' : '+\u20b90'});
            final zoneCount = breakdown['zone_count'];
            final zoneMult = breakdown['zone_count_multiplier'];
            if (zoneCount != null && zoneCount > 2) {
              _premiumBreakdown.add({'label': 'Multi-zone coverage ($zoneCount zones)', 'value': '+${(((zoneMult ?? 1.0) - 1) * 100).round()}%'});
            }
            if (monsoon != null && monsoon > 1.0) {
              _premiumBreakdown.add({'label': 'Monsoon loading (${monsoon}x)', 'value': '+30%'});
            }
            if (flood == true) {
              _premiumBreakdown.add({'label': 'Flood zone surcharge', 'value': '+8%'});
            }
            if (loyalty != null && loyalty > 0) {
              _premiumBreakdown.add({'label': 'Loyalty discount', 'value': '-${loyalty}%'});
            }
          }
          _premiumFetched = true;
        });
      } else {
        setState(() => _premiumFetched = true);
        _showError('Could not fetch ML premium. Using default rate.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _premiumFetched = true);
      _showError('Registration or premium fetch failed. Using default rate.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatBreakdownKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  Future<void> _activateAndNavigate() async {
    if (_registeredWorkerId == null) {
      _showError('No worker ID found. Please go back and complete registration.');
      return;
    }
    final upiId = _upiController.text.trim();
    if (upiId.isEmpty || !upiId.contains('@')) {
      _showError('Please enter a valid UPI ID (e.g. name@okicici)');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final upiCheck = await _apiService.verifyUpi(upiId);
      if (upiCheck['valid'] != true) {
        if (!mounted) return;
        _showError(upiCheck['error']?.toString() ?? 'UPI validation failed');
        setState(() => _isLoading = false);
        return;
      }
      await _apiService.updateWorker(_registeredWorkerId!, {'upi_id': upiId});
      final result = await _apiService.activatePolicy(_registeredWorkerId!);
      if (!mounted) return;
      if (result['error'] != null) {
        _showError(result['error'].toString());
        setState(() => _isLoading = false);
        return;
      }
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      _showError('Could not activate policy. Please try again.');
      setState(() => _isLoading = false);
    }
  }

  void _nextPage() {
    if (_isLoading) return;

    if (_currentPage == 0) {
      if (_partnerIdController.text.trim().isEmpty) {
        _showError('Please enter your Partner ID');
        return;
      }
      if (_nameController.text.trim().isEmpty) {
        _showError('Please enter your name');
        return;
      }
      if (_phoneController.text.trim().isEmpty) {
        _showError('Please enter your phone number');
        return;
      }
      _goToNextPage();
    } else if (_currentPage == 1) {
      if (!_aadhaarVerified) {
        _showError('Please verify your Aadhaar number first');
        return;
      }
      _fetchZones();
      _goToNextPage();
    } else if (_currentPage == 2) {
      if (_selectedZones.isEmpty) {
        _showError('Please select at least one delivery zone');
        return;
      }
      _registerAndFetchPremium();
      _goToNextPage();
    } else if (_currentPage == 3) {
      _goToNextPage();
    } else if (_currentPage == 4) {
      _activateAndNavigate();
    }
  }

  void _goToNextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.shield, color: AppTheme.primaryBlue, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Delisure',
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

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildPartnerIdPage(),
                  _buildAadhaarPage(),
                  _buildZonesPage(),
                  _buildRiskProfilePage(),
                  _buildUpiPage(),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: const Color(0xFF09090B),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF09090B),
                          ),
                        )
                      : Text(
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
      child: SingleChildScrollView(
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
            TextField(
              controller: _nameController,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
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
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textSecondary),
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
      ),
    );
  }

  Widget _buildAadhaarPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verify your\nAadhaar Number',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your 12-digit Aadhaar number for identity verification.',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _aadhaarController,
            keyboardType: TextInputType.number,
            maxLength: 14,
            enabled: !_aadhaarVerified,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 4,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'XXXX XXXX XXXX',
              hintStyle: TextStyle(color: AppTheme.textHint),
              counterText: '',
              errorText: _aadhaarError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _aadhaarVerified ? AppTheme.successGreen : AppTheme.borderColor,
                  width: _aadhaarVerified ? 1.5 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
              ),
              filled: true,
              fillColor: AppTheme.bgInput,
              suffixIcon: _aadhaarVerified
                  ? const Icon(Icons.check_circle, color: AppTheme.successGreen)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          if (!_aadhaarVerified)
            Center(
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _verifyAadhaar,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryBlue,
                          ),
                        )
                      : Text(
                          'Verify Aadhaar',
                          style: GoogleFonts.inter(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          if (_aadhaarVerified) ...[
            Center(
              child: Text(
                'Aadhaar verified successfully',
                style: GoogleFonts.inter(
                  color: AppTheme.successGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
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
    final zones = _availableZones.isNotEmpty ? _availableZones : MockData.chennaiZones;

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
          if (_isLoading && !_zonesFetched)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: zones.map((zone) {
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
    final String premiumDisplay = '\u20b9$_premiumAmount/week';
    final bool hasBreakdown = _premiumBreakdown.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _isLoading && !_premiumFetched
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryBlue),
                  SizedBox(height: 16),
                  Text(
                    'Calculating your premium...',
                    style: TextStyle(color: AppTheme.primaryBlue),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
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
                          premiumDisplay,
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
                            _premiumTier,
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
                  Text(
                    'Premium Breakdown',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (hasBreakdown) ...[
                    for (var item in _premiumBreakdown)
                      _buildBreakdownRow(item['label'] ?? '', item['value'] ?? ''),
                    Divider(height: 24, color: AppTheme.dividerColor),
                    _buildBreakdownRow('Total weekly premium', '\u20b9$_premiumAmount', bold: true),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor.withAlpha(60)),
                      ),
                      child: Text(
                        'Detailed breakdown unavailable — using standard rate based on ${_selectedZones.length} zone(s).',
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withAlpha(12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryBlue.withAlpha(30)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.primaryBlue, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your premium is calculated by our XGBoost AI model based on your selected zones, historical disruption risk, number of zones, and current season. Fewer high-risk zones = lower premium.',
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.primaryBlue, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
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
    final String premiumDisplay = '\u20b9$_premiumAmount/week';

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
            '\u20b9$_premiumAmount will be debited weekly via UPI auto-pay. Cancel anytime.',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _upiController,
            style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'name@okicici, name@ybl, etc.',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: AppTheme.textHint),
              labelText: 'Your UPI ID',
              labelStyle: GoogleFonts.inter(color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.bgInput,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue),
              ),
              prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
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
                _buildMandateRow('Amount', premiumDisplay),
                _buildMandateRow('Frequency', 'Weekly (Monday)'),
                _buildMandateRow('Max debit', '\u20b9$_premiumAmount'),
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
