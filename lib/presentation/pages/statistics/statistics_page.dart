import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wfer_flousk_firebase/core/constants/app_colors.dart';
import 'package:wfer_flousk_firebase/core/localization/app_localizations.dart';
import 'package:wfer_flousk_firebase/core/utils/currency_utils.dart';
import 'package:wfer_flousk_firebase/core/utils/date_utils.dart';
import 'package:wfer_flousk_firebase/core/widgets/fintech_page_app_bar.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/expense_controller.dart';
import 'package:wfer_flousk_firebase/presentation/controllers/settings_controller.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

// "all" a ete ajoute pour couvrir TOUTES les depenses enregistrees, quelle
// que soit leur date : sans cet onglet, une depense importee d'un mois
// different du mois en cours (par exemple un ancien releve bancaire PDF)
// n'apparaissait dans AUCUN des 3 onglets existants (Quotidien/
// Hebdomadaire/Mensuel sont tous relatifs a la date d'aujourd'hui), ce qui
// donnait l'impression que les graphiques ne se mettaient jamais a jour.
enum StatsSegment { daily, weekly, monthly, all }

class _StatisticsPageState extends State<StatisticsPage> {
  static const double _horizontalPadding = 20;
  static const double _sectionSpacing = 20;

  StatsSegment _segment = StatsSegment.monthly;

  String _t(String english, {String? fr}) {
    return context.l10n.phrase(english, french: fr);
  }

  String _ta(String english, Map<String, String> args, {String? fr}) {
    return context.l10n.phraseWithArgs(english, args, french: fr);
  }

