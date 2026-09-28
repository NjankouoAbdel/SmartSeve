import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';
import 'package:wfer_flousk_firebase/core/constants/ui_tokens.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/models/ocr_scan_result.dart';
import 'package:wfer_flousk_firebase/core/utils/currency_utils.dart';
import 'package:wfer_flousk_firebase/core/utils/date_utils.dart';
import 'package:wfer_flousk_firebase/core/utils/icon_utils.dart';
import 'package:wfer_flousk_firebase/core/widgets/animated_primary_button.dart';
import 'package:wfer_flousk_firebase/core/widgets/fintech_page_app_bar.dart';
import 'package:wfer_flousk_firebase/core/widgets/glass_card.dart';
import 'package:wfer_flousk_firebase/core/widgets/gradient_background.dart';
import 'package:wfer_flousk_firebase/core/widgets/responsive_page_body.dart';
import 'package:wfer_flousk_firebase/domain/entities/custom_category.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';
import 'package:wfer_flousk_firebase/presentation/widgets/statement_review_dialog.dart';

/// Les 3 facons d'ajouter une transaction, presentees comme des options
/// paralleles et explicites plutot que cachees les unes derriere les autres:
/// saisie manuelle (le formulaire habituel), scan d'un reçu (photo -> OCR ->
/// formulaire pre-rempli), ou import d'un releve bancaire PDF (plusieurs
/// transactions ajoutees en bloc apres verification).
enum _AddExpenseMode { manual, scan, pdf }

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({
    required this.isStandalone,
    super.key,
    this.onSaved,
    this.initialExpense,
  });

  final bool isStandalone;
  final VoidCallback? onSaved;
  final Expense? initialExpense;

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final Uuid _uuid = const Uuid();

  ExpenseCategory _selectedCategory = ExpenseCategory.food;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  bool _savedSuccess = false;
  bool _busyScan = false;
  _AddExpenseMode _mode = _AddExpenseMode.manual;

  /// En mode Scanner, le formulaire (montant/date/note) ne sert qu'a
  /// verifier ce que l'OCR a detecte — il n'a donc aucune raison de
  /// s'afficher tant qu'aucun scan n'a ete fait (l'utilisateur verrait
  /// sinon un montant a 0 et la date du jour par defaut, avant meme
  /// d'avoir scanne quoi que ce soit). Reste a `false` tant qu'aucun scan
  /// n'a reussi; repasse a `false` des qu'on change de mode pour repartir
  /// propre.
  bool _scanResultReady = false;
  String? _selectedCustomCategoryId;
  String? _selectedCustomCategoryName;
  int? _selectedCustomCategoryIconCodePoint;
  int? _selectedCustomCategoryColorValue;

  bool get _isEditing => widget.initialExpense != null;

  String _t(String english, {String? fr}) {
    return context.l10n.phrase(english, french: fr);
  }

  @override
  void initState() {
    super.initState();
    final Expense? initial = widget.initialExpense;
    if (initial == null) {
      return;
    }
    _amountController.text = initial.amount.toStringAsFixed(2);
    _noteController.text = initial.note;
    _selectedCategory = initial.category;
    _selectedDate = initial.date;
    _selectedCustomCategoryId = initial.customCategoryId;
    _selectedCustomCategoryName = initial.customCategoryName;
    _selectedCustomCategoryIconCodePoint = initial.customCategoryIconCodePoint;
    _selectedCustomCategoryColorValue = initial.customCategoryColorValue;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 4),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveExpense() async {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final double amount = _resolveAmountInput(_amountController.text) ?? 0;

    if (amount <= 0) {
      _snack(
        _t(
          'Please enter a valid amount.',
          fr: 'Veuillez entrer un montant valide.',
        ),
      );
      return;
    }
    _amountController.text = amount.toStringAsFixed(2);

    final SettingsController settings = context.read<SettingsController>();
    final ExpenseController expenseController = context
        .read<ExpenseController>();
    final ToolsController toolsController = context.read<ToolsController>();

    String note = _noteController.text.trim();
    final bool hasCustomCategory =
        _selectedCustomCategoryId != null &&
        (_selectedCustomCategoryName ?? '').trim().isNotEmpty;

    if (!hasCustomCategory &&
        _selectedCategory == ExpenseCategory.other &&
        note.isEmpty) {
      final String? customOther = await _promptOtherCategoryName();
      if (!mounted) return;
      if (customOther == null || customOther.trim().isEmpty) {
        return;
      }
      note = customOther.trim();
      _noteController.text = note;
    }

    if (hasCustomCategory && note.isEmpty) {
      note = _selectedCustomCategoryName!.trim();
      _noteController.text = note;
    }

    setState(() {
      _isSaving = true;
      _savedSuccess = false;
    });

    final Expense expense = Expense(
      id: widget.initialExpense?.id ?? _uuid.v4(),
      amount: amount,
      category: _selectedCategory,
      date: _selectedDate,
      note: note,
      currencyCode: settings.currencyCode,
      accountId:
          widget.initialExpense?.accountId ?? settings.activeBankAccountId,
      customCategoryId: hasCustomCategory ? _selectedCustomCategoryId : null,
      customCategoryName: hasCustomCategory
          ? _selectedCustomCategoryName
          : null,
      customCategoryIconCodePoint: hasCustomCategory
          ? _selectedCustomCategoryIconCodePoint
          : null,
      customCategoryColorValue: hasCustomCategory
          ? _selectedCustomCategoryColorValue
          : null,
      isTransfer: widget.initialExpense?.isTransfer ?? false,
      transferGroupId: widget.initialExpense?.transferGroupId,
    );

    try {
      if (_isEditing) {
        await expenseController.updateExpense(expense);
      } else {
        await expenseController.addExpense(expense);
      }

      unawaited(
        _runPostSaveChecks(
          toolsController: toolsController,
          expenseController: expenseController,
          settings: settings,
        ),
      );

      if (!mounted) {
        return;
      }

      if (widget.isStandalone) {
        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        _savedSuccess = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) {
        return;
      }

      _snack(
        _isEditing
            ? _t(
                'Expense updated successfully.',
                fr: 'Depense mise a jour avec succes.',
              )
            : _t(
                'Expense saved successfully.',
                fr: 'Depense enregistree avec succes.',
              ),
      );

      widget.onSaved?.call();

      _formKey.currentState?.reset();
      _amountController.clear();
      _noteController.clear();
      setState(() {
        _selectedCategory = ExpenseCategory.food;
        _selectedDate = DateTime.now();
        _savedSuccess = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _snack(_saveErrorMessage(error));
      setState(() {
        _savedSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _saveErrorMessage(Object error) {
    final String raw = error.toString();
    final String message = raw.toLowerCase();
    if (message.contains('permission-denied') ||
        message.contains('insufficient permissions')) {
      return _t(
        'Cloud write denied. Check Auth, Firestore rules, and App Check enforcement, then retry.',
        fr: 'Ecriture cloud refusee. Verifiez Auth, regles Firestore et App Check, puis reessayez.',
      );
    }
    if (message.contains('operation-not-allowed')) {
      return _t(
        'Anonymous sign-in is disabled in Firebase Auth.',
        fr: 'La connexion anonyme est desactivee dans Firebase Auth.',
      );
    }
    if (message.contains('network')) {
      return _t(
        'Network error while saving. Check connection and retry.',
        fr: 'Erreur reseau pendant la sauvegarde. Verifiez la connexion et reessayez.',
      );
    }
    return _t('Save failed: ', fr: 'Echec de sauvegarde : ') + raw;
  }

  @override
  Widget build(BuildContext context) {
    final String currencyCode = context.select<SettingsController, String>(
      (SettingsController settings) => settings.currencyCode,
    );
    final List<CustomCategory> customCategories = context
        .select<SettingsController, List<CustomCategory>>(
          (SettingsController settings) => settings.customCategories,
        );
    final String activeAccountId = context.select<SettingsController, String>(
      (SettingsController settings) => settings.activeBankAccountId,
    );
    final ExpenseController expenses = context.watch<ExpenseController>();

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ResponsivePageBody(
            top: 8,
            bottom: 8,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  FintechPageAppBar(
                    title: _isEditing
                        ? _t('Edit Expense', fr: 'Modifier depense')
                        : _t('Add Expense', fr: 'Ajouter depense'),
                    showBackToHome: true,
                  ),
                  const SizedBox(height: UiTokens.spacingMd),
                  _modeSelector(context),
                  const SizedBox(height: UiTokens.spacingMd),
                  if (_mode == _AddExpenseMode.pdf)
                    _pdfPanel(context)
                  else if (_mode == _AddExpenseMode.scan) ...<Widget>[
                    // Tant qu'aucun reçu n'a ete scanne avec succes, on
                    // n'affiche QUE le bouton de scan: pas de formulaire
                    // vide (montant/date/note) qui n'aurait rien a
                    // verifier. Le formulaire n'apparait qu'une fois
                    // qu'il y a vraiment quelque chose a confirmer.
                    _scanPanel(context),
                    if (_scanResultReady) ...<Widget>[
                      const SizedBox(height: UiTokens.spacingMd),
                      _mainCard(
                        context,
                        currencyCode,
                        expenses,
                        activeAccountId,
                        customCategories,
                        hideCategoryPicker: true,
                      ),
                    ],
                  ] else
                    _mainCard(
                      context,
                      currencyCode,
                      expenses,
                      activeAccountId,
                      customCategories,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Selecteur des 3 facons d'ajouter une transaction, presentees comme des
  /// options paralleles et explicites (voir [_AddExpenseMode]): l'utilisateur
  /// choisit d'abord COMMENT il veut ajouter, puis l'ecran en dessous change
  /// en consequence.
  Widget _modeSelector(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _modeChip(
            context,
            _AddExpenseMode.manual,
            _t('Manual', fr: 'Manuel'),
            Icons.edit_note_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _modeChip(
            context,
            _AddExpenseMode.scan,
            _t('Scan', fr: 'Scanner'),
            Icons.document_scanner_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _modeChip(
            context,
            _AddExpenseMode.pdf,
            _t('PDF', fr: 'PDF'),
            Icons.picture_as_pdf_outlined,
          ),
        ),
      ],
    );
  }

  Widget _modeChip(
    BuildContext context,
    _AddExpenseMode mode,
    String label,
    IconData icon,
  ) {
    final bool selected = _mode == mode;
    return InkWell(
      onTap: () => setState(() {
        _mode = mode;
        // On repart propre a chaque changement d'onglet: si on quitte le
        // mode Scanner puis qu'on y revient, le formulaire de
        // confirmation doit rester cache tant qu'un nouveau scan n'a pas
        // ete fait (voir _scanResultReady).
        _scanResultReady = false;
      }),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: selected
              ? const LinearGradient(
                  colors: <Color>[
                    AppColors.primaryBlue,
                    AppColors.gradientBlue2,
                  ],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.85),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.deepBlue.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppColors.primaryBlue,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.deepBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Panneau affiche en mode "Scanner": l'utilisateur prend/choisit une
  /// photo de reçu, qui pre-remplit le formulaire habituel affiche juste en
  /// dessous (voir [_scanSingleReceipt]) pour qu'il puisse verifier/corriger
  /// avant d'enregistrer.
  Widget _scanPanel(BuildContext context) {
    return GlassCard(
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.document_scanner_outlined,
                size: 18,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('Scan a receipt', fr: 'Scanner un reçu'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _scanResultReady
                ? _t(
                    'Amount, date and note were prefilled below from your '
                    'receipt — check them before saving, or scan another '
                    'receipt.',
                    fr:
                        'Le montant, la date et la note ci-dessous ont ete '
                        'preremplis a partir de votre reçu — verifiez-les '
                        'avant d\'enregistrer, ou scannez un autre reçu.',
                  )
                : _t(
                    'Take or choose a photo of a receipt. The amount, date '
                    'and note will be detected automatically so you can '
                    'review them before saving.',
                    fr:
                        'Prenez ou choisissez une photo de reçu. Le '
                        'montant, la date et la note seront detectes '
                        'automatiquement afin que vous puissiez les '
                        'verifier avant d\'enregistrer.',
                  ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busyScan
                  ? null
                  : () => _scanSingleReceipt(context),
              icon: _busyScan
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _scanResultReady
                          ? Icons.refresh_rounded
                          : Icons.camera_alt_outlined,
                    ),
              label: Text(
                _busyScan
                    ? _t('Analyzing…', fr: 'Analyse en cours…')
                    : _scanResultReady
                    ? _t('Scan Another Receipt', fr: 'Scanner un autre reçu')
                    : _t('Scan Receipt', fr: 'Scanner un reçu'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Panneau affiche en mode "PDF": contrairement au scan (qui pre-remplit LE
  /// formulaire pour UNE transaction), un releve PDF contient generalement
  /// PLUSIEURS transactions — le formulaire habituel ne s'applique donc pas
  /// ici. Cette action ouvre directement le fichier puis la fenetre de
  /// verification/import group (voir [_importPdfStatement]).
  Widget _pdfPanel(BuildContext context) {
    return GlassCard(
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.picture_as_pdf_outlined,
                size: 18,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('Import a PDF statement', fr: 'Importer un relevé PDF'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              'Choose a PDF bank statement. Every detected transaction can '
              'be reviewed and corrected before being added in bulk.',
              fr:
                  'Choisissez un relevé bancaire au format PDF. Chaque '
                  'transaction détectée peut être vérifiée et corrigée '
                  'avant d\'être ajoutée en bloc.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busyScan
                  ? null
                  : () => _importPdfStatement(context),
              icon: _busyScan
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open_outlined),
              label: Text(
                _busyScan
                    ? _t(
                        'Reading PDF and detecting transactions…',
                        fr: 'Lecture du PDF et détection des transactions…',
                      )
                    : _t('Choose PDF File', fr: 'Choisir un fichier PDF'),
              ),
            ),
          ),
          if (_busyScan) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t(
                      'This can take a few seconds for a multi-page '
                      'statement, please wait…',
                      fr:
                          'Cela peut prendre quelques secondes pour un '
                          'relevé de plusieurs pages, veuillez patienter…',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<ImageSource?> _pickImageSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(_t('Camera', fr: 'Caméra')),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(_t('Gallery', fr: 'Galerie')),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Scanne UNE photo de reçu et pre-remplit le formulaire courant (montant,
  /// date, note) au lieu d'ajouter directement une depense: on est deja sur
  /// l'ecran d'ajout, l'utilisateur garde la main pour corriger la categorie
  /// avant d'enregistrer avec le bouton habituel.
  Future<void> _scanSingleReceipt(BuildContext context) async {
    final ImageSource? source = await _pickImageSource(context);
    if (source == null || !mounted) {
      return;
    }

    final ToolsController tools = context.read<ToolsController>();
    setState(() => _busyScan = true);
    final OcrScanResult? result = await tools.scanReceipt(source);
    if (mounted) {
      setState(() => _busyScan = false);
    }
    if (!mounted) {
      return;
    }

    if (result == null) {
      _snack(
        tools.lastOcrError ??
            _t(
              'Scan failed or canceled.',
              fr: 'Scan échoué ou annulé.',
            ),
      );
      return;
    }

    setState(() {
      final double? amount = result.amount;
      if (amount != null && amount > 0) {
        _amountController.text = amount.toStringAsFixed(2);
      }
      final DateTime? date = result.date;
      if (date != null) {
        _selectedDate = date;
      }
      if (_noteController.text.trim().isEmpty) {
        _noteController.text = result.suggestedNote;
      }
      // Categorie devinee automatiquement par l'OCR/IA a partir du texte du
      // reçu — aucune categorie n'est proposee a l'utilisateur en mode
      // Scanner, donc on l'applique directement (et on efface une eventuelle
      // categorie personnalisee choisie precedemment en mode Manuel).
      _selectedCategory = result.suggestedCategory;
      _selectedCustomCategoryId = null;
      _selectedCustomCategoryName = null;
      _selectedCustomCategoryIconCodePoint = null;
      _selectedCustomCategoryColorValue = null;
      // Maintenant qu'on a un resultat, le formulaire de confirmation
      // (montant/date/note) peut enfin s'afficher — voir _scanResultReady.
      _scanResultReady = true;
    });

    _snack(
      _t(
        'Receipt scanned. Check the amount before saving.',
        fr: 'Reçu scanné. Vérifiez le montant avant d\'enregistrer.',
      ),
    );
  }

  /// Importe un PDF de relevé bancaire (plusieurs transactions) directement
  /// depuis l'ecran d'ajout: contrairement au scan simple, ceci ajoute les
  /// transactions cochees en bloc (via le meme ecran de revue que le Centre
  /// Outils) plutot que de remplir ce formulaire, qui ne represente qu'une
  /// seule transaction a la fois.
  Future<void> _importPdfStatement(BuildContext context) async {
    final ToolsController tools = context.read<ToolsController>();
    final ExpenseController expenseController = context
        .read<ExpenseController>();
    final SettingsController settings = context.read<SettingsController>();

    setState(() => _busyScan = true);
    final BankStatementScanResult? result = await tools
        .scanBankStatementFromPdf();
    if (mounted) {
      setState(() => _busyScan = false);
    }
    if (!mounted) {
      return;
    }

    if (result == null) {
      final String errorMessage =
          tools.lastStatementScanError ??
          _t(
            'Statement scan failed or canceled.',
            fr: 'Scan du relevé échoué ou annulé.',
          );
      // TEMPORAIRE (diagnostic) : une simple SnackBar disparait toute seule
      // apres quelques secondes, ce qui rend difficile d'en faire une bonne
      // capture d'ecran. On affiche donc ce message dans une fenetre qui
      // reste ouverte tant que l'utilisateur ne l'a pas fermee lui-meme, et
      // dont le texte peut etre selectionne/copie directement (plus fiable
      // qu'une capture d'ecran). A simplifier une fois le probleme du PDF
      // resolu.
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text(
              _t('Statement import failed', fr: 'Échec de l\'import du relevé'),
            ),
            content: SingleChildScrollView(
              child: SelectableText(errorMessage),
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
      return;
    }

    await showStatementReviewDialog(
      context: context,
      tools: tools,
      result: result,
      expenses: expenseController,
      settings: settings,
    );
  }

  Future<String?> _promptOtherCategoryName() async {
    String categoryName = _noteController.text.trim();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_t('Name this category', fr: 'Nommer cette categorie')),
          content: TextFormField(
            initialValue: categoryName,
            onChanged: (String value) {
              categoryName = value;
            },
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: _t(
                'Example: Gifts, Coffee, Pets...',
                fr: 'Exemple : Cadeaux, Cafe, Animaux...',
              ),
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_t('Cancel', fr: 'Annuler')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(categoryName.trim());
              },
              child: Text(_t('Save', fr: 'Enregistrer')),
            ),
          ],
        );
      },
    );
    return result;
  }

  Future<void> _onCategoryTap(ExpenseCategory category) async {
    if (category != ExpenseCategory.other) {
      setState(() {
        _selectedCategory = category;
        _selectedCustomCategoryId = null;
        _selectedCustomCategoryName = null;
        _selectedCustomCategoryIconCodePoint = null;
        _selectedCustomCategoryColorValue = null;
      });
      return;
    }

    final String? customOther = await _promptOtherCategoryName();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedCategory = ExpenseCategory.other;
      _selectedCustomCategoryId = null;
      _selectedCustomCategoryName = null;
      _selectedCustomCategoryIconCodePoint = null;
      _selectedCustomCategoryColorValue = null;
      if (customOther != null && customOther.trim().isNotEmpty) {
        _noteController.text = customOther.trim();
      }
    });
  }

  void _onCustomCategoryTap(CustomCategory customCategory) {
    setState(() {
      _selectedCategory = ExpenseCategory.other;
      _selectedCustomCategoryId = customCategory.id;
      _selectedCustomCategoryName = customCategory.name;
      _selectedCustomCategoryIconCodePoint = customCategory.iconCodePoint;
      _selectedCustomCategoryColorValue = customCategory.colorValue;
    });
  }

  Future<void> _runPostSaveChecks({
    required ToolsController toolsController,
    required ExpenseController expenseController,
    required SettingsController settings,
  }) async {
    await Future<void>.delayed(Duration.zero);
    await toolsController.evaluateBudgets(
      expenses: expenseController.expensesForAccount(
        settings.activeBankAccountId,
      ),
      currencyCode: settings.currencyCode,
    );
    await toolsController.evaluateSmartSavingPlan(
      totalIncomeForMonth:
          settings.monthlyIncome +
          expenseController.monthlyIncomeTransactionsForAccount(
            settings.activeBankAccountId,
          ),
      savingsGoal: settings.monthlySavingsGoal,
      spentForMonth: expenseController.monthlySpendingForAccount(
        settings.activeBankAccountId,
      ),
      currencyCode: settings.currencyCode,
    );
  }

  Widget _mainCard(
    BuildContext context,
    String currencyCode,
    ExpenseController expenses,
    String activeAccountId,
    List<CustomCategory> customCategories, {
    bool hideCategoryPicker = false,
  }) {
    return GlassCard(
      borderRadius: 22,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.92),
          Colors.white.withValues(alpha: 0.82),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: AppColors.deepBlue,
            displayColor: AppColors.deepBlue,
          ),
          iconTheme: const IconThemeData(color: AppColors.primaryBlue),
          inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
            fillColor: Colors.white,
            labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.deepBlue.withValues(alpha: 0.72),
            ),
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              _amountInput(context, currencyCode),
              const SizedBox(height: UiTokens.spacingMd),
              // En mode Scanner/PDF, la categorie est devinee automatiquement
              // par l'OCR/IA (voir OcrService._guessCategory) et n'est pas
              // proposee a l'utilisateur ici.
              if (!hideCategoryPicker) ...<Widget>[
                _categoryGrid(context, customCategories),
                const SizedBox(height: UiTokens.spacingMd),
              ],
              _dateField(context),
              const SizedBox(height: UiTokens.spacingSm),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: _t('Note', fr: 'Note'),
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: UiTokens.spacingMd),
              _todayPreview(context, expenses, currencyCode, activeAccountId),
              const SizedBox(height: UiTokens.spacingMd),
              AnimatedPrimaryButton(
                label: _isEditing
                    ? _t('Update Expense', fr: 'Mettre a jour depense')
                    : _t('Save Expense', fr: 'Enregistrer depense'),
                icon: Icons.check_rounded,
                isLoading: _isSaving,
                isSuccess: _savedSuccess,
                onPressed: _isSaving ? null : _saveExpense,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountInput(BuildContext context, String currencyCode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _amountController,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.deepBlue,
                fontWeight: FontWeight.w700,
                fontSize: 38,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '250.00',
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return _t('Amount required', fr: 'Montant requis');
                }
                return null;
              },
            ),
          ),
          IconButton(
            onPressed: _openCalculatorSheet,
            tooltip: _t('Calculator', fr: 'Calculatrice'),
            icon: const Icon(Icons.calculate_rounded),
          ),
          Text(
            currencyCode,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.deepBlue.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryGrid(
    BuildContext context,
    List<CustomCategory> customCategories,
  ) {
    final List<({ExpenseCategory category, CustomCategory? custom})> items =
        <({ExpenseCategory category, CustomCategory? custom})>[
          ...ExpenseCategory.values.map(
            (ExpenseCategory category) => (category: category, custom: null),
          ),
          ...customCategories.map(
            (CustomCategory customCategory) =>
                (category: ExpenseCategory.other, custom: customCategory),
          ),
        ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (BuildContext context, int index) {
        final ExpenseCategory category = items[index].category;
        final CustomCategory? custom = items[index].custom;
        final bool selected = custom != null
            ? _selectedCustomCategoryId == custom.id
            : _selectedCustomCategoryId == null &&
                  category == _selectedCategory;
        final IconData icon = custom != null
            ? AppIconUtils.fromCodePoint(
                custom.iconCodePoint,
                fallback: Icons.label_rounded,
              )
            : _iconForCategory(category);
        final String label = custom != null
            ? custom.name
            : category.localizedLabel(
                Localizations.localeOf(context).languageCode,
              );
        final Color idleColor = custom != null
            ? Color(custom.colorValue)
            : AppColors.primaryBlue;

        return InkWell(
          onTap: () {
            if (custom != null) {
              _onCustomCategoryTap(custom);
              return;
            }
            _onCategoryTap(category);
          },
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: selected
                  ? const LinearGradient(
                      colors: <Color>[
                        AppColors.primaryBlue,
                        AppColors.gradientBlue2,
                      ],
                    )
                  : null,
              color: selected ? null : const Color(0xFFF0F4FA),
              boxShadow: <BoxShadow>[
                if (selected)
                  BoxShadow(
                    color: AppColors.softBlueGlow.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, color: selected ? Colors.white : idleColor),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? Colors.white : AppColors.deepBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dateField(BuildContext context) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          border: Border.all(color: AppColors.deepBlue.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.calendar_today_rounded, size: 18),
            const SizedBox(width: 8),
            Text(
              DateUtilsX.short(
                _selectedDate,
                localeCode: Localizations.localeOf(context).languageCode,
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.deepBlue),
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }

  Widget _todayPreview(
    BuildContext context,
    ExpenseController expenses,
    String currencyCode,
    String activeAccountId,
  ) {
    final DateTime now = DateTime.now();
    final List<Expense> today = expenses.expenses
        .where(
          (Expense e) =>
              e.date.year == now.year &&
              e.date.month == now.month &&
              e.date.day == now.day &&
              e.accountId == activeAccountId,
        )
        .take(3)
        .toList(growable: false);

    if (today.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF4F7FC),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: today
              .map((Expense expense) {
                final bool isIncome = expense.amount < 0;
                final String signedAmount =
                    '${isIncome ? '+' : '-'}${CurrencyUtils.formatAmount(expense.amount.abs(), currencyCode)}';
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  leading: Icon(
                    _iconForExpense(expense),
                    color: isIncome
                        ? AppColors.incomeGreen
                        : _colorForExpense(expense),
                  ),
                  title: Text(
                    expense.note.trim().isEmpty
                        ? expense.categoryLabel(
                            Localizations.localeOf(context).languageCode,
                          )
                        : expense.note.trim(),
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${isIncome ? _t('Income', fr: 'Revenu') : _t('Expense', fr: 'Depense')} • ${DateUtilsX.short(expense.date, localeCode: Localizations.localeOf(context).languageCode)}',
                    style: const TextStyle(color: Color(0xFF627085)),
                  ),
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 86,
                      maxWidth: 130,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          signedAmount,
                          style: TextStyle(
                            color: isIncome
                                ? AppColors.incomeGreen
                                : AppColors.expenseRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  IconData _iconForCategory(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.transport:
        return Icons.directions_bus_filled_rounded;
      case ExpenseCategory.rent:
        return Icons.apartment_rounded;
      case ExpenseCategory.shopping:
        return Icons.shopping_bag_rounded;
      case ExpenseCategory.bills:
        return Icons.receipt_long_rounded;
      case ExpenseCategory.other:
        return Icons.more_horiz_rounded;
    }
  }

  IconData _iconForExpense(Expense expense) {
    if (expense.isCustomCategory &&
        expense.customCategoryIconCodePoint != null) {
      return AppIconUtils.fromCodePoint(
        expense.customCategoryIconCodePoint,
        fallback: _iconForCategory(expense.category),
      );
    }
    return _iconForCategory(expense.category);
  }

  Color _colorForExpense(Expense expense) {
    if (expense.isCustomCategory && expense.customCategoryColorValue != null) {
      return Color(expense.customCategoryColorValue!);
    }
    return AppColors.primaryBlue;
  }

  Future<void> _openCalculatorSheet() async {
    String expression = _amountController.text.trim();
    if (expression.isEmpty) {
      expression = '0';
    }

    final String? result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setSheetState,
              ) {
                void append(String value) {
                  setSheetState(() {
                    if (expression == '0' && value != '.') {
                      expression = value;
                    } else {
                      expression += value;
                    }
                  });
                }

                return SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13293D),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder:
                            (
                              BuildContext context,
                              BoxConstraints constraints,
                            ) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.calculate_rounded,
                                      color: AppColors.skyBlue,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _t('Calculator', fr: 'Calculatrice'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          Navigator.of(sheetContext).pop(),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    expression,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      <String>[
                                            '7',
                                            '8',
                                            '9',
                                            '/',
                                            '4',
                                            '5',
                                            '6',
                                            '*',
                                            '1',
                                            '2',
                                            '3',
                                            '-',
                                            '.',
                                            '0',
                                            'C',
                                            '+',
                                          ]
                                          .map((String value) {
                                            final bool isOperator = '+-*/'
                                                .contains(value);
                                            final bool isClear = value == 'C';
                                            return SizedBox(
                                              width:
                                                  (constraints.maxWidth - 24) /
                                                  4,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  if (isClear) {
                                                    setSheetState(
                                                      () => expression = '0',
                                                    );
                                                    return;
                                                  }
                                                  append(value);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isOperator
                                                      ? AppColors.primaryBlue
                                                      : Colors.white.withValues(
                                                          alpha: 0.10,
                                                        ),
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: Text(value),
                                              ),
                                            );
                                          })
                                          .toList(growable: false),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      final double? value = _resolveAmountInput(
                                        expression,
                                      );
                                      if (value == null || value <= 0) {
                                        return;
                                      }
                                      Navigator.of(
                                        sheetContext,
                                      ).pop(value.toStringAsFixed(2));
                                    },
                                    icon: const Icon(Icons.check_rounded),
                                    label: Text(
                                      _t('Use Result', fr: 'Utiliser resultat'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _amountController.text = result;
      });
    }
  }

  double? _resolveAmountInput(String raw) {
    final String expression = raw
        .trim()
        .replaceAll(',', '.')
        .replaceAll(' ', '');
    if (expression.isEmpty) {
      return null;
    }

    final double? direct = double.tryParse(expression);
    if (direct != null) {
      return direct;
    }

    return _evaluateExpression(expression);
  }

  double? _evaluateExpression(String expression) {
    final List<double> values = <double>[];
    final List<String> ops = <String>[];

    int i = 0;
    bool expectNumber = true;

    int precedence(String op) => (op == '+' || op == '-') ? 1 : 2;

    bool applyTopOp() {
      if (ops.isEmpty || values.length < 2) {
        return false;
      }
      final String op = ops.removeLast();
      final double right = values.removeLast();
      final double left = values.removeLast();
      switch (op) {
        case '+':
          values.add(left + right);
          break;
        case '-':
          values.add(left - right);
          break;
        case '*':
          values.add(left * right);
          break;
        case '/':
          if (right == 0) {
            return false;
          }
          values.add(left / right);
          break;
        default:
          return false;
      }
      return true;
    }

    while (i < expression.length) {
      final String ch = expression[i];

      if ('+-*/'.contains(ch)) {
        if (expectNumber && ch == '-') {
          int j = i + 1;
          while (j < expression.length &&
              ('0123456789.'.contains(expression[j]))) {
            j++;
          }
          final double? value = double.tryParse(expression.substring(i, j));
          if (value == null) {
            return null;
          }
          values.add(value);
          i = j;
          expectNumber = false;
          continue;
        }

        if (expectNumber) {
          return null;
        }

        while (ops.isNotEmpty && precedence(ops.last) >= precedence(ch)) {
          if (!applyTopOp()) {
            return null;
          }
        }
        ops.add(ch);
        i++;
        expectNumber = true;
        continue;
      }

      if ('0123456789.'.contains(ch)) {
        int j = i + 1;
        while (j < expression.length &&
            ('0123456789.'.contains(expression[j]))) {
          j++;
        }
        final double? value = double.tryParse(expression.substring(i, j));
        if (value == null) {
          return null;
        }
        values.add(value);
        i = j;
        expectNumber = false;
        continue;
      }

      return null;
    }

    while (ops.isNotEmpty) {
      if (!applyTopOp()) {
        return null;
      }
    }

    if (values.length != 1) {
      return null;
    }

    return max(values.single, 0).toDouble();
  }

  void _snack(String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }
}
