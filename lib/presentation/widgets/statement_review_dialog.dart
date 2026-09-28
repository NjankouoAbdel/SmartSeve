import 'package:flutter/material.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/models/ocr_scan_result.dart';
import 'package:wfer_flousk_firebase/core/utils/date_utils.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';

/// Boite de dialogue de revue/correction des transactions detectees dans un
/// relevé bancaire (photo ou PDF).
///
/// Partagee entre plusieurs points d'entree de l'app (le Centre Outils et
/// l'ecran "Ajouter une depense") pour eviter de dupliquer ~200 lignes d'UI:
/// quel que soit l'endroit d'ou l'utilisateur lance un scan/import de
/// relevé, il retrouve exactement le meme ecran de verification avant
/// import group.
Future<void> showStatementReviewDialog({
  required BuildContext context,
  required ToolsController tools,
  required BankStatementScanResult result,
  required ExpenseController expenses,
  required SettingsController settings,
}) async {
  // Chaque transaction reste un objet mutable (voir ScannedTransaction): les
  // champs amount/description/suggestedCategory/included sont modifies
  // directement par les controles ci-dessous, pas besoin de reconstruire
  // toute la liste a chaque frappe.
  final List<ScannedTransaction> transactions = result.transactions;
  final List<TextEditingController> amountControllers = transactions
      .map(
        (ScannedTransaction t) =>
            TextEditingController(text: t.amount.toStringAsFixed(2)),
      )
      .toList(growable: false);
  final List<TextEditingController> noteControllers = transactions
      .map((ScannedTransaction t) => TextEditingController(text: t.description))
      .toList(growable: false);

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        // Nomme volontairement "builderContext" (et non "context") pour ne
        // PAS masquer le `context` de l'ecran appelant: le controle
        // `context.mounted` plus bas, apres la fermeture du dialogue, doit
        // verifier que CET ecran est toujours monte, pas ce dialogue qu'on
        // vient justement de fermer.
        builder: (BuildContext builderContext, StateSetter setDialogState) {
          final int includedCount = transactions
              .where((ScannedTransaction t) => t.included)
              .length;
          return AlertDialog(
            title: Text(
              builderContext.l10n.phraseWithArgs(
                'Review {count} transaction(s)',
                <String, String>{'count': transactions.length.toString()},
                french: 'Verifier {count} transaction(s)',
              ),
            ),
            content: SizedBox(
              width: 480,
              height: 420,
              child: ListView.separated(
                itemCount: transactions.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const Divider(height: 20),
                itemBuilder: (BuildContext context, int index) {
                  final ScannedTransaction t = transactions[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Checkbox(
                        value: t.included,
                        onChanged: (bool? value) {
                          setDialogState(() => t.included = value ?? false);
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: TextField(
                                    controller: amountControllers[index],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: context.l10n.phrase(
                                        'Amount',
                                        french: 'Montant',
                                      ),
                                    ),
                                    onChanged: (String value) {
                                      final double? parsed = double.tryParse(
                                        value.replaceAll(',', '.'),
                                      );
                                      if (parsed != null) {
                                        t.amount = parsed;
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t.date == null
                                      ? '-'
                                      : DateUtilsX.short(
                                          t.date!,
                                          localeCode: settings.localeCode,
                                        ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: noteControllers[index],
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: context.l10n.phrase(
                                  'Note',
                                  french: 'Note',
                                ),
                              ),
                              onChanged: (String value) =>
                                  t.description = value,
                            ),
                            // Pas de selecteur de categorie ici: elle est
                            // devinee automatiquement par l'OCR/IA (voir
                            // OcrService._guessCategory) a partir du texte de
                            // la ligne, sans intervention de l'utilisateur.
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  builderContext.l10n.phrase('Cancel', french: 'Annuler'),
                ),
              ),
              ElevatedButton(
                onPressed: includedCount == 0
                    ? null
                    : () async {
                        final int added = await tools
                            .addExpensesFromBankStatement(
                              transactions: transactions,
                              expenseController: expenses,
                              currencyCode: settings.currencyCode,
                              accountId: settings.activeBankAccountId,
                            );
                        await tools.evaluateBudgets(
                          expenses: expenses.expensesForAccount(
                            settings.activeBankAccountId,
                          ),
                          currencyCode: settings.currencyCode,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.phraseWithArgs(
                                '{count} transaction(s) imported.',
                                <String, String>{'count': added.toString()},
                                french: '{count} transaction(s) importee(s).',
                              ),
                            ),
                          ),
                        );
                      },
                child: Text(
                  builderContext.l10n.phraseWithArgs(
                    'Import {count}',
                    <String, String>{'count': includedCount.toString()},
                    french: 'Importer {count}',
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  for (final TextEditingController c in amountControllers) {
    c.dispose();
  }
  for (final TextEditingController c in noteControllers) {
    c.dispose();
  }
}
