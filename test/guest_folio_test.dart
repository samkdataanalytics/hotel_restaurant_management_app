import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/domain/entities/booking.dart';
import 'package:hotel_checkin/domain/entities/expense.dart';
import 'package:hotel_checkin/domain/entities/menu_item.dart';
import 'package:hotel_checkin/domain/entities/restaurant_order.dart';
import 'package:hotel_checkin/staff_mobile/data/front_desk_repository.dart';

ArrivalEntry _stay({double roomTotal = 20000}) => ArrivalEntry(
      booking: Booking(
        id: 'b1',
        bookingRef: 'BK-0001',
        guestId: 'g1',
        roomId: 'r1',
        checkInDate: DateTime(2026, 9, 12),
        checkOutDate: DateTime(2026, 9, 15),
        status: BookingStatus.checkedIn,
        numberOfGuests: 2,
        totalAmount: roomTotal,
      ),
    );

RestaurantOrder _order(double amount) => RestaurantOrder(
      id: 'o1',
      orderNumber: '1',
      type: OrderType.roomService,
      createdAt: DateTime(2026, 9, 13),
      paymentStatus: PaymentStatus.chargedToRoom,
      items: [
        OrderItem(
          id: 'li1',
          menuItem: MenuItem(
            id: 'm1',
            name: 'Club Sandwich',
            description: '',
            price: amount,
            category: 'Mains',
          ),
        ),
      ],
    );

Expense _expense(double amount, {bool billable = true}) => Expense(
      id: 'e1',
      description: 'Minibar',
      amount: amount,
      category: ExpenseCategory.other,
      date: DateTime(2026, 9, 13),
      isBillable: billable,
    );

void main() {
  group('GuestFolio', () {
    test('the room charge alone is the total when nothing else is billed', () {
      final folio = GuestFolio(stay: _stay(roomTotal: 20000));
      expect(folio.total, 20000);
    });

    test('adds restaurant orders billed to the room', () {
      final folio = GuestFolio(
        stay: _stay(roomTotal: 20000),
        restaurantOrders: [_order(3500)],
      );
      expect(folio.restaurantTotal, 3500);
      expect(folio.total, 23500);
    });

    test('adds billable expenses', () {
      final folio = GuestFolio(
        stay: _stay(roomTotal: 20000),
        expenses: [_expense(1200)],
      );
      expect(folio.expensesTotal, 1200);
      expect(folio.total, 21200);
    });

    test('excludes non-billable expenses from what the guest owes', () {
      // An internal cost recorded against the room is the hotel's, not the
      // guest's — billing it would overcharge them.
      final folio = GuestFolio(
        stay: _stay(roomTotal: 20000),
        expenses: [_expense(1200, billable: false)],
      );
      expect(folio.expensesTotal, 0);
      expect(folio.total, 20000);
    });

    test('sums all three sources together', () {
      final folio = GuestFolio(
        stay: _stay(roomTotal: 20000),
        restaurantOrders: [_order(3500)],
        expenses: [_expense(1200), _expense(800, billable: false)],
      );
      expect(folio.total, 24700);
    });

    test('a stay with no charges at all reads as empty', () {
      final folio = GuestFolio(stay: _stay(roomTotal: 0));
      expect(folio.isEmpty, isTrue);
      expect(folio.total, 0);
    });
  });
}