  @override
  Widget build(BuildContext context) {
    final ExpenseController expenseController = context
        .watch<ExpenseController>();
    final SettingsController settings = context.watch<SettingsController>();
    final String activeAccountId = settings.activeBankAccountId;

    final List<Expense> source = expenseController
        .expensesForAccount(activeAccountId)
        .toList(growable: false);
    final List<Expense> filtered = _filteredExpenses(_segment, source);
    final List<_CategorySlice> slices = _buildCategorySlices(
      filtered,
      settings.localeCode,
    );
    final _LineSeries lineSeries = _buildLineSeries(
      _segment,
      source,
      settings.localeCode,
    );
    final ({double thisWeek, double lastWeek}) weeklyComparison =
        _buildWeeklyExpenseComparison(source);

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: <double>[0, 0.52, 1],
                colors: <Color>[
                  Color(0xFF0D1B2A),
                  Color(0xFF0F2233),
                  Color(0xFF0B0F14),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.softBlueGlow.withValues(alpha: 0.10),
                      AppColors.softBlueGlow.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  builder: (BuildContext context, double value, Widget? child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 10),
                        const FintechPageAppBar(
                          title: 'Statistics',
                          showBackToHome: true,
                        ),
                        const SizedBox(height: 15),
                        _segmentControl(context),
                        const SizedBox(height: 20),
                        _pieCard(context, slices, settings.currencyCode),
                        const SizedBox(height: _sectionSpacing),
                        _lineCard(context, lineSeries, settings.currencyCode),
                        const SizedBox(height: _sectionSpacing),
                        _comparisonCard(
                          context,
                          thisWeek: weeklyComparison.thisWeek,
                          lastWeek: weeklyComparison.lastWeek,
                          currencyCode: settings.currencyCode,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _segmentControl(BuildContext context) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFF122638),
        borderRadius: BorderRadius.circular(25),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              children: <Widget>[
                AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  alignment: _alignmentForSegment(_segment),
                  child: FractionallySizedBox(
                    widthFactor: 1 / 4,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: <Color>[Color(0xFF0D47A1), Color(0xFF1565C0)],
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    _segmentButton(
                      _t('Daily', fr: 'Quotidien'),
                      StatsSegment.daily,
                    ),
                    _segmentButton(
                      _t('Weekly', fr: 'Hebdomadaire'),
                      StatsSegment.weekly,
                    ),
                    _segmentButton(
                      _t('Monthly', fr: 'Mensuel'),
                      StatsSegment.monthly,
                    ),
                    _segmentButton(
                      _t('All', fr: 'Tout'),
                      StatsSegment.all,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _segmentButton(String label, StatsSegment value) {
    final bool selected = _segment == value;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _segment = value);
        },
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFFAAB4C3),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pieCard(
    BuildContext context,
    List<_CategorySlice> slices,
    String currencyCode,
  ) {
    final _CategorySlice? topSlice = slices.isEmpty
        ? null
        : slices.reduce((_CategorySlice a, _CategorySlice b) {
            return a.percent >= b.percent ? a : b;
          });

    return _premiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _t('Spending by Category', fr: 'Depenses par categorie'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.tune_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (slices.isEmpty)
            _emptyState(
              context,
              icon: Icons.pie_chart_outline_rounded,
              text: _t(
                'No expense data for this period.',
                fr: 'Aucune depense pour cette periode.',
              ),
            )
          else
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double chartSize = constraints.maxWidth
                    .clamp(190, 250)
                    .toDouble();
                final double centerSpace = (chartSize * 0.28)
                    .clamp(54, 70)
                    .toDouble();
                final double sectionRadius = (chartSize * 0.25)
                    .clamp(48, 62)
                    .toDouble();

                return Center(
                  child: Container(
                    width: chartSize,
                    height: chartSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.softBlueGlow.withValues(alpha: 0.28),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        PieChart(
                          PieChartData(
                            centerSpaceRadius: centerSpace,
                            sectionsSpace: 1.5,
                            sections: slices
                                .map((_CategorySlice slice) {
                                  return PieChartSectionData(
                                    value: slice.percent,
                                    color: slice.color,
                                    radius: sectionRadius,
                                    showTitle: false,
                                  );
                                })
                                .toList(growable: false),
                          ),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                        if (topSlice != null)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '${topSlice.percent.round()}%',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontSize: chartSize < 220 ? 19 : 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              SizedBox(
                                width: centerSpace * 1.6,
                                child: Text(
                                  topSlice.label,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFFAAB4C3),
                                      ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (slices.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            ...slices.map((_CategorySlice slice) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: slice.color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        slice.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        CurrencyUtils.formatAmount(slice.amount, currencyCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFAAB4C3),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${slice.percent.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFAAB4C3),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _lineCard(
    BuildContext context,
    _LineSeries series,
    String currencyCode,
  ) {
    final double maxValue = max(
      series.expenseValues.fold<double>(0, max),
      series.incomeValues.fold<double>(0, max),
    );
    final double maxY = max(100, maxValue * 1.2);

    return _premiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _segment == StatsSegment.monthly
                ? _t(
                    'Cashflow (Last 6 Months)',
                    fr: 'Flux de tresorerie (6 derniers mois)',
                  )
                : _segment == StatsSegment.weekly
                ? _t(
                    'Cashflow (Last 6 Weeks)',
                    fr: 'Flux de tresorerie (6 dernieres semaines)',
                  )
                : _segment == StatsSegment.all
                ? _t(
                    'Cashflow (All Time, by Month)',
                    fr: 'Flux de tresorerie (tout l\'historique, par mois)',
                  )
                : _t(
                    'Cashflow (Last 7 Days)',
                    fr: 'Flux de tresorerie (7 derniers jours)',
                  ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: <Widget>[
              _legendDot(
                context,
                color: AppColors.expenseRed,
                label: _t('Expense', fr: 'Depense'),
              ),
              _legendDot(
                context,
                color: AppColors.incomeGreen,
                label: _t('Income', fr: 'Revenu'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!series.hasData)
            _emptyState(
              context,
              icon: Icons.show_chart_rounded,
              text: _t(
                'No transactions yet for chart.',
                fr: 'Aucune transaction pour le graphique.',
              ),
            )
          else
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 5,
                    getDrawingHorizontalLine: (_) {
                      return FlLine(
                        color: Colors.white.withValues(alpha: 0.10),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: maxY / 5,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            _axisAmount(value, currencyCode),
                            style: const TextStyle(
                              color: Color(0xFFAAB4C3),
                              fontSize: 11,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int index = value.toInt();
                          if (index < 0 || index >= series.labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              series.labels[index],
                              style: const TextStyle(
                                color: Color(0xFFAAB4C3),
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: <LineChartBarData>[
                    _lineSeriesStyle(
                      values: series.expenseValues,
                      lineColor: AppColors.expenseRed,
                      areaStartAlpha: 0.22,
                    ),
                    _lineSeriesStyle(
                      values: series.incomeValues,
                      lineColor: AppColors.incomeGreen,
                      areaStartAlpha: 0.18,
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              ),
            ),
        ],
      ),
    );
  }

  LineChartBarData _lineSeriesStyle({
    required List<double> values,
    required Color lineColor,
    required double areaStartAlpha,
  }) {
    return LineChartBarData(
      spots: List<FlSpot>.generate(
        values.length,
        (int i) => FlSpot(i.toDouble(), values[i]),
      ),
      isCurved: true,
      color: lineColor,
      barWidth: 3.2,
      dotData: FlDotData(
        show: true,
        getDotPainter:
            (FlSpot spot, double percent, LineChartBarData barData, int index) {
              return FlDotCirclePainter(
                radius: 3,
                color: Colors.white,
                strokeColor: lineColor,
                strokeWidth: 2,
              );
            },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            lineColor.withValues(alpha: areaStartAlpha),
            lineColor.withValues(alpha: 0.02),
          ],
        ),
      ),
    );
  }

  Widget _comparisonCard(
    BuildContext context, {
    required double thisWeek,
    required double lastWeek,
    required String currencyCode,
  }) {
    final double diff = thisWeek - lastWeek;
    final bool moreSpent = diff > 0;
    final double progressValue = max(thisWeek, lastWeek) <= 0
        ? 0
        : (thisWeek / max(thisWeek, lastWeek)).clamp(0, 1);

    final String helper = moreSpent
        ? _ta(
            'You spent {amount} more this week',
            <String, String>{
              'amount': CurrencyUtils.formatAmount(diff, currencyCode),
            },
            fr: 'Vous avez depense {amount} de plus cette semaine',
          )
        : _ta(
            'You spent {amount} less this week',
            <String, String>{
              'amount': CurrencyUtils.formatAmount(diff.abs(), currencyCode),
            },
            fr: 'Vous avez depense {amount} de moins cette semaine',
          );

    return _premiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _t(
              'Weekly Expense Comparison',
              fr: 'Comparaison hebdomadaire des depenses',
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _t('This Week', fr: 'Cette semaine'),
                      style: TextStyle(color: Color(0xFFAAB4C3), fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyUtils.formatAmount(thisWeek, currencyCode),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF4CAF50),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _t('Last Week', fr: 'Semaine derniere'),
                      style: TextStyle(color: Color(0xFFAAB4C3), fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyUtils.formatAmount(lastWeek, currencyCode),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 10,
              color: const Color(0xFF0F2233),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progressValue,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[Color(0xFF0D47A1), Color(0xFF1565C0)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFAAB4C3),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(
    BuildContext context, {
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFFAAB4C3)),
        ),
      ],
    );
  }

  Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return SizedBox(
      height: 190,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 28, color: Colors.white.withValues(alpha: 0.42)),
            const SizedBox(height: 8),
            Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFAAB4C3)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF13293D),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }

  Alignment _alignmentForSegment(StatsSegment segment) {
    // 4 onglets a repartir a egale distance de -1 (tout a gauche) a +1
    // (tout a droite) : -1, -1/3, +1/3, +1.
    switch (segment) {
      case StatsSegment.daily:
        return Alignment.centerLeft;
      case StatsSegment.weekly:
        return const Alignment(-1 / 3, 0);
      case StatsSegment.monthly:
        return const Alignment(1 / 3, 0);
      case StatsSegment.all:
        return Alignment.centerRight;
    }
  }

  List<Expense> _filteredExpenses(StatsSegment segment, List<Expense> source) {
    final DateTime now = DateTime.now();
    switch (segment) {
      case StatsSegment.daily:
        final DateTime dayStart = DateTime(now.year, now.month, now.day);
        final DateTime dayEnd = dayStart.add(const Duration(days: 1));
        return source
            .where((Expense e) => _isInRange(e.date, dayStart, dayEnd))
            .toList(growable: false);
      case StatsSegment.weekly:
        final DateTime weekStart = _startOfWeek(now);
        final DateTime weekEnd = weekStart.add(const Duration(days: 7));
        return source
            .where((Expense e) => _isInRange(e.date, weekStart, weekEnd))
            .toList(growable: false);
      case StatsSegment.monthly:
        final DateTime monthStart = DateTime(now.year, now.month, 1);
        final DateTime monthEnd = DateTime(now.year, now.month + 1, 1);
        return source
            .where((Expense e) => _isInRange(e.date, monthStart, monthEnd))
            .toList(growable: false);
      case StatsSegment.all:
        // Aucun filtre de date: TOUTES les depenses enregistrees, meme
        // celles d'un releve importe couvrant des mois passes.
        return source;
    }
  }

  List<_CategorySlice> _buildCategorySlices(
    List<Expense> filtered,
    String localeCode,
  ) {
    final Map<ExpenseCategory, Color> colors = <ExpenseCategory, Color>{
      ExpenseCategory.food: const Color(0xFF42A5F5),
      ExpenseCategory.transport: const Color(0xFF1E88E5),
      ExpenseCategory.rent: const Color(0xFF1565C0),
      ExpenseCategory.shopping: const Color(0xFF64B5F6),
      ExpenseCategory.bills: const Color(0xFF90CAF9),
      ExpenseCategory.other: const Color(0xFF29B6F6),
    };
    final Map<String, _CategorySlice> totals = <String, _CategorySlice>{};

    for (final Expense expense in filtered) {
      if (expense.amount <= 0 || expense.isTransfer) {
        continue;
      }

      final bool hasCustom =
          expense.isCustomCategory &&
          (expense.customCategoryName ?? '').trim().isNotEmpty;
      final String key = hasCustom
          ? 'custom:${expense.customCategoryId ?? expense.customCategoryName}'
          : 'base:${expense.category.key}';
      final String label = hasCustom
          ? expense.customCategoryName!.trim()
          : expense.category.localizedLabel(localeCode);
      final Color color = hasCustom && expense.customCategoryColorValue != null
          ? Color(expense.customCategoryColorValue!)
          : (colors[expense.category] ?? const Color(0xFF42A5F5));

      final _CategorySlice existing =
          totals[key] ??
          _CategorySlice(label: label, percent: 0, amount: 0, color: color);
      totals[key] = _CategorySlice(
        label: existing.label,
        percent: 0,
        amount: existing.amount + expense.amount,
        color: existing.color,
      );
    }

    final double total = totals.values.fold<double>(
      0,
      (double p, _CategorySlice c) => p + c.amount,
    );
    if (total <= 0) {
      return const <_CategorySlice>[];
    }

    final List<_CategorySlice> slices = totals.values
        .map((_CategorySlice slice) {
          return _CategorySlice(
            label: slice.label,
            percent: (slice.amount / total) * 100,
            amount: slice.amount,
            color: slice.color,
          );
        })
        .toList(growable: false);

    slices.sort((_CategorySlice a, _CategorySlice b) {
      return b.amount.compareTo(a.amount);
    });
    return slices;
  }

  _LineSeries _buildLineSeries(
    StatsSegment segment,
    List<Expense> source,
    String localeCode,
  ) {
    final DateTime now = DateTime.now();
    final List<String> labels = <String>[];
    final List<double> expenseValues = <double>[];
    final List<double> incomeValues = <double>[];

    if (segment == StatsSegment.monthly) {
      for (int i = 5; i >= 0; i--) {
        final DateTime start = DateTime(now.year, now.month - i, 1);
        final DateTime end = DateTime(start.year, start.month + 1, 1);
        labels.add(DateUtilsX.monthShort(start, localeCode: localeCode));
        expenseValues.add(_sumExpenses(source, start, end));
        incomeValues.add(_sumIncome(source, start, end));
      }
      return _LineSeries(
        labels: labels,
        expenseValues: expenseValues,
        incomeValues: incomeValues,
      );
    }

    if (segment == StatsSegment.all) {
      if (source.isEmpty) {
        return const _LineSeries(
          labels: <String>[],
          expenseValues: <double>[],
          incomeValues: <double>[],
        );
      }
      // Un "mois" (annee+mois) par entree, pour regrouper TOUTES les
      // depenses par mois calendaire, meme celles de mois tres anciens
      // (ex: un vieux releve PDF importe), plutot que de se limiter aux 6
      // derniers mois glissants comme le fait l'onglet "Mensuel".
      DateTime earliest = source.first.date;
      DateTime latest = source.first.date;
      for (final Expense e in source) {
        if (e.date.isBefore(earliest)) {
          earliest = e.date;
        }
        if (e.date.isAfter(latest)) {
          latest = e.date;
        }
      }
      final DateTime firstMonth = DateTime(earliest.year, earliest.month, 1);
      final DateTime lastMonth = DateTime(latest.year, latest.month, 1);
      int monthCount =
          (lastMonth.year - firstMonth.year) * 12 +
          (lastMonth.month - firstMonth.month) +
          1;
      // Garde-fou: si l'historique s'etale sur des annees, on ne garde que
      // les 12 derniers mois avec des donnees pour que le graphique reste
      // lisible.
      const int maxMonths = 12;
      if (monthCount > maxMonths) {
        monthCount = maxMonths;
      }
      for (int i = monthCount - 1; i >= 0; i--) {
        final DateTime start = DateTime(
          lastMonth.year,
          lastMonth.month - i,
          1,
        );
        final DateTime end = DateTime(start.year, start.month + 1, 1);
        labels.add(DateUtilsX.monthShort(start, localeCode: localeCode));
        expenseValues.add(_sumExpenses(source, start, end));
        incomeValues.add(_sumIncome(source, start, end));
      }
      return _LineSeries(
        labels: labels,
        expenseValues: expenseValues,
        incomeValues: incomeValues,
      );
    }

    if (segment == StatsSegment.weekly) {
      final DateTime currentWeekStart = _startOfWeek(now);
      for (int i = 5; i >= 0; i--) {
        final DateTime start = currentWeekStart.subtract(Duration(days: i * 7));
        final DateTime end = start.add(const Duration(days: 7));
        labels.add('${start.day}/${start.month}');
        expenseValues.add(_sumExpenses(source, start, end));
        incomeValues.add(_sumIncome(source, start, end));
      }
      return _LineSeries(
        labels: labels,
        expenseValues: expenseValues,
        incomeValues: incomeValues,
      );
    }

    for (int i = 6; i >= 0; i--) {
      final DateTime day = DateTime(now.year, now.month, now.day - i);
      final DateTime start = DateTime(day.year, day.month, day.day);
      final DateTime end = start.add(const Duration(days: 1));
      labels.add('${day.day}');
      expenseValues.add(_sumExpenses(source, start, end));
      incomeValues.add(_sumIncome(source, start, end));
    }

    return _LineSeries(
      labels: labels,
      expenseValues: expenseValues,
      incomeValues: incomeValues,
    );
  }

  ({double thisWeek, double lastWeek}) _buildWeeklyExpenseComparison(
    List<Expense> source,
  ) {
    final DateTime now = DateTime.now();
    final DateTime thisWeekStart = _startOfWeek(now);
    final DateTime thisWeekEnd = thisWeekStart.add(const Duration(days: 7));
    final DateTime lastWeekStart = thisWeekStart.subtract(
      const Duration(days: 7),
    );
    final DateTime lastWeekEnd = thisWeekStart;

    return (
      thisWeek: _sumExpenses(source, thisWeekStart, thisWeekEnd),
      lastWeek: _sumExpenses(source, lastWeekStart, lastWeekEnd),
    );
  }

  double _sumExpenses(List<Expense> source, DateTime start, DateTime end) {
    return source
        .where(
          (Expense e) =>
              _isInRange(e.date, start, end) && e.amount > 0 && !e.isTransfer,
        )
        .fold<double>(0, (double sum, Expense e) => sum + e.amount);
  }

  double _sumIncome(List<Expense> source, DateTime start, DateTime end) {
    return source
        .where(
          (Expense e) =>
              _isInRange(e.date, start, end) && e.amount < 0 && !e.isTransfer,
        )
        .fold<double>(0, (double sum, Expense e) => sum + e.amount.abs());
  }

  bool _isInRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && value.isBefore(end);
  }

  DateTime _startOfWeek(DateTime date) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  String _axisAmount(double value, String currencyCode) {
    final String symbol = CurrencyUtils.symbolOf(currencyCode);
    if (value >= 1000) {
      return '$symbol ${(value / 1000).toStringAsFixed(1)}k';
    }
    return '$symbol ${value.toStringAsFixed(0)}';
  }
}

class _CategorySlice {
  const _CategorySlice({
    required this.label,
    required this.percent,
    required this.amount,
    required this.color,
  });

  final String label;
  final double percent;
  final double amount;
  final Color color;
}

class _LineSeries {
  const _LineSeries({
    required this.labels,
    required this.expenseValues,
    required this.incomeValues,
  });

  final List<String> labels;
  final List<double> expenseValues;
  final List<double> incomeValues;

  bool get hasData {
    return expenseValues.any((double value) => value > 0) ||
        incomeValues.any((double value) => value > 0);
  }
}
