import 'package:flutter/material.dart';
import 'package:tims_data_exporter/models/data_model.dart';
import 'package:tims_data_exporter/screens/home_screen.dart';
import 'package:tims_data_exporter/widgets/file_generator.dart';

class ActionBottomSheet extends StatelessWidget {
  final DataModel? item;
  final List<DataModel> filteredData;
  final List<String> pdfPaths; // Added pdfPaths
  final void Function(String message, {NotificationType type}) showSnackBar;
  final void Function({required bool isProcessing, double progress}) setProcessing;
  final String? dbPath;
  final bool processWithDb;

  const ActionBottomSheet({
    super.key,
    this.item,
    required this.filteredData,
    required this.pdfPaths, // Added pdfPaths
    required this.showSnackBar,
    required this.setProcessing,
    this.dbPath,
    this.processWithDb = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FileGenerator.generateAllInvoices(
                context: context,
                filteredData: filteredData,
                showSnackBar: showSnackBar,
                setProcessing: setProcessing,
                pdfPaths: pdfPaths, // Pass pdfPaths
                dbPath: dbPath,
                processWithDb: processWithDb,
              );
            },
            child: const Text('Generate All Invoices'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FileGenerator.generateAllCreditNotes(
                context: context,
                filteredData: filteredData,
                showSnackBar: showSnackBar,
                setProcessing: setProcessing,
                pdfPaths: pdfPaths, // Pass pdfPaths
                dbPath: dbPath,
                processWithDb: processWithDb,
              );
            },
            child: const Text('Generate All Credit Notes'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FileGenerator.generateAllDocuments(
                context: context,
                filteredData: filteredData,
                showSnackBar: showSnackBar,
                setProcessing: setProcessing,
                pdfPaths: pdfPaths, // Pass pdfPaths
                dbPath: dbPath,
                processWithDb: processWithDb,
              );
            },
            child: const Text('Generate All Documents'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
