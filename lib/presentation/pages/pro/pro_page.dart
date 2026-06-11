import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';
import 'package:wfer_flousk_firebase/core/constants/ui_tokens.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/widgets/animated_primary_button.dart';
import 'package:wfer_flousk_firebase/core/widgets/fintech_page_app_bar.dart';
import 'package:wfer_flousk_firebase/core/widgets/glass_card.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/core/widgets/responsive_page_body.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/purchase_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/widgets/app_logo.dart';

class ProPage extends StatelessWidget {
  const ProPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PurchaseController? purchase = context.watch<PurchaseController?>();
    final SettingsController settings = context.watch<SettingsController>();
    final bool storeAvailable = purchase?.storeAvailable ?? false;
    final bool isPurchasePending = purchase?.isPurchasePending ?? false;
    final bool hasProduct = purchase?.hasProduct ?? false;
    final String localizedPrice =
        purchase?.localizedPrice ??
        context.l10n.phrase('Unavailable', french: 'Indisponible');
    final String? purchaseError = purchase == null
        ? context.l10n.phrase(
            'Billing is disabled in offline mode.',
            french: 'La facturation est desactivee en mode hors ligne.',
          )
        : purchase.errorMessage;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ResponsivePageBody(
            top: 8,
            bottom: 16,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const FintechPageAppBar(
                    title: 'Go Pro',
                    showBackToHome: true,
                  ),
                  const SizedBox(height: UiTokens.spacingSm),
                  Center(
                    child: Column(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.softBlueGlow.withValues(
                                  alpha: 0.45,
                                ),
                                blurRadius: 34,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const AppLogo(size: 94, heroTag: null),
                        ),
                        const SizedBox(height: UiTokens.spacingSm),
                        Text(
                          settings.isPro
                              ? context.l10n.phrase(
                                  'Pro is Active',
                                  french: 'Pro est actif',
                                )
                              : context.l10n.phrase(
                                  'Upgrade to Pro',
                                  french: 'Passer a Pro',
                                ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.phrase(
                            'Premium tools for serious personal finance management.',
                            french:
                                'Des outils premium pour une gestion financiere serieuse.',
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: UiTokens.spacingLg),
                  GlassCard(
                    borderRadius: 20,
                    child: Column(
                      children: <Widget>[
                        _FeatureRow(
                          context.l10n.phrase(
                            'Unlimited Budgets',
                            french: 'Budgets illimites',
                          ),
                        ),
                        _FeatureRow(
                          context.l10n.phrase(
                            'Unlimited bank accounts (more than 2 wallets)',
                            french:
                                'Comptes bancaires illimites (plus de 2 portefeuilles)',
                          ),
                        ),
                        _FeatureRow(
                          context.l10n.phrase(
                            'Advanced Insights',
                            french: 'Insights avances',
                          ),
                        ),
                        _FeatureRow(
                          context.l10n.phrase(
                            'Export to PDF',
                            french: 'Exporter en PDF',
                          ),
                        ),
                        _FeatureRow(
                          context.l10n.phrase(
                            'Backup & Restore',
                            french: 'Sauvegarde et restauration',
                          ),
                        ),
                        _FeatureRow(
                          context.l10n.phrase(
                            'Fingerprint Lock',
                            french: 'Verrou empreinte',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: UiTokens.spacingMd),
                  GlassCard(
                    borderRadius: 20,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.primaryBlue,
                        AppColors.gradientBlue2,
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.l10n.phraseWithArgs(
                              'Pro Lifetime - {price}',
                              <String, String>{'price': localizedPrice},
                              french: 'Pro a vie - {price}',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: UiTokens.spacingMd),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: !settings.isPro
                          ? AnimatedPrimaryButton(
                              label: isPurchasePending
                                  ? context.l10n.phrase(
                                      'Processing...',
                                      french: 'Traitement...',
                                    )
                                  : context.l10n.phrase(
                                      'Unlock Pro',
                                      french: 'Debloquer Pro',
                                    ),
                              icon: Icons.lock_open_rounded,
                              isLoading: isPurchasePending,
                              onPressed: hasProduct && storeAvailable
                                  ? purchase?.buyPro
                                  : null,
                            )
                          : AnimatedPrimaryButton(
                              label: context.l10n.phrase(
                                'Pro Unlocked',
                                french: 'Pro debloque',
                              ),
                              icon: Icons.verified_rounded,
                              isSuccess: true,
                              onPressed: null,
                            ),
                    ),
                  ),
                  const SizedBox(height: UiTokens.spacingXs),
                  Center(
                    child: TextButton(
                      onPressed: storeAvailable
                          ? purchase?.restorePurchases
                          : null,
                      child: Text(
                        context.l10n.phrase(
                          'Restore Purchases',
                          french: 'Restaurer achats',
                        ),
                      ),
                    ),
                  ),
                  if (purchaseError != null && purchaseError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: UiTokens.spacingXs),
                      child: Text(
                        purchaseError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.incomeGreen,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

