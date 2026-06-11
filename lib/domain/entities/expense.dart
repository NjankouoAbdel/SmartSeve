enum ExpenseCategory { food, transport, rent, shopping, bills, other }

extension ExpenseCategoryX on ExpenseCategory {
  String get label {
    return localizedLabel('en');
  }

  String localizedLabel(String localeCode) {
    final String code = localeCode.toLowerCase().replaceAll('_', '-').split('-').first;

    const Map<ExpenseCategory, Map<String, String>> labels =
        <ExpenseCategory, Map<String, String>>{
          ExpenseCategory.food: <String, String>{
            'en': 'Food',
            'fr': 'Alimentation',
            'ar': 'طعام',
            'es': 'Comida',
            'de': 'Essen',
            'it': 'Cibo',
            'pt': 'Comida',
            'ru': 'Еда',
            'tr': 'Yemek',
            'id': 'Makanan',
            'hi': 'भोजन',
            'zh': '餐饮',
            'ja': '食費',
            'ko': '식비',
            'nl': 'Eten',
          },
          ExpenseCategory.transport: <String, String>{
            'en': 'Transport',
            'fr': 'Transport',
            'ar': 'مواصلات',
            'es': 'Transporte',
            'de': 'Transport',
            'it': 'Trasporto',
            'pt': 'Transporte',
            'ru': 'Транспорт',
            'tr': 'Ulasim',
            'id': 'Transportasi',
            'hi': 'परिवहन',
            'zh': '交通',
            'ja': '交通',
            'ko': '교통',
            'nl': 'Vervoer',
          },
          ExpenseCategory.rent: <String, String>{
            'en': 'Rent',
            'fr': 'Loyer',
            'ar': 'إيجار',
            'es': 'Alquiler',
            'de': 'Miete',
            'it': 'Affitto',
            'pt': 'Aluguel',
            'ru': 'Аренда',
            'tr': 'Kira',
            'id': 'Sewa',
            'hi': 'किराया',
            'zh': '房租',
            'ja': '家賃',
            'ko': '월세',
            'nl': 'Huur',
          },
          ExpenseCategory.shopping: <String, String>{
            'en': 'Shopping',
            'fr': 'Shopping',
            'ar': 'تسوق',
            'es': 'Compras',
            'de': 'Einkaufen',
            'it': 'Shopping',
            'pt': 'Compras',
            'ru': 'Покупки',
            'tr': 'Alisveris',
            'id': 'Belanja',
            'hi': 'खरीदारी',
            'zh': '购物',
            'ja': '買い物',
            'ko': '쇼핑',
            'nl': 'Winkelen',
          },
          ExpenseCategory.bills: <String, String>{
            'en': 'Bills',
            'fr': 'Factures',
            'ar': 'فواتير',
            'es': 'Facturas',
            'de': 'Rechnungen',
            'it': 'Bollette',
            'pt': 'Contas',
            'ru': 'Счета',
            'tr': 'Faturalar',
            'id': 'Tagihan',
            'hi': 'बिल',
            'zh': '账单',
            'ja': '請求',
            'ko': '청구서',
            'nl': 'Rekeningen',
          },
          ExpenseCategory.other: <String, String>{
            'en': 'Other',
            'fr': 'Autre',
            'ar': 'أخرى',
            'es': 'Otro',
            'de': 'Andere',
            'it': 'Altro',
            'pt': 'Outro',
            'ru': 'Другое',
            'tr': 'Diger',
            'id': 'Lainnya',
            'hi': 'अन्य',
            'zh': '其他',
            'ja': 'その他',
            'ko': '기타',
            'nl': 'Overig',
          },
        };

    return labels[this]?[code] ?? labels[this]!['en']!;
  }

  String get key {
    return name;
  }

  static ExpenseCategory fromKey(String value) {
    return ExpenseCategory.values.firstWhere(
      (ExpenseCategory category) => category.name == value,
      orElse: () => ExpenseCategory.other,
    );
  }
}

class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
    required this.currencyCode,
    this.accountId = 'main',
    this.customCategoryId,
    this.customCategoryName,
    this.customCategoryIconCodePoint,
    this.customCategoryColorValue,
    this.isTransfer = false,
    this.transferGroupId,
  });

  final String id;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final String note;
  final String currencyCode;
  final String accountId;
  final String? customCategoryId;
  final String? customCategoryName;
  final int? customCategoryIconCodePoint;
  final int? customCategoryColorValue;
  final bool isTransfer;
  final String? transferGroupId;

  bool get isCustomCategory {
    return customCategoryName != null && customCategoryName!.trim().isNotEmpty;
  }

  String categoryLabel(String localeCode) {
    if (isCustomCategory) {
      return customCategoryName!.trim();
    }
    return category.localizedLabel(localeCode);
  }
}
