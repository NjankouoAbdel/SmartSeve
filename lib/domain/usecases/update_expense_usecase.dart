import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/domain/repositories/expense_repository.dart';

class UpdateExpenseUseCase {
  UpdateExpenseUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<void> call(Expense expense) {
    return _repository.updateExpense(expense);
  }
}

