import 'package:flutter/material.dart';

/// Which slice of the order list is showing.
enum OrderFilter { active, roomService, today, all }

/// The filter chips above the order list.
///
/// Scrolls horizontally. The four labels plus the theme's generous chip
/// padding need roughly 500 logical pixels, which is wider than any phone we
/// ship to — a plain [Row] overflowed even on a 440pt Pro Max, and staff
/// running a large system text size made it worse. Scrolling is also the
/// Material pattern for a filter set that cannot fit.
///
/// Not [Wrap]: a second row of chips would push the list down and move the
/// first ticket off the top of the screen, which is the one thing a kitchen
/// queue cannot afford.
class OrderFilterBar extends StatelessWidget {
  final OrderFilter filter;
  final ValueChanged<OrderFilter> onChanged;

  const OrderFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  static const _labels = <(OrderFilter, String)>[
    (OrderFilter.active, 'In the kitchen'),
    (OrderFilter.roomService, 'Room service'),
    (OrderFilter.today, 'Today'),
    (OrderFilter.all, 'All'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Padding on the scroll view, not inside it, so the first and last chip
      // can still scroll clear of the edge instead of being clipped by it.
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (final (f, label) in _labels) ...[
            ChoiceChip(
              label: Text(label),
              selected: filter == f,
              onSelected: (_) => onChanged(f),
            ),
            if (f != _labels.last.$1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
