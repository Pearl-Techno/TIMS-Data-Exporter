import 'package:intl/intl.dart';

class CSVComparisonModel {
  final String controlCode;
  final double amount;
  final bool foundInTable;
  final String? tableTsNum;
  final DateTime? tableDate;
  final double? tableAmount;

  CSVComparisonModel({
    required this.controlCode,
    required this.amount,
    required this.foundInTable,
    this.tableTsNum,
    this.tableDate,
    this.tableAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'Control Code': controlCode,
      'CSV Amount': amount,
      'Found in Table': foundInTable ? 'Yes' : 'No',
      'Table TS Num': tableTsNum ?? 'N/A',
      'Table Date': tableDate != null
          ? DateFormat('dd/MM/yyyy').format(tableDate!)
          : 'N/A',
      'Table Amount': tableAmount?.toStringAsFixed(2) ?? 'N/A',
    };
  }
}

class ComparisonResult {
  final List<CSVComparisonModel> missingFromTable;
  final List<CSVComparisonModel> missingFromCSV;
  final int totalInCSV;
  final int totalInTable;
  final int matched;

  ComparisonResult({
    required this.missingFromTable,
    required this.missingFromCSV,
    required this.totalInCSV,
    required this.totalInTable,
    required this.matched,
  });
}
