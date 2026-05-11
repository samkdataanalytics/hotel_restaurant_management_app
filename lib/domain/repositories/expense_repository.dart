import '../entities/expense.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> getAllExpenses();
  Future<List<Expense>> getExpenses();
  Future<List<Expense>> getRoomExpenses(String roomId);
  Future<List<Expense>> getExpensesByBookingId(String bookingId);
  Future<void> insertExpense(Expense expense);
  Future<void> addExpense(Expense expense);
  Future<void> updateExpense(Expense expense);
  Future<void> deleteExpense(String id);
}
