import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import '../models/data_model.dart';
import '../data/database_helper.dart';

enum CSVTemplate {
  standard, // Original format: Column E = Control Code, Column G = Amount
  vatRegistered, // VAT Registered Customers: Column A = PIN, Column B = Name, Column E = Control Code, Column G = Amount
}

class CSVComparisonDialog extends StatefulWidget {
  final DatabaseHelper? dbHelper;
  final DateTime? monthFilter;

  const CSVComparisonDialog({
    super.key,
    required this.dbHelper,
    this.monthFilter,
  });

  @override
  State<CSVComparisonDialog> createState() => _CSVComparisonDialogState();
}

class _CSVComparisonDialogState extends State<CSVComparisonDialog> {
  ComparisonResult? _comparisonResult;
  bool _isLoading = false;
  String? _selectedFileName;
  String _activeTab = 'matched';
  String _progressMessage = '';
  CSVTemplate _selectedTemplate = CSVTemplate.standard;

  // Export selection
  bool _exportMatched = true;
  bool _exportMissingFromSystem = true;
  bool _exportMissingFromCSV = false;

  // Pagination for results
  int _matchedPage = 1;
  int _missingFromTablePage = 1;
  int _missingFromCSVPage = 1;
  final int _pageSize = 50;

  static const double vatRate = 0.16; // 16% VAT

  static const Color _primary = Color(0xFF2563EB);
  static const Color _success = Color(0xFF10B981);
  static const Color _error = Color(0xFFEF4444);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _info = Color(0xFF3B82F6);
  static const Color _surfaceVariant = Color(0xFFF3F4F6);
  static const Color _textSecondary = Color(0xFF6B7280);

  Future<Directory> _getExportDirectory() async {
    const String exportPath = r'C:\DTR APP\CSV Comparison';
    final Directory directory = Directory(exportPath);

    if (!await directory.exists()) {
      await directory.create(recursive: true);
      if (kDebugMode) {
        print('Created directory: $exportPath');
      }
    }

    return directory;
  }

  String _formatControlCodeForDisplay(String code) {
    String cleaned = code.trim();
    if (cleaned.startsWith('|')) {
      cleaned = cleaned.substring(1);
    }
    return '|$cleaned';
  }

  String _formatTsNumForDisplay(String tsNum) {
    return '"$tsNum"';
  }

  // Calculate VAT amount from total (16% of total)
  double _calculateVATAmount(double totalAmount) {
    return totalAmount * vatRate;
  }

  // Calculate amount excluding VAT
  double _calculateExcludingVAT(double totalAmount) {
    return totalAmount / (1 + vatRate);
  }

  List<List<String>> _parseCSV(String rawData) {
    List<List<String>> result = [];
    List<String> lines = rawData.split('\n');

    for (String line in lines) {
      if (line.trim().isEmpty) continue;
      List<String> row = [];
      StringBuffer current = StringBuffer();
      bool inQuotes = false;

      for (int i = 0; i < line.length; i++) {
        String char = line[i];
        if (char == '"') {
          inQuotes = !inQuotes;
        } else if (char == ',' && !inQuotes) {
          row.add(current.toString().trim());
          current.clear();
        } else {
          current.write(char);
        }
      }
      row.add(current.toString().trim());
      result.add(row);
    }

    return result;
  }

  String _convertToCSV(List<List<String>> data) {
    StringBuffer buffer = StringBuffer();
    for (var row in data) {
      for (int i = 0; i < row.length; i++) {
        String cell = row[i];
        if (cell.contains(',') ||
            cell.contains('"') ||
            cell.startsWith('0') ||
            cell.startsWith('|')) {
          cell = '"${cell.replaceAll('"', '""')}"';
        }
        buffer.write(cell);
        if (i < row.length - 1) buffer.write(',');
      }
      buffer.write('\n');
    }
    return buffer.toString();
  }

  String _cleanControlCode(String code) {
    String cleaned = code.trim();
    if (cleaned.startsWith('|')) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.endsWith('|')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  Future<void> _pickAndCompareCSV() async {
    if (widget.dbHelper == null) {
      _showSnackBar('Database not connected', _error);
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _progressMessage = 'Reading CSV file...';
      });

      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) {
        setState(() => _isLoading = false);
        return;
      }

      _selectedFileName = result.files.first.name;
      String filePath = result.files.first.path!;
      File file = File(filePath);
      String rawData = await file.readAsString();

      setState(() => _progressMessage = 'Parsing CSV data...');
      List<List<String>> csvData = _parseCSV(rawData);

      if (csvData.isEmpty || csvData.length < 2) {
        _showSnackBar('CSV file is empty or invalid', _error);
        setState(() => _isLoading = false);
        return;
      }

      List<String> headers = csvData[0];

      // Validate based on template selection
      if (_selectedTemplate == CSVTemplate.standard) {
        if (headers.length < 7) {
          _showSnackBar(
              'Standard CSV must have at least 7 columns (Column E for Control Code, Column G for Amount)',
              _error);
          setState(() => _isLoading = false);
          return;
        }
      } else {
        if (headers.length < 7) {
          _showSnackBar(
              'VAT Registered CSV must have at least 7 columns (Column A=PIN, Column B=Name, Column E=Control Code, Column G=Amount)',
              _error);
          setState(() => _isLoading = false);
          return;
        }
      }

      setState(() => _progressMessage =
          'Extracting control codes, buyer info and amounts from CSV...');
      Map<String, CSVRecord> csvRecords = {};

