import 'package:flutter/material.dart';

class OnlineFoundationScreen extends StatelessWidget {
  const OnlineFoundationScreen({
    super.key,
    required this.title,
    required this.drawer,
  });

  final String title;
  final Widget drawer;

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: drawer,
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xffe6f2f0),
                    child: Icon(
                      Icons.cloud_done_outlined,
                      size: 36,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Online Mode – Stage 1',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Online Products and Customers are ready in this first stage. Online sales, invoices, dashboard and reports will be enabled in the next stage after their transaction-safe APIs are completed.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This screen is intentionally unavailable online for now, so no billing record can be saved to the wrong database.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
