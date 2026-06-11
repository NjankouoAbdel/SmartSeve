import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';
import 'package:wfer_flousk_firebase/core/constants/ui_tokens.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/navigation/app_router.dart';
import 'package:wfer_flousk_firebase/core/widgets/glass_card.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/accounts/account_selector_page.dart';
import 'package:wfer_flousk_firebase/presentation/widgets/app_logo.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const int _lastPageIndex = 3;

  final PageController _pageController = PageController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  int _currentPage = 0;
  bool _busy = false;

  String _t(String english, {String? fr}) {
    return context.l10n.phrase(english, french: fr);
  }

  String get _typedFullName {
    final String first = _firstNameController.text.trim();
    final String last = _lastNameController.text.trim();
    final String value = '$first $last'.trim();
    return value.isEmpty ? _t('SMART User', fr: 'Utilisateur SMART') : value;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              children: <Widget>[
                _topBar(context),
                const SizedBox(height: 10),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (int value) {
                      setState(() => _currentPage = value);
                    },
                    children: <Widget>[
                      _profileFormPage(context),
                      _guidePage(
                        context,
                        icon: Icons.dashboard_customize_rounded,
                        title: 'How the app works',
                        description:
                            'Home gives quick overview, Add saves expense, Statistics shows insights, Settings controls your preferences.',
                        example:
                            'Example: Add 45.00 MAD in Food and track monthly trend instantly.',
                        highlights: const <String>[
                          'Quick Add',
                          'Smart Stats',
                          'Clean Settings',
                        ],
                      ),
                      _guidePage(
                        context,
                        icon: Icons.lightbulb_rounded,
                        title: 'Smart usage tips',
                        description:
                            'Set monthly income and savings goal to get a clear spend-vs-save view before month end.',
                        example:
                            'Example: Income 7000 MAD, goal 1200 MAD, app helps keep spending under control.',
                        highlights: const <String>[
                          'Income Plan',
                          'Savings Goal',
                          'Monthly Control',
                        ],
                      ),
                      _welcomePage(context),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _dots(),
                const SizedBox(height: 12),
                _bottomControls(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Text(
            '${_currentPage + 1}/${_lastPageIndex + 1}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _t('Welcome to SMART DAILY', fr: 'Bienvenue sur SMART DAILY'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }

  Widget _profileFormPage(BuildContext context) {
    return Center(
      child: GlassCard(
        borderRadius: 22,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Center(child: AppLogo(size: 88, heroTag: null)),
              const SizedBox(height: UiTokens.spacingSm),
              Text(
                _t(
                  'Let us personalize your dashboard',
                  fr: 'Personnalisons votre tableau de bord',
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                _t('Enter your first and last name.', fr: 'Entrez votre prenom et nom.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: UiTokens.spacingMd),
              TextFormField(
                controller: _firstNameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: _t('First name', fr: 'Prenom'),
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (String? value) {
                  if ((value ?? '').trim().isEmpty) {
                    return _t('First name is required', fr: 'Le prenom est obligatoire');
                  }
                  return null;
                },
              ),
              const SizedBox(height: UiTokens.spacingSm),
              TextFormField(
                controller: _lastNameController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: _t('Last name', fr: 'Nom'),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (String? value) {
                  if ((value ?? '').trim().isEmpty) {
                    return _t('Last name is required', fr: 'Le nom est obligatoire');
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guidePage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String example,
    required List<String> highlights,
  }) {
    return Center(
      child: GlassCard(
        borderRadius: 26,
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.primaryBlue.withValues(alpha: 0.45),
                AppColors.gradientBlue2.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -40,
                right: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.softBlueGlow.withValues(alpha: 0.18),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: <Color>[
                                AppColors.primaryBlue,
                                AppColors.gradientBlue2,
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.softBlueGlow.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _t(title),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _t('Premium Quick Guide', fr: 'Guide rapide premium'),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.softGrayText,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: highlights
                          .map(
                            (String item) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.white.withValues(alpha: 0.10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Text(
                                _t(item),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t(description),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0.11),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 4,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  AppColors.skyBlue,
                                  AppColors.primaryBlue,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _t('Example', fr: 'Exemple'),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.skyBlue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _t(example),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(height: 1.45),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcomePage(BuildContext context) {
    final String fullName = _typedFullName;

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.84, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (BuildContext context, double value, Widget? child) {
          return Transform.scale(scale: value, child: child);
        },
        child: GlassCard(
          borderRadius: 26,
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width > 500 ? 330 : 250,
                  child: Image.asset(
                    'assets/icons/welcome.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Text(
                  _t('Welcome Onboard', fr: 'Bienvenue a bord'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.skyBlue,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _t('Welcome,', fr: 'Bienvenue,'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                fullName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.94),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  'Your smart daily expense manager is ready.',
                  fr: 'Votre gestionnaire intelligent de depenses est pret.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(
        _lastPageIndex + 1,
        (int index) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(
              alpha: _currentPage == index ? 0.95 : 0.30,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomControls(BuildContext context) {
    final bool isFirst = _currentPage == 0;
    final bool isLast = _currentPage == _lastPageIndex;

    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: (_busy || isFirst) ? null : _onLastPressed,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(_t('Last', fr: 'Precedent')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextButton(
            onPressed: (_busy || isLast) ? null : _onSkipPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.skyBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(_t('Skip', fr: 'Passer')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: <Color>[AppColors.primaryBlue, AppColors.gradientBlue2],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.softBlueGlow.withValues(alpha: 0.38),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _busy ? null : _onPrimaryPressed,
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              isLast
                                  ? _t('Start', fr: 'Commencer')
                                  : _t('Next', fr: 'Suivant'),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              isLast
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onPrimaryPressed() async {
    if (_currentPage == 0) {
      final FormState? form = _formKey.currentState;
      if (form == null || !form.validate()) {
        return;
      }
      await _goToPage(1);
      return;
    }

    if (_currentPage < _lastPageIndex) {
      await _goToPage(_currentPage + 1);
      return;
    }

    await _finishOnboarding();
  }

  Future<void> _onLastPressed() async {
    if (_currentPage <= 0) {
      return;
    }
    await _goToPage(_currentPage - 1);
  }

  Future<void> _onSkipPressed() async {
    await _goToLastPage();
  }

  Future<void> _finishOnboarding() async {
    setState(() => _busy = true);
    final SettingsController settings = context.read<SettingsController>();
    await settings.completeOnboarding(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushReplacement(AppRouter.slideFade(const AccountSelectorPage()));
  }

  Future<void> _goToPage(int page) async {
    await _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goToLastPage() async {
    if (_currentPage == 0) {
      final FormState? form = _formKey.currentState;
      if (form == null || !form.validate()) {
        return;
      }
    }
    await _goToPage(_lastPageIndex);
  }
}

