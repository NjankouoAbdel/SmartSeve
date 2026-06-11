import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/app.dart';
import 'package:wfer_flousk_firebase/core/navigation/shell_navigation_controller.dart';
import 'package:wfer_flousk_firebase/core/services/csv_service.dart';
import 'package:wfer_flousk_firebase/core/services/export_service.dart';
import 'package:wfer_flousk_firebase/core/services/firebase_data_service.dart';
import 'package:wfer_flousk_firebase/core/services/firebase_toolkit_service.dart';
import 'package:wfer_flousk_firebase/core/services/google_sheets_service.dart';
import 'package:wfer_flousk_firebase/core/services/home_widget_service.dart';
import 'package:wfer_flousk_firebase/core/services/local_notification_service.dart';
import 'package:wfer_flousk_firebase/core/services/ocr_service.dart';
import 'package:wfer_flousk_firebase/core/services/purchase_service.dart';
import 'package:wfer_flousk_firebase/core/services/security_service.dart';
import 'package:wfer_flousk_firebase/core/services/tools_store_service.dart';
import 'package:wfer_flousk_firebase/data/datasources/expense_local_datasource.dart';
import 'package:wfer_flousk_firebase/data/repositories/expense_repository_impl.dart';
import 'package:wfer_flousk_firebase/data/repositories/settings_repository_impl.dart';
import 'package:wfer_flousk_firebase/domain/usecases/add_expense_usecase.dart';
import 'package:wfer_flousk_firebase/domain/usecases/delete_expense_usecase.dart';
import 'package:wfer_flousk_firebase/domain/usecases/get_expenses_usecase.dart';
import 'package:wfer_flousk_firebase/domain/usecases/update_expense_usecase.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/purchase_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';
import 'package:wfer_flousk_firebase/firebase_options.dart';

const Duration _startupTimeout = Duration(seconds: 18);