      for (int i = 1; i < csvData.length; i++) {
        // Both templates use Column G (index 6) for amount
        if (csvData[i].length > 6) {
          String controlCode = _cleanControlCode(csvData[i][4].toString());
          double amount = 0.0;
          String amountStr = csvData[i][6].toString().trim();
          amountStr = amountStr.replaceAll(RegExp(r'[^0-9.-]'), '');
          amount = double.tryParse(amountStr) ?? 0.0;

          // Extract buyer PIN and Name for VAT Registered template
          String buyerPIN = '';
          String buyerName = '';
          if (_selectedTemplate == CSVTemplate.vatRegistered) {
            if (csvData[i].isNotEmpty) {
              buyerPIN = csvData[i][0].toString().trim();
            }
            if (csvData[i].length > 1) {
              buyerName = csvData[i][1].toString().trim();
            }
          }

          if (controlCode.isNotEmpty) {
            csvRecords[controlCode] = CSVRecord(
              controlCode: controlCode,
              amount: amount,
              rowIndex: i,
              buyerPIN: buyerPIN,
              buyerName: buyerName,
            );
          }
        }
      }

      if (csvRecords.isEmpty) {
        _showSnackBar('No valid control codes found in CSV', _error);
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _progressMessage = 'Comparing with database records...');

      List<String> allControlCodes =
          await widget.dbHelper!.getAllControlCodes();
      Set<String> dbControlCodes = Set.from(allControlCodes);
      Map<String, DataModel> tableRecords = {};
      Set<String> controlCodesToFetch = csvRecords.keys.toSet();
      controlCodesToFetch.retainAll(dbControlCodes);

      if (controlCodesToFetch.isNotEmpty) {
        setState(() => _progressMessage =
            'Fetching matched transaction details (${controlCodesToFetch.length} records)...');
        tableRecords = await widget.dbHelper!
            .getTransactionsByControlCodes(controlCodesToFetch.toList());
      }

      List<MatchedRecord> matchedRecords = [];
      List<CSVComparisonModel> missingFromTable = [];
      List<CSVComparisonModel> missingFromCSV = [];
      double totalMissingFromTableAmount = 0.0;

      for (var entry in csvRecords.entries) {
        if (tableRecords.containsKey(entry.key)) {
          DataModel tableRecord = tableRecords[entry.key]!;
          double tableTotal = tableRecord.totalAmount ?? 0;
          double tableExcludingVAT = _calculateExcludingVAT(tableTotal);
          double tableVATAmount = _calculateVATAmount(tableExcludingVAT);

          // CSV amount is VAT-exclusive, so compare with table amount excluding VAT
          double amountDifference = entry.value.amount - tableExcludingVAT;

          matchedRecords.add(MatchedRecord(
            controlCode: entry.key,
            csvAmount: entry.value.amount,
            tableAmount: tableTotal,
            tableAmountExcludingVAT: tableExcludingVAT,
            tableVATAmount: tableVATAmount,
            amountDifference: amountDifference,
            tsNum: tableRecord.tsNum,
            date: tableRecord.date,
            buyerPIN: entry.value.buyerPIN,
            buyerName: entry.value.buyerName,
            systemBuyerPIN: tableRecord.buyerPIN,
          ));
        } else {
          totalMissingFromTableAmount += entry.value.amount;
          missingFromTable.add(CSVComparisonModel(
            controlCode: entry.key,
            amount: entry.value.amount,
            foundInTable: false,
            buyerPIN: entry.value.buyerPIN,
            buyerName: entry.value.buyerName,
          ));
        }
      }

      Set<String> csvControlCodesSet = csvRecords.keys.toSet();
      Set<String> missingFromCSVCodes =
          dbControlCodes.difference(csvControlCodesSet);
      double totalMissingFromCSVAmount = 0.0;
      int totalMissingFromCSV = missingFromCSVCodes.length;
      List<String> limitedMissingCodes =
          missingFromCSVCodes.take(1000).toList();

      if (limitedMissingCodes.isNotEmpty) {
        setState(
            () => _progressMessage = 'Fetching missing from CSV details...');
        Map<String, DataModel> missingTransactions = await widget.dbHelper!
            .getTransactionsByControlCodes(limitedMissingCodes);
        for (var entry in missingTransactions.entries) {
          totalMissingFromCSVAmount += entry.value.totalAmount ?? 0;
          missingFromCSV.add(CSVComparisonModel(
            controlCode: entry.key,
            amount: 0.0,
            foundInTable: true,
            tableTsNum: entry.value.tsNum,
            tableDate: entry.value.date,
            tableAmount: entry.value.totalAmount,
            tableAmountExcludingVAT:
                _calculateExcludingVAT(entry.value.totalAmount ?? 0),
            tableVATAmount: _calculateVATAmount(
                _calculateExcludingVAT(entry.value.totalAmount ?? 0)),
            systemBuyerPIN: entry.value.buyerPIN,
          ));
        }
      }

      setState(() {
        _comparisonResult = ComparisonResult(
          matchedRecords: matchedRecords,
          missingFromTable: missingFromTable,
          missingFromCSV: missingFromCSV,
          totalInCSV: csvRecords.length,
          totalInTable: dbControlCodes.length,
          matched: matchedRecords.length,
          totalMissingFromCSV: totalMissingFromCSV,
          totalMissingFromTableAmount: totalMissingFromTableAmount,
          totalMissingFromCSVAmount: totalMissingFromCSVAmount,
        );
        _matchedPage = 1;
        _missingFromTablePage = 1;
        _missingFromCSVPage = 1;
      });

