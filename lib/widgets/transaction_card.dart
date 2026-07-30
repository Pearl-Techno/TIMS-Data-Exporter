import 'package:flutter/material.dart';
import 'package:tims_data_exporter/models/data_model.dart';

class TransactionCard extends StatelessWidget {
  final DataModel item;
  final String pdfPath; // Added pdfPath
  final VoidCallback onGenerateInvoice;
  final VoidCallback onGenerateCreditNote;

  const TransactionCard({
    super.key,
    required this.item,
    required this.pdfPath, // Added pdfPath
    required this.onGenerateInvoice,
    required this.onGenerateCreditNote,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction #${item.tsNum}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Buyer PIN: ${item.buyerPIN ?? 'N/A'}'),
            Text('Total Amount: KES ${item.totalAmount?.toStringAsFixed(2) ?? '0.00'}'),
            const SizedBox(height: 8),
            if (item.itemDetails != null && item.itemDetails!.isNotEmpty) ...[
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...item.itemDetails!.map((detail) => Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                    child: Text(
                        '${detail.description}: ${detail.quantity} x KES ${detail.unitPrice.toStringAsFixed(2)} = KES ${detail.itemAmount.toStringAsFixed(2)}'),
                  )),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: onGenerateInvoice,
                  child: const Text('Generate Invoice'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onGenerateCreditNote,
                  child: const Text('Generate Credit Note'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
