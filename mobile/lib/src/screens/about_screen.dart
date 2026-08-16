import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About App')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              'assets/branding/av-smartbilling-icon-concept-3.png',
              width: 112,
              height: 112,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'AV Smartbilling',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Version 1.0.0',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 28),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simple billing, even without internet',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'AV Smartbilling is an offline-first billing app for creating invoices, managing products and customers, and tracking everyday sales from your Android phone.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.cloud_off_outlined),
                title: Text('Offline-first'),
                subtitle: Text(
                  'Keep billing when the internet is unavailable.',
                ),
              ),
              Divider(height: 1, indent: 72),
              ListTile(
                leading: Icon(Icons.qr_code_scanner),
                title: Text('Fast barcode scanning'),
                subtitle: Text('Scan products directly into a new bill.'),
              ),
              Divider(height: 1, indent: 72),
              ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Data stays on this phone'),
                subtitle: Text(
                  'Product, customer and invoice data is stored locally.',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
