import 'package:wfer_flousk_firebase/domain/repositories/expense_repository.dart';

class DeleteExpenseUseCase {
  DeleteExpenseUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<void> call(String id) {
    return _repository.deleteExpense(id);
  }
}

