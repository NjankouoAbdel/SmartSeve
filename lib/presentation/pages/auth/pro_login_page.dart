import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';
import 'package:wfer_flousk_firebase/core/constants/ui_tokens.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/services/firebase_toolkit_service.dart';
import 'package:wfer_flousk_firebase/core/widgets/animated_primary_button.dart';
import 'package:wfer_flousk_firebase/core/widgets/fintech_page_app_bar.dart';
import 'package:wfer_flousk_firebase/core/widgets/glass_card.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/core/widgets/responsive_page_body.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';

class ProLoginPage extends StatefulWidget {
  const ProLoginPage({super.key});

  @override
  State<ProLoginPage> createState() => _ProLoginPageState();
}

class _ProLoginPageState extends State<ProLoginPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  late final TabController _tabController;

  bool _submitting = false;

  bool get _isSignUp => _tabController.index == 1;

  String _t(String english, {String? fr}) {
    return context.l10n.phrase(english, french: fr);
  }

  String _ta(String english, Map<String, String> args, {String? fr}) {
    return context.l10n.phraseWithArgs(english, args, french: fr);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final ToolsController tools = context.watch<ToolsController>();
    final SettingsController settings = context.watch<SettingsController>();
    final UsageOverview usage = tools.usageOverview;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ResponsivePageBody(
            top: 8,
            bottom: 14,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const FintechPageAppBar(
                    title: 'Cloud Login',
                    showBackToHome: true,
                  ),
                  const SizedBox(height: UiTokens.spacingSm),
                  GlassCard(
                    borderRadius: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _t(
                            'Secure Account Access',
                            fr: 'Acces securise au compte',
                          ),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _t(
                            'Login to sync data across devices and track monthly free usage.',
                            fr: 'Connectez-vous pour synchroniser les donnees entre appareils et suivre l usage mensuel gratuit.',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: UiTokens.spacingMd),
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
                                  prefixIcon: Icon(Icons.email_outlined),
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
                                  prefixIcon: Icon(Icons.lock_outline_rounded),
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
                                    prefixIcon: Icon(
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: UiTokens.spacingSm),
                  GlassCard(
                    borderRadius: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          tools.userEmail == null
                              ? _t(
                                  'No cloud account connected',
                                  fr: 'Aucun compte cloud connecte',
                                )
                              : _ta(
                                  'Connected as {email}',
                                  <String, String>{
                                    'email': tools.userEmail ?? '',
                                  },
                                  fr: 'Connecte en tant que {email}',
                                ),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          usage.isPro
                              ? _t(
                                  'Pro account active: unlimited monthly usage.',
                                  fr: 'Compte Pro actif : usage mensuel illimite.',
                                )
                              : _ta(
                                  'Free usage this month: {used}/{limit}',
                                  <String, String>{
                                    'used': usage.used.toString(),
                                    'limit': usage.limit.toString(),
                                  },
                                  fr: 'Usage gratuit ce mois : {used}/{limit}',
                                ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        if (!usage.isPro)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              value: usage.limit <= 0
                                  ? 0
                                  : (usage.used / usage.limit).clamp(0, 1),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            OutlinedButton.icon(
                              onPressed: () {
                                tools.refreshUsage(isProLocal: settings.isPro);
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(
                                _t('Refresh Usage', fr: 'Actualiser usage'),
                              ),
                            ),
                            if (tools.userEmail != null)
                              OutlinedButton.icon(
                                onPressed: tools.signOut,
                                icon: const Icon(Icons.logout_rounded),
                                label: Text(_t('Logout', fr: 'Deconnexion')),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (tools.lastCloudError != null) ...<Widget>[
                    const SizedBox(height: UiTokens.spacingSm),
                    Text(
                      tools.lastCloudError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _submitting = true);
    final ToolsController tools = context.read<ToolsController>();
    final SettingsController settings = context.read<SettingsController>();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    final bool isSignUp = _isSignUp;
    try {
      final String? error = isSignUp
          ? await tools.signUp(email, password)
          : await tools.signIn(email, password);

      await tools.refreshUsage(isProLocal: settings.isPro);

      if (!mounted) {
        return;
      }

      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSignUp
                ? _t(
                    'Account created successfully.',
                    fr: 'Compte cree avec succes.',
                  )
                : _t('Logged in successfully.', fr: 'Connexion reussie.'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Unable to complete the request. Please try again.',
              fr: 'Impossible de terminer la demande. Veuillez reessayer.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
