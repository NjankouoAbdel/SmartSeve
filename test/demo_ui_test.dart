import 'package:flutter/material.dart';
import 'package:wfer_flousk_firebase/core/services/home_widget_service.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/presentation/pages/pro/pro_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/shell/main_shell_page.dart';
import 'package:wfer_flousk_firebase/core/models/ocr_scan_result.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/navigation/shell_navigation_controller.dart';
import 'package:wfer_flousk_firebase/core/services/firebase_data_service.dart';
import 'package:wfer_flousk_firebase/core/services/firebase_toolkit_service.dart';
import 'package:wfer_flousk_firebase/core/widgets/animated_primary_button.dart';
import 'package:wfer_flousk_firebase/data/repositories/settings_repository_impl.dart';
import 'package:wfer_flousk_firebase/domain/entities/budget_goal.dart';
import 'package:wfer_flousk_firebase/domain/entities/recurring_expense_plan.dart';
import 'package:wfer_flousk_firebase/domain/entities/tool_notice.dart';
import 'package:wfer_flousk_firebase/domain/repositories/expense_repository.dart';
import 'package:wfer_flousk_firebase/domain/usecases/add_expense_usecase.dart';
import 'package:wfer_flousk_firebase/domain/usecases/delete_expense_usecase.dart';
import 'package:wfer_flousk_firebase/domain/usecases/get_expenses_usecase.dart';
import 'package:wfer_flousk_firebase/domain/usecases/update_expense_usecase.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/tools_controller.dart';
import 'package:wfer_flousk_firebase/presentation/pages/accounts/account_selector_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/add_expense/add_expense_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/auth/pro_login_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/home/home_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/onboarding/onboarding_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/settings/settings_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/settings/wallet_manager_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/statistics/statistics_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/tools/finance_chatbot_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/tools/tools_center_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/transactions/transactions_page.dart';
import 'package:wfer_flousk_firebase/presentation/pages/wallet_planner/wallet_planner_page.dart';

// Offline presentation fixtures: no Firebase initialization or business writes.
class _Data extends Fake implements FirebaseDataService {}

class _Repository extends Fake implements ExpenseRepository {
  _Repository(this.data);
  final List<Expense> data;
  @override
  Future<List<Expense>> getExpenses() async => data;
}

class _HomeWidget extends Fake implements HomeWidgetService {
  @override
  Stream<HomeWidgetQuickAction> get quickActions => const Stream.empty();
}

class _Settings extends SettingsRepositoryImpl {
  _Settings({this.localeCode = 'fr'}) : super(_Data());
  final String localeCode;
  @override
  String getLocaleCode() => localeCode;
  @override
  Future<void> setBankAccounts(List<Map<String, dynamic>> value) async {}
}

class _Tools extends ChangeNotifier implements ToolsController {
  bool locked = false;
  @override
  bool get authBusy => false;
  @override
  OcrScanResult? get lastOcrResult => null;
  @override
  Future<void> signOut() async {}

  @override
  bool get isLocked => locked;
  @override
  bool get pinEnabled => locked;
  @override
  bool get biometricEnabled => locked;
  @override
  bool get biometricSupported => false;
  @override
  int get unreadNoticeCount => 0;
  @override
  List<BudgetGoal> get budgets => [];
  @override
  List<RecurringExpensePlan> get recurringPlans => [];
  @override
  List<ToolNotice> get notices => [];
  @override
  String? get userEmail => 'presentation.longue@example.com';
  @override
  String? get lastCloudError => null;
  @override
  UsageOverview get usageOverview =>
      const UsageOverview(used: 0, limit: 180, isPro: false, remaining: 180);
  @override
  Future<String?> signIn(String email, String password) async =>
      throw StateError('Offline');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(
  Widget page,
  _Tools tools, {
  List<Expense> data = const [],
  String localeCode = 'fr',
}) {
  final repository = _Repository(data);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsController(_Settings(localeCode: localeCode)),
      ),
      ChangeNotifierProvider<ExpenseController>(
        create: (_) => ExpenseController(
          addExpenseUseCase: AddExpenseUseCase(repository),
          getExpensesUseCase: GetExpensesUseCase(repository),
          updateExpenseUseCase: UpdateExpenseUseCase(repository),
          deleteExpenseUseCase: DeleteExpenseUseCase(repository),
        )..loadExpenses(),
      ),
      ChangeNotifierProvider<ToolsController>.value(value: tools),
      Provider(create: (_) => ShellNavigationController()),
      Provider<HomeWidgetService>(create: (_) => _HomeWidget()),
    ],
    child: MaterialApp(
      locale: Locale(localeCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: SafeArea(child: page)),
    ),
  );
}