Future<T?> _runStartupStep<T>({
  required String label,
  required Future<T> Function() action,
  required List<String> warnings,
  Duration timeout = _startupTimeout,
}) async {
  try {
    return await action().timeout(timeout);
  } catch (error, stackTrace) {
    final String message = '$label: $error';
    warnings.add(message);
    debugPrint('Startup step failed -> $message');
    debugPrintStack(stackTrace: stackTrace);
    return null;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final List<String> startupWarnings = <String>[];

  await _runStartupStep<void>(
    label: 'Firebase.initializeApp',
    warnings: startupWarnings,
    action: () async {
      if (DefaultFirebaseOptions.isConfiguredForCurrentPlatform) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp();
      }
    },
  );

  FirebaseDataService? firebaseDataService;
  try {
    firebaseDataService = FirebaseDataService();
  } catch (error, stackTrace) {
    startupWarnings.add('FirebaseDataService: $error');
    debugPrint('Startup step failed -> FirebaseDataService: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  if (firebaseDataService == null) {
    runApp(_StartupFailureApp(issues: startupWarnings));
    return;
  }

  await _runStartupStep<void>(
    label: 'FirebaseDataService.ensureSignedIn',
    action: firebaseDataService.ensureSignedIn,
    warnings: startupWarnings,
  );

  final ExpenseLocalDataSource expenseLocalDataSource =
      ExpenseLocalDataSourceImpl(firebaseDataService);
  final ExpenseRepositoryImpl expenseRepository = ExpenseRepositoryImpl(
    expenseLocalDataSource,
  );
  final SettingsRepositoryImpl settingsRepository = SettingsRepositoryImpl(
    firebaseDataService,
  );
  await _runStartupStep<void>(
    label: 'SettingsRepository.initialize',
    action: settingsRepository.initialize,
    warnings: startupWarnings,
  );

  final AddExpenseUseCase addExpenseUseCase = AddExpenseUseCase(
    expenseRepository,
  );
  final GetExpensesUseCase getExpensesUseCase = GetExpensesUseCase(
    expenseRepository,
  );
  final UpdateExpenseUseCase updateExpenseUseCase = UpdateExpenseUseCase(
    expenseRepository,
  );
  final DeleteExpenseUseCase deleteExpenseUseCase = DeleteExpenseUseCase(
    expenseRepository,
  );

  final SettingsController settingsController = SettingsController(
    settingsRepository,
  );

  final ExpenseController expenseController = ExpenseController(
    addExpenseUseCase: addExpenseUseCase,
    getExpensesUseCase: getExpensesUseCase,
    updateExpenseUseCase: updateExpenseUseCase,
    deleteExpenseUseCase: deleteExpenseUseCase,
  );
  await _runStartupStep<void>(
    label: 'ExpenseController.loadExpenses',
    action: expenseController.loadExpenses,
    warnings: startupWarnings,
  );

  final FirebaseToolkitService firebaseToolkitService =
      FirebaseToolkitService(dataService: firebaseDataService);
  await _runStartupStep<void>(
    label: 'FirebaseToolkitService.initialize',
    action: firebaseToolkitService.initialize,
    warnings: startupWarnings,
  );
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    unawaited(
      firebaseToolkitService.recordNonFatal(
        details.exception,
        details.stack ?? StackTrace.current,
      ),
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    unawaited(firebaseToolkitService.recordNonFatal(error, stack));
    return true;
  };

  final PurchaseService purchaseService = PurchaseService();
  final PurchaseController purchaseController = PurchaseController(
    purchaseService: purchaseService,
    settingsRepository: settingsRepository,
    firebaseToolkitService: firebaseToolkitService,
    onProChanged: settingsController.setProState,
  );
  purchaseController.setLocaleCode(settingsController.localeCode);
  await _runStartupStep<void>(
    label: 'PurchaseController.initialize',
    action: purchaseController.initialize,
    warnings: startupWarnings,
  );

  final ExportService exportService = ExportService();
  final GoogleSheetsService googleSheetsService = GoogleSheetsService();
  final HomeWidgetService homeWidgetService = HomeWidgetService();
  final ShellNavigationController shellNavigationController =
      ShellNavigationController();
  final ToolsStoreService toolsStoreService = ToolsStoreService(
    firebaseDataService: firebaseDataService,
  );
  await _runStartupStep<void>(
    label: 'ToolsStoreService.initialize',
    action: toolsStoreService.initialize,
    warnings: startupWarnings,
  );
  final ToolsController toolsController = ToolsController(
    storeService: toolsStoreService,
    localNotificationService: LocalNotificationService(),
    firebaseToolkitService: firebaseToolkitService,
    csvService: CsvService(),
    ocrService: OcrService(),
    securityService: SecurityService(LocalAuthentication()),
  );
  await _runStartupStep<void>(
    label: 'ToolsController.initialize',
    action: toolsController.initialize,
    warnings: startupWarnings,
  );
  toolsController.setLocaleCode(settingsController.localeCode);
  await _runStartupStep<int>(
    label: 'ToolsController.processRecurringExpenses',
    warnings: startupWarnings,
    action: () => toolsController.processRecurringExpenses(
      expenseController: expenseController,
      currencyCode: settingsController.currencyCode,
      accountId: settingsController.activeBankAccountId,
    ),
  );
  await _runStartupStep<void>(
    label: 'ToolsController.evaluateBudgets',
    warnings: startupWarnings,
    action: () => toolsController.evaluateBudgets(
      expenses: expenseController.expenses.toList(),
      currencyCode: settingsController.currencyCode,
    ),
  );

  Future<void> syncHomeWidget() async {
    final String accountId = settingsController.activeBankAccountId;
    final double income =
        settingsController.monthlyIncome +
        expenseController.monthlyIncomeTransactionsForAccount(accountId);
    final double spending = expenseController.monthlySpendingForAccount(
      accountId,
    );
    final double balance = income - spending;

    await homeWidgetService.updateDashboardWidget(
      accountName: settingsController.activeBankAccount.name,
      balance: balance,
      monthlySpending: spending,
      currencyCode: settingsController.currencyCode,
    );
  }

  void scheduleHomeWidgetSync() {
    unawaited(syncHomeWidget());
  }

  void syncToolsLocale() {
    toolsController.setLocaleCode(settingsController.localeCode);
  }

  void syncPurchaseLocale() {
    purchaseController.setLocaleCode(settingsController.localeCode);
  }

  settingsController.addListener(scheduleHomeWidgetSync);
  settingsController.addListener(syncToolsLocale);
  settingsController.addListener(syncPurchaseLocale);
  expenseController.addListener(scheduleHomeWidgetSync);
  scheduleHomeWidgetSync();

  if (startupWarnings.isNotEmpty) {
    debugPrint('Startup completed with ${startupWarnings.length} warning(s):');
    for (final String warning in startupWarnings) {
      debugPrint('- $warning');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<ExportService>.value(value: exportService),
        Provider<GoogleSheetsService>.value(value: googleSheetsService),
        Provider<HomeWidgetService>.value(value: homeWidgetService),
        Provider<ShellNavigationController>.value(
          value: shellNavigationController,
        ),
        ChangeNotifierProvider<SettingsController>.value(
          value: settingsController,
        ),
        ChangeNotifierProvider<ExpenseController>.value(
          value: expenseController,
        ),
        ChangeNotifierProvider<ToolsController>.value(value: toolsController),
        ChangeNotifierProvider<PurchaseController>.value(
          value: purchaseController,
        ),
      ],
      child: const SmartExpenseApp(),
    ),
  );
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.issues});

  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Startup failed',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The app could not initialize required services. '
                    'Check console logs and Firebase setup.',
                  ),
                  if (issues.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    SelectableText(issues.join('\n')),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

