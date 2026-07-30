import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:qr/qr.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/data_model.dart';
import '../models/item_detail.dart';
import '../services/license_manager.dart';
import '../screens/home_screen.dart';

enum OverwriteResult { overwrite, readFromDb, cancel }

class FileGenerator {
  /// Ensures all application directories are created.
  static Future<void> initAppDirectories() async {
    await getOutputDirectory();
  }

  /// Persists custom directory paths and QR settings.
  static Future<void> saveCustomPaths(
      {String? dtrAppPath,
      String? ticketPath,
      String? taxInvoicesPath,
      double? qrX,
      double? qrY,
      String? qrLayout,
      String? qrPositionPreset}) async {
    final prefs = await SharedPreferences.getInstance();
    if (dtrAppPath != null) {
      dtrAppPath.isEmpty
          ? await prefs.remove('path_dtr_app')
          : await prefs.setString('path_dtr_app', dtrAppPath);
    }
    if (ticketPath != null) {
      ticketPath.isEmpty
          ? await prefs.remove('path_ticket')
          : await prefs.setString('path_ticket', ticketPath);
    }
    if (taxInvoicesPath != null) {
      taxInvoicesPath.isEmpty
          ? await prefs.remove('path_tax_invoices')
          : await prefs.setString('path_tax_invoices', taxInvoicesPath);
    }
    if (qrX != null) {
      qrX < 0
          ? await prefs.remove('qr_x_pos')
          : await prefs.setDouble('qr_x_pos', qrX);
    }
    if (qrY != null) {
      qrY < 0
          ? await prefs.remove('qr_y_pos')
          : await prefs.setDouble('qr_y_pos', qrY);
    }
    if (qrLayout != null) {
      await prefs.setString('qr_layout', qrLayout);
    }
    if (qrPositionPreset != null) {
      await prefs.setString('qr_position_preset', qrPositionPreset);
    }
  }

  static Future<Map<String, String>> getOutputDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? customDtr = prefs.getString('path_dtr_app');
    final String? customTicket = prefs.getString('path_ticket');
    final String? customTax = prefs.getString('path_tax_invoices');

    Directory dtrAppDir;
    Directory ticketDir;
    Directory taxInvoicesDir;

    // Determine DTR APP Directory (Priority: Saved Path > OS Default)
    if (customDtr != null && customDtr.isNotEmpty) {
      dtrAppDir = Directory(customDtr);
    } else if (Platform.isWindows) {
      dtrAppDir = Directory(r'C:\DTR APP');
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      dtrAppDir = Directory(path.join(appDir.path, 'DTR APP'));
    }

