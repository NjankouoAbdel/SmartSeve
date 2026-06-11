import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wfer_flousk_firebase/core/services/firebase_data_service.dart';
import 'package:wfer_flousk_firebase/data/models/expense_model.dart';

abstract class ExpenseLocalDataSource {
  Future<List<ExpenseModel>> getAllExpenses();
  Future<void> addExpense(ExpenseModel expense);
  Future<void> updateExpense(ExpenseModel expense);
  Future<void> deleteExpense(String id);
}

class ExpenseLocalDataSourceImpl implements ExpenseLocalDataSource {
  ExpenseLocalDataSourceImpl(this._firebaseDataService);

  final FirebaseDataService _firebaseDataService;

  @override
  Future<List<ExpenseModel>> getAllExpenses() async {
    final CollectionReference<Map<String, dynamic>> collection =
        await _firebaseDataService.expensesCollection();
    final QuerySnapshot<Map<String, dynamic>> snapshot = await collection.get();

    final List<ExpenseModel> expenses = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data = <String, dynamic>{
            ...doc.data(),
            if (!(doc.data().containsKey('id'))) 'id': doc.id,
          };
          return ExpenseModel.fromMap(data);
        })
        .toList(growable: false);

    expenses.sort((ExpenseModel a, ExpenseModel b) => b.date.compareTo(a.date));
    return expenses;
  }

  @override
  Future<void> addExpense(ExpenseModel expense) async {
    final CollectionReference<Map<String, dynamic>> collection =
        await _firebaseDataService.expensesCollection();
    await collection.doc(expense.id).set(
      <String, dynamic>{
        ...expense.toMap(),
        'id': expense.id,
      },
    );
  }

  @override
  Future<void> updateExpense(ExpenseModel expense) async {
    final CollectionReference<Map<String, dynamic>> collection =
        await _firebaseDataService.expensesCollection();
    await collection.doc(expense.id).set(
      <String, dynamic>{
        ...expense.toMap(),
        'id': expense.id,
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> deleteExpense(String id) async {
    final CollectionReference<Map<String, dynamic>> collection =
        await _firebaseDataService.expensesCollection();
    await collection.doc(id).delete();
  }
}

