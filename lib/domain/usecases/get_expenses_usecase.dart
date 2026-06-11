import 'package:wfer_flousk_firebase/domain/entities/expense.dart';
import 'package:wfer_flousk_firebase/domain/repositories/expense_repository.dart';

class GetExpensesUseCase {
  GetExpensesUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<List<Expense>> call() {
    return _repository.getExpenses();
  }
}

