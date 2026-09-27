import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';
import 'package:wfer_flousk_firebase/core/constants/ui_tokens.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/navigation/post_auth_navigation.dart';
import 'package:wfer_flousk_firebase/core/widgets/animated_primary_button.dart';
import 'package:wfer_flousk_firebase/core/widgets/glass_card.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/core/widgets/responsive_page_body.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';
import 'package:wfer_flousk_firebase/presentation/widgets/app_logo.dart';

/// Mandatory authentication gate shown right after the splash screen.
///
/// The user MUST create an account or sign in with a real email address
/// before reaching onboarding or the app's home screen. This replaces silent
/// anonymous access so that every user of the app is tied to a real,
/// verifiable account (data already written under an anonymous session, if
/// any, is preserved and linked to the new account by
/// [FirebaseToolkitService.signUp]/[signIn]).
class RequireLoginPage extends StatefulWidget {
  const RequireLoginPage({super.key});

  @override
  State<RequireLoginPage> createState() => _RequireLoginPageState();
}

class _RequireLoginPageState extends State<RequireLoginPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late final TabController _tabController;

  bool _submitting = false;
  String? _errorMessage;

  bool get _isSignUp => _tabController.index == 1;

  String _t(String english, {String? fr}) {
    return context.l10n.phrase(english, french: fr);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() => _errorMessage = null);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final ToolsController tools = context.read<ToolsController>();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final bool isSignUp = _isSignUp;

    try {
      final String? error = isSignUp
          ? await tools.signUp(email, password)
          : await tools.signIn(email, password);

      if (!mounted) {
        return;
      }

      if (error != null) {
        setState(() {
          _submitting = false;
          _errorMessage = error;
        });
        return;
      }

      await navigateToPostAuthDestination(context);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = _t(
          'Unable to complete the request. Please try again.',
          fr: 'Impossible de terminer la demande. Veuillez reessayer.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ToolsController tools = context.watch<ToolsController>();

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ResponsivePageBody(
            top: 24,
            bottom: 24,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Center(
                    child: AppLogo(
                      size: 84,
                      assetPath: 'assets/icons/app_icon.jpeg',
                      heroTag: 'auth_gate_logo',
                    ),
                  ),
                  const SizedBox(height: UiTokens.spacingMd),
                  Text(
                    _t(
                      'Secure Account Required',
                      fr: 'Compte securise requis',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t(
                      'For your security, create an account or sign in with your email to continue.',
                      fr: 'Pour votre securite, creez un compte ou connectez-vous avec votre email pour continuer.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: UiTokens.spacingLg),
                  GlassCard(
                    borderRadius: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  AppColors.primaryBlue,
                                  AppColors.gradientBlue2,
                                ],
                              ),
                            ),
                            labelStyle: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            unselectedLabelColor: AppColors.softGrayText,
                            tabs: <Widget>[
                              Tab(text: _t('Sign In', fr: 'Se connecter')),
                              Tab(text: _t('Sign Up', fr: 'Creer compte')),
                            ],
                          ),
                        ),
                        const SizedBox(height: UiTokens.spacingMd),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: <Widget>[
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: _t('Email', fr: 'Email'),
                                  prefixIcon: const Icon(Icons.email_outlined),
                                ),
                                validator: (String? value) {
                                  final String text = value?.trim() ?? '';
                                  if (text.isEmpty || !text.contains('@')) {
                                    return _t(
                                      'Enter a valid email.',
                                      fr: 'Entrez un email valide.',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: UiTokens.spacingSm),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  hintText: _t('Password', fr: 'Mot de passe'),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                ),
                                validator: (String? value) {
                                  final String text = value?.trim() ?? '';
                                  if (text.length < 6) {
                                    return _t(
                                      'Minimum 6 characters.',
                                      fr: 'Minimum 6 caracteres.',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              if (_isSignUp) ...<Widget>[
                                const SizedBox(height: UiTokens.spacingSm),
                                TextFormField(
                                  controller: _confirmController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    hintText: _t(
                                      'Confirm Password',
                                      fr: 'Confirmer mot de passe',
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.verified_user_outlined,
                                    ),
                                  ),
                                  validator: (String? value) {
                                    if (!_isSignUp) {
                                      return null;
                                    }
                                    if ((value ?? '') !=
                                        _passwordController.text) {
                                      return _t(
                                        'Passwords do not match.',
                                        fr: 'Les mots de passe ne correspondent pas.',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: UiTokens.spacingMd),
                              AnimatedPrimaryButton(
                                label: _isSignUp
                                    ? _t(
                                        'Create Account',
                                        fr: 'Creer un compte',
                                      )
                                    : _t(
                                        'Login Securely',
                                        fr: 'Connexion securisee',
                                      ),
                                icon: _isSignUp
                                    ? Icons.person_add_alt_rounded
                                    : Icons.login_rounded,
                                isLoading: _submitting || tools.authBusy,
                                onPressed: _submit,
                              ),
                              if (_errorMessage != null) ...<Widget>[
                                const SizedBox(height: UiTokens.spacingSm),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}
