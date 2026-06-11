import 'package:wfer_flousk_firebase/data/datasources/expense_local_datasource.dart';
import 'package:wfer_flousk_firebase/data/models/expense_model.dart';
import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/domain/repositories/expense_repository.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(this._localDataSource);

  final ExpenseLocalDataSource _localDataSource;

  @override
  Future<void> addExpense(Expense expense) {
    return _localDataSource.addExpense(ExpenseModel.fromEntity(expense));
  }

  @override
  Future<void> updateExpense(Expense expense) {
    return _localDataSource.updateExpense(ExpenseModel.fromEntity(expense));
  }

  @override
  Future<void> deleteExpense(String id) {
    return _localDataSource.deleteExpense(id);
  }

  @override
  Future<List<Expense>> getExpenses() async {
    final List<ExpenseModel> models = await _localDataSource.getAllExpenses();
    return models.map((ExpenseModel model) => model.toEntity()).toList();
  }
}

