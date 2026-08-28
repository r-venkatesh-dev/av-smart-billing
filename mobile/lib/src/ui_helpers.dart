import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
String money(int paise) => currency.format(paise / 100);

String formatQuantity(num value) {
  final number = value.toDouble();
  if (number == number.roundToDouble()) return number.toInt().toString();
  return number.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

String readableUnit(String value, {num quantity = 2}) {
  final unit = value.trim();
  if (unit.isEmpty || double.tryParse(unit) != null || unit.length > 16) {
    return quantity.toDouble() == 1 ? 'item' : 'items';
  }
  return unit;
}

String stockLabel(num quantity, String unit) =>
    'Stock: ${formatQuantity(quantity)}';
        // 'Stock: ${formatQuantity(quantity)} - ${readableUnit(unit, quantity: quantity)}';

String formatPercent(num value) => '${formatQuantity(value)}%';

String errorMessage(Object error) {
  final message = error.toString();
  for (final prefix in const [
    'FormatException: ',
    'DatabaseException(',
    'Exception: ',
  ]) {
    if (message.startsWith(prefix)) {
      return message
          .substring(prefix.length)
          .replaceFirst(RegExp(r'\)\s*$'), '');
    }
  }
  return message;
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : null,
    ),
  );
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.icon,
    required this.title,
    this.content,
    this.actions = const [],
    this.danger = false,
    this.showClose = true,
    this.contentPadding = const EdgeInsets.fromLTRB(22, 14, 22, 6),
  });

  final IconData icon;
  final Widget title;
  final Widget? content;
  final List<Widget> actions;
  final bool danger;
  final bool showClose;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = danger ? theme.colorScheme.error : const Color(0xff057c73);
    final iconBackground = danger
        ? theme.colorScheme.errorContainer
        : const Color(0xffe6f2f0);
    final dialogWidth = (MediaQuery.sizeOf(context).width - 40)
        .clamp(280.0, 520.0)
        .toDouble();

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 14, 0),
              child: SizedBox(
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accent, size: 31),
                    ),
                    if (showClose)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          tooltip: 'Close dialog',
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xff202623),
                  fontWeight: FontWeight.w800,
                ),
                child: title,
              ),
            ),
            if (content != null)
              Flexible(
                fit: FlexFit.loose,
                child: Padding(padding: contentPadding, child: content),
              ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    for (var index = 0; index < actions.length; index++) ...[
                      if (index > 0) const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: FilledButtonTheme(
                            data: FilledButtonThemeData(
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            child: TextButtonTheme(
                              data: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: accent,
                                  side: BorderSide(color: accent),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              child: actions[index],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    ),
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 44,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          const Text(
            'Something went wrong',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
