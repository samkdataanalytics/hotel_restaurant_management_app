import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Reusable Cash + Card split-payment input panel.
///
/// Typing in one field auto-fills the other so they always sum to [total].
/// The [onChanged] callback fires whenever either amount changes.
class SplitPaymentInputs extends StatelessWidget {
  final double total;
  final NumberFormat currency;
  final TextEditingController cashCtrl;
  final TextEditingController cardCtrl;
  final double cashAmount;
  final double cardAmount;
  final void Function(double cash, double card) onChanged;

  const SplitPaymentInputs({
    super.key,
    required this.total,
    required this.currency,
    required this.cashCtrl,
    required this.cardCtrl,
    required this.cashAmount,
    required this.cardAmount,
    required this.onChanged,
  });

  void _onCashChanged(String v) {
    final cash = double.tryParse(v.trim()) ?? 0.0;
    final card = (total - cash).clamp(0.0, total);
    cardCtrl.text = card.toStringAsFixed(2);
    onChanged(cash, card);
  }

  void _onCardChanged(String v) {
    final card = double.tryParse(v.trim()) ?? 0.0;
    final cash = (total - card).clamp(0.0, total);
    cashCtrl.text = cash.toStringAsFixed(2);
    onChanged(cash, card);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = total - cashAmount - cardAmount;
    final balanced = remaining.abs() < 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _splitRow(
          icon: Icons.money_rounded,
          label: 'Cash',
          color: Colors.green.shade600,
          ctrl: cashCtrl,
          onChanged: _onCashChanged,
          onQuickFill: () {
            cashCtrl.text = total.toStringAsFixed(2);
            cardCtrl.text = '0.00';
            onChanged(total, 0);
          },
        ),
        const SizedBox(height: 10),
        _splitRow(
          icon: Icons.credit_card_rounded,
          label: 'Card',
          color: Colors.blue.shade600,
          ctrl: cardCtrl,
          onChanged: _onCardChanged,
          onQuickFill: () {
            cardCtrl.text = total.toStringAsFixed(2);
            cashCtrl.text = '0.00';
            onChanged(0, total);
          },
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: balanced ? const Color(0xFFF0FFF4) : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: balanced ? Colors.green.shade300 : Colors.amber.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                balanced ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 16,
                color: balanced ? const Color(0xFF22C55E) : Colors.amber.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: balanced
                    ? Text(
                        'Balanced  ·  ${currency.format(cashAmount)} cash + ${currency.format(cardAmount)} card',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700),
                      )
                    : Text(
                        remaining > 0
                            ? 'Still to allocate: ${currency.format(remaining.abs())}'
                            : 'Over-allocated by: ${currency.format(remaining.abs())}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade800),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _splitRow({
    required IconData icon,
    required String label,
    required Color color,
    required TextEditingController ctrl,
    required ValueChanged<String> onChanged,
    required VoidCallback onQuickFill,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: '0.00',
                labelText: label,
                labelStyle: TextStyle(fontSize: 12, color: color),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: color.withAlpha(100)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: color, width: 1.5),
                ),
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onQuickFill,
          style: TextButton.styleFrom(
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Full',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// A pill-shaped toggle that activates split payment mode.
class SplitPaymentToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const SplitPaymentToggle({super.key, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.purple.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.purple.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call_split_rounded,
                size: 14,
                color: active ? Colors.purple.shade600 : Colors.grey.shade500),
            const SizedBox(width: 4),
            Text('Split',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.purple.shade600 : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
