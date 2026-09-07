import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/navigation/app_router.dart';
import 'package:wfer_flousk_firebase/core/navigation/shell_navigation_controller.dart';
import 'package:wfer_flousk_firebase/core/services/export_service.dart';
import 'package:wfer_flousk_firebase/core/services/google_sheets_service.dart';
import 'package:wfer_flousk_firebase/core/theme/theme_preferences.dart';
import 'package:wfer_flousk_firebase/core/utils/currency_utils.dart';
import 'package:wfer_flousk_firebase/core/utils/expense_filtering.dart';
import 'package:wfer_flousk_firebase/core/utils/responsive_utils.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/purchase_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/pro/pro_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/settings/wallet_manager_page.dart';
import 'package:wfer_flousk_firebase/presentation/widgets/expense_filter_bottom_sheet.dart';
import 'package:wfer_flousk_firebase/presentation/widgets/app_logo.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Temporary QA switch: keep true while testing export without Pro.
  // IMPORTANT: set to false before production release.
  static const bool _allowExportWithoutPro = false;

  bool _animateIn = false;
  bool _remindersEnabled = true;
  bool _quickAddEnabled = true;
  bool _fingerprintEnabled = false;
  String _weekStart = 'Monday';
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  ExpenseAdvancedFilter _reportFilter = const ExpenseAdvancedFilter();

  String _t(String english, {String? fr}) {
    return context.l10n.phrase(english, french: fr);
  }

  String _ta(String english, Map<String, String> args, {String? fr}) {
    return context.l10n.phraseWithArgs(english, args, french: fr);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _animateIn = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.maxContentWidth(context),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: _animateIn ? 1 : 0),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double value, Widget? child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 14),
                        child: child,
                      ),
                    );
                  },
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _appBar(context),
                        const SizedBox(height: 14),
                        _stagger(0, _headerCard(context, settings)),
                        const SizedBox(height: 20),
                        _stagger(1, _appearanceCard(context, settings)),
                        const SizedBox(height: 20),
                        _stagger(2, _preferencesCard(context, settings)),
                        const SizedBox(height: 20),
                        _stagger(3, _securityCard(context, settings)),
                        const SizedBox(height: 20),
                        _stagger(4, _dataCard(context, settings)),
                        const SizedBox(height: 20),
                        _stagger(5, _premiumCard(context, settings)),
                        const SizedBox(height: 20),
                        _stagger(6, _aboutCard(context)),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            '© 2026 SMART SAVE',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF7F8BA0)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _appBar(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: _goHome,
              icon: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white.withValues(alpha: 0.80),
              ),
              iconSize: 24,
            ),
          ),
          Expanded(
            child: Text(
              _t('Settings', fr: 'Parametres'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: _aboutDialog,
              icon: Icon(
                Icons.info_outline_rounded,
                color: Colors.white.withValues(alpha: 0.70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard(BuildContext context, SettingsController settings) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF142A3F),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.skyBlue.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Center(child: AppLogo(size: 32, heroTag: null)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SMART SAVE',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _t('Expense Manager', fr: 'Gestionnaire des depenses'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFAAB4C3),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          settings.isPro
              ? const _ProPill(useGradient: true)
              : Text(
                  _t('Free Plan', fr: 'Plan gratuit'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFAAB4C3),
                    fontSize: 12,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _appearanceCard(BuildContext context, SettingsController settings) {
    return SettingsSectionCard(
      title: _t('Appearance', fr: 'Apparence'),
      children: <Widget>[
        SettingsRow(
          icon: Icons.dark_mode_rounded,
          title: _t('Theme', fr: 'Theme'),
          subtitle: _t('System / Light / Dark', fr: 'Systeme / Clair / Sombre'),
          rowHeight: 64,
          maxTrailingWidth: 230,
          trailing: ThemeSelectorSegmented(
            mode: settings.themeMode,
            onChanged: settings.setThemeMode,
          ),
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.palette_outlined,
          title: _t('Accent', fr: 'Accent'),
          subtitle: _t(
            'Blue / Emerald / Amber / Coral',
            fr: 'Bleu / Emeraude / Ambre / Corail',
          ),
          trailing: _valueChevron(_t(settings.accentPreset.label)),
          onTap: () => _openAccentPresetPicker(settings),
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.gradient_rounded,
          title: _t('Background', fr: 'Arriere-plan'),
          subtitle: _t(
            'Classic / Aurora / Contrast',
            fr: 'Classique / Aurore / Contraste',
          ),
          trailing: _valueChevron(_t(settings.backgroundStyle.label)),
          onTap: () => _openBackgroundStylePicker(settings),
        ),
      ],
    );
  }

  Widget _preferencesCard(BuildContext context, SettingsController settings) {
    final String reminders = _remindersEnabled
        ? _ta('Daily reminder at {time}', <String, String>{
            'time': _formatTime(context, _reminderTime),
          }, fr: 'Rappel quotidien a {time}')
        : _t('Reminders are disabled', fr: 'Les rappels sont desactives');

    return SettingsSectionCard(
      title: _t('Preferences', fr: 'Preferences'),
      children: <Widget>[
        SettingsRow(
          icon: Icons.paid_rounded,
          title: _t('Currency', fr: 'Devise'),
          subtitle: 'MAD / USD / EUR',
          trailing: _valueChevron(settings.currencyCode),
          onTap: () => _openCurrencyPicker(settings),
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.language_rounded,
          title: _t('App Language', fr: 'Langue de l application'),
          subtitle: _t(
            'Choose the language used across the app',
            fr: 'Choisissez la langue utilisee dans toute l application',
          ),
          trailing: _valueChevron(
            context.l10n.languageLabel(settings.localeCode),
          ),
          onTap: () => _openLanguagePicker(settings),
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.calendar_today_rounded,
          title: _t('Week start', fr: 'Debut de semaine'),
          subtitle: _t('Monday / Sunday', fr: 'Lundi / Dimanche'),
          trailing: _valueChevron(
            _weekStart == 'Monday'
                ? _t('Monday', fr: 'Lundi')
                : _t('Sunday', fr: 'Dimanche'),
          ),
          onTap: _openWeekStartPicker,
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.notifications_rounded,
          title: _t('Reminders', fr: 'Rappels'),
          subtitle: reminders,
          trailing: Switch.adaptive(
            value: _remindersEnabled,
            onChanged: (bool value) async {
              if (value) {
                await _pickReminderTime();
              }
              if (!mounted) return;
              setState(() => _remindersEnabled = value);
            },
          ),
          onTap: _pickReminderTime,
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.flash_on_rounded,
          title: _t('Quick Add', fr: 'Ajout rapide'),
          subtitle: _t(
            'Show quick add on Home',
            fr: 'Afficher ajout rapide sur Accueil',
          ),
          trailing: Switch.adaptive(
            value: _quickAddEnabled,
            onChanged: (bool value) => setState(() => _quickAddEnabled = value),
          ),
          onTap: () => setState(() => _quickAddEnabled = !_quickAddEnabled),
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.account_balance_wallet_rounded,
          title: _t('Wallets & Categories', fr: 'Portefeuilles et categories'),
          subtitle: _t(
            'Accounts, transfer, custom categories',
            fr: 'Comptes, transferts, categories personnalisees',
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFAAB4C3),
          ),
          onTap: _openWalletManager,
        ),
      ],
    );
  }

  Widget _securityCard(BuildContext context, SettingsController settings) {
    final bool isPro = settings.isPro;
    return SettingsSectionCard(
      title: _t('Security', fr: 'Securite'),
      children: <Widget>[
        SettingsRow(
          icon: Icons.lock_rounded,
          title: _t('App Lock', fr: 'Verrou application'),
          subtitle: _t('PIN or Fingerprint', fr: 'PIN ou empreinte'),
          trailing: isPro
              ? const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFAAB4C3),
                )
              : _lockedTrailing(false),
          onTap: () {
            if (!isPro) {
              _proGateSheet();
              return;
            }
            _snack(_t('App Lock setup placeholder.'));
          },
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.fingerprint_rounded,
          title: _t('Fingerprint', fr: 'Empreinte'),
          subtitle: _t('Unlock with biometric', fr: 'Debloquer avec biometrie'),
          dimmed: !isPro,
          trailing: isPro
              ? Switch.adaptive(
                  value: _fingerprintEnabled,
                  onChanged: (bool value) {
                    setState(() => _fingerprintEnabled = value);
                  },
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const <Widget>[
                    _ProPill(),
                    SizedBox(width: 6),
                    Switch.adaptive(value: false, onChanged: null),
                  ],
                ),
          maxTrailingWidth: isPro ? 84 : 170,
          onTap: () {
            if (!isPro) {
              _proGateSheet();
            }
          },
        ),
      ],
    );
  }

  Widget _dataCard(BuildContext context, SettingsController settings) {
    final bool canUseExport = settings.isPro || _allowExportWithoutPro;

    return SettingsSectionCard(
      title: _t('Data', fr: 'Donnees'),
      children: <Widget>[
        SettingsRow(
          icon: Icons.picture_as_pdf_rounded,
          title: _t('Export to PDF', fr: 'Exporter en PDF'),
          subtitle: _t(
            'Share your transactions',
            fr: 'Partager vos transactions',
          ),
          trailing: _lockedTrailing(canUseExport),
          onTap: _exportPdf,
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.table_chart_rounded,
          title: _t('Export to Excel', fr: 'Exporter vers Excel'),
          subtitle: _t('CSV / XLSX export', fr: 'Export CSV / XLSX'),
          trailing: _lockedTrailing(canUseExport),
          onTap: _exportExcel,
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.cloud_upload_rounded,
          title: _t('Backup', fr: 'Sauvegarde'),
          subtitle: _t(
            'Save and restore your data',
            fr: 'Sauvegarder et restaurer vos donnees',
          ),
          trailing: _lockedTrailing(settings.isPro),
          onTap: () => _withPro(settings, _backup),
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.settings_backup_restore_rounded,
          title: _t('Restore Backup', fr: 'Restaurer sauvegarde'),
          subtitle: _t(
            'Import backup JSON file',
            fr: 'Importer un fichier JSON de sauvegarde',
          ),
          trailing: _lockedTrailing(settings.isPro),
          onTap: () => _withPro(settings, _restoreBackup),
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.cloud_done_rounded,
          title: _t(
            'Export to Google Sheets',
            fr: 'Exporter vers Google Sheets',
          ),
          subtitle: _t(
            'Direct spreadsheet export',
            fr: 'Export direct vers feuille',
          ),
          trailing: _lockedTrailing(settings.isPro),
          onTap: () => _withPro(settings, _exportGoogleSheets),
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.delete_forever_rounded,
          title: _t('Reset all data', fr: 'Reinitialiser toutes les donnees'),
          subtitle: _t(
            'Clear all transactions',
            fr: 'Effacer toutes les transactions',
          ),
          destructive: true,
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFAAB4C3),
          ),
          onTap: _resetAllData,
        ),
      ],
    );
  }

  Widget _premiumCard(BuildContext context, SettingsController settings) {
    return Column(
      children: <Widget>[
        if (!settings.isPro) ...<Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(22),
            splashColor: Colors.white.withValues(alpha: 0.06),
            onTap: _openProPage,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 88),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF0D47A1), Color(0xFF1565C0)],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _t('Upgrade to Pro', fr: 'Passer a Pro'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          _t(
                            'Export - Backup - Pro tools',
                            fr: 'Export - Sauvegarde - Outils Pro',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    child: Text(
                      _t('Unlock', fr: 'Debloquer'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        SettingsSectionCard(
          title: _t('Billing', fr: 'Facturation'),
          children: <Widget>[
            SettingsRow(
              icon: Icons.restore_rounded,
              title: _t('Restore Purchases', fr: 'Restaurer achats'),
              subtitle: _t(
                'Re-enable Pro on this device',
                fr: 'Reactiver Pro sur cet appareil',
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFAAB4C3),
              ),
              onTap: _restorePurchases,
            ),
          ],
        ),
      ],
    );
  }

  Widget _aboutCard(BuildContext context) {
    return SettingsSectionCard(
      title: _t('About & Legal', fr: 'A propos et legal'),
      children: <Widget>[
        SettingsRow(
          icon: Icons.star_rate_rounded,
          title: _t('Rate us', fr: 'Notez-nous'),
          subtitle: _t('Support the app', fr: 'Soutenez l application'),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFAAB4C3),
          ),
          onTap: () => _snack(_t('Play Store link placeholder.')),
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.policy_rounded,
          title: _t('Privacy Policy', fr: 'Politique de confidentialite'),
          subtitle: _t('Read our policy', fr: 'Lire notre politique'),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFAAB4C3),
          ),
          onTap: _privacyDialog,
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.description_outlined,
          title: _t('Terms of use', fr: 'Conditions d utilisation'),
          subtitle: _t('User terms', fr: 'Conditions utilisateur'),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFAAB4C3),
          ),
          onTap: _termsDialog,
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.warning_amber_rounded,
          title: _t('Maintenance notice', fr: 'Avis de maintenance'),
          subtitle: _t(
            'Status since November 5, 2024',
            fr: 'Statut depuis le 5 novembre 2024',
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFFAAB4C3),
          ),
          onTap: _maintenanceNoticeDialog,
          showDivider: true,
        ),
        SettingsRow(
          icon: Icons.info_outline_rounded,
          title: _t('Version'),
          subtitle: '1.0.0',
        ),
      ],
    );
  }

  Widget _stagger(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _animateIn ? 1 : 0),
      duration: Duration(milliseconds: 250 + (index * 80)),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (BuildContext context, double value, Widget? builtChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: builtChild,
          ),
        );
      },
    );
  }

  Widget _lockedTrailing(bool isPro) {
    if (isPro) {
      return const Icon(Icons.chevron_right_rounded, color: Color(0xFFAAB4C3));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const <Widget>[
        _ProPill(),
        SizedBox(width: 6),
        Icon(Icons.chevron_right_rounded, color: Color(0xFFAAB4C3)),
      ],
    );
  }

  Widget _valueChevron(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFFAAB4C3),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFFAAB4C3)),
      ],
    );
  }

  Future<void> _openCurrencyPicker(SettingsController settings) async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _BottomSheetCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: CurrencyUtils.supportedCurrencies
              .map(
                (String code) => ListTile(
                  title: Text(code),
                  trailing: settings.currencyCode == code
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.skyBlue,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(code),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
    if (selected != null) await settings.setCurrencyCode(selected);
  }

  Future<void> _openLanguagePicker(SettingsController settings) async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _BottomSheetCard(
        child: SizedBox(
          height: 420,
          child: ListView(
            children: AppLocalizations.languageOptions()
                .map(
                  (AppLanguageOption option) => ListTile(
                    title: Text(option.label),
                    trailing: settings.localeCode == option.code
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.skyBlue,
                          )
                        : null,
                    onTap: () => Navigator.of(ctx).pop(option.code),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
    if (selected != null) {
      await settings.setLocaleCode(selected);
    }
  }

  Future<void> _openAccentPresetPicker(SettingsController settings) async {
    final AccentPreset? selected = await showModalBottomSheet<AccentPreset>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _BottomSheetCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AccentPreset.values
              .map(
                (AccentPreset preset) => ListTile(
                  title: Text(_t(preset.label)),
                  trailing: settings.accentPreset == preset
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.skyBlue,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(preset),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
    if (selected != null) {
      await settings.setAccentPreset(selected);
    }
  }

  Future<void> _openBackgroundStylePicker(SettingsController settings) async {
    final BackgroundStyle? selected =
        await showModalBottomSheet<BackgroundStyle>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (BuildContext ctx) => _BottomSheetCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: BackgroundStyle.values
                  .map(
                    (BackgroundStyle style) => ListTile(
                      title: Text(_t(style.label)),
                      trailing: settings.backgroundStyle == style
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppColors.skyBlue,
                            )
                          : null,
                      onTap: () => Navigator.of(ctx).pop(style),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        );
    if (selected != null) {
      await settings.setBackgroundStyle(selected);
    }
  }

  Future<void> _maintenanceNoticeDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_t('Important Notice', fr: 'Avis important')),
          content: Text(
            _t(
              'This app is no longer maintained since November 5, 2024.\n\nYou can continue using it, but it will no longer receive updates or bug fixes. Some features may stop working over time.\n\nRecommendations:\n- Back up your data regularly.\n- Consider an actively maintained alternative.',
              fr: 'Cette application n est plus maintenue depuis le 5 novembre 2024.\n\nVous pouvez continuer a l utiliser, mais elle ne recevra plus de mises a jour ni de corrections de bugs. Certaines fonctions peuvent cesser de fonctionner avec le temps.\n\nRecommandations:\n- Sauvegardez regulierement vos donnees.\n- Envisagez une alternative activement maintenue.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_t('Close', fr: 'Fermer')),
            ),
          ],
        );
      },
    );
  }

  void _openWalletManager() {
    Navigator.of(context).push(AppRouter.slideFade(const WalletManagerPage()));
  }

  Future<void> _openWeekStartPicker() async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _BottomSheetCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(_t('Monday', fr: 'Lundi')),
              trailing: _weekStart == 'Monday'
                  ? const Icon(Icons.check_rounded, color: AppColors.skyBlue)
                  : null,
              onTap: () => Navigator.of(ctx).pop('Monday'),
            ),
            ListTile(
              title: Text(_t('Sunday', fr: 'Dimanche')),
              trailing: _weekStart == 'Sunday'
                  ? const Icon(Icons.check_rounded, color: AppColors.skyBlue)
                  : null,
              onTap: () => Navigator.of(ctx).pop('Sunday'),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _weekStart = selected);
  }

  Future<void> _pickReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _reminderTime = picked;
        _remindersEnabled = true;
      });
    }
  }

  Future<void> _withPro(
    SettingsController settings,
    Future<void> Function() handler,
  ) async {
    if (!settings.isPro) {
      _proGateSheet();
      return;
    }
    await handler();
  }

  Future<void> _exportPdf() async {
    try {
      final ExpenseController expenses = context.read<ExpenseController>();
      final SettingsController settings = context.read<SettingsController>();
      final ExportService exportService = context.read<ExportService>();
      final List<Expense>? filteredExpenses = await _pickReportExpenses(
        settings: settings,
        expenseController: expenses,
      );
      if (filteredExpenses == null) {
        return;
      }
      final ExportArtifact artifact = await exportService.generateExpensesPdf(
        filteredExpenses,
        settings.currencyCode,
      );
      await _shareArtifact(
        artifact,
        successMessage: _t('PDF exported successfully.'),
        fallbackMessage: _t('PDF generated successfully.'),
      );
    } catch (e) {
      _snack(
        _ta('PDF export failed: {error}', <String, String>{'error': '$e'}),
      );
    }
  }

  Future<void> _exportExcel() async {
    try {
      final ExpenseController expenses = context.read<ExpenseController>();
      final SettingsController settings = context.read<SettingsController>();
      final ExportService exportService = context.read<ExportService>();
      final List<Expense>? filteredExpenses = await _pickReportExpenses(
        settings: settings,
        expenseController: expenses,
      );
      if (filteredExpenses == null) {
        return;
      }
      final ExportArtifact artifact = await exportService.generateExpensesExcel(
        filteredExpenses,
        settings.currencyCode,
      );
      await _shareArtifact(
        artifact,
        successMessage: _t('Excel exported successfully.'),
        fallbackMessage: _t('Excel generated successfully.'),
      );
    } catch (e) {
      _snack(
        _ta('Excel export failed: {error}', <String, String>{'error': '$e'}),
      );
    }
  }

  Future<void> _backup() async {
    try {
      final ExpenseController expenses = context.read<ExpenseController>();
      final SettingsController settings = context.read<SettingsController>();
      final ExportArtifact artifact = await context
          .read<ExportService>()
          .generateBackupJson(
            expenses.expensesForAccount(settings.activeBankAccountId),
          );
      await _shareArtifact(
        artifact,
        successMessage: _t('Backup created successfully.'),
        fallbackMessage: _t('Backup generated successfully.'),
      );
    } catch (e) {
      _snack(_ta('Backup failed: {error}', <String, String>{'error': '$e'}));
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final FilePickerResult? picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return;
      }
      if (!mounted) {
        return;
      }

      final Uint8List? bytes = picked.files.single.bytes;
      if (bytes == null || bytes.isEmpty) {
        _snack(_t('Could not read backup file.'));
        return;
      }

      final SettingsController settings = context.read<SettingsController>();
      final List<Expense> restored = context
          .read<ExportService>()
          .parseBackupJson(
            bytes: bytes,
            fallbackCurrency: settings.currencyCode,
          );
      final ExpenseController expenses = context.read<ExpenseController>();
      final int merged = await expenses.addExpensesBulk(restored);
      if (!mounted) {
        return;
      }
      _snack(
        _ta('Backup restored. {count} transaction(s) merged.', <String, String>{
          'count': '$merged',
        }),
      );
    } catch (error) {
      _snack(
        _ta('Restore failed: {error}', <String, String>{'error': '$error'}),
      );
    }
  }

  Future<void> _exportGoogleSheets() async {
    try {
      final GoogleSheetsService sheets = context.read<GoogleSheetsService>();
      final SettingsController settings = context.read<SettingsController>();
      final ExpenseController expenseController = context
          .read<ExpenseController>();
      final List<Expense>? filteredExpenses = await _pickReportExpenses(
        settings: settings,
        expenseController: expenseController,
      );
      if (filteredExpenses == null) {
        return;
      }

      final String url = await sheets.exportExpenses(filteredExpenses);
      if (!mounted) {
        return;
      }
      _snack(
        _ta('Google Sheets export complete: {url}', <String, String>{
          'url': url,
        }),
      );
    } catch (error) {
      _snack(
        _ta('Google Sheets export failed: {error}', <String, String>{
          'error': '$error',
        }),
      );
    }
  }

  Future<List<Expense>?> _pickReportExpenses({
    required SettingsController settings,
    required ExpenseController expenseController,
  }) async {
    final ExpenseAdvancedFilter initial =
        _reportFilter.accountId == null || _reportFilter.accountId!.isEmpty
        ? _reportFilter.copyWith(accountId: settings.activeBankAccountId)
        : _reportFilter;

    final ExpenseAdvancedFilter? selected =
        await showModalBottomSheet<ExpenseAdvancedFilter>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext sheetContext) {
            return ExpenseFilterBottomSheet(
              initialFilter: initial,
              accounts: settings.bankAccounts,
              customCategories: settings.customCategories,
              localeCode: settings.localeCode,
            );
          },
        );
    if (selected == null) {
      return null;
    }
    if (!mounted) {
      return null;
    }
    setState(() => _reportFilter = selected);

    final List<Expense> source = expenseController.expenses.toList();
    return applyExpenseAdvancedFilter(source, selected);
  }

  Future<void> _shareArtifact(
    ExportArtifact artifact, {
    required String successMessage,
    required String fallbackMessage,
  }) async {
    if (!mounted) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile.fromData(
              artifact.bytes,
              mimeType: artifact.mimeType,
              name: artifact.fileName,
            ),
          ],
          fileNameOverrides: <String>[artifact.fileName],
          downloadFallbackEnabled: true,
        ),
      );
      if (!mounted) return;
      _snack(successMessage);
    } catch (_) {
      if (!mounted) return;
      _snack('$fallbackMessage (${artifact.fileName})');
    }
  }

  Future<void> _resetAllData() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dctx) => AlertDialog(
        title: Text(
          _t('Reset all data', fr: 'Reinitialiser toutes les donnees'),
        ),
        content: Text(
          _t(
            'This will permanently delete all transactions. Continue?',
            fr: 'Cela supprimera definitivement toutes les transactions. Continuer ?',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text(_t('Cancel', fr: 'Annuler')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text(_t('Reset', fr: 'Reinitialiser')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    final ExpenseController expenses = context.read<ExpenseController>();
    final List<String> ids = expenses.expenses.map((e) => e.id).toList();
    for (final String id in ids) {
      await expenses.deleteExpense(id);
    }
    if (!mounted) return;
    _snack(_t('All data reset completed.'));
  }

  Future<void> _proGateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _BottomSheetCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppColors.skyBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t('Upgrade to Pro', fr: 'Passer a Pro'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _t(
                'Unlock App Lock, Fingerprint, Export and Backup features.',
                fr: 'Debloquez App Lock, empreinte, export et sauvegarde.',
              ),
              style: TextStyle(color: Color(0xFFAAB4C3)),
            ),
            const SizedBox(height: 12),
            _FeatureLine(
              _t(
                'Unlimited bank accounts (more than 2 wallets)',
                fr: 'Comptes bancaires illimites (plus de 2 portefeuilles)',
              ),
            ),
            _FeatureLine(
              _t('Export to PDF / Excel', fr: 'Exporter en PDF / Excel'),
            ),
            _FeatureLine(
              _t('Backup and restore', fr: 'Sauvegarder et restaurer'),
            ),
            _FeatureLine(_t('Security lock', fr: 'Verrou securite')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openProPage();
                },
                child: Text(_t('Go to Pro Page', fr: 'Aller a la page Pro')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restorePurchases() async {
    final PurchaseController? purchase = context.read<PurchaseController?>();
    if (purchase == null) {
      _snack(_t('Billing is unavailable in this build.'));
      return;
    }
    await purchase.restorePurchases();
    if (!mounted) return;
    final String? message = purchase.errorMessage;
    _snack(
      (message == null || message.isEmpty)
          ? _t('Restore request sent. Purchases will sync shortly.')
          : message,
    );
  }

  void _openProPage() {
    Navigator.of(context).push(AppRouter.slideFade(const ProPage()));
  }

  void _privacyDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dctx) => AlertDialog(
        title: Text(_t('Privacy Policy', fr: 'Politique de confidentialite')),
        content: Text(_t('Privacy policy URL placeholder handler.')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text(_t('Close', fr: 'Fermer')),
          ),
        ],
      ),
    );
  }

  void _termsDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dctx) => AlertDialog(
        title: Text(_t('Terms of use', fr: 'Conditions d utilisation')),
        content: Text(_t('Terms URL placeholder handler.')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text(_t('Close', fr: 'Fermer')),
          ),
        ],
      ),
    );
  }

  void _aboutDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dctx) => AlertDialog(
        title: Text(_t('About SMART SAVE')),
        content: Text(_t('Premium expense manager.\nVersion 1.0.0')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text(_t('Close', fr: 'Fermer')),
          ),
        ],
      ),
    );
  }

  void _goHome() {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.read<ShellNavigationController>().goHome();
  }

  String _formatTime(BuildContext context, TimeOfDay time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: const Color(0xFF13293D),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13293D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
    this.trailing,
    this.onTap,
    this.showDivider = false,
    this.destructive = false,
    this.dimmed = false,
    this.maxTrailingWidth = 148,
    this.rowHeight = 62,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool destructive;
  final bool dimmed;
  final double maxTrailingWidth;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final Color titleColor = destructive
        ? const Color(0xFFFF5252)
        : Colors.white;
    final Color iconColor = destructive
        ? const Color(0xFFFF5252)
        : const Color(0xFF42A5F5);

    return Opacity(
      opacity: dimmed ? 0.65 : 1,
      child: Column(
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              splashColor: Colors.white.withValues(alpha: 0.03),
              highlightColor: Colors.transparent,
              child: SizedBox(
                height: rowHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: <Widget>[
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF142A3F),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: iconColor, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: titleColor,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFFAAB4C3),
                                      fontSize: 12.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (trailing != null)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxTrailingWidth.clamp(
                                0,
                                constraints.maxWidth * 0.45,
                              ),
                            ),
                            child: trailing!,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.only(left: 72, right: 16),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
        ],
      ),
    );
  }
}