    try {
      if (!await dtrAppDir.exists()) {
        await dtrAppDir.create(recursive: true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('DTR APP Directory creation error. Falling back to documents: $e');
      }
      final fallbackDir = await getApplicationDocumentsDirectory();
      dtrAppDir = Directory(path.join(fallbackDir.path, 'DTR APP'));
      await dtrAppDir.create(recursive: true);
    }

    // Determine Ticket Directory (Priority: Saved Path > OS Default)
    if (customTicket != null && customTicket.isNotEmpty) {
      ticketDir = Directory(customTicket);
    } else if (Platform.isWindows) {
      ticketDir = Directory(r'C:\FBtemp\Ticket');
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      ticketDir = Directory(path.join(appDir.path, 'Ticket'));
    }

    try {
      if (!await ticketDir.exists()) {
        await ticketDir.create(recursive: true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Ticket Directory creation error. Falling back to documents: $e');
      }
      final fallbackDir = await getApplicationDocumentsDirectory();
      ticketDir = Directory(path.join(fallbackDir.path, 'Ticket'));
      await ticketDir.create(recursive: true);
    }

    // Determine Tax Invoices Directory (Priority: Saved Path > Default Subfolder)
    if (customTax != null && customTax.isNotEmpty) {
      taxInvoicesDir = Directory(customTax);
    } else {
      taxInvoicesDir = Directory(path.join(dtrAppDir.path, 'tax_invoices'));
    }

    try {
      if (!await taxInvoicesDir.exists()) {
        await taxInvoicesDir.create(recursive: true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Tax Invoices Directory creation error. Falling back to default: $e');
      }
      taxInvoicesDir = Directory(path.join(dtrAppDir.path, 'tax_invoices'));
      await taxInvoicesDir.create(recursive: true);
    }

    // Define and Create Subdirectories
    final Map<String, String> paths = {
      'ticket': ticketDir.path,
      'textFiles': path.join(dtrAppDir.path, 'text files'),
      'processedInvoices': path.join(dtrAppDir.path, 'processed'),
      'duplicates': path.join(dtrAppDir.path, 'duplicate'),
      'input': path.join(dtrAppDir.path, 'invoice'),
      'taxInvoices': taxInvoicesDir.path,
    };

    for (final subPath in paths.values) {
      final dir = Directory(subPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }

    return paths;
  }

  static Future<Map<String, String>?> _queryDbForTransactionData(String tsNum,
      {required String dbPath}) async {
    try {
      final cleanTsNum =
          tsNum.replaceFirst(RegExp(r'^CN', caseSensitive: false), '');
      final database = await openDatabase(dbPath);
      final result = await database.query(
        'fb_transaction',
        columns: ['Date', 'MwNum', 'SerialNumber', 'QrCode'],
        where: 'TsNum = ?',
        whereArgs: [cleanTsNum],
      );
      if (result.isNotEmpty) {
        final row = result.first;
        return {
          'Date': row['Date'] as String? ?? '',
          'MwNum': row['MwNum'] as String? ?? '',
          'SerialNumber': row['SerialNumber'] as String? ?? '',
          'QrCode': row['QrCode'] as String? ?? '',
        };
      }
      if (kDebugMode) {
        print('No matching transaction found for TsNum: $tsNum');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error querying database for TsNum $tsNum: $e');
      }
      throw Exception('Failed to query database: $e');
    }
  }

  static Uint8List? _generateQrCodeImage(String data) {
    try {
      final qrCode = QrCode(
        payload: QrPayload.fromString(data),
        errorCorrectLevel: QrErrorCorrectLevel.low,
        minTypeNumber: 10,
      );
      final qrImage = QrImage(qrCode);
      final moduleCount = qrImage.moduleCount;
      if (kDebugMode) {
        print(
            'QR Code: version=10, moduleCount=$moduleCount, dataLength=${data.length}');
      }
      if (moduleCount == 0) {
        throw Exception('Invalid QR code module count');
      }
      const size = 100;
      final scale = size ~/ moduleCount;
      if (scale == 0) {
        throw Exception(
            'QR code scale too small for module count $moduleCount');
      }
      final image =
          img.Image(width: moduleCount * scale, height: moduleCount * scale);
      for (var y = 0; y < moduleCount; y++) {
        for (var x = 0; x < moduleCount; x++) {
          final isDark = qrImage.isDark(y, x);
          final color =
              isDark ? img.ColorRgb8(0, 0, 0) : img.ColorRgb8(255, 255, 255);
          for (var dy = 0; dy < scale; dy++) {
            for (var dx = 0; dx < scale; dx++) {
              image.setPixel(x * scale + dx, y * scale + dy, color);
            }
          }
        }
      }
      final pngBytes = img.encodePng(image);
      final result = Uint8List.fromList(pngBytes);
      if (kDebugMode) {
        print('QR Code PNG data length: ${result.length}');
      }
      if (result.isEmpty) {
        throw Exception('Generated QR code image data is empty');
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error generating QR code: $e');
      }
      return null;
    }
  }

  static Future<double?> _getConversionRate(
      BuildContext context, String currency,
      {String? defaultRate}) async {
    final TextEditingController controller =
        TextEditingController(text: defaultRate);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Conversion Rate to KES'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Invoice is in $currency. Enter conversion rate (1 $currency = ? KES):'),
            TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Conversion Rate',
                hintText: 'e.g., 130.0',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final rate = double.tryParse(controller.text.replaceAll(',', ''));
              if (rate != null && rate > 0) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid positive number')),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final rate = double.tryParse(controller.text.replaceAll(',', ''));
      return rate != null && rate > 0 ? rate : null;
    }
    return null;
  }

  static Future<String?> _promptForLicenseKey(
      BuildContext context, String status) async {
    final controller = TextEditingController();
    final bool isInitial = status == 'unactivated';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('License Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isInitial
                ? 'Welcome! Please enter your license key (Quantyx***) to activate TIM\'s Data Exporter.'
                : 'Your license has expired. Please enter the renewal license key (e.g., Quantyx***) to continue.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'License Key',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
  }

  static Future<bool> verifyLicense(
      BuildContext context,
      void Function(String message, {NotificationType type})
          showSnackBar) async {
    final status = await LicenseManager.checkLicenseStatus();
    if (!status['isExpired']) return true;

    if (!context.mounted) return false;
    final key = await _promptForLicenseKey(context, status['status']);
    if (key == null) return false;

    if (await LicenseManager.activateLicense(key)) {
      showSnackBar('License activated successfully!',
          type: NotificationType.success);
      return true;
    } else {
      showSnackBar('Invalid license key. Please contact Quantyx Labs.',
          type: NotificationType.error);
      return false;
    }
  }

  static Future<String?> _promptForCuin(
      BuildContext context, String currentCuin,
      {String title = 'Enter CUIN'}) async {
    final controller = TextEditingController(text: '');
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter the Control Unit Invoice Number (CUIN):'),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'CUIN',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<bool> _confirmReprocessInvoice(
      BuildContext context, String filePath) async {
    final bool? reprocess = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invoice Already Processed'),
        content: Text(
            'Invoice at $filePath has already been processed. Process again?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Process Again'),
          ),
        ],
      ),
    );
    return reprocess ?? false;
  }

  static Future<void> _modifyPdfWithDbData({
    required BuildContext context,
    required String pdfPath,
    required String tsNum,
    required Map<String, String> outputDirs,
    required void Function(String message, {NotificationType type})
        showSnackBar,
    required String dbPath,
    double? qrX,
    double? qrY,
  }) async {
    try {
      final processedPath = path.join(outputDirs['processedInvoices']!,
          tsNum.isNotEmpty ? '$tsNum.pdf' : path.basename(pdfPath));
      final processedFile = File(processedPath);

      final isSameFile =
          path.normalize(pdfPath) == path.normalize(processedPath);
      if (await processedFile.exists() && !isSameFile) {
        if (!context.mounted) return;
        final shouldReprocess =
            await _confirmReprocessInvoice(context, processedPath);
        if (!shouldReprocess) {
          showSnackBar('Invoice processing cancelled for TsNum: $tsNum',
              type: NotificationType.info);
          return;
        }
      }

      // Wait for database data with auto-retry - 45 seconds max
      Map<String, String>? transactionData;

      // Show initial status
      if (context.mounted) {
        showSnackBar(
            '⏳ Waiting for transaction data from database... (max 45 seconds)',
            type: NotificationType.info);
      }

      const int maxAttempts = 9; // 9 attempts * 5 seconds = 45 seconds
      const Duration retryInterval = Duration(seconds: 5);

      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        // Query the database
        transactionData =
            await _queryDbForTransactionData(tsNum, dbPath: dbPath);

        if (transactionData != null) {
          // Data found! Exit the loop
          if (kDebugMode) {
            print(
                'Transaction data found for TsNum: $tsNum after ${attempt + 1} attempt(s)');
          }
          if (context.mounted) {
            showSnackBar('✅ Transaction data found successfully!',
                type: NotificationType.success);
          }
          break;
        }

        // If this is the last attempt, don't wait
        if (attempt < maxAttempts - 1) {
          // Show progress
          final secondsElapsed = (attempt + 1) * 5;
          if (context.mounted) {
            showSnackBar(
                '⏳ Waiting for transaction data... ($secondsElapsed seconds elapsed)',
                type: NotificationType.info);
          }
          await Future.delayed(retryInterval);
        }
      }

      // After all attempts, check if we got the data
      if (transactionData == null) {
        // Show failure message and stop
        if (context.mounted) {
          showSnackBar(
            '❌ Failed to retrieve transaction data for TsNum: $tsNum after 45 seconds.',
            type: NotificationType.error,
          );
        }

        // Copy the original PDF to processed folder without modifications
        final originalPdfFile = File(pdfPath);
        if (!await processedFile.exists() && !isSameFile) {
          await originalPdfFile.copy(processedPath);
          if (kDebugMode) {
            print('Copied original PDF to $processedPath (without QR code)');
          }
        }

        // Show detailed failure dialog
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('Database Timeout'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction data for TsNum: $tsNum could not be found in the database.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Possible reasons:\n'
                    '• The transaction hasn\'t been synced to the database yet\n'
                    '• The TsNum is incorrect\n'
                    '• The database file is not accessible',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'PDF was processed but QR code was not added.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Option to retry manually
                    _modifyPdfWithDbData(
                      context: context,
                      pdfPath: pdfPath,
                      tsNum: tsNum,
                      outputDirs: outputDirs,
                      showSnackBar: showSnackBar,
                      dbPath: dbPath,
                      qrX: qrX,
                      qrY: qrY,
                    );
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // If we have data, proceed with PDF modification
      final originalPdfFile = File(pdfPath);
      if (!await processedFile.exists() && !isSameFile) {
        await originalPdfFile.copy(processedPath);
        if (kDebugMode) {
          print('Copied original PDF to $processedPath');
        }
      }

      final bytes = await originalPdfFile.readAsBytes();
      final pdfDocument = PdfDocument(inputBytes: bytes);
      final font = PdfStandardFont(PdfFontFamily.helvetica, 8);
      const double qrCodeSize = 42;
      const double lineSpacing = 12;

      String formattedDate = transactionData['Date'] ?? '';
      try {
        final dateTime = DateTime.parse(formattedDate);
        formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing date "${transactionData['Date']}": $e');
        }
      }

      final qrCodeData = transactionData['QrCode'] ?? '';
      PdfBitmap? pdfBitmap;
      if (qrCodeData.isNotEmpty) {
        final qrImageData = _generateQrCodeImage(qrCodeData);
        if (qrImageData != null) {
          pdfBitmap = PdfBitmap(qrImageData);
        } else {
          showSnackBar('Failed to generate QR code for TsNum: $tsNum',
              type: NotificationType.error);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final String layout = prefs.getString('qr_layout') ?? 'beside';
      final String preset = prefs.getString('qr_position_preset') ?? 'bottom_right';
      final double? effectiveQrX = qrX ?? prefs.getDouble('qr_x_pos');
      final double? effectiveQrY = qrY ?? prefs.getDouble('qr_y_pos');

      for (int i = 0; i < pdfDocument.pages.count; i++) {
        final page = pdfDocument.pages[i];
        final pageSize = page.getClientSize();

        double xPosition;
        double yPosition;

        if (preset == 'custom' || (effectiveQrX != null || effectiveQrY != null)) {
          xPosition = effectiveQrX ??
              (preset == 'bottom_left'
                  ? 40
                  : (layout == 'below' ? (pageSize.width - 150) : (pageSize.width - 210)));
          yPosition = effectiveQrY ??
              (layout == 'below' ? (pageSize.height - 110) : (pageSize.height - 60));
        } else if (preset == 'bottom_left') {
          xPosition = 40;
          yPosition = layout == 'below' ? (pageSize.height - 110) : (pageSize.height - 60);
        } else {
          // bottom_right (default)
          xPosition = layout == 'below' ? (pageSize.width - 150) : (pageSize.width - 210);
          yPosition = layout == 'below' ? (pageSize.height - 110) : (pageSize.height - 60);
        }

        if (pdfBitmap != null) {
          page.graphics.drawImage(
            pdfBitmap,
            Rect.fromLTWH(xPosition, yPosition, qrCodeSize, qrCodeSize),
          );
        }

        if (layout == 'below') {
          page.graphics.drawString(
            'Date: $formattedDate',
            font,
            bounds: Rect.fromLTWH(
                xPosition, yPosition + qrCodeSize + lineSpacing, 160, 12),
          );
          page.graphics.drawString(
            'CUIN: ${transactionData['MwNum']}',
            font,
            bounds: Rect.fromLTWH(
                xPosition, yPosition + qrCodeSize + 2 * lineSpacing, 160, 12),
          );
          page.graphics.drawString(
            'CUSN: ${transactionData['SerialNumber']}',
            font,
            bounds: Rect.fromLTWH(
                xPosition, yPosition + qrCodeSize + 3 * lineSpacing, 160, 12),
          );
        } else {
          // 'beside' - details on the right side of the QR code
          final double textXPosition = xPosition + qrCodeSize + 8;
          page.graphics.drawString(
            'Date: $formattedDate',
            font,
            bounds: Rect.fromLTWH(
                textXPosition, yPosition, 160, 12),
          );
          page.graphics.drawString(
            'CUIN: ${transactionData['MwNum']}',
            font,
            bounds: Rect.fromLTWH(
                textXPosition, yPosition + lineSpacing, 160, 12),
          );
          page.graphics.drawString(
            'CUSN: ${transactionData['SerialNumber']}',
            font,
            bounds: Rect.fromLTWH(
                textXPosition, yPosition + 2 * lineSpacing, 160, 12),
          );
        }
      }

      final outputPath = path.join(outputDirs['taxInvoices']!,
          tsNum.isNotEmpty ? '${tsNum}_TAX.pdf' : '${path.basenameWithoutExtension(pdfPath)}_TAX.pdf');
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdfDocument.save());
      pdfDocument.dispose();

      if (kDebugMode) {
        print('TAX PDF saved to $outputPath');
      }
      showSnackBar('✅ TAX PDF saved at $outputPath',
          type: NotificationType.success);
    } catch (e) {
      showSnackBar('Error modifying PDF: $e', type: NotificationType.error);
      if (kDebugMode) {
        print('Error modifying PDF for TsNum $tsNum: $e');
      }
    }
  }

  static Future<void> _moveToDuplicates(
      BuildContext context,
      String pdfPath,
      String duplicatesDir,
      void Function(String message, {NotificationType type})
          showSnackBar) async {
    try {
      final file = File(pdfPath);
      final fileName = path.basename(pdfPath);
      if (await file.exists()) {
        String targetDupPath = path.join(duplicatesDir, fileName);
        if (await File(targetDupPath).exists()) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          targetDupPath = path.join(duplicatesDir,
              '${path.basenameWithoutExtension(fileName)}_$timestamp.pdf');
        }
        await file.rename(targetDupPath);
        if (context.mounted) {
          showSnackBar('Moved to duplicates: ${path.basename(targetDupPath)}',
              type: NotificationType.info);
        }
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar('Error moving to duplicates: $e',
            type: NotificationType.error);
      }
    }
  }

  static Future<OverwriteResult> _confirmOverwrite(
      BuildContext context, String filePath) async {
    final OverwriteResult? result = await showDialog<OverwriteResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('File Exists'),
          ],
        ),
        content: Text(
            'File $filePath already exists. How would you like to proceed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, OverwriteResult.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, OverwriteResult.readFromDb),
            child: const Text('Read from DB'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, OverwriteResult.overwrite),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
    return result ?? OverwriteResult.cancel;
  }

  static Future<bool> _confirmBulkOverwrite(
      BuildContext context, String type) async {
    final bool? overwrite = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Existing $type'),
        content: Text('Some $type files already exist. Overwrite all?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip Existing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Overwrite All'),
          ),
        ],
      ),
    );
    return overwrite ?? false;
  }

  /// Helper to detect if the document is from Sleek Kenya
  static bool _isSleekTemplate(String text) {
    return text.contains('Sleek Kenya') ||
        text.contains('SLEEK KENYA') ||
        text.contains('Sleek Kenya Ltd') ||
        text.contains('Sleek Kenya Limited');
  }

  static String _generateInvoiceContent(DataModel item) {
    item.validate();
    final content = StringBuffer();
    content.write('"${item.tsNum}"@1j\n');
    content.write('"${item.buyerPIN ?? ''}"@39F\n');

    final double absConvertedTotalAmount =
        (item.convertedTotalAmount ?? 0).abs();
    final int targetGrandTotalCents = (absConvertedTotalAmount * 100).round();

    const maxDescriptionLength = 100;
    final details = item.itemDetails ?? [];

    // Check if this is a Sleek Kenya document
    final bool isSleek = _isSleekTemplate(item.rawText ?? '');

    int calculatedItemsTotalCents = 0;

    for (int i = 0; i < details.length; i++) {
      final detail = details[i];
      detail.validate();

      var description = detail.description
          .replaceAll(RegExp(r"[^\w\s']"), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (description.length > maxDescriptionLength) {
        description = description.substring(0, maxDescriptionLength).trim();
      }

      final sanitizedItemCode =
          detail.itemCode?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final suffix = (sanitizedItemCode != null && sanitizedItemCode.isNotEmpty)
          ? 'H"$sanitizedItemCode"@P'
          : 'H1R';

      // Use the item amount directly from the parsed data
      // This is the Total (Incl) value from the invoice
      final double itemTotal = detail.itemAmount.abs();
      final int scaledQuantity = (detail.quantity * 100).round();

      if (scaledQuantity > 0 && itemTotal > 0) {
        // Calculate the unit price in CENTS
        final double unitPrice = itemTotal / detail.quantity;
        final int unitPriceCents = (unitPrice * 100).round();

        calculatedItemsTotalCents +=
            ((scaledQuantity * unitPriceCents) / 100).round();

        // Write the line item with the actual quantity and unit price in cents
        content
            .write('"$description"@$scaledQuantity*$unitPriceCents$suffix\n');
      }

      // ONLY add discount line if NOT from Sleek Kenya
      // Sleek Kenya invoices/credit notes already have discounts applied in the item amount
      if (!isSleek && detail.discountRate != null && detail.discountRate! > 0) {
        final discountStr = (detail.discountRate! * 100).toStringAsFixed(0);
        content.write('"Discount"@$discountStr*1M\n');
      }
    }

    final int finalTotalCents = calculatedItemsTotalCents > 0
        ? calculatedItemsTotalCents
        : targetGrandTotalCents;
    final formattedTotal = finalTotalCents.toString();
    content.write('${formattedTotal}H0T\n');
    content.write('${formattedTotal}H1T\n');
    content.write('S\n');
    content.write('1J\n');
    return content.toString();
  }

  static String _generateCreditNoteContent(DataModel item, {String? cuin}) {
    item.validate();
    final content = StringBuffer();
    content.write('"${cuin ?? item.mwNum ?? ""}"@"${item.tsNum}"@3j\n');
    content.write('"${item.buyerPIN ?? ''}"@39F\n');

    final double absConvertedTotalAmount =
        (item.convertedTotalAmount ?? 0).abs();
    final int targetGrandTotalCents = (absConvertedTotalAmount * 100).round();

    const maxDescriptionLength = 100;
    final details = item.itemDetails ?? [];

    // Check if this is a Sleek Kenya document
    final bool isSleek = _isSleekTemplate(item.rawText ?? '');

    int calculatedItemsTotalCents = 0;

    for (int i = 0; i < details.length; i++) {
      final detail = details[i];
      detail.validate();

      var description = detail.description
          .replaceAll(RegExp(r"[^\w\s']"), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (description.length > maxDescriptionLength) {
        description = description.substring(0, maxDescriptionLength).trim();
      }

      final sanitizedItemCode =
          detail.itemCode?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final suffix = (sanitizedItemCode != null && sanitizedItemCode.isNotEmpty)
          ? 'H"$sanitizedItemCode"@P'
          : 'H1R';

      // Use the item amount directly from the parsed data
      // This is the Total (Incl) value from the invoice
      final double itemTotal = detail.itemAmount.abs();
      final int scaledQuantity = (detail.quantity * 100).round();

      if (scaledQuantity > 0 && itemTotal > 0) {
        // Calculate the unit price in CENTS
        final double unitPrice = itemTotal / detail.quantity;
        final int unitPriceCents = (unitPrice * 100).round();

        calculatedItemsTotalCents +=
            ((scaledQuantity * unitPriceCents) / 100).round();

        // Write the line item with the actual quantity and unit price in cents
        content
            .write('"$description"@$scaledQuantity*$unitPriceCents$suffix\n');
      }

      // ONLY add discount line if NOT from Sleek Kenya
      // Sleek Kenya invoices/credit notes already have discounts applied in the item amount
      if (!isSleek && detail.discountRate != null && detail.discountRate! > 0) {
        final discountStr = (detail.discountRate! * 100).toStringAsFixed(0);
        content.write('"Discount"@$discountStr*1M\n');
      }
    }

    final int finalTotalCents = calculatedItemsTotalCents > 0
        ? calculatedItemsTotalCents
        : targetGrandTotalCents;
    final formattedTotal = finalTotalCents.toString();
    content.write('${formattedTotal}H0T\n');
    content.write('${formattedTotal}H1T\n');
    content.write('S\n');
    content.write('1J\n');
    return content.toString();
  }

  static Future<void> _writeFile(
    String ticketPath,
    String textFilesPath,
    String content, {
    bool overwrite = false,
  }) async {
    final ticketFile = File(ticketPath);
    final textFilesFile = File(textFilesPath);
    if (await ticketFile.exists() && !overwrite) {
      throw Exception('File already exists: $ticketPath');
    }
    if (await textFilesFile.exists() && !overwrite) {
      throw Exception('File already exists: $textFilesPath');
    }
    await ticketFile.writeAsString(content);
    await textFilesFile.writeAsString(content);
    if (kDebugMode) {
      print('Written to $ticketPath and $textFilesPath:\n$content');
    }
  }

  static Future<void> generateCreditNote({
    required BuildContext context,
    required DataModel item,
    required void Function(String message, {NotificationType type})
        showSnackBar,
    required Future<Map<String, String>> Function() getOutputDirectory,
    required String pdfPath,
    bool processWithDb = true,
    String? dbPath,
    double? qrX,
    double? qrY,
  }) async {
    try {
      if (!await verifyLicense(context, showSnackBar)) return;

      item.validate();
      if (item.itemDetails == null || item.itemDetails!.isEmpty) {
        showSnackBar('No item details available.',
            type: NotificationType.warning);
        return;
      }
      final outputDirs = await getOutputDirectory();
      final processedPath = path.join(outputDirs['processedInvoices']!,
          item.tsNum.isNotEmpty ? '${item.tsNum}.pdf' : path.basename(pdfPath));
      final processedFile = File(processedPath);
      final isSameFile =
          path.normalize(pdfPath) == path.normalize(processedPath);

      if (await processedFile.exists()) {
        if (!context.mounted) return;
        final shouldReprocess =
            await _confirmReprocessInvoice(context, processedPath);
        if (!context.mounted) return;
        if (!shouldReprocess) {
          if (!isSameFile) {
            await _moveToDuplicates(
                context, pdfPath, outputDirs['duplicates']!, showSnackBar);
          }
          return;
        }
      }
      final ticketPath =
          path.join(outputDirs['ticket']!, 'PC_${item.tsNum}.txt');
      final textFilesPath =
          path.join(outputDirs['textFiles']!, 'PC_${item.tsNum}.txt');

      String? selectedCuin;
      if (context.mounted) {
        final result = await _promptForCuin(context, '',
            title: 'Enter Original Invoice CUIN');
        if (result == null) {
          showSnackBar('Credit note generation cancelled.',
              type: NotificationType.info);
          return;
        }
        selectedCuin = result;
      }

      final content = _generateCreditNoteContent(item, cuin: selectedCuin);
      try {
        await _writeFile(ticketPath, textFilesPath, content);
      } catch (e) {
        if (!context.mounted) return;
        final result = await _confirmOverwrite(context, ticketPath);
        if (result == OverwriteResult.overwrite) {
          await _writeFile(ticketPath, textFilesPath, content, overwrite: true);
        } else if (result == OverwriteResult.readFromDb) {
          showSnackBar(
              'Using existing text file and reading response from database.',
              type: NotificationType.info);
        } else {
          showSnackBar('Credit note generation cancelled.',
              type: NotificationType.info);
          return;
        }
      }
      showSnackBar('Credit note generated at $ticketPath and $textFilesPath',
          type: NotificationType.success);

      String currentPdfPath = pdfPath;
      if (!isSameFile && pdfPath.isNotEmpty) {
        try {
          final file = File(pdfPath);
          if (await file.exists()) {
            if (await File(processedPath).exists()) {
              await File(processedPath).delete().catchError((_) => file);
            }
            await file.copy(processedPath);
            await file.delete().catchError((_) => file);
            currentPdfPath = processedPath;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error moving file to processed: $e');
          }
        }
      }

      if (processWithDb && currentPdfPath.isNotEmpty) {
        assert(dbPath != null,
            'dbPath must be provided when processWithDb is true');
        if (!context.mounted) return;
        await _modifyPdfWithDbData(
          context: context,
          pdfPath: currentPdfPath,
          tsNum: item.tsNum,
          outputDirs: outputDirs,
          showSnackBar: showSnackBar,
          dbPath: dbPath!,
          qrX: qrX,
          qrY: qrY,
        );
      }
    } catch (e, s) {
      if (context.mounted) {
        showSnackBar('Error generating credit note: $e',
            type: NotificationType.error);
      }
      if (kDebugMode) {
        debugPrint(
            '--- ERROR: Failed to generate Credit Note for ${item.tsNum} ---');
        debugPrint('Exception: $e');
        debugPrint('Stack Trace: $s');
        debugPrint('---------------------------------------------------------');
      }
    }
  }

  static Future<void> generateInvoice({
    required BuildContext context,
    required DataModel item,
    required void Function(String message, {NotificationType type})
        showSnackBar,
    required Future<Map<String, String>> Function() getOutputDirectory,
    required String pdfPath,
    bool processWithDb = true,
    String? dbPath,
    double? qrX,
    double? qrY,
  }) async {
    try {
      if (!await verifyLicense(context, showSnackBar)) return;

      item.validate();
      if (item.itemDetails == null || item.itemDetails!.isEmpty) {
        showSnackBar('No item details available.',
            type: NotificationType.warning);
        return;
      }
      final outputDirs = await getOutputDirectory();
      final fileName = path.basename(pdfPath);
      final processedPath = path.join(outputDirs['processedInvoices']!,
          item.tsNum.isNotEmpty ? '${item.tsNum}.pdf' : fileName);

      final isAlreadyInProcessed =
          path.normalize(pdfPath) == path.normalize(processedPath);

      if (await File(processedPath).exists() && !isAlreadyInProcessed) {
        if (!context.mounted) return;
        final shouldReprocess =
            await _confirmReprocessInvoice(context, processedPath);
        if (!context.mounted) return;
        if (!shouldReprocess) {
          await _moveToDuplicates(
              context, pdfPath, outputDirs['duplicates']!, showSnackBar);
          return;
        }
      }

      final ticketPath =
          path.join(outputDirs['ticket']!, 'PC_${item.tsNum}.txt');
      final textFilesPath =
          path.join(outputDirs['textFiles']!, 'PC_${item.tsNum}.txt');
      final content = _generateInvoiceContent(item);
      try {
        await _writeFile(ticketPath, textFilesPath, content);
      } catch (e) {
        if (!context.mounted) return;
        final result = await _confirmOverwrite(context, ticketPath);
        if (result == OverwriteResult.overwrite) {
          await _writeFile(ticketPath, textFilesPath, content, overwrite: true);
        } else if (result == OverwriteResult.readFromDb) {
          showSnackBar(
              'Using existing text file and reading response from database.',
              type: NotificationType.info);
        } else {
          showSnackBar('Invoice generation cancelled.',
              type: NotificationType.info);
          return;
        }
      }
      showSnackBar('Invoice generated at $ticketPath and $textFilesPath',
          type: NotificationType.success);

      String currentPdfPath = pdfPath;
      if (!isAlreadyInProcessed) {
        try {
          final file = File(pdfPath);
          if (await file.exists()) {
            if (await File(processedPath).exists()) {
              await File(processedPath).delete().catchError((_) => file);
            }
            await file.copy(processedPath);
            await file.delete().catchError((_) => file);
            currentPdfPath = processedPath;
          }
        } catch (e) {
          showSnackBar('Error moving file to processed: $e',
              type: NotificationType.error);
        }
      }

      if (processWithDb && currentPdfPath.isNotEmpty) {
        assert(dbPath != null,
            'dbPath must be provided when processWithDb is true');
        if (!context.mounted) return;
        await _modifyPdfWithDbData(
          context: context,
          pdfPath: currentPdfPath,
          tsNum: item.tsNum,
          outputDirs: outputDirs,
          showSnackBar: showSnackBar,
          dbPath: dbPath!,
          qrX: qrX,
          qrY: qrY,
        );
      }
    } catch (e, s) {
      if (context.mounted) {
        showSnackBar('Error generating invoice: $e',
            type: NotificationType.error);
      }
      if (kDebugMode) {
        debugPrint(
            '--- ERROR: Failed to generate Invoice for ${item.tsNum} ---');
        debugPrint('Exception: $e');
        debugPrint('Stack Trace: $s');
        debugPrint('---------------------------------------------------------');
      }
    }
  }

  static Future<void> generateAllCreditNotes({
    required BuildContext context,
    required List<DataModel> filteredData,
    required void Function(String message, {NotificationType type})
        showSnackBar,
    required void Function({required bool isProcessing, double progress})
        setProcessing,
    required List<String> pdfPaths,
    bool processWithDb = true,
    String? dbPath,
    double? qrX,
    double? qrY,
  }) async {
    if (filteredData.isEmpty) {
      showSnackBar('No transactions to process.', type: NotificationType.info);
      return;
    }
    if (!await verifyLicense(context, showSnackBar)) return;

    setProcessing(isProcessing: true);
    try {
      final outputDirs = await getOutputDirectory();
      bool overwriteAll = false;
      bool hasExisting = false;
      for (var item in filteredData) {
        final ticketPath =
            path.join(outputDirs['ticket']!, 'PC_${item.tsNum}.txt');
        final textFilesPath =
            path.join(outputDirs['textFiles']!, 'PC_${item.tsNum}.txt');
        if (await File(ticketPath).exists() ||
            await File(textFilesPath).exists()) {
          hasExisting = true;
          break;
        }
      }
      if (hasExisting) {
        if (!context.mounted) return;
        overwriteAll = await _confirmBulkOverwrite(context, 'Credit Notes');
      }
      if (!context.mounted) return;

      int successCount = 0;
      int failCount = 0;
      final failedTsNums = <String>[];
      for (var i = 0; i < filteredData.length; i++) {
        final item = filteredData[i];
        final pdfPath = pdfPaths[i];
        try {
          if (item.itemDetails == null || item.itemDetails!.isEmpty) {
            failedTsNums.add(item.tsNum);
            failCount++;
            continue;
          }
          final processedPath = path.join(outputDirs['processedInvoices']!,
              item.tsNum.isNotEmpty ? '${item.tsNum}.pdf' : path.basename(pdfPath));
          final processedFile = File(processedPath);
          final isSameFile =
              path.normalize(pdfPath) == path.normalize(processedPath);

          if (await processedFile.exists()) {
            if (!context.mounted) continue;
            final shouldReprocess =
                await _confirmReprocessInvoice(context, processedPath);
            if (!shouldReprocess) {
              failedTsNums.add(item.tsNum);
              if (!isSameFile) {
                if (!context.mounted) continue;
                await _moveToDuplicates(
                    context, pdfPath, outputDirs['duplicates']!, showSnackBar);
              }
              failCount++;
              continue;
            }
          }
          final ticketPath =
              path.join(outputDirs['ticket']!, 'PC_${item.tsNum}.txt');
          final textFilesPath =
              path.join(outputDirs['textFiles']!, 'PC_${item.tsNum}.txt');

          String? selectedCuin;
          if (context.mounted) {
            final result = await _promptForCuin(context, '',
                title: 'Enter Original Invoice CUIN');
            if (result == null) {
              failedTsNums.add(item.tsNum);
              failCount++;
              continue;
            }
            selectedCuin = result;
          }

          final content = _generateCreditNoteContent(item, cuin: selectedCuin);
          try {
            await _writeFile(ticketPath, textFilesPath, content,
                overwrite: overwriteAll);
          } catch (e) {
            if ((await File(ticketPath).exists() ||
                    await File(textFilesPath).exists()) &&
                !overwriteAll) {
              continue;
            }
            if (!context.mounted) continue;
            final result = await _confirmOverwrite(context, ticketPath);
            if (result == OverwriteResult.overwrite) {
              await _writeFile(ticketPath, textFilesPath, content,
                  overwrite: true);
            } else if (result == OverwriteResult.readFromDb) {
              // Proceed without writing
            } else {
              continue;
            }
          }

          String currentPdfPath = pdfPath;
          if (!isSameFile && pdfPath.isNotEmpty) {
            try {
              final file = File(pdfPath);
              if (await file.exists()) {
                if (await File(processedPath).exists()) {
                  await File(processedPath).delete().catchError((_) => file);
                }
                await file.copy(processedPath);
                await file.delete().catchError((_) => file);
                currentPdfPath = processedPath;
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error moving file to processed: $e');
              }
            }
          }

          if (processWithDb && currentPdfPath.isNotEmpty) {
            assert(dbPath != null,
                'dbPath must be provided when processWithDb is true');
            if (!context.mounted) continue;
            await _modifyPdfWithDbData(
              context: context,
              pdfPath: currentPdfPath,
              tsNum: item.tsNum,
              outputDirs: outputDirs,
              showSnackBar: showSnackBar,
              dbPath: dbPath!,
              qrX: qrX,
              qrY: qrY,
            );
          }
          successCount++;
        } catch (e) {
          failedTsNums.add(item.tsNum);
          failCount++;
        }
        setProcessing(
            isProcessing: true, progress: (i + 1) / filteredData.length);
      }
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Credit Notes Generation'),
          content: Text(
              'Generated $successCount credit notes successfully.${failCount > 0 ? '\nFailed $failCount (TsNum: ${failedTsNums.join(', ')})' : ''}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        showSnackBar('Error generating credit notes: $e',
            type: NotificationType.error);
      }
    } finally {
      setProcessing(isProcessing: false);
    }
  }

  static Future<void> generateAllInvoices({
    required BuildContext context,
    required List<DataModel> filteredData,
    required void Function(String message, {NotificationType type})
        showSnackBar,
    required void Function({required bool isProcessing, double progress})
        setProcessing,
    required List<String> pdfPaths,
    bool processWithDb = true,
    String? dbPath,
    double? qrX,
    double? qrY,
  }) async {
    if (filteredData.isEmpty) {
      showSnackBar('No transactions to process.', type: NotificationType.info);
      return;
    }
    if (!await verifyLicense(context, showSnackBar)) return;

    setProcessing(isProcessing: true);
    try {
      final outputDirs = await getOutputDirectory();
      bool overwriteAll = false;
      bool hasExisting = false;
      for (var item in filteredData) {
        final ticketPath =
            path.join(outputDirs['ticket']!, 'PC_${item.tsNum}.txt');
        final textFilesPath =
            path.join(outputDirs['textFiles']!, 'PC_${item.tsNum}.txt');
        if (await File(ticketPath).exists() ||
            await File(textFilesPath).exists()) {
          hasExisting = true;
          break;
        }
      }
      if (hasExisting) {
        if (!context.mounted) return;
        overwriteAll = await _confirmBulkOverwrite(context, 'Invoices');
      }
      if (!context.mounted) return;

      int successCount = 0;
      int failCount = 0;
      final failedTsNums = <String>[];
      for (var i = 0; i < filteredData.length; i++) {
        final item = filteredData[i];
        final pdfPath = pdfPaths[i];
        try {
          if (item.itemDetails == null || item.itemDetails!.isEmpty) {
            failedTsNums.add(item.tsNum);
            failCount++;
            continue;
          }
          final processedPath = path.join(outputDirs['processedInvoices']!,
              item.tsNum.isNotEmpty ? '${item.tsNum}.pdf' : path.basename(pdfPath));
          final processedFile = File(processedPath);
          final isSameFile =
              path.normalize(pdfPath) == path.normalize(processedPath);

          if (await processedFile.exists()) {
            if (!context.mounted) continue;
            final shouldReprocess =
                await _confirmReprocessInvoice(context, processedPath);
            if (!shouldReprocess) {
              failedTsNums.add(item.tsNum);
              if (!isSameFile) {
                if (!context.mounted) continue;
                await _moveToDuplicates(
                    context, pdfPath, outputDirs['duplicates']!, showSnackBar);
              }
              failCount++;
              continue;
            }
          }
          final ticketPath =
              path.join(outputDirs['ticket']!, 'PC_${item.tsNum}.txt');
          final textFilesPath =
              path.join(outputDirs['textFiles']!, 'PC_${item.tsNum}.txt');
          final content = _generateInvoiceContent(item);
          try {
            await _writeFile(ticketPath, textFilesPath, content,
                overwrite: overwriteAll);
          } catch (e) {
            if ((await File(ticketPath).exists() ||
                    await File(textFilesPath).exists()) &&
                !overwriteAll) {
              continue;
            }
            if (!context.mounted) continue;
            final result = await _confirmOverwrite(context, ticketPath);
            if (result == OverwriteResult.overwrite) {
              await _writeFile(ticketPath, textFilesPath, content,
                  overwrite: true);
            } else if (result == OverwriteResult.readFromDb) {
              // Proceed without writing
            } else {
              continue;
            }
          }

          String currentPdfPath = pdfPath;
          if (!isSameFile && pdfPath.isNotEmpty) {
            try {
              final file = File(pdfPath);
              if (await file.exists()) {
                if (await File(processedPath).exists()) {
                  await File(processedPath).delete().catchError((_) => file);
                }
                await file.copy(processedPath);
                await file.delete().catchError((_) => file);
                currentPdfPath = processedPath;
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error moving file to processed: $e');
              }
            }
          }

          if (processWithDb && currentPdfPath.isNotEmpty) {
            assert(dbPath != null,
                'dbPath must be provided when processWithDb is true');
            if (!context.mounted) continue;
            await _modifyPdfWithDbData(
              context: context,
              pdfPath: currentPdfPath,
              tsNum: item.tsNum,
              outputDirs: outputDirs,
              showSnackBar: showSnackBar,
              dbPath: dbPath!,
              qrX: qrX,
              qrY: qrY,
            );
          }
          successCount++;
        } catch (e) {
          failedTsNums.add(item.tsNum);
          failCount++;
        }
        setProcessing(
            isProcessing: true, progress: (i + 1) / filteredData.length);
      }
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invoices Generation'),
          content: Text(
              'Generated $successCount invoices successfully.${failCount > 0 ? '\nFailed $failCount (TsNum: ${failedTsNums.join(', ')})' : ''}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        showSnackBar('Error generating invoices: $e',
            type: NotificationType.error);
      }
    } finally {
      setProcessing(isProcessing: false);
    }
  }

  static Future<void> generateAllDocuments({
    required BuildContext context,
    required List<DataModel> filteredData,
    required void Function(String message, {NotificationType type})
        showSnackBar,
    required void Function({required bool isProcessing, double progress})
        setProcessing,
    required List<String> pdfPaths,
    bool processWithDb = true,
    String? dbPath,
    double? qrX,
    double? qrY,
  }) async {
    if (filteredData.isEmpty) {
      showSnackBar('No transactions to process.', type: NotificationType.info);
      return;
    }
    if (!await verifyLicense(context, showSnackBar)) return;

    setProcessing(isProcessing: true);
    try {
      final outputDirs = await getOutputDirectory();
      bool overwriteAll = false;
      bool hasExisting = false;
      for (var item in filteredData) {
        final invoicePath =
            path.join(outputDirs['ticket']!, 'PC_${item.tsNum}.txt');
        final creditNotePath =
            path.join(outputDirs['ticket']!, 'PC_CN_${item.tsNum}.txt');
        final invoiceTextFilesPath =
            path.join(outputDirs['textFiles']!, 'PC_${item.tsNum}.txt');
        final creditNoteTextFilesPath =
            path.join(outputDirs['textFiles']!, 'PC_CN_${item.tsNum}.txt');
        if (await File(invoicePath).exists() ||
            await File(creditNotePath).exists() ||
            await File(invoiceTextFilesPath).exists() ||
            await File(creditNoteTextFilesPath).exists()) {
          hasExisting = true;
          break;
        }
      }
      if (hasExisting) {
        if (!context.mounted) return;
        overwriteAll = await _confirmBulkOverwrite(context, 'Documents');
      }
      if (!context.mounted) return;

      int successCount = 0;
      int failCount = 0;
      final failedTsNums = <String>[];
      for (var i = 0; i < filteredData.length; i++) {
        final item = filteredData[i];
        final pdfPath = pdfPaths[i];
        try {
          if (item.itemDetails == null || item.itemDetails!.isEmpty) {
            failedTsNums.add(item.tsNum);
            failCount++;
            continue;
          }
          final processedPath = path.join(outputDirs['processedInvoices']!,
              item.tsNum.isNotEmpty ? '${item.tsNum}.pdf' : path.basename(pdfPath));
          final processedFile = File(processedPath);
          final isSameFile =
              path.normalize(pdfPath) == path.normalize(processedPath);

          if (await processedFile.exists()) {
            if (!context.mounted) continue;
            final shouldReprocess =
                await _confirmReprocessInvoice(context, processedPath);
            if (!shouldReprocess) {
              failedTsNums.add(item.tsNum);
              if (!isSameFile) {
                if (!context.mounted) continue;
                await _moveToDuplicates(
                    context, pdfPath, outputDirs['duplicates']!, showSnackBar);
              }
              failCount++;
              continue;
            }
          }
          final invoicePath =
              path.join(outputDirs['ticket']!, 'PC_${item.tsNum}.txt');
          final creditNotePath =
              path.join(outputDirs['ticket']!, 'PC_CN_${item.tsNum}.txt');
          final invoiceTextFilesPath =
              path.join(outputDirs['textFiles']!, 'PC_${item.tsNum}.txt');
          final creditNoteTextFilesPath =
              path.join(outputDirs['textFiles']!, 'PC_CN_${item.tsNum}.txt');
          final invoiceContent = _generateInvoiceContent(item);

          String? selectedCuin;
          if (context.mounted) {
            final result = await _promptForCuin(context, '',
                title: 'Enter Original Invoice CUIN');
            if (result == null) {
              failedTsNums.add(item.tsNum);
              failCount++;
              continue;
            }
            selectedCuin = result;
          }

          final creditNoteContent =
              _generateCreditNoteContent(item, cuin: selectedCuin);
          try {
            await _writeFile(invoicePath, invoiceTextFilesPath, invoiceContent,
                overwrite: overwriteAll);
            await _writeFile(
                creditNotePath, creditNoteTextFilesPath, creditNoteContent,
                overwrite: overwriteAll);
          } catch (e) {
            if ((await File(invoicePath).exists() ||
                    await File(creditNotePath).exists() ||
                    await File(invoiceTextFilesPath).exists() ||
                    await File(creditNoteTextFilesPath).exists()) &&
                !overwriteAll) {
              continue;
            }
            if (!context.mounted) continue;
            final resultInvoice = await _confirmOverwrite(context, invoicePath);
            if (resultInvoice == OverwriteResult.overwrite) {
              await _writeFile(
                  invoicePath, invoiceTextFilesPath, invoiceContent,
                  overwrite: true);
            } else if (resultInvoice == OverwriteResult.cancel) {
              continue;
            }
            if (!context.mounted) continue;
            final resultCreditNote =
                await _confirmOverwrite(context, creditNotePath);
            if (resultCreditNote == OverwriteResult.overwrite) {
              await _writeFile(
                  creditNotePath, creditNoteTextFilesPath, creditNoteContent,
                  overwrite: true);
            } else if (resultCreditNote == OverwriteResult.cancel) {
              continue;
            }
          }

          String currentPdfPath = pdfPath;
          if (!isSameFile && pdfPath.isNotEmpty) {
            try {
              final file = File(pdfPath);
              if (await file.exists()) {
                if (await File(processedPath).exists()) {
                  await File(processedPath).delete().catchError((_) => file);
                }
                await file.copy(processedPath);
                await file.delete().catchError((_) => file);
                currentPdfPath = processedPath;
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error moving file to processed: $e');
              }
            }
          }

          if (processWithDb && currentPdfPath.isNotEmpty) {
            assert(dbPath != null,
                'dbPath must be provided when processWithDb is true');
            if (!context.mounted) continue;
            await _modifyPdfWithDbData(
              context: context,
              pdfPath: currentPdfPath,
              tsNum: item.tsNum,
              outputDirs: outputDirs,
              showSnackBar: showSnackBar,
              dbPath: dbPath!,
              qrX: qrX,
              qrY: qrY,
            );
          }
          successCount++;
        } catch (e) {
          failedTsNums.add(item.tsNum);
          failCount++;
        }
        setProcessing(
            isProcessing: true, progress: (i + 1) / filteredData.length);
      }
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Documents Generation'),
          content: Text(
              'Generated $successCount documents successfully.${failCount > 0 ? '\nFailed $failCount (TsNum: ${failedTsNums.join(', ')})' : ''}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        showSnackBar('Error generating documents: $e',
            type: NotificationType.error);
      }
    } finally {
      setProcessing(isProcessing: false);
    }
  }

  static Future<List<DataModel>> parsePdfsToDataModels({
    required BuildContext context,
    required List<String> pdfPaths,
    required void Function(String message, {NotificationType type})
        showSnackBar,
    required void Function({required bool isProcessing, double progress})
        setProcessing,
  }) async {
    final List<DataModel> dataModels = [];
    for (var i = 0; i < pdfPaths.length; i++) {
      final pdfPath = pdfPaths[i];
      try {
        final file = File(pdfPath);
        final bytes = await file.readAsBytes();
        final pdfDocument = PdfDocument(inputBytes: bytes);
        final text = PdfTextExtractor(pdfDocument).extractText();
        pdfDocument.dispose();
        if (kDebugMode) {
          print('Extracted text from $pdfPath:\n$text');
        }
        if (!context.mounted) continue;
        final dataModel = await _parsePdfTextToDataModel(context, text, i + 1, pdfPath: pdfPath);
        // Store the raw text for Sleek detection later
        dataModel.rawText = text;
        dataModels.add(dataModel);
      } catch (e, s) {
        if (!context.mounted) continue;
        if (kDebugMode) {
          debugPrint('--- ERROR: Failed to parse PDF $pdfPath ---');
          debugPrint('Exception: $e');
          debugPrint('Stack Trace: $s');
        }
        showSnackBar('Error parsing PDF $pdfPath: $e',
            type: NotificationType.error);
      }
      setProcessing(isProcessing: true, progress: (i + 1) / pdfPaths.length);
    }
    return dataModels;
  }

  static Future<Map<String, DataModel>> parsePdfsToDataModelsMap({
    required BuildContext context,
    required List<String> pdfPaths,
    required void Function(String message, {NotificationType type})
        showSnackBar,
    required void Function({required bool isProcessing, double progress})
        setProcessing,
  }) async {
    final Map<String, DataModel> dataModels = {};
    for (var i = 0; i < pdfPaths.length; i++) {
      final pdfPath = pdfPaths[i];
      try {
        final file = File(pdfPath);
        final bytes = await file.readAsBytes();
        final pdfDocument = PdfDocument(inputBytes: bytes);
        final text = PdfTextExtractor(pdfDocument).extractText();
        pdfDocument.dispose();
        if (kDebugMode) {
          print('Extracted text from $pdfPath:\n$text');
        }
        if (!context.mounted) continue;
        final dataModel = await _parsePdfTextToDataModel(context, text, i + 1, pdfPath: pdfPath);
        // Store the raw text for Sleek detection later
        dataModel.rawText = text;
        dataModels[pdfPath] = dataModel;
      } catch (e, s) {
        if (!context.mounted) continue;
        if (kDebugMode) {
          debugPrint('--- ERROR: Failed to parse PDF $pdfPath ---');
          debugPrint('Exception: $e');
          debugPrint('Stack Trace: $s');
        }
        showSnackBar('Error parsing PDF $pdfPath: $e',
            type: NotificationType.error);
      }
      setProcessing(isProcessing: true, progress: (i + 1) / pdfPaths.length);
    }
    return dataModels;
  }

  static Future<DataModel> parsePdfTextToDataModelForTesting(
      String text, int id, {String? pdfPath}) async {
    return _parsePdfTextToDataModel(null, text, id, pdfPath: pdfPath);
  }

  static String normalizeSpacedTextForTesting(String text) {
    return _normalizeSpacedText(text);
  }

  static String _normalizeSpacedText(String rawText) {
    final spacedPattern = RegExp(r'\b(?:[A-Za-z0-9_]\s){2,}[A-Za-z0-9_]\b');
    return rawText.replaceAllMapped(spacedPattern, (match) {
      return match.group(0)!.replaceAll(' ', '');
    });
  }

  static Future<DataModel> _parsePdfTextToDataModel(
      BuildContext? context, String textInput, int id, {String? pdfPath}) async {
    // Sanitize raw PDF text FIRST (remove NUL bytes, non-breaking spaces, CRLF)
    final String cleanTextInput = textInput
        .replaceAll('\u0000', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    // Normalize character-spaced text FIRST before template detection
    final String text = _normalizeSpacedText(cleanTextInput);
    // Detect Template Type FIRST
    final bool isTemplateE =
        (text.contains('CASH SALE NO.') || text.contains('INVOICE NO.')) &&
            text.contains('STOCK CODE');
    final bool isTemplateH = text.contains('AUCTORITA TECHNOLOGIES LTD') &&
        text.contains('Invoice No.') &&
        text.contains('VAT @16%');
    final bool isTemplateI = (text.contains('SALVEN TRADING') ||
            text.contains('PANDA FLOWERS LIMITED')) &&
        text.contains('Invoice');
    final bool isTemplateF = text.contains('Protective Custody') &&
        text.toUpperCase().contains('HS CODE');
    final bool isTemplateG =
        text.toUpperCase().contains('SHIVTRONICS KENYA LTD');
    final bool isTemplateJ = text.contains('MARKETPOWER INTERNATIONAL LTD') ||
        text.contains('marketpower.co.ke');
    final bool isTemplatePharmacor =
        text.toUpperCase().contains('PHARMACOR LTD') ||
            text.toUpperCase().contains('PHARMACOR');
    final bool isTemplateAlphaKnits = text.toLowerCase().contains('alphaknits') ||
        text.contains('Alpha Knits') ||
        text.contains('ALPHA KNITS') ||
        text.contains('Alpha Knts') ||
        text.contains('ALPHA KNTS') ||
        text.contains('1561U') ||
        text.contains('P000600759T') ||
        text.contains('P659T') ||
        (pdfPath != null &&
            (pdfPath.toLowerCase().contains('alpha') ||
                pdfPath.toLowerCase().contains('knits')));
    final bool isTemplateRaa = text.toUpperCase().contains('RAA LIMITED') ||
        text.toUpperCase().contains('RAA LTD') ||
        text.contains('raalimited.com');

    // TEMPLATE S: Sleek Kenya invoices
    final bool isTemplateSleek = _isSleekTemplate(text);

    // ============================================================
    // 1. Determine Document Type (Invoice vs Credit Note)
    // ============================================================
    final bool isCreditNote = text.toUpperCase().contains('CREDIT NOTE') ||
        text.toUpperCase().contains('CREDIT TO') ||
        text.toUpperCase().contains('CREDIT NOTE NO') ||
        (isTemplateAlphaKnits && text.toUpperCase().contains('CREDIT')) ||
        (pdfPath != null &&
            (path.basename(pdfPath).toUpperCase().startsWith('CR') ||
                path.basename(pdfPath).toUpperCase().contains('CREDIT')));

    // ============================================================
    // 2. Extract Total Amount & Currency
    // ============================================================
    String? detectedCurrency;
    String totalAmountStr = '0.0';
    double? vatAmountA;

    final totalAmountMatch = RegExp(
            r'(?:Total|Amount|Credit)\s*(?:Amount|Total)?\s*(KES|USD|EUR|GBP|KSh|\$|â‚¬|Â£)\s*([-]?[\d,]+\.\d{2})',
            caseSensitive: false)
        .firstMatch(text);
    final totalAmountMatchI = RegExp(
            r'Total\s*(?:US\$|KES)?\s*([-]?[\d,]+\.\d{2})',
            caseSensitive: false)
        .firstMatch(text);

    final totalMatchG = isTemplateG
        ? RegExp(
                r'Total\s+Subtotal\s+VAT\s+Total[\s\S]*?KES\s+([-]?[\d,]+\.\d{2})',
                caseSensitive: false)
            .firstMatch(text)
        : null;

    final totalMatchJ = isTemplateJ
        ? RegExp(
                r'([\d,]+\.\d{2})\s+([\d,]+\.\d{2})\s+Total\s*VAT\s*Grand\s*Total[\s\S]*?([\d,]+\.\d{2})',
                caseSensitive: false)
            .firstMatch(text.replaceAll('D6', '6'))
        : null;

    if (totalMatchJ != null) {
      totalAmountStr = totalMatchJ.group(1)!.replaceAll(',', '');
      vatAmountA = double.tryParse(totalMatchJ.group(2)!.replaceAll(',', ''));
    } else if (isTemplateAlphaKnits) {
      final totalsRowMatch = RegExp(
        r'(?:Delivery\s*Terms\s*:|Total\s*Quantty\s*[\d,]+)\s*([\d,]+\.\d{2})\s+([\d,]+\.\d{2})\s+([\d,]+\.\d{2})\s+([\d,]+\.\d{2})',
        caseSensitive: false,
      ).firstMatch(text);

      final grandTotalMatch = RegExp(
        r'Grand\s*Total\s*([\d,]+\.\d{2})',
        caseSensitive: false,
      ).firstMatch(text);

      final netTotalMatch = RegExp(
        r'(?:Net\s*Total|Sub\s*Total|SubTotal)\s*([\d,]+\.\d{2})',
        caseSensitive: false,
      ).firstMatch(text);

      final vatMatch = RegExp(
        r'Tax\s*([\d,]+\.\d{2})',
        caseSensitive: false,
      ).firstMatch(text);

      double netTotal = 0.0;
      double parsedVat = 0.0;

      if (totalsRowMatch != null) {
        netTotal =
            double.tryParse(totalsRowMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
        parsedVat =
            double.tryParse(totalsRowMatch.group(4)!.replaceAll(',', '')) ?? 0.0;
        vatAmountA = parsedVat;
      } else if (grandTotalMatch != null) {
        final double grand =
            double.tryParse(grandTotalMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
        if (vatMatch != null) {
          parsedVat =
              double.tryParse(vatMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
          vatAmountA = parsedVat;
          netTotal = grand - parsedVat;
        } else {
          netTotal = grand / 1.16;
          vatAmountA = grand - netTotal;
        }
        totalAmountStr = grand.toStringAsFixed(2);
      } else if (netTotalMatch != null) {
        netTotal =
            double.tryParse(netTotalMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
        if (vatMatch != null) {
          parsedVat =
              double.tryParse(vatMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
          vatAmountA = parsedVat;
        }
      }

      if (grandTotalMatch == null) {
        if (parsedVat > 0) {
          vatAmountA = parsedVat;
          totalAmountStr = (netTotal + parsedVat).toStringAsFixed(2);
        } else if (text.contains('0.00 0.00 0.00') ||
            detectedCurrency == 'USD' ||
            text.toUpperCase().contains('SHOWN IN USD')) {
          vatAmountA = 0.0;
          totalAmountStr = netTotal.toStringAsFixed(2);
        } else {
          vatAmountA = netTotal * 0.16;
          totalAmountStr = (netTotal * 1.16).toStringAsFixed(2);
        }
      }
    } else if (isTemplateRaa) {
      final totalsMatch = RegExp(
        r'Sub\s*Total\s*\(Excl\)\s*VAT\s*Total\s*\(Incl\)[\s\r\n]*([\d,]+\.\d{2})\s*([\d,]+\.\d{2})\s*([\d,]+\.\d{2})',
        caseSensitive: false,
      ).firstMatch(text);
      if (totalsMatch != null) {
        vatAmountA = double.tryParse(totalsMatch.group(2)!.replaceAll(',', ''));
        totalAmountStr = totalsMatch.group(3)!.replaceAll(',', '');
      } else {
        final totalMatchFallback = RegExp(
          r'(?:Total|Sub\s*Total)\s*\(Incl\)?\s*[:]?\s*([\d,]+\.\d{2})',
          caseSensitive: false,
        ).firstMatch(text);
        if (totalMatchFallback != null) {
          totalAmountStr = totalMatchFallback.group(1)!.replaceAll(',', '');
        }
      }
    } else if (isTemplateE) {
      final totalMatchE = RegExp(
              r'([\d,]+\.\d{2})\s*[\r\n]+\s*(?:[\d,]+\.\d{2})\s*[\r\n]+\s*TOTAL VALUE:',
              caseSensitive: false)
          .firstMatch(text);
      if (totalMatchE != null) {
        totalAmountStr = totalMatchE.group(1)?.replaceAll(',', '') ?? '0.0';
      } else {
        final totalMatchFallback = RegExp(
                r'(?:TOTAL|AMOUNT|CREDIT)\s*(?:TOTAL|AMOUNT)?\s*[:]?\s*(?:KES|USD|EUR)?\s*([-]?[\d,]+\.\d{2})',
                caseSensitive: false)
            .firstMatch(text);
        totalAmountStr =
            totalMatchFallback?.group(1)?.replaceAll(',', '') ?? '0.0';
      }
    } else if (isTemplateI) {
      if (text.toUpperCase().contains('NEDERLAND') ||
          text.toUpperCase().contains('AALSMEER') ||
          text.contains('â‚¬') ||
          text.contains('EUR')) {
        detectedCurrency = 'EUR';
      } else if (text.contains('US\$')) {
        detectedCurrency = 'USD';
      }

      final footerMatch = RegExp(
              r'FRESH\s*CUT\s*FLOWERS[\s\S]*?(?:US\$|â‚¬|EUR|GBP|KES)?\s*[\d,]+\.\d{2}[\s\S]*?(?:US\$|â‚¬|EUR|GBP|KES)?\s*([-]?[\d,]+\.\d{2})',
              caseSensitive: false)
          .firstMatch(text);

      if (footerMatch != null) {
        totalAmountStr = footerMatch.group(1)!.replaceAll(',', '');
      } else {
        final currencyMatches = RegExp(
                r'(?:â‚¬|US\$|EUR|GBP|KES|KSh)\s*([-]?[\d,]+\.\d{2})',
                caseSensitive: false)
            .allMatches(text)
            .toList();

        if (currencyMatches.isNotEmpty) {
          if (currencyMatches.length >= 4) {
            totalAmountStr =
                currencyMatches[currencyMatches.length - 3].group(1)!;
          } else if (currencyMatches.length >= 2) {
            totalAmountStr = currencyMatches[1].group(1)!;
          } else {
            totalAmountStr = currencyMatches.last.group(1)!;
          }
        } else if (totalAmountMatchI != null) {
          totalAmountStr = totalAmountMatchI.group(1)!;
        }
      }
      totalAmountStr = totalAmountStr.replaceAll(',', '');
    } else if (totalMatchG != null) {
      totalAmountStr = totalMatchG.group(1)?.replaceAll(',', '') ?? '0.0';
    } else if (totalAmountMatch != null) {
      detectedCurrency = totalAmountMatch.group(1);
      totalAmountStr = totalAmountMatch.group(2)?.replaceAll(',', '') ?? '0.0';
    } else {
      final totalMatchFallback = RegExp(
              r'(?:TOTAL|AMOUNT)\s*[:]?\s*(?:KES|USD|EUR)?\s*([\d,]+\.\d{2})',
              caseSensitive: false)
          .firstMatch(text);
      totalAmountStr =
          totalMatchFallback?.group(1)?.replaceAll(',', '') ?? '0.0';
    }

    final double totalAmount = double.tryParse(totalAmountStr) ?? 0.0;

    // Detect Currency Symbol
    var currencyMatch =
        RegExp(r'(KES|USD|EUR|GBP|KSh|\$|â‚¬|Â£)').firstMatch(text);
    String currencySymbol =
        detectedCurrency ?? currencyMatch?.group(1) ?? 'KES';

    final currencyMap = {
      'KES': 'KES',
      'KSh': 'KES',
      'USD': 'USD',
      r'$': 'USD',
      'EUR': 'EUR',
      'â‚¬': 'EUR',
      'GBP': 'GBP',
      'Â£': 'GBP',
    };
    final String currency =
        isTemplateE ? 'KES' : (currencyMap[currencySymbol] ?? 'KES');

    // Handle Conversion Rate
    double? conversionRate;
    double convertedTotalAmount = totalAmount;

    if (currency != 'KES') {
      final rateMatch = RegExp(
              r'1\s*(?:USD|\$|EUR|â‚¬|GBP|Â£)\s*=\s*([\d,.]+)\s*KES',
              caseSensitive: false)
          .firstMatch(text);
      final defaultRate = rateMatch?.group(1);

      if (context != null) {
        if (!context.mounted) throw Exception('Context unmounted');
        conversionRate =
            await _getConversionRate(context, currency, defaultRate: defaultRate);
      } else {
        conversionRate = double.tryParse(defaultRate ?? '') ?? 130.0;
      }
      if (conversionRate == null) {
        throw Exception('Conversion rate not provided for $currency');
      }
      convertedTotalAmount = totalAmount * conversionRate;

      if (isTemplateI) {
        final labelIdx = text.indexOf('Total (In Kes)');
        if (labelIdx != -1) {
          final kesSearchText = text.substring(labelIdx);
          final matches =
              RegExp(r'([\d,]+\.\d{2})').allMatches(kesSearchText).toList();
          if (matches.isNotEmpty) {
            final extractedValue =
                double.tryParse(matches.last.group(1)!.replaceAll(',', ''));
            if (extractedValue != null && extractedValue > (totalAmount * 10)) {
              convertedTotalAmount = extractedValue;
            }
          }
        }
      }
    }
    final lines = text.split('\n');
    final List<ItemDetail> itemDetails = [];

    // ============================================================
    // SLEEK KENYA - INVOICE PARSING (numeric item codes like 90019)
    // This is the working invoice parser - DO NOT MODIFY
    // ============================================================
    List<ItemDetail> parseSleekItems(List<String> lines, int trId) {
      final extractedItems = <ItemDetail>[];

      for (int i = 0; i < lines.length; i++) {
        final rawLine = lines[i];
        final line = rawLine.replaceAll('\u0000', '').trim();
        if (line.isEmpty) continue;

        // Check if this line contains an item code (3-20 digits/chars at start)
        if (line.contains('.')) continue;
        final itemCodeMatch = RegExp(r'^([A-Z]?\d{3,20})\b').firstMatch(line);
        if (itemCodeMatch == null) continue;
        final itemCode = itemCodeMatch.group(1)!;

        // Build description from following lines until we hit numbers
        final descriptionParts = <String>[];
        int j = i + 1;
        while (j < lines.length) {
          final cand = lines[j].replaceAll('\u0000', '').trim();
          if (cand.isEmpty) {
            j++;
            continue;
          }
          // Stop if we hit another item code
          if (!cand.contains('.') && RegExp(r'^([A-Z]?\d{3,20})\b').hasMatch(cand)) {
            break;
          }
          // Stop if we hit a number (start of the numeric data)
          if (RegExp(r'^[\d,]+\.\d{2}$').hasMatch(cand) ||
              RegExp(r'^[-\d,]+\.\d{2}').hasMatch(cand)) {
            break;
          }
          // Skip common header labels
          if (RegExp(
                  r'^(Qty|Quantity|Unit|Price|Amount|Total|Tax|HSN|Description|Item Code|Item Description|Ordered|Prev|Disc %|Copy)$',
                  caseSensitive: false)
              .hasMatch(cand)) {
            j++;
            continue;
          }
          descriptionParts.add(cand);
          j++;
        }

        final description = descriptionParts.join(' ').trim();
        if (description.isEmpty) continue;

        // Now collect numbers from the following lines
        final List<double> nums = [];
        int k = j;
        while (k < lines.length && nums.length < 7) {
          final currentLine = lines[k].replaceAll('\u0000', '').trim();
          if (currentLine.isEmpty) {
            k++;
            continue;
          }

          // Skip header labels
          if (RegExp(
                  r'^(Qty|Quantity|Unit|Price|Amount|Total|Tax|HSN|Description|Item Code|Item Description|Ordered|Prev|Disc %|Copy)$',
                  caseSensitive: false)
              .hasMatch(currentLine)) {
            k++;
            continue;
          }

          // Check if this is the start of the next item
          if (!currentLine.contains('.') && RegExp(r'^([A-Z]?\d{3,20})\b').hasMatch(currentLine)) {
            break;
          }

          // Extract number from this line
          final numMatch = RegExp(r'[\d,]+\.\d{2}').firstMatch(currentLine);
          if (numMatch != null) {
            final value =
                double.tryParse(numMatch.group(0)!.replaceAll(',', ''));
            if (value != null) {
              nums.add(value);
            }
          }
          k++;
        }

        if (nums.isEmpty || nums.length < 3) {
          continue;
        }

        // nums[0] = Quantity, nums[1] = Tax, nums[2] = Total (Incl)
        final double quantity = nums[0];
        final double totalAmount = nums[2];

        if (quantity > 0 && totalAmount > 0) {
          final double unitPrice = totalAmount / quantity;
          extractedItems.add(ItemDetail(
            id: extractedItems.length + 1,
            trId: trId,
            description: description,
            itemCode: itemCode,
            quantity: quantity,
            unitPrice: unitPrice,
            itemAmount: totalAmount,
            discountRate: null, // Discount already applied in the total
            taxCode: 1,
          ));
          i = k - 1;
        }
      }

      return extractedItems;
    }

    // ============================================================
    // SLEEK KENYA - CREDIT NOTE PARSING (alphanumeric item codes like M11102)
    // This is the NEW credit note parser - ONLY used for credit notes
    // ============================================================
    List<ItemDetail> parseCreditNoteItems(List<String> lines, int trId) {
      final extractedItems = <ItemDetail>[];

      for (int i = 0; i < lines.length; i++) {
        final rawLine = lines[i];
        final line = rawLine.replaceAll('\u0000', '').trim();
        if (line.isEmpty) continue;

        // Check if this line contains an alphanumeric item code (letter + digits) or numeric
        if (line.contains('.')) continue;
        final itemCodeMatch = RegExp(r'^([A-Z]?\d{3,20})\b').firstMatch(line);
        if (itemCodeMatch == null) continue;
        final itemCode = itemCodeMatch.group(1)!;

        // Build description from following lines
        final descriptionParts = <String>[];
        int j = i + 1;
        while (j < lines.length) {
          final cand = lines[j].replaceAll('\u0000', '').trim();
          if (cand.isEmpty) {
            j++;
            continue;
          }
          // Stop if we hit another item code
          if (!cand.contains('.') && RegExp(r'^([A-Z]?\d{3,20})\b').hasMatch(cand)) {
            break;
          }
          // Stop if we hit a number (start of the numeric data)
          if (RegExp(r'^[\d,]+\.\d{2}$').hasMatch(cand) ||
              RegExp(r'^[-\d,]+\.\d{2}').hasMatch(cand)) {
            break;
          }
          // Skip common header labels
          if (RegExp(
                  r'^(Qty|Quantity|Unit|Price|Amount|Total|Tax|HSN|Description|Item Code|Item Description|Ordered|Prev|Disc %|Copy|Delivery Method)$',
                  caseSensitive: false)
              .hasMatch(cand)) {
            j++;
            continue;
          }
          descriptionParts.add(cand);
          j++;
        }

        final description = descriptionParts.join(' ').trim();
        if (description.isEmpty) continue;

        // Now collect numbers from the following lines
        // Credit note format: Quantity (1.00), Tax (44.75), Total (324.41)
        final List<double> nums = [];
        int k = j;
        while (k < lines.length && nums.length < 4) {
          final currentLine = lines[k].replaceAll('\u0000', '').trim();
          if (currentLine.isEmpty) {
            k++;
            continue;
          }

          // Check if this is the start of the next item
          if (!currentLine.contains('.') && RegExp(r'^([A-Z]?\d{3,20})\b').hasMatch(currentLine)) {
            break;
          }

          // Skip header labels
          if (RegExp(
                  r'^(Qty|Quantity|Unit|Price|Amount|Total|Tax|HSN|Description|Item Code|Item Description|Ordered|Prev|Disc %|Copy|Delivery Method)$',
                  caseSensitive: false)
              .hasMatch(currentLine)) {
            k++;
            continue;
          }

          // Extract number from this line
          final numMatch = RegExp(r'[\d,]+\.\d{2}').firstMatch(currentLine);
          if (numMatch != null) {
            final value =
                double.tryParse(numMatch.group(0)!.replaceAll(',', ''));
            if (value != null) {
              nums.add(value);
            }
          }
          k++;
        }

        if (nums.isEmpty || nums.length < 3) {
          continue;
        }

        // Credit note format:
        // nums[0] = Quantity (2.00)
        // nums[1] = Tax amount (71.53)
        // nums[2] = Total (Incl) amount (518.56)

        final double quantity = nums[0];
        final double totalAmount = nums[2];

        if (quantity > 0 && totalAmount > 0) {
          final double unitPrice = totalAmount / quantity;
          extractedItems.add(ItemDetail(
            id: extractedItems.length + 1,
            trId: trId,
            description: description,
            itemCode: itemCode,
            quantity: quantity,
            unitPrice: unitPrice,
            itemAmount: totalAmount,
            discountRate: null, // Discount already applied in the total
            taxCode: 1,
          ));
          i = k - 1;
        }
      }

      return extractedItems;
    }

    // ============================================================
    // ATTEMPT SLEEK PARSING
    // ============================================================
    if (isTemplateSleek) {
      if (isCreditNote) {
        // Use credit note parser for alphanumeric item codes
        final creditNoteItems = parseCreditNoteItems(lines, id);
        if (creditNoteItems.isNotEmpty) {
          itemDetails.addAll(creditNoteItems);
        }
      } else {
        // Use regular parser for invoice numeric item codes
        final sleekItems = parseSleekItems(lines, id);
        if (sleekItems.isNotEmpty) {
          itemDetails.addAll(sleekItems);
        }
      }
    }

    // ============================================================
    // SLEEK KENYA - TsNum Extraction using "Our Reference"
    // ============================================================
    String tsNum = '';
    String buyerPIN = '';
    String sellerPIN = '';
    String cuin = '';

    if (isTemplateSleek) {
      // Strategy 1: Find "Our Reference" in the text and extract the value
      final ourRefIndex = text.indexOf('Our Reference');
      if (ourRefIndex >= 0) {
        final afterRef = text.substring(ourRefIndex + 'Our Reference'.length);
        final tokens = RegExp(r'\b([A-Z0-9]+)\b').allMatches(afterRef);

        for (final token in tokens) {
          final candidate = token.group(1)!;
          // Skip dates, Order No (SO), Delivery Note (DEL), and Account (NAI)
          if (!candidate.contains('/') &&
              !RegExp(r'^SO\d+$').hasMatch(candidate) &&
              !RegExp(r'^DEL\d+$').hasMatch(candidate) &&
              !RegExp(r'^[A-Z]{3}\d{3}$').hasMatch(candidate)) {
            tsNum = candidate;
            break;
          }
        }

        // If no valid token found, try the last token
        if (tsNum.isEmpty && tokens.isNotEmpty) {
          final lastToken = tokens.last.group(1)!;
          if (!lastToken.contains('/') &&
              !RegExp(r'^SO\d+$').hasMatch(lastToken) &&
              !RegExp(r'^DEL\d+$').hasMatch(lastToken)) {
            tsNum = lastToken;
          }
        }
      }

      // Strategy 2: Look for 5-digit number (invoice) or CRN pattern (credit note)
      if (tsNum.isEmpty) {
        // Credit note: CRN pattern
        final crnMatch = RegExp(r'\b(CRN[A-Z0-9]+)\b', caseSensitive: false)
            .firstMatch(text);
        if (crnMatch != null) {
          tsNum = crnMatch.group(1)!;
        } else {
          // Invoice: 5-digit number
          final numMatch = RegExp(r'\b(\d{5})\b').firstMatch(text);
          if (numMatch != null) {
            tsNum = numMatch.group(1)!;
          }
        }
      }

      // PIN extraction: Buyer PIN is under "Tax Registration" in To: block
      final toIndex = text.indexOf('To:', 0);
      if (toIndex >= 0) {
        final toEndIndex = text.indexOf('\n\n', toIndex + 3);
        final toBlock = toEndIndex > 0
            ? text.substring(toIndex, toEndIndex)
            : text.substring(toIndex);

        final taxRegMatch = RegExp(
                r'Tax\s*Registration\s*[\n\r]*\s*([A-Z]\d{9}[A-Z])',
                caseSensitive: false)
            .firstMatch(toBlock);
        if (taxRegMatch != null) {
          buyerPIN = taxRegMatch.group(1) ?? '';
        }
      }

      // Seller PIN extraction: Look before To: block
      if (sellerPIN.isEmpty && toIndex > 0) {
        final beforeTo = text.substring(0, toIndex);
        final sellerMatch = RegExp(r'([A-Z]\d{6,}[A-Z])').firstMatch(beforeTo);
        if (sellerMatch != null) {
          sellerPIN = sellerMatch.group(1) ?? '';
        }
      }

      // If buyer PIN is empty, try to find any PIN that's not the seller PIN
      if (buyerPIN.isEmpty && sellerPIN.isNotEmpty) {
        final allPins = RegExp(r'([A-Z]\d{6,}[A-Z])', caseSensitive: false)
            .allMatches(text);
        for (final match in allPins) {
          final pin = match.group(1);
          if (pin != null && pin != sellerPIN) {
            buyerPIN = pin;
            break;
          }
        }
      }
    } else if (isTemplateJ) {
      final String cleaned = text.replaceAll('D6', '6');
      final tsMatch = RegExp(r'Attn\s*:\s*(\d+)').firstMatch(cleaned);
      if (tsMatch != null) {
        tsNum = tsMatch.group(1) ?? '';
      }
      final sellerPinMatchJ =
          RegExp(r'PIN:\s*([A-Z]\d{9,}[A-Z])').firstMatch(cleaned);
      if (sellerPinMatchJ != null) {
        sellerPIN = sellerPinMatchJ.group(1) ?? '';
      }
      final allPins = RegExp(r'([A-Z]\d{9,}[A-Z])').allMatches(cleaned);
      for (final m in allPins) {
        final p = m.group(1);
        if (p != null && p != sellerPIN) {
          buyerPIN = p;
          break;
        }
      }
      if (vatAmountA == null) {
        final vatMatch = RegExp(
                r'[\d,]+\.\d{2}\s+([\d,]+\.\d{2})\s+Total\s*VAT\s*Grand\s*Total',
                caseSensitive: false)
            .firstMatch(cleaned);
        if (vatMatch != null) {
          vatAmountA = double.tryParse(vatMatch.group(1)!.replaceAll(',', ''));
        }
      }
    } else if (isTemplateE) {
      var tsNumMatchE = RegExp(
              r'(\d{8,})\s*[\r\n]+\s*(?:CASH\s+SALE\s+NO|INVOICE\s+NO)\.?',
              caseSensitive: false)
          .firstMatch(text);
      tsNumMatchE ??= RegExp(
              r'(?:CASH\s+SALE\s+NO|INVOICE\s+NO)\.?\s*[\r\n]+\s*(\d+)',
              caseSensitive: false)
          .firstMatch(text);
      tsNumMatchE ??= RegExp(
              r'(\d{8,})\s*[\r\n]+\d{2}/\d{2}/\d{4}\s*[\r\n]+\d+\s*[\r\n]+(?:CASH\s+SALE\s+NO|INVOICE\s+NO)\.?',
              caseSensitive: false)
          .firstMatch(text);
      if (tsNumMatchE != null) {
        tsNum = tsNumMatchE.group(1) ?? '';
      }

      if (tsNum.isEmpty) {
        final labelIndex = text.contains('CASH SALE NO.')
            ? text.indexOf('CASH SALE NO.')
            : text.indexOf('INVOICE NO.');
        if (labelIndex > 0) {
          final beforeText = text.substring(0, labelIndex);
          final numberMatch = RegExp(r'(\d{8,})').firstMatch(beforeText);
          if (numberMatch != null) {
            tsNum = numberMatch.group(1) ?? '';
          }
        }
      }

      var sellerPinMatch =
          RegExp(r'PIN\s+No\.?\s*([A-Z]\d{9,}[A-Z])', caseSensitive: false)
              .firstMatch(text);
      if (sellerPinMatch != null) {
        sellerPIN = sellerPinMatch.group(1) ?? '';
      }

      var buyerPinMatchE = RegExp(
              r'BUYER\s+PIN:\s*[\r\n]+\s*([A-Z]\d{9,}[A-Z])',
              caseSensitive: false)
          .firstMatch(text);
      buyerPinMatchE ??=
          RegExp(r'BUYER\s+PIN:\s*([A-Z]\d{9,}[A-Z])', caseSensitive: false)
              .firstMatch(text);
      if (buyerPinMatchE != null) {
        buyerPIN = buyerPinMatchE.group(1) ?? '';
      }

      if (buyerPIN.isEmpty && sellerPIN.isNotEmpty) {
        final allPins = RegExp(r'([A-Z]\d{9,}[A-Z])', caseSensitive: false)
            .allMatches(text);
        for (var match in allPins) {
          final pin = match.group(1);
          if (pin != sellerPIN) {
            buyerPIN = pin ?? '';
            break;
          }
        }
      }

      var cuinMatch = RegExp(r'CUIN\.?\s*([A-Z0-9]{10,})', caseSensitive: false)
          .firstMatch(text);
      cuinMatch ??= RegExp(r'CUIN:\s*([A-Z0-9]{10,})', caseSensitive: false)
          .firstMatch(text);
      if (cuinMatch != null) {
        cuin = cuinMatch.group(1) ?? '';
      }
    } else if (isTemplatePharmacor) {
      final tsMatch = RegExp(
              r'(?:Invoice|Credit\s*Note)\s*No\.?\s*[\r\n]*\s*([A-Za-z0-9]+)',
              caseSensitive: false)
          .firstMatch(text);
      if (tsMatch != null) {
        tsNum = tsMatch.group(1)!;
      }
      final refMatch = RegExp(
              r"Buyer's\s*Ref\.?\s*[\r\n]*\s*([A-Za-z0-9]+)",
              caseSensitive: false)
          .firstMatch(text);
      if (refMatch != null) {
        cuin = refMatch.group(1)!;
      }
      final sellerMatch = RegExp(
              r"Company's\s*(?:PIN|VAT\s*No\.?)\s*:\s*([A-Z]\d{9,}[A-Z])",
              caseSensitive: false)
          .firstMatch(text);
      if (sellerMatch != null) {
        sellerPIN = sellerMatch.group(1)!;
      }
      final buyerMatch = RegExp(
              r'(?:Buyer|Party)[\s\S]*?PIN\s*:\s*([A-Z]\d{9,}[A-Z])',
              caseSensitive: false)
          .firstMatch(text);
      if (buyerMatch != null) {
        buyerPIN = buyerMatch.group(1)!;
      }
      if (buyerPIN.isEmpty || buyerPIN == sellerPIN) {
        final allPins = RegExp(r'([A-Z]\d{9,}[A-Z])', caseSensitive: false)
            .allMatches(text);
        for (final m in allPins) {
          final p = m.group(1)!;
          if (p != sellerPIN) {
            buyerPIN = p;
            break;
          }
        }
      }
    } else if (isTemplateAlphaKnits) {
      final tsMatch = RegExp(
              r'(?:CREDIT\s*NOTE\s*NO|INVOICE\s*NO|Invoice\s*No)\.?\s*[\:\s\r\n]*([A-Za-z0-9]+)',
              caseSensitive: false)
          .firstMatch(text);
      if (tsMatch != null) {
        tsNum = tsMatch.group(1)!;
      }

      final sellerMatch = RegExp(
              r'PIN\s+NO\.?\s*([A-Z]\d{9}[A-Z])',
              caseSensitive: false)
          .firstMatch(text);
      if (sellerMatch != null) {
        sellerPIN = sellerMatch.group(1)!;
      } else {
        sellerPIN = 'P000600759T';
      }

      final allPins = RegExp(r'([A-Z]\d{9}[A-Z])').allMatches(text);
      for (final m in allPins) {
        final pin = m.group(1)!;
        if (pin.toUpperCase() != sellerPIN.toUpperCase() && pin.toUpperCase() != 'P000600759T') {
          buyerPIN = pin;
          break;
        }
      }
    } else if (isTemplateRaa) {
      final crnMatch =
          RegExp(r'CRN(\d+)', caseSensitive: false).firstMatch(text);
      if (crnMatch != null) {
        tsNum = crnMatch.group(1)!;
      } else {
        final tsMatch = RegExp(
          r'Invoice\s*Number\s*:\s*(\d+?)(?:100\d{8,}|[A-Z]|Order|\s|$)',
          caseSensitive: false,
        ).firstMatch(text);
        if (tsMatch != null) {
          tsNum = tsMatch.group(1)!;
        }
      }

      final buyerMatch = RegExp(
        r'PIN:\s*([A-Z]\d{9}[A-Z])',
        caseSensitive: false,
      ).firstMatch(text);
      if (buyerMatch != null) {
        buyerPIN = buyerMatch.group(1)!;
      }

      final sellerMatch = RegExp(r'([A-Z]\d{9}[A-Z])').firstMatch(text);
      if (sellerMatch != null && sellerMatch.group(1) != buyerPIN) {
        sellerPIN = sellerMatch.group(1)!;
      } else {
        sellerPIN = 'P051151358Q';
      }
    } else if (!isTemplateSleek &&
        !isTemplatePharmacor &&
        !isTemplateE &&
        !isTemplateH &&
        !isTemplateI &&
        !isTemplateJ &&
        !isTemplateAlphaKnits &&
        !isTemplateRaa) {
      var tsNumMatch = RegExp(r'#\s*(INV\d+)').firstMatch(text);
      tsNumMatch ??= RegExp(r'Invoice\s*No\.?\s*(\d+)', caseSensitive: false)
          .firstMatch(text);
      tsNumMatch ??= RegExp(r'INVOICE\s*[\r\n]+\s*(\d+)', caseSensitive: false)
          .firstMatch(text);
      tsNumMatch ??= RegExp(r'CREDIT\s*[\r\n]+\s*(\d+)', caseSensitive: false)
          .firstMatch(text);
      tsNumMatch ??= RegExp(r'(?:Invoice|Credit)\s*No\.?\s*[\r\n]+\s*(\d+)',
              caseSensitive: false)
          .firstMatch(text);
      tsNumMatch ??=
          RegExp(r'(?:Invoice|Credit)\s*No\.?\s+(\d+)', caseSensitive: false)
              .firstMatch(text);
      tsNumMatch ??=
          RegExp(r'Document\s*Number\s*[\r\n]+\s*(\d+)').firstMatch(text);
      tsNumMatch ??= RegExp(
              r'(\d+)\s*[\r\n]+[\d/]+\s*[\r\n]+\d+\s*[\r\n]+CASH\s*SALE\s*NO',
              caseSensitive: false)
          .firstMatch(text);
      tsNumMatch ??=
          RegExp(r'CASH\s*SALE\s*NO\.?\s*(\d+)', caseSensitive: false)
              .firstMatch(text);

      var tsNumMatchC = RegExp(
              r'BILL\s*#\s*[\r\n]+\s*([A-Z]+)\s*[\r\n]+\s*-\s*[\r\n]+\s*(\d+)')
          .firstMatch(text);

      if (tsNumMatch != null) {
        tsNum = tsNumMatch.group(1) ?? '';
      } else if (tsNumMatchC != null) {
        tsNum = '${tsNumMatchC.group(1)}-${tsNumMatchC.group(2)}';
      }

      var buyerPinMatch = RegExp(r'PIN\s*([A-Z]\d+[A-Z])').firstMatch(text);
      buyerPinMatch ??=
          RegExp(r'PIN\s*(?:No\.?\s*)?([A-Z]\d{9}[A-Z])', caseSensitive: false)
              .firstMatch(text);
      buyerPinMatch ??= RegExp(
              r'Customer\s+Pin\s+No\.?\s*[\r\n]+\s*([A-Z]\d{9,}[A-Z])',
              caseSensitive: false)
          .firstMatch(text);
      buyerPinMatch ??= RegExp(r'CUSTOMER\s+PIN\s+NO\s+([A-Z]\d{9,}[A-Z])',
              caseSensitive: false)
          .firstMatch(text);
      buyerPinMatch ??=
          RegExp(r'Invoice\s*To[\s\S]*?([A-Z]\d{9,}[A-Z])').firstMatch(text);
      buyerPinMatch ??= RegExp(r'KENYA([A-Z]\d{9,}[A-Z])').firstMatch(text);

      buyerPIN = buyerPinMatch?.group(1) ?? '';

      if (isTemplateF || isTemplateG) {
        final sellerPinMatchFG = RegExp(
                r'Company\s+(?:Pin:|PIN\s+Reg\.?|VAT\s+Number)[\s\r\n]+([A-Z]\d{9,}[A-Z])',
                caseSensitive: false)
            .firstMatch(text);
        if (sellerPinMatchFG != null) {
          sellerPIN = sellerPinMatchFG.group(1) ?? '';
        }
      }

      if (buyerPIN.isNotEmpty &&
          sellerPIN.isNotEmpty &&
          buyerPIN.toUpperCase() == sellerPIN.toUpperCase()) {
        final allPins = RegExp(r'([A-Z]\d{9,}[A-Z])', caseSensitive: false)
            .allMatches(text);
        buyerPIN = '';
        for (final match in allPins) {
          final pin = match.group(1);
          if (pin != null && pin.toUpperCase() != sellerPIN.toUpperCase()) {
            buyerPIN = pin;
            break;
          }
        }
      }

      var cuinMatch =
          RegExp(r'CUIN\s*[\r\n]+\s*([A-Z0-9]{10,})', caseSensitive: false)
              .firstMatch(text);
      cuinMatch ??= RegExp(r'CUIN\.?\s*([A-Z0-9]{10,})', caseSensitive: false)
          .firstMatch(text);
      if (cuinMatch != null) {
        cuin = cuinMatch.group(1) ?? '';
      }

      final vatMatchE = RegExp(
              r'([\d,]+\.\d{2})\s*[\r\n]+\s*(?:[\d,]+\.\d{2})\s*[\r\n]+\s*(?:[\d,]+\.\d{2})\s*[\r\n]+\s*TOTAL VALUE:',
              caseSensitive: false)
          .firstMatch(text);
      if (vatMatchE != null) {
        vatAmountA = double.tryParse(vatMatchE.group(1)!.replaceAll(',', ''));
      }
    }

    // ============================================================
    // TEMPLATE H: AUCTORITA TECHNOLOGIES LTD
    // ============================================================
    if (isTemplateH) {
      var tsNumMatch = RegExp(r'Invoice\s*No\.?\s*(\d+)', caseSensitive: false)
          .firstMatch(text);
      tsNumMatch ??=
          RegExp(r'Invoice\s*No\.?\s*[\r\n]+\s*(\d+)', caseSensitive: false)
              .firstMatch(text);
      if (tsNumMatch != null) {
        tsNum = tsNumMatch.group(1) ?? tsNumMatch.group(2) ?? '';
      }

      var buyerPinMatch =
          RegExp(r'PIN\s*:\s*([A-Z]\d{9,}[A-Z])', caseSensitive: false)
              .firstMatch(text);
      if (buyerPinMatch != null) {
        buyerPIN = buyerPinMatch.group(1) ?? '';
      }

      var sellerPinMatch = RegExp(r"Company's\s*PIN\s*:\s*([A-Z]\d{9,}[A-Z])",
              caseSensitive: false)
          .firstMatch(text);
      if (sellerPinMatch != null) {
        sellerPIN = sellerPinMatch.group(1) ?? '';
      }

      final vatAmountAMatch = RegExp(r'VAT\s*@\d+%\s*[\r\n\s]*([\d,]+\.\d{2})',
              caseSensitive: false)
          .firstMatch(text);
      vatAmountA = double.tryParse(
          vatAmountAMatch?.group(1)?.replaceAll(',', '') ?? '0.0');

      // Parse items for Template H
      final itemLines = text.split('\n');
      String currentDesc = '';
      double? currentQty;
      double? currentRate;
      double? currentTotal;

      for (int i = 0; i < itemLines.length; i++) {
        final line = itemLines[i].trim();
        if (line.isEmpty) continue;

        // Check for item description
        final descMatch = RegExp(r'^\d+\.\s*(.+)$').firstMatch(line);
        if (descMatch != null) {
          // If we have a previous item, add it
          if (currentDesc.isNotEmpty) {
            _addItemH(itemDetails, id, currentDesc, currentQty, currentRate,
                currentTotal);
          }
          currentDesc = descMatch.group(1)!.trim();
          currentQty = null;
          currentRate = null;
          currentTotal = null;
          continue;
        }

        // Check for quantity
        final qtyMatch = RegExp(r'Qty\s*:\s*([\d,.]+)').firstMatch(line);
        if (qtyMatch != null) {
          currentQty = double.tryParse(qtyMatch.group(1)!.replaceAll(',', ''));
          continue;
        }

        // Check for rate
        final rateMatch = RegExp(r'Rate\s*:\s*([\d,.]+)').firstMatch(line);
        if (rateMatch != null) {
          currentRate =
              double.tryParse(rateMatch.group(1)!.replaceAll(',', ''));
          continue;
        }

        // Check for amount
        final amountMatch = RegExp(r'Amount\s*:\s*([\d,.]+)').firstMatch(line);
        if (amountMatch != null) {
          currentTotal =
              double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
          // If we have a complete item, add it
          if (currentDesc.isNotEmpty && currentTotal != null) {
            _addItemH(itemDetails, id, currentDesc, currentQty, currentRate,
                currentTotal);
            // Reset for next item
            currentDesc = '';
            currentQty = null;
            currentRate = null;
            currentTotal = null;
          }
          continue;
        }

        // If we have a description and total is null, this might be a continuation
        if (currentDesc.isNotEmpty && currentDesc.length < 100) {
          currentDesc += ' $line';
        }
      }

      // Add any remaining item
      if (currentDesc.isNotEmpty && currentTotal != null) {
        _addItemH(itemDetails, id, currentDesc, currentQty, currentRate,
            currentTotal);
      }
    }

    // ============================================================
    // TEMPLATE I: SALVEN TRADING COMPANY LTD / PANDA FLOWERS LIMITED
    // ============================================================
    if (isTemplateI) {
      var tsNumMatch = RegExp(r'Invoice\s*No\.?\s*[\r\n]*\s*([A-Z0-9]+)',
              caseSensitive: false)
          .firstMatch(text);
      if (tsNumMatch != null) {
        tsNum = tsNumMatch.group(1) ?? '';
      }

      final Set<String> sellerIdentifiers = {};

      final pinMatchI =
          RegExp(r'([A-Z]\d{9}[A-Z])', caseSensitive: false).firstMatch(text);
      if (pinMatchI != null) {
        sellerIdentifiers.add(pinMatchI.group(1)!.toUpperCase());
        sellerPIN = pinMatchI.group(1)!;
      }

      final vatMatchI =
          RegExp(r'(\d{7,8}[A-Z])', caseSensitive: false).firstMatch(text);
      if (vatMatchI != null) {
        sellerIdentifiers.add(vatMatchI.group(1)!.toUpperCase());
        if (sellerPIN.isEmpty) sellerPIN = vatMatchI.group(1)!;
      }

      var sellerPinNearNameMatch = RegExp(
              r'([A-Z0-9]{8,11})\s*[\r\n]+\s*PANDA\s+FLOWERS\s+LIMITED',
              caseSensitive: false)
          .firstMatch(text);
      if (sellerPinNearNameMatch != null) {
        sellerIdentifiers.add(sellerPinNearNameMatch.group(1)!.toUpperCase());
      }

      final pinMatches =
          RegExp(r'([A-Z]\d{9}[A-Z]|\d{7,8}[A-Z])', caseSensitive: false)
              .allMatches(text);

      buyerPIN = '';
      for (final m in pinMatches) {
        final foundPin = m.group(1)!.toUpperCase();
        if (!sellerIdentifiers.contains(foundPin)) {
          buyerPIN = foundPin;
          break;
        }
      }

      final footerMatchI = RegExp(r'US\$([\d,]+\.\d{2})US\$([\d,]+\.\d{2})',
              caseSensitive: false)
          .firstMatch(text);
      if (footerMatchI != null) {
        vatAmountA =
            double.tryParse(footerMatchI.group(1)!.replaceAll(',', ''));
      } else {
        final vatAmountAMatchI = RegExp(
                r'VAT\s*TOTAL\s*(?:US\$|KES)?\s*([\d,]+\.\d{2})',
                caseSensitive: false)
            .firstMatch(text);
        vatAmountA = double.tryParse(
            vatAmountAMatchI?.group(1)?.replaceAll(',', '') ?? '0.0');
      }

      // Parse items for Template I
      final itemLines = text.split('\n');
      for (int i = 0; i < itemLines.length; i++) {
        final line = itemLines[i].trim();
        if (line.isEmpty) continue;

        // Check for item code pattern
        final codeMatch = RegExp(r'^([A-Z0-9]{6,})\s+').firstMatch(line);
        if (codeMatch != null) {
          final itemCode = codeMatch.group(1)!;
          final rest = line.substring(codeMatch.end).trim();

          // Try to find description and numbers
          final descMatch = RegExp(r'^([^0-9]+)').firstMatch(rest);
          if (descMatch != null) {
            final description = descMatch.group(1)!.trim();
            final numbers =
                rest.substring(descMatch.end).trim().split(RegExp(r'\s+'));

            if (numbers.length >= 3) {
              final qty = double.tryParse(numbers[0].replaceAll(',', ''));
              final total = double.tryParse(numbers[2].replaceAll(',', ''));
              if (qty != null && total != null && qty > 0) {
                final unitPrice = total / qty;
                itemDetails.add(ItemDetail(
                  id: itemDetails.length + 1,
                  trId: id,
                  description: description.isNotEmpty ? description : 'Item',
                  itemCode: itemCode,
                  quantity: qty,
                  unitPrice: unitPrice,
                  itemAmount: total,
                  taxCode: 1,
                ));
              }
            }
          }
        }
      }
    }

    if (isTemplateJ) {
      final String cleaned = text.replaceAll('D6', '6');
      final descMatch = RegExp(
              r'(Rent for the period of [\d/]+-[\d/]+)\s+(\d+)',
              caseSensitive: false)
          .firstMatch(cleaned);
      final totalMatch = RegExp(
              r'([\d,]+\.\d{2})\s+([\d,]+\.\d{2})\s+Total\s*VAT\s*Grand\s*Total[\s\S]*?([\d,]+\.\d{2})',
              caseSensitive: false)
          .firstMatch(cleaned);

      if (descMatch != null && totalMatch != null) {
        final description = descMatch.group(1)!.trim();
        final qty = double.tryParse(descMatch.group(2)!) ?? 1.0;
        final netAmount =
            double.tryParse(totalMatch.group(3)!.replaceAll(',', '')) ?? 0.0;

        itemDetails.add(ItemDetail(
          id: itemDetails.length + 1,
          trId: id,
          description: description,
          quantity: qty,
          unitPrice: netAmount,
          itemAmount: netAmount,
          taxCode: 1,
        ));
      }
    }

    // ============================================================
    // TEMPLATE PHARMACOR: PHARMACOR LTD
    // ============================================================
    if (isTemplatePharmacor) {
      final itemLines = text.split('\n');

      bool isProductDesc(String str) {
        final clean = str.trim();
        if (clean.isEmpty || !RegExp(r'^[A-Za-z]').hasMatch(clean)) return false;

        // Exclude unit words alone
        if (RegExp(
                r'^(Bottle|VIAL|PACKET|PCS|BOX|KG|LTR|CARTONS|BAG|PAIL|TUBE|CAN|SET|ROLL|DOZEN|PAIR)$',
                caseSensitive: false)
            .hasMatch(clean)) {
          return false;
        }

        return !RegExp(
                r'^(Batch|Mfg|Expiry|Total|Company|Buyer|Party|PIN|Invoice|Credit|Delivery|Supplier|Sl|No\.|Description|Amount|per|Rate|Quantity|continued|This|Declaration|Authorised|E\.\s*&\s*O\.E|Kenyan|Mode|Terms|Payment|Despatched|Destination)',
                caseSensitive: false)
            .hasMatch(clean);
      }

      for (int i = 0; i < itemLines.length; i++) {
        final line = itemLines[i].trim();
        if (line.isEmpty) continue;

        String? description;
        int nextSearchIndex = i + 1;

        // Pattern 1: Same line "1 CLAVAM BID..."
        final sameLineMatch =
            RegExp(r'^(\d{1,3})\s+([A-Za-z].*)$').firstMatch(line);

        if (sameLineMatch != null &&
            isProductDesc(sameLineMatch.group(2)!.trim())) {
          description = sameLineMatch.group(2)!.trim();
          nextSearchIndex = i + 1;
        } else if (RegExp(r'^(\d{1,3})$').hasMatch(line)) {
          // Pattern 2: Number on its own line "1", description on next non-empty line
          int k = i + 1;
          while (k < itemLines.length) {
            final nextLine = itemLines[k].trim();
            if (nextLine.isEmpty) {
              k++;
              continue;
            }
            if (isProductDesc(nextLine)) {
              description = nextLine;
              nextSearchIndex = k + 1;
            }
            break;
          }
        }

        if (description == null || description.isEmpty) continue;

        // Search next lines (up to 10) for Amount, Rate, Quantity
        double? amount;
        double? rate;
        double? qty;

        int j = nextSearchIndex;
        while (j < itemLines.length && (j - nextSearchIndex) <= 10) {
          final cand = itemLines[j].trim();
          if (cand.isEmpty) {
            j++;
            continue;
          }

          // Check if candidate is pure decimal number (Amount or Rate)
          if (RegExp(r'^[\d,]+\.\d{2}$').hasMatch(cand)) {
            final val = double.tryParse(cand.replaceAll(',', ''));
            if (val != null) {
              if (amount == null) {
                amount = val;
              } else {
                rate ??= val;
              }
            }
          } else {
            // Check if candidate is Quantity line (e.g. "9,000 Bottle" or "100 PACKET")
            final qtyMatch = RegExp(
                    r'^([\d,]+)\s*(?:Bottle|VIAL|PACKET|PCS|BOX|KG|LTR|CARTONS)',
                    caseSensitive: false)
                .firstMatch(cand);
            if (qtyMatch != null && qty == null) {
              qty = double.tryParse(qtyMatch.group(1)!.replaceAll(',', ''));
            }
          }

          if (amount != null && rate != null && qty != null) {
            break;
          }
          j++;
        }

        if (amount != null && qty != null && qty > 0) {
          final unitPrice = rate ?? (amount / qty);

          String itemDesc = description;
          String? itemCode;

          // Check if description ends with HS Code or Item Code (e.g. 0039.11.30)
          final codeMatch = RegExp(
                  r'\s+((?:\d{1,6}[\.-])+\d{1,6}|[A-Z0-9]{6,15})$',
                  caseSensitive: false)
              .firstMatch(description);
          if (codeMatch != null) {
            itemCode = codeMatch.group(1);
            itemDesc = description.substring(0, codeMatch.start).trim();
          }

          itemDetails.add(ItemDetail(
            id: itemDetails.length + 1,
            trId: id,
            description: itemDesc,
            itemCode: itemCode,
            quantity: qty,
            unitPrice: unitPrice,
            itemAmount: amount,
            taxCode: 1,
          ));
        }
      }
    }

    // ============================================================
    // ============================================================
    // TEMPLATE ALPHA KNITS: ALPHA KNITS LTD
    // ============================================================
    if (isTemplateAlphaKnits) {
      sellerPIN = 'P000600759T';

      // Extract Transaction Number (Invoice No or Credit Note No)
      if (tsNum.isEmpty) {
        var tsNumMatch = RegExp(
          r'(?:CREDIT\s*NOTE\s*NO|INVOICE\s*NO|Invoice\s*No)\.?\s*[\:\s\r\n]*([A-Za-z0-9]+)',
          caseSensitive: false,
        ).firstMatch(text);
        if (tsNumMatch != null) {
          tsNum = tsNumMatch.group(1) ?? '';
        }
      }

      // Fallback line-by-line scan for tsNum if not matched
      if (tsNum.isEmpty) {
        final lines = text.split('\n').map((l) => l.trim()).toList();
        for (int i = 0; i < lines.length; i++) {
          final lUpper = lines[i].toUpperCase();
          if (lUpper.contains('CREDIT NOTE') ||
              lUpper.contains('INVOICE NO') ||
              lUpper.contains('INVOICE') ||
              lUpper.contains('CREDIT')) {
            for (int j = i + 1; j < lines.length && j < i + 6; j++) {
              final cand = lines[j];
              if (cand.isNotEmpty &&
                  RegExp(r'^[A-Za-z0-9]+$').hasMatch(cand) &&
                  !cand.toUpperCase().contains('DATE') &&
                  !cand.toUpperCase().contains('ISSUE') &&
                  !cand.toUpperCase().contains('ORDER') &&
                  !cand.toUpperCase().contains('PRINTING') &&
                  !cand.toUpperCase().contains('ORIGINAL') &&
                  !cand.toUpperCase().contains('ORGINAL')) {
                tsNum = cand;
                break;
              }
            }
            if (tsNum.isNotEmpty) break;
          }
        }
      }

      if (tsNum.isEmpty && pdfPath != null) {
        final fnMatch = RegExp(r'(\d{4,8})').firstMatch(path.basename(pdfPath));
        if (fnMatch != null) {
          tsNum = fnMatch.group(1)!;
        }
      }

      // Extract Buyer PIN (skipping Seller PIN P000600759T)
      final pinMatches = RegExp(r'([A-Z]\d{9}[A-Z])', caseSensitive: false)
          .allMatches(text);
      for (final m in pinMatches) {
        final pin = m.group(1)!.toUpperCase();
        if (pin != sellerPIN) {
          buyerPIN = pin;
          break;
        }
      }

      // Extract CUIN for Credit Notes
      if (isCreditNote) {
        final cuinMatch = RegExp(
          r'Based\s*on\s*(?:A\s*)?(?:Invoce|Invoice|Sales\s*Order)\s*(\d+)',
          caseSensitive: false,
        ).firstMatch(text);
        if (cuinMatch != null) {
          cuin = cuinMatch.group(1) ?? '';
        }
      }

      if (isCreditNote) {
        // Line-by-line extraction for Credit Notes (handles multiline text extracted by Syncfusion)
        final lines = text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final uomMatch = RegExp(
            r'^(KGMS|KGS|KG|PCS|PC|DOZEN|DZ|MTRS|MTR|BGS|BAGS|SETS|LTRS|LTR|BOX|PKT|PAIR|PAIRS)\b',
            caseSensitive: false,
          ).firstMatch(line);

          if (uomMatch != null && i >= 1) {
            // Collect upcoming numeric lines after UOM index i
            final List<double> numValues = [];
            final List<String> numRawStrings = [];
            int j = i + 1;
            while (j < lines.length && numValues.length < 4) {
              final cand = lines[j].trim();
              if (cand.isEmpty) {
                j++;
                continue;
              }
              // Stop if candidate matches another UOM or table header or non-numeric footer
              if (RegExp(r'^(?:KGMS|KGS|KG|PCS|PC|DOZEN|DZ|MTRS|MTR|BGS|BAGS|SETS|LTRS|LTR|BOX|PKT|PAIR|PAIRS)\b', caseSensitive: false).hasMatch(cand) ||
                  cand.toUpperCase().contains('SUB TOTAL') ||
                  cand.toUpperCase().contains('GRAND TOTAL') ||
                  cand.toUpperCase().contains('NET TOTAL') ||
                  cand.toUpperCase().contains('BASED ON')) {
                break;
              }

              final cleanedNum = cand.replaceAll(RegExp(r'[^\d,\.]'), '');
              final parsedNum = double.tryParse(cleanedNum.replaceAll(',', ''));
              if (parsedNum != null) {
                numValues.add(parsedNum);
                numRawStrings.add(cleanedNum);
              } else if (numValues.isNotEmpty) {
                // If we already collected numbers and hit a non-number line, stop
                break;
              }
              j++;
            }

            if (numValues.length >= 3) {
              final qty = numValues[0];
              final price = numValues[1];
              double vat = 0.0;
              double amount = 0.0;

              if (numValues.length >= 4) {
                vat = numValues[2];
                amount = numValues[3];
              } else {
                vat = 0.0;
                amount = numValues[2];
              }

              // Extract description and code from preceding lines
              String desc = lines[i - 1];
              String code = i >= 2 ? lines[i - 2] : desc;

              // If code is numeric (including decimal HS codes like 0002.32), zero, or header, try line i-3 or i-4
              if (code == '0' || RegExp(r'^\d+(\.\d+)?$').hasMatch(code) ||
                  code.contains('Item Code') ||
                  code.contains('HS Code') ||
                  code.contains('Item Description') ||
                  code.contains('Uom') ||
                  code.contains('Qty') ||
                  code.contains('Unit Price') ||
                  code.contains('Total Amount')) {
                int searchIdx = i - 3;
                while (searchIdx >= 0 && (i - searchIdx) <= 5) {
                  final candCode = lines[searchIdx].trim();
                  if (candCode.isNotEmpty &&
                      candCode != '0' &&
                      !RegExp(r'^\d+(\.\d+)?$').hasMatch(candCode) &&
                      !candCode.toUpperCase().startsWith('LPO') &&
                      !candCode.contains('Item Code') &&
                      !candCode.contains('HS Code') &&
                      !candCode.contains('Item Description') &&
                      !candCode.contains('Uom')) {
                    code = candCode;
                    break;
                  }
                  searchIdx--;
                }
                if (code == '0' || code.contains('Item Code') || code.contains('HS Code') || code.contains('Item Description') || code.contains('Uom')) {
                  code = desc;
                }
              }

              final bool isZeroRated = vat == 0 ||
                  detectedCurrency == 'USD' ||
                  text.toUpperCase().contains('SHOWN IN USD');
              final double itemAmountIncl =
                  isZeroRated ? amount : (amount * 1.16);
              final double unitPriceIncl = qty > 0
                  ? (itemAmountIncl / qty)
                  : (isZeroRated ? price : price * 1.16);

              if (qty > 0 && itemAmountIncl > 0) {
                itemDetails.add(ItemDetail(
                  id: itemDetails.length + 1,
                  trId: id,
                  description: desc.isNotEmpty ? desc : 'Item',
                  itemCode: code,
                  quantity: qty,
                  unitPrice: unitPriceIncl,
                  itemAmount: itemAmountIncl,
                  taxCode: isZeroRated ? 2 : 1,
                ));
              }
            }
          }
        }

        // Fallback for single-line space separated credit note text
        if (itemDetails.isEmpty) {
          final cnItemRegex = RegExp(
            r"([A-Z0-9_\-]+)\s+([A-Za-z0-9_\-\s\(\)\/\.\+\#\&\_\:\'\%]+?)\s+([A-Za-z]{2,10})\s+([\d,\.]+)\s+([\d,\.]+)\s+(\d+)\s+([\d,]+\.\d{2})",
            caseSensitive: false,
          );
          final cnMatches = cnItemRegex.allMatches(text);
          for (final match in cnMatches) {
            var itemCode = match.group(1)!.trim();
            var description = match.group(2)!.trim();
            if (description.toUpperCase().startsWith('CONE')) {
              itemCode = '$itemCode CONE';
              description = description.substring(4).trim();
            }
            if (description.contains('Total Amount')) {
              description = description
                  .substring(description.indexOf('Total Amount') +
                      'Total Amount'.length)
                  .trim();
            }

            final qty =
                double.tryParse(match.group(4)!.replaceAll(',', '')) ?? 0.0;
            final unitPriceExcl =
                double.tryParse(match.group(5)!.replaceAll(',', '')) ?? 0.0;
            final vatStr = match.group(6)!.trim();
            final itemAmountExcl =
                double.tryParse(match.group(7)!.replaceAll(',', '')) ?? 0.0;

            final bool isZeroRated = vatStr == '0' || vatStr == '0.00';
            final double itemAmountIncl =
                isZeroRated ? itemAmountExcl : (itemAmountExcl * 1.16);
            final double unitPriceIncl = qty > 0
                ? (itemAmountIncl / qty)
                : (isZeroRated ? unitPriceExcl : unitPriceExcl * 1.16);

            if (qty > 0 && itemAmountIncl > 0) {
              itemDetails.add(ItemDetail(
                id: itemDetails.length + 1,
                trId: id,
                description: description.isNotEmpty ? description : 'Item',
                itemCode: itemCode,
                quantity: qty,
                unitPrice: unitPriceIncl,
                itemAmount: itemAmountIncl,
                taxCode: isZeroRated ? 2 : 1,
              ));
            }
          }
        }
      } else {
        int startIndex = -1;
        final headerMatches = [
          'Total Amount',
          'Item Descripton',
          'Item Description',
          'Unit PriceVat%',
          'HS Code'
        ];
        for (final h in headerMatches) {
          final idx = text.indexOf(h);
          if (idx != -1) {
            final cand = idx + h.length;
            if (startIndex == -1 || cand > startIndex) {
              startIndex = cand;
            }
          }
        }

        int endIndex = text.length;
        final footerMatches = [
          'Total Quantty',
          'Grand Total',
          'Sub Total',
          'Notes :',
          'Based on Sales Orders',
          'Delivery Terms :'
        ];
        for (final f in footerMatches) {
          final idx = text.indexOf(f);
          if (idx != -1 && (startIndex == -1 || idx > startIndex)) {
            endIndex = idx;
            break;
          }
        }

        String tableBlock = (startIndex != -1 && startIndex < endIndex)
            ? text.substring(startIndex, endIndex)
            : text;

        // Insert newlines between concatenated item lines (e.g. "88.56KNITTED" -> "88.56\nKNITTED")
        tableBlock = tableBlock.replaceAllMapped(
          RegExp(r'(\.\d{2})([A-Z]|1X1)'),
          (m) => '${m.group(1)}\n${m.group(2)}',
        );
        final itemRegex = RegExp(
          r"([A-Za-z0-9_\-\s\(\)\/\.\+\#\&\_\:\'\%]+?)\s+([\d,]+\.\d{2})\s*([A-Za-z]{2,10})?\s+([\d,]+\.\d{2})(\d{1,3})?\s*([A-Z0-9_\-\s\'\/\.]+?)\s+(\d+\.\d{2}[\d\.]*)\s+([\d,]+\.\d{2})",
          caseSensitive: false,
        );

        final matches = itemRegex.allMatches(tableBlock);
        for (final match in matches) {
          var description = match.group(1)!.trim();
          // Clean up description if it captured preceding page header text
          if (description.contains('Total Amount')) {
            description = description
                .substring(description.indexOf('Total Amount') +
                    'Total Amount'.length)
                .trim();
          } else if (description.contains('Item Descripton')) {
            description = description
                .substring(description.indexOf('Item Descripton') +
                    'Item Descripton'.length)
                .trim();
          }

          final qty =
              double.tryParse(match.group(2)!.replaceAll(',', '')) ?? 0.0;
          final unitPriceExcl =
              double.tryParse(match.group(4)!.replaceAll(',', '')) ?? 0.0;
          final siNo = match.group(5);
          final rawCode = match.group(6)!.trim();
          final vatStr = match.group(7)!.trim();

          String itemCode = rawCode;
          if (siNo != null && RegExp(r'^\d').hasMatch(rawCode)) {
            itemCode = '$siNo$rawCode';
          }

          // If HS Code is present in vatStr (e.g. "0.000002.32.00"), use HS Code as product code
          if (vatStr.length > 5) {
            final String rawHs = vatStr.startsWith('16.00')
                ? vatStr.substring(5)
                : (vatStr.startsWith('0.00') ? vatStr.substring(4) : vatStr);
            final String cleanedHs =
                rawHs.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
            if (cleanedHs.isNotEmpty && cleanedHs.length >= 4) {
              itemCode = cleanedHs;
            }
          }

          final itemAmountExcl =
              double.tryParse(match.group(8)!.replaceAll(',', '')) ?? 0.0;

          // Check if item has 16% VAT or 0% VAT
          final bool isZeroRated = vatStr.startsWith('0.00') ||
              vatStr == '0.00' ||
              vatStr == '0' ||
              detectedCurrency == 'USD' ||
              text.toUpperCase().contains('SHOWN IN USD');

          final double itemAmountIncl =
              isZeroRated ? itemAmountExcl : (itemAmountExcl * 1.16);
          final double unitPriceIncl = qty > 0
              ? (itemAmountIncl / qty)
              : (isZeroRated ? unitPriceExcl : unitPriceExcl * 1.16);

          if (qty > 0 && itemAmountIncl > 0) {
            itemDetails.add(ItemDetail(
              id: itemDetails.length + 1,
              trId: id,
              description: description.isNotEmpty ? description : 'Item',
              itemCode: itemCode,
              quantity: qty,
              unitPrice: unitPriceIncl,
              itemAmount: itemAmountIncl,
              taxCode: isZeroRated ? 2 : 1,
            ));
          }
        }
      }
    }

    bool isValidRaaDescription(String t) {
      if (t.trim().isEmpty) return false;
      final upper = t.toUpperCase();
      if (double.tryParse(t.trim()) != null) return false;
      if (upper.contains('SUB TOTAL') ||
          upper.contains('TOTAL (INCL)') ||
          upper.contains('RECEIVED BY') ||
          upper.contains('PREPARED BY') ||
          upper.contains('AUTHORISED BY') ||
          upper.contains('PRINTED ON') ||
          upper.contains('ID NO:') ||
          upper.contains('DESIGNATION:') ||
          upper.contains('TIME:') ||
          upper.contains('SIGNATURE:')) {
        return false;
      }
      return true;
    }

    if (isTemplateRaa) {
      // Truncate text before summary footer section so totals are not parsed as items
      int footerIndex = text.indexOf('Sub Total (Excl)');
      if (footerIndex == -1) footerIndex = text.indexOf('Total (Incl)');
      if (footerIndex == -1) footerIndex = text.indexOf('WE HAVE RECEIVED');
      if (footerIndex == -1) footerIndex = text.indexOf('Designation:');

      final parseableText =
          (footerIndex != -1) ? text.substring(0, footerIndex) : text;

      final itemLines = parseableText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      for (int i = 0; i < itemLines.length; i++) {
        final line = itemLines[i];
        // 1. Check for single-line RAA item (e.g. "0039.11.55 515.00 515.00 Mentho Plus... DOZ")
        final raaItemMatch = RegExp(
          r'^(?:(\d{2})?(\d{2}\.\d{2}\.\d{2}|\d{4,8}))?([\d,]+\.\d{2})\s*([\d,]+\.\d{2})(.+?)(?:\s*(DOZ|PCS|CTN|BOX|PKT|KG|LTR|SET|PAIR|DOZEN|BAG|UNITS?|EA))?$',
          caseSensitive: false,
        ).firstMatch(line);

        // 2. Check for multiline RAA Credit Note / Invoice item amount line (e.g. "1,640.008,200.00")
        final raaAmountMatch = (raaItemMatch == null &&
                !line.contains('Printed On') &&
                !line.contains('Sub Total') &&
                !line.contains('Total'))
            ? RegExp(r'^([\d,]+\.\d{2})\s*([\d,]+\.\d{2})$').firstMatch(line)
            : null;

        if (raaItemMatch != null) {
          final prefix = raaItemMatch.group(1) ?? '';
          final codeOnLine = raaItemMatch.group(2);
          final hsCode = codeOnLine != null ? '$prefix$codeOnLine' : null;
          final val1 =
              double.tryParse(raaItemMatch.group(3)!.replaceAll(',', '')) ?? 0.0;
          final val2 =
              double.tryParse(raaItemMatch.group(4)!.replaceAll(',', '')) ?? 0.0;
          final lineAmount = val1 > val2 ? val1 : val2;
          final lineUnitPrice = val1 < val2 ? val1 : val2;
          var description = raaItemMatch.group(5)!.trim();
          if (description.contains('Please ensure')) {
            description =
                description.substring(0, description.indexOf('Please ensure')).trim();
          }
          description = description.replaceAll(
            RegExp(r'(DOZ|PCS|CTN|BOX|PKT|KG|LTR|SET|PAIR|DOZEN|BAG|UNITS?|EA)$', caseSensitive: false),
            '',
          ).trim();

          // If description captured a number (e.g. "2" or "1") or footer text (e.g. "Printed On"), fallback to succeeding or preceding line
          final double? descAsNum = double.tryParse(description);
          final descUpper = description.toUpperCase();
          if (description.isEmpty ||
              descAsNum != null ||
              descUpper.contains('PRINTED') ||
              descUpper.contains('RECEIVED BY') ||
              descUpper.contains('PREPARED BY') ||
              descUpper.contains('AUTHORISED BY')) {
            if (i + 1 < itemLines.length && isValidRaaDescription(itemLines[i + 1])) {
              description = itemLines[i + 1].trim();
            } else if (i >= 1 && isValidRaaDescription(itemLines[i - 1])) {
              description = itemLines[i - 1].trim();
            }
          }

          double qty = 1.0;
          if (i >= 1 && double.tryParse(itemLines[i - 1]) != null) {
            qty = double.parse(itemLines[i - 1]);
          } else if (i >= 2 && double.tryParse(itemLines[i - 2]) != null) {
            qty = double.parse(itemLines[i - 2]);
          }
          if (qty == 1.0 && lineUnitPrice > 0) {
            qty = (lineAmount / lineUnitPrice).roundToDouble();
            if (qty == 0) qty = 1.0;
          }

          final bool isZeroRated = (vatAmountA ?? 0) == 0;
          final double itemAmountIncl = lineAmount;
          final double unitPriceIncl = qty > 0 ? (itemAmountIncl / qty) : lineUnitPrice;

          if (qty > 0 && itemAmountIncl > 0 && description.isNotEmpty) {
            itemDetails.add(ItemDetail(
              id: itemDetails.length + 1,
              trId: id,
              description: description,
              itemCode: hsCode,
              quantity: qty,
              unitPrice: unitPriceIncl,
              itemAmount: itemAmountIncl,
              taxCode: isZeroRated ? 2 : 1,
            ));
          }
        } else if (raaAmountMatch != null) {
          final val1 =
              double.tryParse(raaAmountMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
          final val2 =
              double.tryParse(raaAmountMatch.group(2)!.replaceAll(',', '')) ?? 0.0;
          final lineAmount = val1 > val2 ? val1 : val2;
          final lineUnitPrice = val1 < val2 ? val1 : val2;

          String description = '';
          double qty = 1.0;

          if (i >= 1 && double.tryParse(itemLines[i - 1]) != null) {
            qty = double.parse(itemLines[i - 1]);
            if (i + 1 < itemLines.length && isValidRaaDescription(itemLines[i + 1])) {
              description = itemLines[i + 1].trim();
            }
          } else {
            if (i >= 1 && isValidRaaDescription(itemLines[i - 1])) {
              description = itemLines[i - 1].trim();
            }
            if (i >= 2) {
              final parsedQty = double.tryParse(itemLines[i - 2]);
              if (parsedQty != null && parsedQty > 0) {
                qty = parsedQty;
              }
            }
          }

          if (description.contains('Please ensure')) {
            description =
                description.substring(0, description.indexOf('Please ensure')).trim();
          }

          if (qty == 1.0 && lineUnitPrice > 0) {
            qty = (lineAmount / lineUnitPrice).roundToDouble();
            if (qty == 0) qty = 1.0;
          }

          final bool isZeroRated = (vatAmountA ?? 0) == 0;
          final double itemAmountIncl = lineAmount;
          final double unitPriceIncl = qty > 0 ? (itemAmountIncl / qty) : lineUnitPrice;

          if (qty > 0 && itemAmountIncl > 0 && description.isNotEmpty && !description.contains('Sub Total') && !description.contains('Total (Incl)')) {
            itemDetails.add(ItemDetail(
              id: itemDetails.length + 1,
              trId: id,
              description: description,
              itemCode: null,
              quantity: qty,
              unitPrice: unitPriceIncl,
              itemAmount: itemAmountIncl,
              taxCode: isZeroRated ? 2 : 1,
            ));
          }
        }
      }
    }

    // ============================================================
    // Fallback: If no items found and this is a Sleek invoice, try harder
    // ============================================================
    if (isTemplateSleek && itemDetails.isEmpty) {
      // Try a different approach - look for patterns in the text
      final itemLines = text.split('\n');
      for (int i = 0; i < itemLines.length; i++) {
        final line = itemLines[i].trim();
        // Look for item code pattern
        if (line.contains('.')) continue;
        final codeMatch = RegExp(r'^([A-Z]?\d{3,20})\b').firstMatch(line);
        if (codeMatch != null) {
          final itemCode = codeMatch.group(1)!;
          // Look for description in next lines
          String desc = '';
          int j = i + 1;
          while (j < itemLines.length) {
            final nextLine = itemLines[j].trim();
            if (nextLine.isEmpty) {
              j++;
              continue;
            }
            if (RegExp(r'^[\d,]+\.\d{2}$').hasMatch(nextLine)) {
              break;
            }
            if (!nextLine.contains('.') && RegExp(r'^([A-Z]?\d{3,20})\b').hasMatch(nextLine)) {
              break;
            }
            desc += (desc.isEmpty ? '' : ' ') + nextLine;
            j++;
          }

          // Look for numbers after the description
          final List<double> nums = [];
          int k = j;
          while (k < itemLines.length && nums.length < 7) {
            final numLine = itemLines[k].trim();
            if (numLine.isEmpty) {
              k++;
              continue;
            }
            if (!numLine.contains('.') && RegExp(r'^([A-Z]?\d{3,20})\b').hasMatch(numLine)) {
              break;
            }
            final numMatch = RegExp(r'[\d,]+\.\d{2}').firstMatch(numLine);
            if (numMatch != null) {
              final val =
                  double.tryParse(numMatch.group(0)!.replaceAll(',', ''));
              if (val != null) nums.add(val);
            }
            k++;
          }

          if (nums.length >= 3) {
            final quantity = nums[0];
            final totalAmount = nums[2];
            if (quantity > 0 && totalAmount > 0) {
              final unitPrice = totalAmount / quantity;
              itemDetails.add(ItemDetail(
                id: itemDetails.length + 1,
                trId: id,
                description: desc.trim(),
                itemCode: itemCode,
                quantity: quantity,
                unitPrice: unitPrice,
                itemAmount: totalAmount,
                discountRate: null, // Discount already applied
                taxCode: 1,
              ));
            }
          }
        }
      }
    }

    if (tsNum.isEmpty && pdfPath != null) {
      final fnMatch = RegExp(r'(\d{4,8})').firstMatch(path.basename(pdfPath));
      if (fnMatch != null) {
        tsNum = fnMatch.group(1)!;
      }
    }

    if (kDebugMode) {
      print('Item matches found: ${itemDetails.length}');
      print('TsNum: $tsNum');
      print('Buyer PIN: $buyerPIN');
      print('Seller PIN: $sellerPIN');
      print('CUIN: $cuin');
      print('Total Amount: $totalAmount');
      print('Currency: $currency');
      print('Converted Total: $convertedTotalAmount');
    }

    // Fallback: If totalAmount is zero or template is Alpha Knits, sum up the items to ensure the file is generated correctly
    double effectiveTotal = totalAmount;
    double effectiveConvertedTotal = convertedTotalAmount;
    if ((effectiveTotal == 0 || isTemplateAlphaKnits) && itemDetails.isNotEmpty) {
      effectiveTotal =
          itemDetails.fold(0, (sum, item) => sum + item.itemAmount);
      effectiveConvertedTotal = (currency != 'KES' && conversionRate != null)
          ? effectiveTotal * conversionRate
          : effectiveTotal;
    }

    return DataModel(
      id: id,
      tsNum: tsNum,
      buyerPIN: buyerPIN,
      totalAmount: effectiveTotal,
      convertedTotalAmount: effectiveConvertedTotal,
      itemDetails: itemDetails.isEmpty ? null : itemDetails,
      currency: currency,
      mwNum: cuin.isNotEmpty ? cuin : null,
      trType: isCreditNote ? 1 : 0,
      vatAmountA: vatAmountA,
    );
  }

  /// Helper to safely add items from the Auctorita state machine
  static void _addItemH(List<ItemDetail> list, int trId, String description,
      double? qty, double? rate, double? total) {
    if (total == null && rate == null) return;

    final double effectiveQty = qty ?? 1.0;
    final double effectiveTotal =
        total ?? (rate != null ? rate * effectiveQty : 0.0);
    final double effectiveRate =
        rate ?? (effectiveQty != 0 ? effectiveTotal / effectiveQty : 0.0);

    list.add(ItemDetail(
      id: list.length + 1,
      trId: trId,
      description: description.trim(),
      quantity: effectiveQty,
      unitPrice: effectiveRate,
      itemAmount: effectiveTotal,
      taxCode: 1, // Standard VAT
    ));
  }

  /// Exports the provided data to a CSV file (compatible with Excel).
  static Future<void> exportToExcel({
    required List<DataModel> data,
    required String filePath,
  }) async {
    try {
      final StringBuffer buffer = StringBuffer();

      // CSV Header
      buffer.writeln(
          'TS-NUM,BUYER PIN,DATE,MW-NUM,RELEVANT MW-NUM,TOTAL AMOUNT,VAT AMOUNT,CONTROL CODE,ITEM COUNT');

      for (final item in data) {
        final String dateStr = item.date != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(item.date!)
            : '';

        buffer.writeln([
          '="${item.tsNum}"',
          '="${item.buyerPIN ?? ''}"',
          '"$dateStr"',
          '="${item.mwNum ?? ''}"',
          '="${item.relevantMwNum ?? ''}"',
          item.totalAmount ?? 0.0,
          item.totalVat,
          '="${item.controlCode ?? ''}"',
          item.itemDetails?.length ?? 0,
        ].join(','));
      }

      final File file = File(filePath);
      await file.writeAsBytes([0xEF, 0xBB, 0xBF]);
      await file.writeAsString(buffer.toString(), mode: FileMode.append);
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }
}
