import '../../domain/entities/expense.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/supabase_data_source.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final SupabaseDataSource _dataSource;

  ExpenseRepositoryImpl(this._dataSource);

  @override
  Future<List<Expense>> getAllExpenses() => _dataSource.getAllExpenses();

  @override
  Future<List<Expense>> getExpenses() => _dataSource.getAllExpenses();

  @override
  Future<List<Expense>> getRoomExpenses(String roomId) => _dataSource.getRoomExpenses(roomId);

  @override
  Future<List<Expense>> getExpensesByBookingId(String bookingId) => _dataSource.getExpensesByBookingId(bookingId);

  @override
  Future<void> insertExpense(Expense expense) => _dataSource.insertExpense(expense);

  @override
  Future<void> addExpense(Expense expense) => _dataSource.insertExpense(expense);

  @override
  Future<void> updateExpense(Expense expense) => _dataSource.updateExpense(expense);

  @override
  Future<void> deleteExpense(String id) => _dataSource.deleteExpense(id);
}