      String templateName = _selectedTemplate == CSVTemplate.standard
          ? 'Standard'
          : 'VAT Registered';
      _showSnackBar(
          '[$templateName Template] Comparison complete! Found ${matchedRecords.length} matches, '
          '${missingFromTable.length} missing from system (KES ${NumberFormat('#,##0.00').format(totalMissingFromTableAmount)}), '
          '$totalMissingFromCSV missing from CSV (showing first 1000)',
          _success);
    } catch (e) {
      _showSnackBar('Error processing CSV: $e', _error);
      debugPrint('CSV Comparison Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showExportOptionsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Options'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text('Matched Records'),
                  subtitle: Text(
                      '${_comparisonResult!.matchedRecords.length} records'),
                  value: _exportMatched,
                  onChanged: (value) {
                    setStateDialog(() {
                      _exportMatched = value ?? false;
                    });
                  },
                  activeColor: _success,
                ),
                CheckboxListTile(
                  title: const Text('Missing from System (in CSV only)'),
                  subtitle: Text(
                      '${_comparisonResult!.missingFromTable.length} records - Total: KES ${NumberFormat('#,##0.00').format(_comparisonResult!.totalMissingFromTableAmount)}'),
                  value: _exportMissingFromSystem,
                  onChanged: (value) {
                    setStateDialog(() {
                      _exportMissingFromSystem = value ?? false;
                    });
                  },
                  activeColor: _error,
                ),
                CheckboxListTile(
                  title: const Text('Missing from CSV (in System only)'),
                  subtitle: Text(
                      '${_comparisonResult!.totalMissingFromCSV} records - Total: KES ${NumberFormat('#,##0.00').format(_comparisonResult!.totalMissingFromCSVAmount)}'),
                  value: _exportMissingFromCSV,
                  onChanged: (value) {
                    setStateDialog(() {
                      _exportMissingFromCSV = value ?? false;
                    });
                  },
                  activeColor: _warning,
                ),
                const Divider(),
                if (!_exportMatched &&
                    !_exportMissingFromSystem &&
                    !_exportMissingFromCSV)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Please select at least one option to export',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_exportMatched ||
                  _exportMissingFromSystem ||
                  _exportMissingFromCSV) {
                Navigator.pop(context);
                _exportComparisonToCSV();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
            ),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportComparisonToCSV() async {
    if (_comparisonResult == null) return;

    try {
      final directory = await _getExportDirectory();
      final exportDateTime = DateTime.now();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(exportDateTime);
      final templateName = _selectedTemplate == CSVTemplate.standard
          ? 'Standard'
          : 'VAT_Registered';
      final fileName = 'CSV_Comparison_${templateName}_$timestamp.csv';
      final filePath = '${directory.path}/$fileName';

      List<List<String>> csvData = [];

      // ========== HEADER SECTION ==========
      csvData.add(['CSV COMPARISON REPORT']);
      csvData.add(['']);
      csvData.add(['EXPORT INFORMATION']);
      csvData.add(
          ['Export Date:', DateFormat('dd/MM/yyyy').format(exportDateTime)]);
      csvData
          .add(['Export Time:', DateFormat('HH:mm:ss').format(exportDateTime)]);
      csvData.add(['Export Timestamp:', timestamp]);
      csvData.add(['CSV Template Used:', templateName]);
      csvData.add(['Source CSV File:', _selectedFileName ?? 'N/A']);
      csvData.add(['Database:', 'Connected']);
      csvData.add(['VAT Rate:', '16%']);
      csvData.add([
        'Note:',
        'CSV amounts are VAT-exclusive. System amounts include 16% VAT.'
      ]);
      if (widget.monthFilter != null) {
        csvData.add([
          'Month Filter:',
          DateFormat('MMMM yyyy').format(widget.monthFilter!)
        ]);
      }
      csvData.add(['']);
      csvData.add(['SUMMARY']);
      csvData.add(
          ['Total CSV Records:', _comparisonResult!.totalInCSV.toString()]);
      csvData.add([
        'Total System Records:',
        _comparisonResult!.totalInTable.toString()
      ]);
      csvData.add(['Matched Records:', _comparisonResult!.matched.toString()]);
      csvData.add([
        'Missing from System:',
        _comparisonResult!.missingFromTable.length.toString()
      ]);
      csvData.add([
        'Missing from System Total Amount:',
        'KES ${NumberFormat('#,##0.00').format(_comparisonResult!.totalMissingFromTableAmount)}'
      ]);
      csvData.add([
        'Missing from CSV:',
        _comparisonResult!.totalMissingFromCSV.toString()
      ]);
      csvData.add([
        'Missing from CSV Total Amount:',
        'KES ${NumberFormat('#,##0.00').format(_comparisonResult!.totalMissingFromCSVAmount)}'
      ]);
      csvData.add(['']);
      csvData.add(['']);

      // ========== DATA HEADER ==========
      if (_selectedTemplate == CSVTemplate.vatRegistered) {
        csvData.add([
          'Comparison Type',
          'Buyer PIN',
          'Buyer Name',
          'Control Code',
          'CSV Amount (Excl. VAT)',
          'System Amount (Incl. VAT)',
          'System Amount (Excl. VAT)',
          'VAT Amount (16%)',
          'Amount Difference (Excl. VAT)',
          'TS Num',
          'Transaction Date',
          'Export Date',
          'Export Time',
          'Status'
        ]);
      } else {
        csvData.add([
          'Comparison Type',
          'Control Code',
          'CSV Amount (Excl. VAT)',
          'System Amount (Incl. VAT)',
          'System Amount (Excl. VAT)',
          'VAT Amount (16%)',
          'Amount Difference (Excl. VAT)',
          'TS Num',
          'Transaction Date',
          'Export Date',
          'Export Time',
          'Status'
        ]);
      }

      // ========== MATCHED RECORDS ==========
      if (_exportMatched && _comparisonResult!.matchedRecords.isNotEmpty) {
        for (var item in _comparisonResult!.matchedRecords) {
          if (_selectedTemplate == CSVTemplate.vatRegistered) {
            csvData.add([
              'Matched',
              item.buyerPIN ?? 'N/A',
              item.buyerName ?? 'N/A',
              _formatControlCodeForDisplay(item.controlCode),
              'KES ${NumberFormat('#,##0.00').format(item.csvAmount)}',
              'KES ${NumberFormat('#,##0.00').format(item.tableAmount)}',
              'KES ${NumberFormat('#,##0.00').format(item.tableAmountExcludingVAT)}',
              'KES ${NumberFormat('#,##0.00').format(item.tableVATAmount)}',
              'KES ${NumberFormat('#,##0.00').format(item.amountDifference)}',
              _formatTsNumForDisplay(item.tsNum),
              item.date != null
                  ? DateFormat('dd/MM/yyyy').format(item.date!)
                  : 'N/A',
              DateFormat('dd/MM/yyyy').format(exportDateTime),
              DateFormat('HH:mm:ss').format(exportDateTime),
              item.amountDifference.abs() < 0.01
                  ? 'Exact Match'
                  : 'Amount Mismatch',
            ]);
          } else {
            csvData.add([
              'Matched',
              _formatControlCodeForDisplay(item.controlCode),
              'KES ${NumberFormat('#,##0.00').format(item.csvAmount)}',
              'KES ${NumberFormat('#,##0.00').format(item.tableAmount)}',
              'KES ${NumberFormat('#,##0.00').format(item.tableAmountExcludingVAT)}',
              'KES ${NumberFormat('#,##0.00').format(item.tableVATAmount)}',
              'KES ${NumberFormat('#,##0.00').format(item.amountDifference)}',
              _formatTsNumForDisplay(item.tsNum),
              item.date != null
                  ? DateFormat('dd/MM/yyyy').format(item.date!)
                  : 'N/A',
              DateFormat('dd/MM/yyyy').format(exportDateTime),
              DateFormat('HH:mm:ss').format(exportDateTime),
              item.amountDifference.abs() < 0.01
                  ? 'Exact Match'
                  : 'Amount Mismatch',
            ]);
          }
        }
      }

      // ========== MISSING FROM SYSTEM ==========
      if (_exportMissingFromSystem &&
          _comparisonResult!.missingFromTable.isNotEmpty) {
        csvData.add([
          '--- MISSING FROM SYSTEM ONLY ---',
          '',
          '',
          '',
          'Total Amount (Excl. VAT): KES ${NumberFormat('#,##0.00').format(_comparisonResult!.totalMissingFromTableAmount)}',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          ''
        ]);

        for (var item in _comparisonResult!.missingFromTable) {
          if (_selectedTemplate == CSVTemplate.vatRegistered) {
            csvData.add([
              'Missing from System',
              item.buyerPIN ?? 'N/A',
              item.buyerName ?? 'N/A',
              _formatControlCodeForDisplay(item.controlCode),
              'KES ${NumberFormat('#,##0.00').format(item.amount)}',
              'N/A',
              'N/A',
              'N/A',
              'N/A',
              'N/A',
              'N/A',
              DateFormat('dd/MM/yyyy').format(exportDateTime),
              DateFormat('HH:mm:ss').format(exportDateTime),
              'Not Found in System',
            ]);
          } else {
            csvData.add([
              'Missing from System',
              _formatControlCodeForDisplay(item.controlCode),
              'KES ${NumberFormat('#,##0.00').format(item.amount)}',
              'N/A',
              'N/A',
              'N/A',
              'N/A',
              'N/A',
              'N/A',
              DateFormat('dd/MM/yyyy').format(exportDateTime),
              DateFormat('HH:mm:ss').format(exportDateTime),
              'Not Found in System',
            ]);
          }
        }
      }

      // ========== MISSING FROM CSV ==========
      if (_exportMissingFromCSV &&
          _comparisonResult!.missingFromCSV.isNotEmpty) {
        csvData.add([
          '--- MISSING FROM CSV ONLY ---',
          '',
          '',
          '',
          'Total Amount (Incl. VAT): KES ${NumberFormat('#,##0.00').format(_comparisonResult!.totalMissingFromCSVAmount)}',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          ''
        ]);

        int exportLimit = 10000;
        var missingFromCSV = _comparisonResult!.missingFromCSV;
        if (missingFromCSV.length > exportLimit) {
          missingFromCSV = missingFromCSV.take(exportLimit).toList();
          csvData.add([
            'Note',
            '',
            '',
            '',
            'Only showing first $exportLimit of ${_comparisonResult!.totalMissingFromCSV} records',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            ''
          ]);
        }

        for (var item in missingFromCSV) {
          if (_selectedTemplate == CSVTemplate.vatRegistered) {
            csvData.add([
              'Missing from CSV',
              item.systemBuyerPIN ?? 'N/A',
              'N/A',
              _formatControlCodeForDisplay(item.controlCode),
              'N/A',
              item.tableAmount != null
                  ? 'KES ${NumberFormat('#,##0.00').format(item.tableAmount!)}'
                  : 'N/A',
              item.tableAmountExcludingVAT != null
                  ? 'KES ${NumberFormat('#,##0.00').format(item.tableAmountExcludingVAT!)}'
                  : 'N/A',
              item.tableVATAmount != null
                  ? 'KES ${NumberFormat('#,##0.00').format(item.tableVATAmount!)}'
                  : 'N/A',
              'N/A',
              _formatTsNumForDisplay(item.tableTsNum ?? 'N/A'),
              item.tableDate != null
                  ? DateFormat('dd/MM/yyyy').format(item.tableDate!)
                  : 'N/A',
              DateFormat('dd/MM/yyyy').format(exportDateTime),
              DateFormat('HH:mm:ss').format(exportDateTime),
              'In System Only',
            ]);
          } else {
            csvData.add([
              'Missing from CSV',
              _formatControlCodeForDisplay(item.controlCode),
              'N/A',
              item.tableAmount != null
                  ? 'KES ${NumberFormat('#,##0.00').format(item.tableAmount!)}'
                  : 'N/A',
              item.tableAmountExcludingVAT != null
                  ? 'KES ${NumberFormat('#,##0.00').format(item.tableAmountExcludingVAT!)}'
                  : 'N/A',
              item.tableVATAmount != null
                  ? 'KES ${NumberFormat('#,##0.00').format(item.tableVATAmount!)}'
                  : 'N/A',
              'N/A',
              _formatTsNumForDisplay(item.tableTsNum ?? 'N/A'),
              item.tableDate != null
                  ? DateFormat('dd/MM/yyyy').format(item.tableDate!)
                  : 'N/A',
              DateFormat('dd/MM/yyyy').format(exportDateTime),
              DateFormat('HH:mm:ss').format(exportDateTime),
              'In System Only',
            ]);
          }
        }
      }

      // ========== FOOTER ==========
      csvData.add(['']);
      csvData.add(['--- END OF REPORT ---']);
      csvData.add(['Report Generated By: TIMS Data Exporter']);
      csvData.add(['Template Used: $_selectedTemplate']);
      csvData.add(['VAT Calculation: 16% of amount excluding VAT']);
      csvData.add([
        'Export completed at:',
        DateFormat('dd/MM/yyyy HH:mm:ss').format(exportDateTime)
      ]);

      String csv = _convertToCSV(csvData);
      File file = File(filePath);
      await file.writeAsString(csv);

      if (!mounted) return;
      _showSnackBar('Exported to: $filePath', _success);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Iconsax.tick_circle, color: _success),
              SizedBox(width: 8),
              Text('Export Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('File saved to:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  filePath,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 8),
              Text('File name: $fileName',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Text('Template: $templateName',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Text('VAT Rate: 16%', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                  'Export Date: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(exportDateTime)}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              const Text(
                'Note: CSV amounts are VAT-exclusive. System amounts include 16% VAT.',
                style: TextStyle(fontSize: 11, color: _warning),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  if (Platform.isWindows) {
                    await Process.run('explorer', ['/select,', filePath]);
                  }
                } catch (e) {
                  debugPrint('Error opening folder: $e');
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              icon: const Icon(Iconsax.folder_open, size: 16),
              label: const Text('Open Folder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Export failed: $e', _error);
      debugPrint('Export error: $e');
    }
  }

  Widget _buildTemplateSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.document_text, size: 20, color: _primary),
          const SizedBox(width: 12),
          const Text(
            'CSV Template:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SegmentedButton<CSVTemplate>(
              segments: const [
                ButtonSegment(
                  value: CSVTemplate.standard,
                  label: Text('Standard CSV'),
                  icon: Icon(Iconsax.document, size: 16),
                ),
                ButtonSegment(
                  value: CSVTemplate.vatRegistered,
                  label: Text('VAT Registered'),
                  icon: Icon(Iconsax.profile_2user, size: 16),
                ),
              ],
              selected: {_selectedTemplate},
              onSelectionChanged: (Set<CSVTemplate> selection) {
                setState(() {
                  _selectedTemplate = selection.first;
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return _primary;
                    }
                    return Colors.white;
                  },
                ),
                foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return _textSecondary;
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_comparisonResult == null) return const SizedBox();

    double totalCSVAmount = _comparisonResult!.matchedRecords
        .fold(0.0, (sum, record) => sum + record.csvAmount);
    double totalSystemAmountExcludingVAT = _comparisonResult!.matchedRecords
        .fold(0.0, (sum, record) => sum + record.tableAmountExcludingVAT);
    double totalDifference = totalCSVAmount - totalSystemAmountExcludingVAT;

    String templateLabel = _selectedTemplate == CSVTemplate.standard
        ? 'Standard CSV Template'
        : 'VAT Registered CSV Template';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary.withValues(alpha: 0.1), _surfaceVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              templateLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('CSV Records',
                  _comparisonResult!.totalInCSV.toString(), _primary),
              _buildStatItem('System Records',
                  _comparisonResult!.totalInTable.toString(), _primary),
              _buildStatItem(
                  'Matched', _comparisonResult!.matched.toString(), _success),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  _buildStatItem(
                      'Missing from System',
                      _comparisonResult!.missingFromTable.length.toString(),
                      _error),
                  Text(
                    'KES ${NumberFormat('#,##0.00').format(_comparisonResult!.totalMissingFromTableAmount)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _error,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  _buildStatItem('Missing from CSV',
                      '${_comparisonResult!.totalMissingFromCSV}', _warning),
                  Text(
                    'KES ${NumberFormat('#,##0.00').format(_comparisonResult!.totalMissingFromCSVAmount)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAmountStat(
                        'CSV Total (Excl. VAT)', totalCSVAmount, _primary),
                    _buildAmountStat('System Total (Excl. VAT)',
                        totalSystemAmountExcludingVAT, _primary),
                  ],
                ),
                const Divider(),
                _buildAmountStat('Difference', totalDifference,
                    totalDifference.abs() < 0.01 ? _success : _error),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.info_circle, size: 14, color: _info),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'CSV amounts are VAT-exclusive. System amounts include 16% VAT.',
                    style: TextStyle(fontSize: 10, color: _info),
                  ),
                ),
              ],
            ),
          ),
          if (_comparisonResult!.totalMissingFromCSV > 1000)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Note: Only showing first 1000 of ${_comparisonResult!.totalMissingFromCSV} records missing from CSV',
                style: TextStyle(fontSize: 11, color: _warning),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAmountStat(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          'KES ${NumberFormat('#,##0.00').format(amount)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: _textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: _textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildComparisonTable() {
    if (_comparisonResult == null) return const SizedBox();

    if (_activeTab == 'matched') {
      return _buildMatchedTable();
    } else if (_activeTab == 'missing_from_table') {
      return _buildMissingFromTable();
    } else {
      return _buildMissingFromCSV();
    }
  }

  Widget _buildMatchedTable() {
    List<MatchedRecord> allData = _comparisonResult!.matchedRecords;
    int totalPages = (allData.length / _pageSize).ceil();
    int startIndex = (_matchedPage - 1) * _pageSize;
    int endIndex = startIndex + _pageSize;
    if (endIndex > allData.length) endIndex = allData.length;
    List<MatchedRecord> data = allData.sublist(startIndex, endIndex);

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.tick_circle, size: 64, color: _success),
            const SizedBox(height: 16),
            const Text(
              'No matched records found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Iconsax.tick_circle, size: 20, color: _success),
                  const SizedBox(width: 8),
                  Text(
                    'Matched Records (${allData.length} records)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (totalPages > 1)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Iconsax.arrow_left, size: 16),
                      onPressed: _matchedPage > 1
                          ? () => setState(() => _matchedPage--)
                          : null,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                    ),
                    Text(
                      'Page $_matchedPage of $totalPages',
                      style: const TextStyle(fontSize: 12),
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.arrow_right, size: 16),
                      onPressed: _matchedPage < totalPages
                          ? () => setState(() => _matchedPage++)
                          : null,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: WidgetStateProperty.all(_surfaceVariant),
                columns: _selectedTemplate == CSVTemplate.vatRegistered
                    ? const [
                        DataColumn(label: Text('Buyer PIN')),
                        DataColumn(label: Text('Buyer Name')),
                        DataColumn(label: Text('Control Code')),
                        DataColumn(label: Text('CSV Amount'), numeric: true),
                        DataColumn(label: Text('System Amount'), numeric: true),
                        DataColumn(
                            label: Text('System (Excl. VAT)'), numeric: true),
                        DataColumn(label: Text('VAT 16%'), numeric: true),
                        DataColumn(label: Text('Difference'), numeric: true),
                        DataColumn(label: Text('TS Num')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Status')),
                      ]
                    : const [
                        DataColumn(label: Text('Control Code')),
                        DataColumn(label: Text('CSV Amount'), numeric: true),
                        DataColumn(label: Text('System Amount'), numeric: true),
                        DataColumn(
                            label: Text('System (Excl. VAT)'), numeric: true),
                        DataColumn(label: Text('VAT 16%'), numeric: true),
                        DataColumn(label: Text('Difference'), numeric: true),
                        DataColumn(label: Text('TS Num')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Status')),
                      ],
                rows: data.map((item) {
                  bool isExactMatch = item.amountDifference.abs() < 0.01;
                  if (_selectedTemplate == CSVTemplate.vatRegistered) {
                    return DataRow(
                      color: WidgetStateProperty.all(
                        isExactMatch ? null : _warning.withValues(alpha: 0.1),
                      ),
                      cells: [
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.buyerPIN ?? 'N/A',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.buyerName ?? 'N/A',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatControlCodeForDisplay(item.controlCode),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Text(
                            'KES ${NumberFormat('#,##0.00').format(item.csvAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          Text(
                            'KES ${NumberFormat('#,##0.00').format(item.tableAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          Text(
                            'KES ${NumberFormat('#,##0.00').format(item.tableAmountExcludingVAT)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          Text(
                            'KES ${NumberFormat('#,##0.00').format(item.tableVATAmount)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, color: _info),
                          ),
                        ),
                        DataCell(
                          Text(
                            'KES ${NumberFormat('#,##0.00').format(item.amountDifference)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isExactMatch ? _success : _error,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatTsNumForDisplay(item.tsNum),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.date != null
                                ? DateFormat('dd/MM/yyyy').format(item.date!)
                                : 'N/A',
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isExactMatch
                                  ? _success.withValues(alpha: 0.1)
                                  : _warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isExactMatch ? 'Exact Match' : 'Amount Mismatch',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isExactMatch ? _success : _warning,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return DataRow(
                      color: WidgetStateProperty.all(
                        isExactMatch ? null : _warning.withValues(alpha: 0.1),
                      ),
                      cells: [
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatControlCodeForDisplay(item.controlCode),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            'KES ${NumberFormat('#,##0.00').format(item.csvAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          Text(
                            'KES ${NumberFormat('#,##0.00').format(item.tableAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          Text(
                            'KES ${NumberFormat('#,##0.00').format(item.tableAmountExcludingVAT)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          Text(
                            'KES ${NumberFormat('#,##0.00').format(item.tableVATAmount)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, color: _info),
                          ),
                        ),
                        DataCell(
                          Text(
                            'KES ${NumberFormat('#,##0.00').format(item.amountDifference)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isExactMatch ? _success : _error,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatTsNumForDisplay(item.tsNum),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.date != null
                                ? DateFormat('dd/MM/yyyy').format(item.date!)
                                : 'N/A',
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isExactMatch
                                  ? _success.withValues(alpha: 0.1)
                                  : _warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isExactMatch ? 'Exact Match' : 'Amount Mismatch',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isExactMatch ? _success : _warning,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMissingFromTable() {
    List<CSVComparisonModel> allData = _comparisonResult!.missingFromTable;
    int totalPages = (allData.length / _pageSize).ceil();
    int startIndex = (_missingFromTablePage - 1) * _pageSize;
    int endIndex = startIndex + _pageSize;
    if (endIndex > allData.length) endIndex = allData.length;
    List<CSVComparisonModel> data = allData.sublist(startIndex, endIndex);

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.tick_circle, size: 64, color: _success),
            const SizedBox(height: 16),
            const Text(
              'No records missing from system',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _success,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Iconsax.warning_2, size: 20, color: _error),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Missing from System (${allData.length} records)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Total Amount (Excl. VAT): KES ${NumberFormat('#,##0.00').format(_comparisonResult!.totalMissingFromTableAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (totalPages > 1)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Iconsax.arrow_left, size: 16),
                      onPressed: _missingFromTablePage > 1
                          ? () => setState(() => _missingFromTablePage--)
                          : null,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                    ),
                    Text(
                      'Page $_missingFromTablePage of $totalPages',
                      style: const TextStyle(fontSize: 12),
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.arrow_right, size: 16),
                      onPressed: _missingFromTablePage < totalPages
                          ? () => setState(() => _missingFromTablePage++)
                          : null,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: WidgetStateProperty.all(_surfaceVariant),
                columns: _selectedTemplate == CSVTemplate.vatRegistered
                    ? const [
                        DataColumn(label: Text('Buyer PIN')),
                        DataColumn(label: Text('Buyer Name')),
                        DataColumn(label: Text('Control Code')),
                        DataColumn(
                            label: Text('Amount (Excl. VAT)'), numeric: true),
                      ]
                    : const [
                        DataColumn(label: Text('Control Code')),
                        DataColumn(
                            label: Text('Amount (Excl. VAT)'), numeric: true),
                      ],
                rows: data.map((item) {
                  if (_selectedTemplate == CSVTemplate.vatRegistered) {
                    return DataRow(cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.buyerPIN ?? 'N/A',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          item.buyerName ?? 'N/A',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatControlCodeForDisplay(item.controlCode),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          'KES ${NumberFormat('#,##0.00').format(item.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]);
                  } else {
                    return DataRow(cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatControlCodeForDisplay(item.controlCode),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          'KES ${NumberFormat('#,##0.00').format(item.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]);
                  }
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMissingFromCSV() {
    List<CSVComparisonModel> allData = _comparisonResult!.missingFromCSV;
    int totalPages = (allData.length / _pageSize).ceil();
    int startIndex = (_missingFromCSVPage - 1) * _pageSize;
    int endIndex = startIndex + _pageSize;
    if (endIndex > allData.length) endIndex = allData.length;
    List<CSVComparisonModel> data = allData.sublist(startIndex, endIndex);

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.tick_circle, size: 64, color: _success),
            const SizedBox(height: 16),
            const Text(
              'No records missing from CSV',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _success,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Iconsax.document_text, size: 20, color: _warning),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Missing from CSV (${allData.length} records)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Total Amount (Incl. VAT): KES ${NumberFormat('#,##0.00').format(_comparisonResult!.totalMissingFromCSVAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (totalPages > 1)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Iconsax.arrow_left, size: 16),
                      onPressed: _missingFromCSVPage > 1
                          ? () => setState(() => _missingFromCSVPage--)
                          : null,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                    ),
                    Text(
                      'Page $_missingFromCSVPage of $totalPages',
                      style: const TextStyle(fontSize: 12),
                    ),
                    IconButton(
                      icon: const Icon(Iconsax.arrow_right, size: 16),
                      onPressed: _missingFromCSVPage < totalPages
                          ? () => setState(() => _missingFromCSVPage++)
                          : null,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: WidgetStateProperty.all(_surfaceVariant),
                columns: _selectedTemplate == CSVTemplate.vatRegistered
                    ? const [
                        DataColumn(label: Text('Control Code')),
                        DataColumn(label: Text('System Buyer PIN')),
                        DataColumn(label: Text('TS Num')),
                        DataColumn(label: Text('Date')),
                        DataColumn(
                            label: Text('Amount (Incl. VAT)'), numeric: true),
                        DataColumn(
                            label: Text('Amount (Excl. VAT)'), numeric: true),
                        DataColumn(label: Text('VAT 16%'), numeric: true),
                      ]
                    : const [
                        DataColumn(label: Text('Control Code')),
                        DataColumn(label: Text('TS Num')),
                        DataColumn(label: Text('Date')),
                        DataColumn(
                            label: Text('Amount (Incl. VAT)'), numeric: true),
                        DataColumn(
                            label: Text('Amount (Excl. VAT)'), numeric: true),
                        DataColumn(label: Text('VAT 16%'), numeric: true),
                      ],
                rows: data.map((item) {
                  if (_selectedTemplate == CSVTemplate.vatRegistered) {
                    return DataRow(cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatControlCodeForDisplay(item.controlCode),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          item.systemBuyerPIN ?? 'N/A',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatTsNumForDisplay(item.tableTsNum ?? 'N/A'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          item.tableDate != null
                              ? DateFormat('dd/MM/yyyy').format(item.tableDate!)
                              : 'N/A',
                        ),
                      ),
                      DataCell(
                        Text(
                          item.tableAmount != null
                              ? 'KES ${NumberFormat('#,##0.00').format(item.tableAmount!)}'
                              : 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        Text(
                          item.tableAmountExcludingVAT != null
                              ? 'KES ${NumberFormat('#,##0.00').format(item.tableAmountExcludingVAT!)}'
                              : 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        Text(
                          item.tableVATAmount != null
                              ? 'KES ${NumberFormat('#,##0.00').format(item.tableVATAmount!)}'
                              : 'N/A',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: _info),
                        ),
                      ),
                    ]);
                  } else {
                    return DataRow(cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatControlCodeForDisplay(item.controlCode),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatTsNumForDisplay(item.tableTsNum ?? 'N/A'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          item.tableDate != null
                              ? DateFormat('dd/MM/yyyy').format(item.tableDate!)
                              : 'N/A',
                        ),
                      ),
                      DataCell(
                        Text(
                          item.tableAmount != null
                              ? 'KES ${NumberFormat('#,##0.00').format(item.tableAmount!)}'
                              : 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        Text(
                          item.tableAmountExcludingVAT != null
                              ? 'KES ${NumberFormat('#,##0.00').format(item.tableAmountExcludingVAT!)}'
                              : 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        Text(
                          item.tableVATAmount != null
                              ? 'KES ${NumberFormat('#,##0.00').format(item.tableVATAmount!)}'
                              : 'N/A',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: _info),
                        ),
                      ),
                    ]);
                  }
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Iconsax.status_up, color: _primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'CSV Comparison Tool',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Iconsax.close_circle),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Template Selector
            _buildTemplateSelector(),
            const SizedBox(height: 16),

            // Upload Section
            if (_comparisonResult == null && !_isLoading)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.document_upload, size: 64, color: _primary),
                    const SizedBox(height: 16),
                    const Text(
                      'Upload CSV file to compare',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedTemplate == CSVTemplate.standard)
                      const Text(
                        'Standard CSV: Column E (Control Code) + Column G (Amount)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      )
                    else
                      const Text(
                        'VAT Registered CSV: Column A (PIN), Column B (Name), Column E (Control Code), Column G (Amount)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.info_circle, size: 14, color: _info),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'CSV amounts are VAT-exclusive (no VAT). System amounts include 16% VAT. Comparison is done on VAT-exclusive amounts.',
                              style: TextStyle(fontSize: 11, color: _info),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.monthFilter != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Filtering by: ${DateFormat('MMMM yyyy').format(widget.monthFilter!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _info,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _pickAndCompareCSV,
                      icon: const Icon(Iconsax.import),
                      label: const Text('Select CSV File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                    if (_selectedFileName != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Selected: $_selectedFileName',
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),

            // Loading Indicator
            if (_isLoading)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _progressMessage,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This may take a moment for large databases',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Results Section
            if (_comparisonResult != null) ...[
              _buildSummaryCard(),
              const SizedBox(height: 16),

              // Tab Selector
              Container(
                decoration: BoxDecoration(
                  color: _surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildTabButton('matched', 'Matched Records',
                        Iconsax.tick_circle, _success),
                    _buildTabButton('missing_from_table', 'Missing from System',
                        Iconsax.warning_2, _error),
                    _buildTabButton('missing_from_csv', 'Missing from CSV',
                        Iconsax.document_text, _warning),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Expanded(child: _buildComparisonTable()),
              const SizedBox(height: 16),

              // Export Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showExportOptionsDialog,
                    icon: const Icon(Iconsax.export_1),
                    label: const Text('Export Results'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _success,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(
      String tabId, String label, IconData icon, Color color) {
    bool isActive = _activeTab == tabId;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tabId),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4)
                  ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: isActive ? color : _textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? color : _textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Helper Models
class CSVRecord {
  final String controlCode;
  final double amount;
  final int rowIndex;
  final String? buyerPIN;
  final String? buyerName;
  CSVRecord({
    required this.controlCode,
    required this.amount,
    required this.rowIndex,
    this.buyerPIN,
    this.buyerName,
  });
}

class MatchedRecord {
  final String controlCode;
  final double csvAmount;
  final double tableAmount;
  final double tableAmountExcludingVAT;
  final double tableVATAmount;
  final double amountDifference;
  final String tsNum;
  final DateTime? date;
  final String? buyerPIN;
  final String? buyerName;
  final String? systemBuyerPIN;
  MatchedRecord({
    required this.controlCode,
    required this.csvAmount,
    required this.tableAmount,
    required this.tableAmountExcludingVAT,
    required this.tableVATAmount,
    required this.amountDifference,
    required this.tsNum,
    this.date,
    this.buyerPIN,
    this.buyerName,
    this.systemBuyerPIN,
  });
}

class CSVComparisonModel {
  final String controlCode;
  final double amount;
  final bool foundInTable;
  final String? tableTsNum;
  final DateTime? tableDate;
  final double? tableAmount;
  final double? tableAmountExcludingVAT;
  final double? tableVATAmount;
  final String? buyerPIN;
  final String? buyerName;
  final String? systemBuyerPIN;
  CSVComparisonModel({
    required this.controlCode,
    required this.amount,
    required this.foundInTable,
    this.tableTsNum,
    this.tableDate,
    this.tableAmount,
    this.tableAmountExcludingVAT,
    this.tableVATAmount,
    this.buyerPIN,
    this.buyerName,
    this.systemBuyerPIN,
  });
}

class ComparisonResult {
  final List<MatchedRecord> matchedRecords;
  final List<CSVComparisonModel> missingFromTable;
  final List<CSVComparisonModel> missingFromCSV;
  final int totalInCSV;
  final int totalInTable;
  final int matched;
  final int totalMissingFromCSV;
  final double totalMissingFromTableAmount;
  final double totalMissingFromCSVAmount;

  ComparisonResult({
    required this.matchedRecords,
    required this.missingFromTable,
    required this.missingFromCSV,
    required this.totalInCSV,
    required this.totalInTable,
    required this.matched,
    required this.totalMissingFromCSV,
    required this.totalMissingFromTableAmount,
    required this.totalMissingFromCSVAmount,
  });
}