class ThemeSelectorSegmented extends StatelessWidget {
  const ThemeSelectorSegmented({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF142A3F),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          _item(
            context.l10n.phrase('System', french: 'Systeme'),
            mode == ThemeMode.system,
            () => onChanged(ThemeMode.system),
          ),
          _item(
            context.l10n.phrase('Light', french: 'Clair'),
            mode == ThemeMode.light,
            () => onChanged(ThemeMode.light),
          ),
          _item(
            context.l10n.phrase('Dark', french: 'Sombre'),
            mode == ThemeMode.dark,
            () => onChanged(ThemeMode.dark),
          ),
        ],
      ),
    );
  }

  Widget _item(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected
                ? const LinearGradient(
                    colors: <Color>[Color(0xFF0D47A1), Color(0xFF1565C0)],
                  )
                : null,
            color: selected ? null : const Color(0xFF142A3F),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFFAAB4C3),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProPill extends StatelessWidget {
  const _ProPill({this.useGradient = false});

  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: useGradient
            ? const LinearGradient(
                colors: <Color>[Color(0xFF0D47A1), Color(0xFF1565C0)],
              )
            : null,
        color: useGradient
            ? null
            : const Color(0xFF0D47A1).withValues(alpha: 0.25),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BottomSheetCard extends StatelessWidget {
  const _BottomSheetCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF13293D),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.incomeGreen,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