void main() {
  final pages = <String, Widget Function()>{
    'onboarding': () => const OnboardingPage(),
    'pro': () => const ProPage(),
    'shell': () => const MainShellPage(),
    'accounts': () => const AccountSelectorPage(),
    'home': () => HomePage(onQuickAddTap: () {}),
    'statistics': () => const StatisticsPage(),
    'transactions': () => const TransactionsPage(),
    'settings': () => const SettingsPage(),
    'wallets': () => const WalletManagerPage(),
    'planner': () => const WalletPlannerPage(),
    'add expense': () => const AddExpensePage(isStandalone: true),
    'login': () => const ProLoginPage(),
    'tools': () => const ToolsCenterPage(),
    'chatbot': () => const FinanceChatbotPage(),
  };
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
    const Size(1280, 800),
    const Size(568, 320),
  ]) {
    for (final entry in pages.entries) {
      testWidgets('${entry.key} at $size', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
        addTearDown(tester.view.reset);
        final tools = _Tools();
        addTearDown(tools.dispose);
        await tester.pumpWidget(_app(entry.value(), tools));
        await tester.pumpAndSettle();
        // Flutter layout errors are left to the test binding so their full diagnostics are reported.
      });
    }
  }

  for (final entry in pages.entries.where(
    (e) => ['home', 'statistics', 'transactions', 'accounts'].contains(e.key),
  )) {
    testWidgets('${entry.key} with long transaction at 320px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      final tools = _Tools();
      addTearDown(tools.dispose);
      await tester.pumpWidget(
        _app(
          entry.value(),
          tools,
          data: [
            Expense(
              id: 'demo',
              amount: 123456789.12,
              category: ExpenseCategory.food,
              date: DateTime.now(),
              note:
                  'Une description de transaction particulierement longue pour la presentation',
              currencyCode: 'USD',
              customCategoryName: 'Une categorie personnalisee tres longue',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      // Flutter layout errors are left to the test binding so their full diagnostics are reported.
    });
  }
  for (final width in [320.0, 1280.0]) {
    testWidgets('calculator uses modal width at $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 568);
      addTearDown(tester.view.reset);
      final tools = _Tools();
      addTearDown(tools.dispose);
      await tester.pumpWidget(
        _app(const AddExpensePage(isStandalone: true), tools),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.calculate_rounded));
      await tester.pumpAndSettle();
      // Flutter layout errors are left to the test binding so their full diagnostics are reported.
      final y = tester.getCenter(find.text('7')).dy;
      expect(tester.getCenter(find.text('/')).dy, y);
      await tester.tap(find.text('7'));
      await tester.ensureVisible(find.text('Utiliser resultat'));
      await tester.tap(find.text('Utiliser resultat'));
      await tester.pumpAndSettle();
      expect(find.text('7.00'), findsOneWidget);
      // Flutter layout errors are left to the test binding so their full diagnostics are reported.
    });
  }
  for (final name in ['add expense', 'login', 'planner', 'chatbot']) {
    testWidgets('$name with keyboard at 320px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.reset);
      final tools = _Tools();
      addTearDown(tools.dispose);
      await tester.pumpWidget(_app(pages[name]!(), tools));
      await tester.pumpAndSettle();
      // Flutter layout errors are left to the test binding so their full diagnostics are reported.
    });
  }
  testWidgets('shell menu and pushed tools return correctly', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    final tools = _Tools();
    addTearDown(tools.dispose);
    await tester.pumpWidget(_app(const MainShellPage(), tools));
    await tester.pumpAndSettle();
    for (final (icon, page) in [
      (Icons.bar_chart_rounded, StatisticsPage),
      (Icons.receipt_long_rounded, TransactionsPage),
      (Icons.settings_rounded, SettingsPage),
    ]) {
      await tester.tap(find.byIcon(icon).last);
      await tester.pumpAndSettle();
      expect(find.byType(page), findsOneWidget);
      // Flutter layout errors are left to the test binding so their full diagnostics are reported.
    }
    await tester.tap(find.byIcon(Icons.home_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notifications_active_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byType(ToolsCenterPage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    // Flutter layout errors are left to the test binding so their full diagnostics are reported.
  });

  testWidgets('all onboarding panels scroll at 320px', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    final tools = _Tools();
    addTearDown(tools.dispose);
    await tester.pumpWidget(_app(const OnboardingPage(), tools));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text('Commencer'), findsOneWidget);
  });
  testWidgets('budget dialog scrolls with keyboard and returns', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    final tools = _Tools();
    addTearDown(tools.dispose);
    await tester.pumpWidget(_app(const ToolsCenterPage(), tools));
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 12 && find.text('Ajouter budget').hitTestable().evaluate().isEmpty;
      i++
    ) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -200));
      await tester.pumpAndSettle();
    }
    expect(find.text('Ajouter budget').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Ajouter budget'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('wallet notification button opens tools, not categories', (
    tester,
  ) async {
    final tools = _Tools();
    addTearDown(tools.dispose);
    await tester.pumpWidget(_app(const WalletManagerPage(), tools));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notifications_active_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(ToolsCenterPage), findsOneWidget);
    expect(find.text('Aucune notification pour le moment.'), findsOneWidget);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await tester.tap(find.byIcon(Icons.notifications_active_outlined).first);
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ToolsCenterPage), findsNothing);
    expect(find.byType(WalletManagerPage), findsOneWidget);
  });
  for (final name in [
    'onboarding',
    'home',
    'statistics',
    'settings',
    'tools',
    'chatbot',
  ]) {
    testWidgets('$name in Arabic at 320px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      final tools = _Tools();
      addTearDown(tools.dispose);
      await tester.pumpWidget(_app(pages[name]!(), tools, localeCode: 'ar'));
      await tester.pumpAndSettle();
    });
  }
  testWidgets('long primary label fits narrow card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: AnimatedPrimaryButton(
                label: 'Debloquer avec biometrie',
                icon: Icons.fingerprint,
                isLoading: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    // Flutter layout errors are left to the test binding so their full diagnostics are reported.
  });
  for (final locked in [false, true]) {
    testWidgets('keyboard leaves ${locked ? 'PIN' : 'onboarding'} scrollable', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.reset);
      final tools = _Tools()..locked = locked;
      addTearDown(tools.dispose);
      await tester.pumpWidget(
        _app(locked ? const ToolsCenterPage() : const OnboardingPage(), tools),
      );
      await tester.pumpAndSettle();
      // Flutter layout errors are left to the test binding so their full diagnostics are reported.
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });
  }
  testWidgets('login exception releases submit button', (tester) async {
    final tools = _Tools();
    addTearDown(tools.dispose);
    await tester.pumpWidget(_app(const ProLoginPage(), tools));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'demo@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.ensureVisible(find.byType(AnimatedPrimaryButton));
    await tester.tap(find.byType(AnimatedPrimaryButton));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedPrimaryButton>(find.byType(AnimatedPrimaryButton))
          .isLoading,
      isFalse,
    );
    expect(find.byType(SnackBar), findsOneWidget);
    // Flutter layout errors are left to the test binding so their full diagnostics are reported.
  });
}
