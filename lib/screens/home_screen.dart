//home_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tims_data_exporter/models/data_model.dart';
import 'package:tims_data_exporter/widgets/file_generator.dart';
import 'package:tims_data_exporter/data/database_helper.dart';
import 'package:tims_data_exporter/widgets/action_bottom_sheet.dart';
import 'package:tims_data_exporter/widgets/transaction_table.dart';
import 'package:path/path.dart' as path;
import 'package:tims_data_exporter/screens/reports_screen.dart'; // Keep this import
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/license_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<DataModel> _transactions = [];
  final List<DataModel> _filteredTransactions = [];
  bool _isLoading = false;
  // final bool _isLoadingMore = false; // Removed unused field
  int _selectedIndex = 0;
  bool _isProcessing = false;
  int _currentPage = 0;
  int _totalPages = 0;
  int _limit = 50; // Make this mutable
  final List<int> _limitOptions = [
    10,
    25,
    50,
    100,
    200,
    500,
    1000,
    2000,
    -1
  ]; // Records per page options
  List<File> _generatedFiles = [];
  final List<DataModel> _selectedTransactions = [];
  String _inputPath = '';
  StreamSubscription<FileSystemEvent>? _dirWatcher;
  bool _isDatabaseConnected = false;
  bool _showSearch = false;
  bool _showFilters = false;
  String _dbPath = r'C:\FBtemp\DB\FbTransaction.db';

  // Dashboard Stats
  double _totalRevenue = 0;
  double _totalVatAmount = 0;
  List<BarChartGroupData> _chartGroups = [];

  // QR Code Position Settings
  double? _qrX;
  double? _qrY;
  String _qrLayout = 'beside';
  String _qrPositionPreset = 'bottom_right';
  String? _customDtrPath;
  String? _customTicketPath;
  String? _customTaxInvoicesPath;

  // Database
  DatabaseHelper? _dbHelper;

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _pageController = TextEditingController();
  SearchMode _searchMode = SearchMode.mwNum;

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  double _minAmount = 0;
  double _maxAmount = double.infinity;

  // Theme Colors
  static const Color _primaryColor = Color(0xFF4F46E5);
  static const Color _primaryLight = Color(0xFF818CF8);
  static const Color _secondaryColor = Color(0xFF06B6D4);
  static const Color _accentColor = Color(0xFF8B5CF6);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _errorColor = Color(0xFFEF4444);
  static const Color _cardBgColor = Colors.white;
  static const Color _surfaceColor = Color(0xFFF8FAFC);
  static const Color _neutral100 = Color(0xFFF1F5F9);
  static const Color _neutral200 = Color(0xFFE2E8F0);
  static const Color _neutral300 = Color(0xFFCBD5E1);
  static const Color _neutral400 = Color(0xFF94A3B8);
  static const Color _neutral500 = Color(0xFF64748B);
  static const Color _neutral600 = Color(0xFF475569);
  static const Color _neutral700 = Color(0xFF334155);
  static const Color _neutral800 = Color(0xFF1E293B);

  // Design Constants
  static const double _borderRadius = 16.0;
  static const double _borderRadiusSmall = 12.0;
  static const double _borderRadiusLarge = 20.0;
  static const double _spacingXS = 4.0;
  static const double _spacingS = 8.0;
  static const double _spacingM = 16.0;
  static const double _spacingL = 24.0;
  static const double _spacingXL = 32.0;

  // SharedPreferences Keys
  static const String _prefDbPath = 'database_path';
  static const String _prefQrX = 'qr_x_pos';
  static const String _prefQrY = 'qr_y_pos';
  static const String _prefDtrPath = 'path_dtr_app';
  static const String _prefTicketPath = 'path_ticket';
  static const String _prefTaxInvoicesPath = 'path_tax_invoices';

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _pageController.text = '1';
  }

  Future<void> _initializeApp() async {
    await _checkLicenseOnStartup();

    // Load saved database path first
    await _loadDatabasePath();

    _initDatabase();
    await _loadSettings();
    await FileGenerator.initAppDirectories();
    _loadGeneratedFiles();
    _loadInputPath();
  }

  Future<void> _loadDatabasePath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString(_prefDbPath);

      if (savedPath != null && savedPath.isNotEmpty) {
        setState(() {
          _dbPath = savedPath;
        });
      } else {
        setState(() {
          _dbPath = r'C:\FBtemp\DB\FbTransaction.db';
        });
      }
    } catch (e) {
      debugPrint('Error loading database path: $e');
      setState(() {
        _dbPath = r'C:\FBtemp\DB\FbTransaction.db';
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _qrX = prefs.getDouble(_prefQrX);
      _qrY = prefs.getDouble(_prefQrY);
      _qrLayout = prefs.getString('qr_layout') ?? 'beside';
      _qrPositionPreset = prefs.getString('qr_position_preset') ?? 'bottom_right';
      _customDtrPath = prefs.getString(_prefDtrPath);
      _customTicketPath = prefs.getString(_prefTicketPath);
      _customTaxInvoicesPath = prefs.getString(_prefTaxInvoicesPath);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dirWatcher?.cancel();
    _scrollController.dispose();
    _pageController.dispose();
    _dbHelper?.closeDatabase();
    super.dispose();
  }

  Future<void> _checkLicenseOnStartup() async {
    final status = await LicenseManager.checkLicenseStatus();
    if (status['isExpired'] == true) {
      if (mounted) {
        // Force the license check prompt.
        // We reuse the logic in FileGenerator which handles the UI dialogs
        await FileGenerator.verifyLicense(context, _showNotification);
      }
    }
  }

  Future<void> _initDatabase() async {
    try {
      final helper = DatabaseHelper(databasePath: _dbPath);
      _dbHelper = helper;
      await _checkDatabaseConnection();
    } catch (e, s) {
      // Changed print to debugPrint
      debugPrint('--- DATABASE INITIALIZATION ERROR ---');
      debugPrint('$e');
      debugPrint('$s');
      debugPrint('--------------------------------------');
      _showErrorDialog('Database Setup Error', e.toString());
    }
  }

  Future<void> _checkDatabaseConnection() async {
    try {
      final exists = await _dbHelper!.databaseExists(_dbPath);
      setState(() {
        _isDatabaseConnected = exists;
      });
      if (exists) {
        _showNotification('Database connected successfully',
            type: NotificationType.success);
        await _dbHelper!.createIndexes();
        _loadPageData();
      } else {
        _showNotification('Database not found at specified path',
            type: NotificationType.warning);
      }
      await _loadDashboardStats();
    } catch (e, s) {
      // Changed print to debugPrint
      debugPrint('--- DATABASE CONNECTION ERROR ---');
      debugPrint('$e');
      debugPrint('$s');
      debugPrint('----------------------------------');
      setState(() {
        _isDatabaseConnected = false;
      });
      _showErrorDialog('Database Connection Failed', e.toString());
    }
  }

  Future<void> _loadDashboardStats() async {
    if (!_isDatabaseConnected || _dbHelper == null) return;
    try {
      final sales = await _dbHelper!.getDailySales();
      double rev = 0;
      double vat = 0;
      List<BarChartGroupData> groups = [];

      for (int i = 0; i < sales.length; i++) {
        final amount = (sales[i]['total_sales'] as num?)?.toDouble() ?? 0.0;
        rev += amount;
        // Estimate VAT if not specifically queried for dashboard
        vat += amount * 0.16;

        groups.add(BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: amount,
              color: _primaryColor,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        ));
      }

      setState(() {
        _totalRevenue = rev;
        _totalVatAmount = vat;
        _chartGroups = groups;
      });
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
    }
  }

  Future<void> _selectDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        dialogTitle: 'Select Database File',
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
        type: FileType.custom,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final newPath = result.files.first.path!;

        // Save the path to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefDbPath, newPath);

        setState(() {
          _dbPath = newPath;
          _transactions.clear();
          _filteredTransactions.clear();
          _currentPage = 0;
          _totalPages = 0;
          _selectedTransactions.clear();
          _isDatabaseConnected = false;
          _pageController.text = '1';
        });

        await _initDatabase();
        if (_isDatabaseConnected) {
          _showNotification('Database updated successfully',
              type: NotificationType.success);
        }
      }
    } catch (e) {
      _showNotification('Error selecting database: $e',
          type: NotificationType.error);
    }
  }

  Future<void> _resetDatabasePath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefDbPath);

      setState(() {
        _dbPath = r'C:\FBtemp\DB\FbTransaction.db';
        _transactions.clear();
        _filteredTransactions.clear();
        _currentPage = 0;
        _totalPages = 0;
        _selectedTransactions.clear();
        _isDatabaseConnected = false;
        _pageController.text = '1';
      });

      await _initDatabase();
      if (mounted) {
        _showNotification('Database path reset to default',
            type: NotificationType.info);
      }
    } catch (e) {
      _showNotification('Error resetting database path: $e',
          type: NotificationType.error);
    }
  }

  Future<void> _loadGeneratedFiles() async {
    try {
      final dirs = await FileGenerator.getOutputDirectory();
      final textFilesDir = Directory(dirs['textFiles']!);
      if (await textFilesDir.exists()) {
        final files = await textFilesDir
            .list()
            .where((fs) => fs is File && fs.path.endsWith('.txt'))
            .cast<File>()
            .toList();

        files.sort((a, b) {
          try {
            if (!a.existsSync()) return 1;
            if (!b.existsSync()) return -1;
            return b.lastModifiedSync().compareTo(a.lastModifiedSync());
          } catch (e) {
            return 0;
          }
        });

        if (mounted) {
          setState(() {
            _generatedFiles = files;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showNotification('Error loading generated files: $e',
            type: NotificationType.error);
      }
    }
  }

  Future<void> _loadInputPath() async {
    final dirs = await FileGenerator.getOutputDirectory();
    if (mounted) {
      setState(() {
        _inputPath = dirs['input'] ?? '';
      });
      if (_inputPath.isNotEmpty) {
        _startWatchingInputDirectory();
      }
    }
  }

  void _startWatchingInputDirectory() {
    if (_dirWatcher != null) {
      _dirWatcher!.cancel();
    }
    final dir = Directory(_inputPath);
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (e) {
        _showNotification('Error creating input directory: $e',
            type: NotificationType.error);
        return;
      }
    }

    _dirWatcher = dir.watch(events: FileSystemEvent.create).listen((event) {
      if (event is FileSystemCreateEvent &&
          !event.isDirectory &&
          event.path.toLowerCase().endsWith('.pdf')) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _showNotification('New PDF detected: ${path.basename(event.path)}',
                type: NotificationType.info);
            _processSingleInputFile(event.path);
          }
        });
      }
    });

    // Perform an initial scan to process files already in the folder
    _scanAndProcessExistingFiles(dir);

    if (kDebugMode) {
      debugPrint('Started watching directory: $_inputPath');
    }
  }

  Future<void> _scanAndProcessExistingFiles(Directory dir) async {
    try {
      final entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          await _processSingleInputFile(entity.path);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // Changed print to debugPrint
        debugPrint('Error scanning existing files: $e');
      }
    }
  }

  Future<void> _processSingleInputFile(String pdfPath) async {
    if (!await File(pdfPath).exists()) {
      _showNotification('File disappeared before processing',
          type: NotificationType.warning);
      return;
    }

    if (_isProcessing) {
      _showNotification('Already processing a file. Please wait.',
          type: NotificationType.warning);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      if (!mounted) return;
      final dataModelsMap = await FileGenerator.parsePdfsToDataModelsMap(
        context: context,
        pdfPaths: [pdfPath],
        showSnackBar: _showNotification,
        setProcessing: ({required bool isProcessing, double? progress}) {},
      );

      if (dataModelsMap.isNotEmpty) {
        final dataModel = dataModelsMap.values.first;
        final originalPath = dataModelsMap.keys.first;

        // Detect if the document is a Credit Note to prompt for CUIN
        // We now use trType (1 = Credit Note) for detection
        final isCreditNote = dataModel.trType == 1;

        if (!mounted) return;
        if (isCreditNote) {
          await FileGenerator.generateCreditNote(
            context: context,
            item: dataModel,
            showSnackBar: _showNotification,
            getOutputDirectory: FileGenerator.getOutputDirectory,
            pdfPath: originalPath,
            processWithDb: _isDatabaseConnected,
            dbPath: _dbPath,
            qrX: _qrX,
            qrY: _qrY,
          );
        } else {
          await FileGenerator.generateInvoice(
            context: context,
            item: dataModel,
            showSnackBar: _showNotification,
            getOutputDirectory: FileGenerator.getOutputDirectory,
            pdfPath: originalPath,
            processWithDb: _isDatabaseConnected,
            dbPath: _dbPath,
            qrX: _qrX,
            qrY: _qrY,
          );
        }
        await _loadGeneratedFiles();
        if (mounted) {
          _showNotification('PDF processed successfully',
              type: NotificationType.success);
        }
      } else {
        _showNotification('Failed to parse data from PDF',
            type: NotificationType.error);
      }
    } catch (e) {
      if (mounted) {
        _showNotification('Error processing file: $e',
            type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickAndProcessPdfs() async {
    if (_isProcessing) {
      _showNotification('Processing is already in progress.',
          type: NotificationType.warning);
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        dialogTitle: 'Select PDF Invoices to Process',
        allowedExtensions: ['pdf'],
        type: FileType.custom,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final paths =
            result.paths.where((p) => p != null).cast<String>().toList();
        if (paths.isEmpty) {
          _showNotification('No valid file paths selected.',
              type: NotificationType.warning);
          return;
        }

        setState(() => _isProcessing = true);
        int successCount = 0;
        int failCount = 0;

        try {
          if (!mounted) return;

          final dataModelsMap = await FileGenerator.parsePdfsToDataModelsMap(
            context: context,
            pdfPaths: paths,
            showSnackBar: _showNotification,
            setProcessing: ({required bool isProcessing, double? progress}) {},
          );

          if (dataModelsMap.isEmpty) {
            _showNotification(
                'Failed to parse any data from the selected PDFs.',
                type: NotificationType.error);
            return;
          }

          for (final entry in dataModelsMap.entries) {
            final originalPath = entry.key;
            final dataModel = entry.value;

            try {
              // Detect if the document is a Credit Note to prompt for CUIN
              // We now use trType (1 = Credit Note) for detection
              final isCreditNote = dataModel.trType == 1;

              if (!mounted) return;
              if (isCreditNote) {
                await FileGenerator.generateCreditNote(
                  context: context,
                  item: dataModel,
                  showSnackBar: _showNotification,
                  getOutputDirectory: FileGenerator.getOutputDirectory,
                  pdfPath: originalPath,
                  processWithDb: _isDatabaseConnected,
                  dbPath: _dbPath,
                  qrX: _qrX,
                  qrY: _qrY,
                );
              } else {
                await FileGenerator.generateInvoice(
                  context: context,
                  item: dataModel,
                  showSnackBar: _showNotification,
                  getOutputDirectory: FileGenerator.getOutputDirectory,
                  pdfPath: originalPath,
                  processWithDb: _isDatabaseConnected,
                  dbPath: _dbPath,
                  qrX: _qrX,
                  qrY: _qrY,
                );
              }
              successCount++;
            } catch (e) {
              failCount++;
              if (mounted) {
                _showNotification(
                    'Error processing file ${path.basename(originalPath)}: $e',
                    type: NotificationType.error);
              }
            }
          }

          await _loadGeneratedFiles();
          if (mounted) {
            _showNotification(
              'Processing complete. Success: $successCount, Failed: $failCount.',
              type: failCount > 0
                  ? NotificationType.warning
                  : NotificationType.success,
            );
          }
        } catch (e) {
          if (mounted) {
            _showNotification('An error occurred during batch processing: $e',
                type: NotificationType.error);
          }
        } finally {
          if (mounted) setState(() => _isProcessing = false);
        }
      }
    } catch (e) {
      _showNotification('Error picking files: $e',
          type: NotificationType.error);
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showFileContent(File file) async {
    try {
      final content = await file.readAsString();
      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: _cardBgColor,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_borderRadiusLarge)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: -5,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(_spacingM),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(_borderRadiusLarge)),
                  border: Border(
                    bottom: BorderSide(color: _neutral200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius:
                                BorderRadius.circular(_borderRadiusSmall),
                          ),
                          child: Icon(Iconsax.document_text,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: _spacingM),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'File Preview',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _neutral800,
                              ),
                            ),
                            const SizedBox(height: _spacingXS),
                            Text(
                              path.basename(file.path),
                              style: TextStyle(
                                fontSize: 12,
                                color: _neutral500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Iconsax.close_circle, color: _neutral400),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(_spacingM),
                  padding: const EdgeInsets.all(_spacingM),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(_borderRadius),
                    border: Border.all(color: _neutral200),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'File Content',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _neutral700,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: _spacingS, vertical: 4),
                              decoration: BoxDecoration(
                                color: _neutral100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${content.length} characters',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _neutral500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: _spacingM),
                        Container(
                          padding: const EdgeInsets.all(_spacingM),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(_borderRadiusSmall),
                          ),
                          child: SelectableText(
                            content,
                            style: TextStyle(
                              fontFamily: 'Roboto Mono',
                              fontSize: 12,
                              color: _neutral700,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(_spacingM),
                decoration: BoxDecoration(
                  color: _neutral100,
                  border: Border(top: BorderSide(color: _neutral200)),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(_borderRadiusLarge)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _neutral600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_borderRadius),
                          ),
                          side: BorderSide(color: _neutral300),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: _spacingM),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          _showNotification('Content copied to clipboard',
                              type: NotificationType.success);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_borderRadius),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text('Copy Content'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showNotification('Error reading file: $e', type: NotificationType.error);
    }
  }

  Future<void> _loadPageData() async {
    final helper = _dbHelper;
    if (!_isDatabaseConnected || helper == null) return;

    setState(() {
      _isLoading = true;
      _transactions.clear();
      _filteredTransactions.clear();
      _selectedTransactions.clear();
    });

    try {
      final offset = _limit == -1 ? 0 : _currentPage * _limit;
      final limitValue = _limit == -1 ? 1000000 : _limit;
      final data = await helper.getData(offset, limitValue);

      if (data.isEmpty && _currentPage > 0) {
        // If no data on current page, go back to first page
        _currentPage = 0;
        _pageController.text = '1';
        await _loadPageData();
        return;
      }

      if (data.isEmpty) {
        _showNotification('No transactions found', type: NotificationType.info);
        setState(() {
          _totalPages = 0;
        });
        return;
      }

      final totalCount = await helper.getTransactionCount();
      _totalPages = _limit == -1 ? 1 : (totalCount / _limit).ceil();

      setState(() {
        _transactions.addAll(data);
        _filteredTransactions.addAll(data);
      });

      _showNotification('Loaded ${data.length} transactions',
          type: NotificationType.success);
    } catch (e, s) {
      debugPrint('--- DATA LOADING ERROR ---');
      debugPrint('$e');
      debugPrint('$s');
      debugPrint('--------------------------');
      _showErrorDialog('Error Loading Transactions', e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _goToNextPage() async {
    if (_currentPage < _totalPages - 1 && !_isLoading) {
      _currentPage++;
      _pageController.text = (_currentPage + 1).toString();
      await _loadPageData();
    }
  }

  Future<void> _goToPreviousPage() async {
    if (_currentPage > 0 && !_isLoading) {
      _currentPage--;
      _pageController.text = (_currentPage + 1).toString();
      await _loadPageData();
    }
  }

  Future<void> _goToFirstPage() async {
    if (_currentPage != 0 && !_isLoading) {
      _currentPage = 0;
      _pageController.text = '1';
      await _loadPageData();
    }
  }

  Future<void> _goToLastPage() async {
    if (_currentPage != _totalPages - 1 && !_isLoading) {
      _currentPage = _totalPages - 1;
      _pageController.text = (_currentPage + 1).toString();
      await _loadPageData();
    }
  }

  Future<void> _changeLimit(int newLimit) async {
    if (newLimit == _limit) return;

    setState(() {
      _limit = newLimit;
      _currentPage = 0;
      _pageController.text = '1';
    });
    await _loadPageData();
  }

  void _performSearch() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _filteredTransactions.clear();
        _filteredTransactions.addAll(_transactions);
        _selectedTransactions.clear();
      });
      return;
    }

    _searchInDatabase(query);
  }

  Future<void> _searchInDatabase(String query) async {
    if (!_isDatabaseConnected || _dbHelper == null) return;

    setState(() {
      _isLoading = true;
      _filteredTransactions.clear();
      _selectedTransactions.clear();
    });

    try {
      List<DataModel> searchResults = [];

      if (_searchMode == SearchMode.mwNum) {
        searchResults =
            await _dbHelper!.searchByMwNumOptimized(query, limit: 200);
      } else {
        searchResults =
            await _dbHelper!.searchByControlCodeOptimized(query, limit: 200);
      }

      setState(() {
        _filteredTransactions.addAll(searchResults);
      });

      if (searchResults.isEmpty) {
        _showNotification('No transactions found matching "$query"',
            type: NotificationType.info);
      } else {
        _showNotification('Found ${searchResults.length} transactions',
            type: NotificationType.success);
      }
    } catch (e, s) {
      // Changed print to debugPrint
      debugPrint('--- SEARCH ERROR ---');
      debugPrint('$e');
      debugPrint('$s');
      debugPrint('--------------------');
      _showErrorDialog('Search Failed', e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _filteredTransactions.clear();
      _filteredTransactions.addAll(_transactions);
      _selectedTransactions.clear();
      _showSearch = false;
    });
  }

  void _applyFilters() async {
    if (_dbHelper == null) return;
    setState(() {
      _isLoading = true;
      _filteredTransactions.clear();
      _selectedTransactions.clear();
      _showFilters = false;
    });

    try {
      final filtered = await _dbHelper!.getFilteredData(
        startDate: _startDate,
        endDate: _endDate,
        minAmount: _minAmount,
        maxAmount: _maxAmount,
      );

      setState(() {
        _filteredTransactions.addAll(filtered);
      });

      _showNotification('Applied filters (${filtered.length} results)',
          type: NotificationType.success);
    } catch (e, s) {
      // Changed print to debugPrint
      debugPrint('--- FILTER ERROR ---');
      debugPrint('$e');
      debugPrint('$s');
      debugPrint('--------------------');
      _showErrorDialog('Filter Application Failed', e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _minAmount = 0;
      _maxAmount = double.infinity;
      _filteredTransactions.clear();
      _filteredTransactions.addAll(_transactions);
      _selectedTransactions.clear();
      _showFilters = false;
    });
  }

  Future<void> _loadItemDetailsForTransaction(DataModel transaction) async {
    if (transaction.itemDetails == null &&
        _isDatabaseConnected &&
        _dbHelper != null) {
      try {
        final items = await _dbHelper!.getItemDetails(transaction.id);
        if (mounted) {
          setState(() {
            transaction.itemDetails = items;
          });
        }
      } catch (e) {
        _showNotification('Error loading item details: $e',
            type: NotificationType.error);
      }
    }
  }

  void _onSelectTransaction(DataModel transaction) {
    setState(() {
      if (_selectedTransactions.any((t) => t.id == transaction.id)) {
        _selectedTransactions.removeWhere((t) => t.id == transaction.id);
      } else {
        _selectedTransactions.add(transaction);
      }
    });
  }

  void _onSelectAll(bool? selected) {
    if (selected == true) {
      setState(() {
        _selectedTransactions.clear();
        _selectedTransactions.addAll(_filteredTransactions);
      });
    } else {
      setState(() {
        _selectedTransactions.clear();
      });
    }
  }

  void _openActionsBottomSheet() {
    if (_selectedTransactions.isEmpty) {
      _showNotification('No transactions selected.',
          type: NotificationType.warning);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => ActionBottomSheet(
        filteredData: _selectedTransactions,
        pdfPaths: List.filled(_selectedTransactions.length, ''),
        showSnackBar: _showNotification,
        setProcessing: ({required bool isProcessing, double? progress}) {
          setState(() {
            _isProcessing = isProcessing;
          });
        },
        dbPath: _dbPath,
        processWithDb: false,
      ),
    );
  }

  void _showQRSettingsDialog() {
    final xController = TextEditingController(text: _qrX?.toString() ?? '');
    final yController = TextEditingController(text: _qrY?.toString() ?? '');
    final dtrController = TextEditingController(text: _customDtrPath ?? '');
    final ticketController =
        TextEditingController(text: _customTicketPath ?? '');
    final taxInvoicesController =
        TextEditingController(text: _customTaxInvoicesPath ?? '');

    String selectedLayout = _qrLayout;
    String selectedPreset = _qrPositionPreset;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Iconsax.setting_2, color: _primaryColor),
              const SizedBox(width: 10),
              const Text('Application Settings'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Directory Paths',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: _neutral800)),
                const SizedBox(height: 8),
                TextField(
                  controller: dtrController,
                  decoration: const InputDecoration(
                      labelText: 'DTR APP Root Path',
                      hintText: r'e.g. C:\DTR APP or \\Server\Share',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ticketController,
                  decoration: const InputDecoration(
                      labelText: 'Ticket Root Path',
                      hintText: r'e.g. C:\FBtemp\Ticket',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: taxInvoicesController,
                  decoration: const InputDecoration(
                      labelText: 'Tax Invoices Export Path (QR PDFs)',
                      hintText: r'e.g. C:\TaxInvoices or \\Server\Share\TaxInvoices',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                Text('QR Code & Details Layout',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: _neutral800)),
                const SizedBox(height: 8),
                Text('Details Placement:',
                    style: TextStyle(
                        fontSize: 12,
                        color: _neutral600,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: selectedLayout,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'beside',
                      child: Text('Details Beside QR Code (Right Side)'),
                    ),
                    DropdownMenuItem(
                      value: 'below',
                      child: Text('Details Below QR Code (Bottom)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedLayout = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text('Page Position Preset:',
                    style: TextStyle(
                        fontSize: 12,
                        color: _neutral600,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: selectedPreset,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'bottom_right',
                      child: Text('Bottom Right (Default)'),
                    ),
                    DropdownMenuItem(
                      value: 'bottom_left',
                      child: Text('Bottom Left'),
                    ),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text('Custom Coordinates'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedPreset = val;
                      });
                    }
                  },
                ),
                if (selectedPreset == 'custom') ...[
                  const SizedBox(height: 16),
                  const Text('Enter custom coordinates (in points):',
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: xController,
                    decoration: const InputDecoration(
                        labelText: 'X Position',
                        hintText: 'e.g. 385',
                        border: OutlineInputBorder()),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: yController,
                    decoration: const InputDecoration(
                        labelText: 'Y Position',
                        hintText: 'e.g. 780',
                        border: OutlineInputBorder()),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
                const SizedBox(height: 24),
                Divider(color: _neutral200),
                const SizedBox(height: 8),
                Text('Database Settings',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: _neutral800)),
                const SizedBox(height: 8),
                Text('Current database path:',
                    style: TextStyle(fontSize: 12, color: _neutral500)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _neutral200),
                  ),
                  child: Text(
                    _dbPath,
                    style: TextStyle(
                      fontSize: 12,
                      color: _neutral700,
                      fontFamily: 'Roboto Mono',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _selectDatabase();
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        icon: Icon(Iconsax.folder_open, size: 16),
                        label: const Text('Change Database'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryColor,
                          side: BorderSide(color: _primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _resetDatabasePath();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      icon: Icon(Iconsax.refresh, size: 16, color: _errorColor),
                      label:
                          Text('Reset', style: TextStyle(color: _errorColor)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _errorColor,
                        side: BorderSide(color: _errorColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                await FileGenerator.saveCustomPaths(
                  qrX: -1,
                  qrY: -1,
                  qrLayout: 'beside',
                  qrPositionPreset: 'bottom_right',
                );
                await _loadSettings();
                if (context.mounted) {
                  Navigator.pop(context);
                  _showNotification(
                      'QR layout reset to default (Beside, Bottom Right)',
                      type: NotificationType.info);
                }
              },
              child:
                  const Text('Reset QR', style: TextStyle(color: _errorColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                final dtrPath = dtrController.text.trim();
                final ticketPath = ticketController.text.trim();
                final taxInvoicesPath = taxInvoicesController.text.trim();
                final qrX = selectedPreset == 'custom'
                    ? double.tryParse(xController.text)
                    : -1.0;
                final qrY = selectedPreset == 'custom'
                    ? double.tryParse(yController.text)
                    : -1.0;

                await FileGenerator.saveCustomPaths(
                  dtrAppPath: dtrPath,
                  ticketPath: ticketPath,
                  taxInvoicesPath: taxInvoicesPath,
                  qrX: qrX,
                  qrY: qrY,
                  qrLayout: selectedLayout,
                  qrPositionPreset: selectedPreset,
                );

                await _loadSettings();
                await FileGenerator.initAppDirectories();
                _loadInputPath();

                if (context.mounted) {
                  Navigator.pop(context);
                  _showNotification('Settings saved successfully',
                      type: NotificationType.success);
                }
              },
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotification(String message,
      {NotificationType type = NotificationType.info}) {
    if (!mounted) return;

    Color bgColor;
    IconData icon;

    switch (type) {
      case NotificationType.success:
        bgColor = _successColor;
        icon = Icons.check_circle;
        break;
      case NotificationType.error:
        bgColor = _errorColor;
        icon = Icons.error;
        break;
      case NotificationType.warning:
        bgColor = _warningColor;
        icon = Icons.warning;
        break;
      case NotificationType.info:
        bgColor = _primaryColor;
        icon = Icons.info;
        break;
    }

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: bgColor,
      behavior: SnackBarBehavior.fixed,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(_borderRadius)),
      ),
      duration: const Duration(seconds: 3),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title,
            style: const TextStyle(
                color: _errorColor, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: SelectableText(message,
              style: const TextStyle(fontFamily: 'Roboto Mono', fontSize: 13)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              _showNotification('Error copied to clipboard',
                  type: NotificationType.info);
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.data_usage, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TIMS Data Exporter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _neutral800,
                ),
              ),
              Text(
                'Enterprise Data Management',
                style: TextStyle(
                  fontSize: 11,
                  color: _neutral500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 1,
      surfaceTintColor: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      actions: [
        Container(
          decoration: BoxDecoration(
            color: _neutral100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Iconsax.setting_2,
                  color: (_qrX != null ||
                          _qrY != null ||
                          _customDtrPath != null ||
                          _customTicketPath != null)
                      ? _primaryColor
                      : _neutral600,
                  size: 20,
                ),
                onPressed: _showQRSettingsDialog,
                tooltip: 'QR Position Settings',
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  _showSearch ? Icons.close : Iconsax.search_normal_1,
                  color: _neutral600,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _clearSearch();
                  });
                },
                tooltip: 'Search',
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Iconsax.filter,
                  color: _showFilters ? _primaryColor : _neutral600,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                tooltip: 'Filters',
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Iconsax.refresh,
                  color: _neutral600,
                  size: 20,
                ),
                onPressed: _isLoading ? null : _loadPageData,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildSearchBar() {
    if (!_showSearch) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(_spacingM),
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border(
          bottom: BorderSide(color: _neutral200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_borderRadius),
                    border: Border.all(color: _neutral300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: _spacingM),
                      Icon(Iconsax.search_normal, color: _neutral400),
                      const SizedBox(width: _spacingS),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: _searchMode == SearchMode.mwNum
                                ? 'Search by Machine/Control Number...'
                                : 'Search by Control Code...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: _neutral400),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => _performSearch(),
                          style: TextStyle(
                            fontSize: 14,
                            color: _neutral700,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.close, size: 18, color: _neutral400),
                          onPressed: _clearSearch,
                        ),
                      const SizedBox(width: _spacingS),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _spacingM),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_borderRadius),
                  border: Border.all(color: _neutral300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SearchMode>(
                    value: _searchMode,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _searchMode = value;
                          _searchController.clear();
                          _performSearch();
                        });
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: SearchMode.mwNum,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: _spacingM),
                          child: Text('MwNum'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: SearchMode.controlCode,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: _spacingM),
                          child: Text('Control Code'),
                        ),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(_borderRadius),
                    icon: Icon(Iconsax.arrow_down_1,
                        color: _neutral400, size: 16),
                    dropdownColor: Colors.white,
                    elevation: 4,
                    style: TextStyle(
                      fontSize: 14,
                      color: _neutral700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_searchController.text.isNotEmpty &&
              _filteredTransactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: _spacingS),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: _spacingS, vertical: 6),
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Iconsax.search_normal_1,
                            size: 12, color: _primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          '${_filteredTransactions.length} results found',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearSearch,
                    style: TextButton.styleFrom(
                      foregroundColor: _neutral500,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.close, size: 14, color: _neutral500),
                        const SizedBox(width: 4),
                        Text(
                          'Clear search',
                          style: TextStyle(
                            fontSize: 12,
                            color: _neutral500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel() {
    if (!_showFilters) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(_spacingM),
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border(
          bottom: BorderSide(color: _neutral200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Iconsax.filter, color: _primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Advanced Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _neutral800,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _clearFilters,
                icon: Icon(Iconsax.close_circle, size: 16, color: _neutral500),
                label: Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 13,
                    color: _neutral500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _spacingL),

          // Date Range
          Text(
            'Date Range',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _neutral700,
            ),
          ),
          const SizedBox(height: _spacingS),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _startDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_borderRadiusSmall),
                      border: Border.all(color: _neutral300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Iconsax.calendar_1, size: 18, color: _neutral400),
                        const SizedBox(width: _spacingS),
                        Expanded(
                          child: Text(
                            _startDate != null
                                ? DateFormat('dd MMM yyyy').format(_startDate!)
                                : 'Start Date',
                            style: TextStyle(
                              color: _startDate != null
                                  ? _neutral700
                                  : _neutral400,
                              fontSize: 14,
                              fontWeight: _startDate != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (_startDate != null)
                          IconButton(
                            icon:
                                Icon(Icons.close, size: 14, color: _neutral400),
                            onPressed: () {
                              setState(() => _startDate = null);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _spacingM),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _neutral100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Iconsax.arrow_right_3, size: 16, color: _neutral400),
              ),
              const SizedBox(width: _spacingM),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: _startDate ?? DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _endDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_borderRadiusSmall),
                      border: Border.all(color: _neutral300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Iconsax.calendar_1, size: 18, color: _neutral400),
                        const SizedBox(width: _spacingS),
                        Expanded(
                          child: Text(
                            _endDate != null
                                ? DateFormat('dd MMM yyyy').format(_endDate!)
                                : 'End Date',
                            style: TextStyle(
                              color:
                                  _endDate != null ? _neutral700 : _neutral400,
                              fontSize: 14,
                              fontWeight: _endDate != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (_endDate != null)
                          IconButton(
                            icon:
                                Icon(Icons.close, size: 14, color: _neutral400),
                            onPressed: () {
                              setState(() => _endDate = null);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: _spacingL),

          // Amount Range
          Text(
            'Amount Range',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _neutral700,
            ),
          ),
          const SizedBox(height: _spacingS),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    border: Border.all(color: _neutral300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Minimum Amount',
                      prefixText: 'KES ',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                      labelStyle: TextStyle(
                        color: _neutral500,
                        fontSize: 13,
                      ),
                      prefixStyle: TextStyle(
                        color: _neutral700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 14,
                      color: _neutral700,
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: (value) {
                      _minAmount = double.tryParse(value) ?? 0;
                    },
                  ),
                ),
              ),
              const SizedBox(width: _spacingM),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _neutral100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Iconsax.arrow_right_3, size: 16, color: _neutral400),
              ),
              const SizedBox(width: _spacingM),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    border: Border.all(color: _neutral300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Maximum Amount',
                      prefixText: 'KES ',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                      labelStyle: TextStyle(
                        color: _neutral500,
                        fontSize: 13,
                      ),
                      prefixStyle: TextStyle(
                        color: _neutral700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 14,
                      color: _neutral700,
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: (value) {
                      _maxAmount = double.tryParse(value) ?? double.infinity;
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: _spacingXL),

          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _applyFilters,
              icon: Icon(Iconsax.filter_tick, size: 20),
              label: const Text(
                'Apply Filters',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_borderRadius),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardPage() {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: _spacingXL),
      child: Column(
        children: [
          // Summary Stats Row
          Padding(
            padding: const EdgeInsets.all(_spacingM),
            child: LayoutBuilder(builder: (context, constraints) {
              return Row(
                children: [
                  _buildStatCard(
                    'Total Revenue',
                    currencyFormat.format(_totalRevenue),
                    Iconsax.money_send,
                    [_primaryColor, _primaryLight],
                    constraints.maxWidth / 2 - 12,
                  ),
                  const SizedBox(width: _spacingM),
                  _buildStatCard(
                    'Total VAT',
                    currencyFormat.format(_totalVatAmount),
                    Iconsax.receipt_item,
                    [_secondaryColor, _accentColor],
                    constraints.maxWidth / 2 - 12,
                  ),
                ],
              );
            }),
          ),

          // Visualization Section
          if (_chartGroups.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: _spacingM),
              padding: const EdgeInsets.all(_spacingL),
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_borderRadius),
                border: Border.all(color: _neutral200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales Volume Trend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _neutral800,
                    ),
                  ),
                  const SizedBox(height: _spacingXL),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        barGroups: _chartGroups,
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) => Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('Day ${val.toInt() + 1}',
                                    style: TextStyle(
                                        fontSize: 10, color: _neutral500)),
                              ),
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 100000),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          _buildDatabaseCard(),
          _buildFileProcessingCard(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      List<Color> colors, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(_spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(_borderRadius),
        boxShadow: [
          BoxShadow(
              color: colors[0].withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 24),
          const SizedBox(height: _spacingM),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseCard() {
    return Container(
      margin: const EdgeInsets.all(_spacingM),
      padding: const EdgeInsets.all(_spacingL),
      decoration: BoxDecoration(
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(_borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(_borderRadius),
                    ),
                    child: Icon(Iconsax.document_text,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: _spacingM),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Database',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _neutral800,
                        ),
                      ),
                      const SizedBox(height: _spacingXS),
                      Text(
                        'Connection & Statistics',
                        style: TextStyle(
                          fontSize: 12,
                          color: _neutral500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: _spacingS, vertical: 6),
                decoration: BoxDecoration(
                  color: _isDatabaseConnected
                      ? _successColor.withValues(alpha: 0.1)
                      : _errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isDatabaseConnected
                        ? _successColor.withValues(alpha: 0.3)
                        : _errorColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _isDatabaseConnected ? _successColor : _errorColor,
                        boxShadow: [
                          BoxShadow(
                            color: (_isDatabaseConnected
                                    ? _successColor
                                    : _errorColor)
                                .withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isDatabaseConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            _isDatabaseConnected ? _successColor : _errorColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: _spacingXL),

          // Database Path
          Container(
            padding: const EdgeInsets.all(_spacingM),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(_borderRadiusSmall),
              border: Border.all(color: _neutral200),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _neutral100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Iconsax.folder, color: _neutral600, size: 20),
                ),
                const SizedBox(width: _spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Database Path',
                        style: TextStyle(
                          fontSize: 12,
                          color: _neutral500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dbPath,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _neutral700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _spacingM),
                ElevatedButton(
                  onPressed: _selectDatabase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor.withValues(alpha: 0.1),
                    foregroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: _spacingM, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: _spacingM),

          // Stats
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(_spacingM),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    border: Border.all(color: _neutral200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Iconsax.receipt_item,
                                color: _primaryColor, size: 18),
                          ),
                          const SizedBox(width: _spacingS),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_transactions.length}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _neutral800,
                                ),
                              ),
                              Text(
                                'Transactions',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _neutral500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_searchController.text.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _neutral100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_filteredTransactions.length} filtered',
                            style: TextStyle(
                              fontSize: 10,
                              color: _neutral600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _spacingM),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(_spacingM),
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    border: Border.all(color: _neutral200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Iconsax.document,
                                color: _accentColor, size: 18),
                          ),
                          const SizedBox(width: _spacingS),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_generatedFiles.length}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _neutral800,
                                ),
                              ),
                              Text(
                                'Generated Files',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _neutral500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_generatedFiles.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _neutral100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _generatedFiles.first.existsSync()
                                ? DateFormat('MMM dd').format(
                                    _generatedFiles.first.lastModifiedSync())
                                : 'N/A',
                            style: TextStyle(
                              fontSize: 10,
                              color: _neutral600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileProcessingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: _spacingM),
      padding: const EdgeInsets.all(_spacingL),
      decoration: BoxDecoration(
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(_borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_secondaryColor, _accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(_borderRadius),
                ),
                child: Icon(Iconsax.document_upload,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: _spacingM),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto Processing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _neutral800,
                    ),
                  ),
                  const SizedBox(height: _spacingXS),
                  Text(
                    'Automatic PDF Import',
                    style: TextStyle(
                      fontSize: 12,
                      color: _neutral500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: _spacingXL),

          // Status
          Container(
            padding: const EdgeInsets.all(_spacingM),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(_borderRadiusSmall),
              border: Border.all(color: _neutral200),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isProcessing
                          ? [
                              _warningColor,
                              Color.lerp(_warningColor, Colors.orange, 0.5)!
                            ]
                          : [
                              _successColor,
                              Color.lerp(_successColor, Colors.green, 0.5)!
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isProcessing ? _warningColor : _successColor)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isProcessing ? Iconsax.refresh : Iconsax.eye,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: _spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isProcessing
                            ? 'Processing Active'
                            : 'Watching for Files',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _neutral800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _inputPath.isNotEmpty
                            ? 'Directory: ${path.basename(_inputPath)}'
                            : 'Waiting for input path...',
                        style: TextStyle(
                          fontSize: 12,
                          color: _neutral500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: _spacingL),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickAndProcessPdfs,
              icon: const Icon(Iconsax.document_upload, size: 20),
              label: const Text(
                'Manually Process PDF(s)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _secondaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_borderRadius),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: _secondaryColor.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white70,
              ),
            ),
          ),

          if (_generatedFiles.isNotEmpty) ...[
            const SizedBox(height: _spacingL),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Files',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _neutral800,
                  ),
                ),
                TextButton(
                  onPressed: _loadGeneratedFiles,
                  style: TextButton.styleFrom(
                    foregroundColor: _primaryColor,
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.refresh, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Refresh',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: _spacingS),
            ..._generatedFiles.take(3).map((file) {
              return Container(
                margin: const EdgeInsets.only(bottom: _spacingS),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: _spacingS,
                    vertical: _spacingXS,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _neutral100,
                      borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    ),
                    child: Icon(Iconsax.document_text,
                        color: _neutral600, size: 20),
                  ),
                  title: Text(
                    path.basename(file.path),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _neutral700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    file.existsSync()
                        ? DateFormat('MMM dd, yyyy - HH:mm')
                            .format(file.lastModifiedSync())
                        : 'Modified: N/A',
                    style: TextStyle(
                      fontSize: 11,
                      color: _neutral500,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Iconsax.eye, size: 18, color: _primaryColor),
                    onPressed: () => _showFileContent(file),
                    style: IconButton.styleFrom(
                      backgroundColor: _primaryColor.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_searchController.text.isNotEmpty ||
        _startDate != null ||
        _endDate != null ||
        _minAmount > 0 ||
        (_limit != -1 && _filteredTransactions.length > _limit) ||
        (_totalPages <= 1 && _limit != -1)) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: _spacingM, vertical: _spacingS),
      padding: const EdgeInsets.all(_spacingM),
      decoration: BoxDecoration(
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(_borderRadius),
        border: Border.all(color: _neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Records per page selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Records per page:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _neutral600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: _spacingS),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(_borderRadiusSmall),
                  border: Border.all(color: _neutral300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _limit,
                    onChanged: (newValue) {
                      if (newValue != null) {
                        _changeLimit(newValue);
                      }
                    },
                    items: _limitOptions.map((value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: _spacingS),
                          child: Text(value == -1 ? 'All' : '$value'),
                        ),
                      );
                    }).toList(),
                    icon: Icon(Iconsax.arrow_down_1,
                        size: 16, color: _neutral500),
                    dropdownColor: Colors.white,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _neutral700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _spacingL),

          if (_limit != -1) ...[
            // Page Indicator
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: _spacingM, vertical: 10),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(_borderRadius),
                border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.document, size: 16, color: _primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: _spacingL),

            // Navigation Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // First Page
                IconButton(
                  onPressed: _currentPage > 0 ? _goToFirstPage : null,
                  icon: Icon(Iconsax.arrow_left_2, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: _currentPage > 0
                        ? _primaryColor.withValues(alpha: 0.1)
                        : _neutral100,
                    foregroundColor:
                        _currentPage > 0 ? _primaryColor : _neutral400,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    ),
                  ),
                  tooltip: 'First Page',
                ),
                const SizedBox(width: 8),

                // Previous Page
                IconButton(
                  onPressed: _currentPage > 0 ? _goToPreviousPage : null,
                  icon: Icon(Iconsax.arrow_left, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: _currentPage > 0
                        ? _primaryColor.withValues(alpha: 0.1)
                        : _neutral100,
                    foregroundColor:
                        _currentPage > 0 ? _primaryColor : _neutral400,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    ),
                  ),
                  tooltip: 'Previous Page',
                ),
                const SizedBox(width: _spacingM),

                // Page Input
                Container(
                  width: 80,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    border: Border.all(color: _neutral300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _pageController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '1',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      hintStyle: TextStyle(color: _neutral400),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: _neutral700,
                      fontWeight: FontWeight.w500,
                    ),
                    onSubmitted: (value) {
                      final page = int.tryParse(value) ?? 1;
                      if (page >= 1 &&
                          page <= _totalPages &&
                          page != _currentPage + 1) {
                        _currentPage = page - 1;
                        _loadPageData();
                      } else {
                        _pageController.text = (_currentPage + 1).toString();
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _spacingS),
                  child: Text(
                    'of $_totalPages',
                    style: TextStyle(
                      fontSize: 13,
                      color: _neutral600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Next Page
                IconButton(
                  onPressed:
                      _currentPage < _totalPages - 1 ? _goToNextPage : null,
                  icon: Icon(Iconsax.arrow_right, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: _currentPage < _totalPages - 1
                        ? _primaryColor.withValues(alpha: 0.1)
                        : _neutral100,
                    foregroundColor: _currentPage < _totalPages - 1
                        ? _primaryColor
                        : _neutral400,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    ),
                  ),
                  tooltip: 'Next Page',
                ),
                const SizedBox(width: 8),

                // Last Page
                IconButton(
                  onPressed:
                      _currentPage < _totalPages - 1 ? _goToLastPage : null,
                  icon: Icon(Iconsax.arrow_right_2, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: _currentPage < _totalPages - 1
                        ? _primaryColor.withValues(alpha: 0.1)
                        : _neutral100,
                    foregroundColor: _currentPage < _totalPages - 1
                        ? _primaryColor
                        : _neutral400,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    ),
                  ),
                  tooltip: 'Last Page',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: _spacingM, vertical: _spacingXL),
      padding: const EdgeInsets.all(_spacingXL),
      decoration: BoxDecoration(
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(_borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _neutral100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isDatabaseConnected ? Iconsax.receipt_search : Iconsax.document,
              size: 48,
              color: _neutral400,
            ),
          ),
          const SizedBox(height: _spacingXL),
          Text(
            _isDatabaseConnected
                ? 'No Transactions Found'
                : 'Database Not Connected',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _neutral800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _spacingM),
          Text(
            _isDatabaseConnected
                ? 'Try adjusting your search or filters to find transactions.\nYou can also check your database connection.'
                : 'Please select a database file to begin viewing transactions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _neutral600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: _spacingXL),
          if (!_isDatabaseConnected)
            ElevatedButton.icon(
              onPressed: _selectDatabase,
              icon: const Icon(Iconsax.folder_open, size: 20),
              label: const Text(
                'Select Database File',
                style: TextStyle(fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: _spacingXL, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_borderRadius),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
            ),
          if (_isDatabaseConnected && _transactions.isEmpty)
            ElevatedButton.icon(
              onPressed: _loadPageData,
              icon: const Icon(Iconsax.refresh, size: 20),
              label: const Text(
                'Load Transactions',
                style: TextStyle(fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: _spacingXL, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_borderRadius),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: _spacingXL * 2),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: _spacingM),
          Text(
            'Loading transactions...',
            style: TextStyle(
              color: _neutral600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsContent() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(
            horizontal: _spacingM,
            vertical: _spacingM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transactions (${_filteredTransactions.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _neutral800,
                ),
              ),
              if (_selectedTransactions.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _openActionsBottomSheet,
                  icon: const Icon(Iconsax.flash_1, size: 16),
                  label: Text('Actions (${_selectedTransactions.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: _spacingM,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (_searchController.text.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _clearSearch,
                  icon: const Icon(Iconsax.close_circle, size: 16),
                  label: const Text(
                    'Clear Search',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _neutral600,
                    side: BorderSide(color: _neutral300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_borderRadiusSmall),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: _spacingM,
                      vertical: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // In HomeScreen's _buildTransactionsContent method:
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _spacingM),
          child: TransactionTable(
            transactions: _filteredTransactions,
            selectedTransactions: _selectedTransactions,
            onSelectTransaction: _onSelectTransaction,
            onSelectAll: _onSelectAll,
            onExpandTransaction: _loadItemDetailsForTransaction,
            showPagination: false,
            dbHelper: _dbHelper, // Add this line
          ),
        ),
        const SizedBox(height: _spacingXL),
      ],
    );
  }

  PreferredSizeWidget _buildReportsAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_secondaryColor, _accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Iconsax.document, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _neutral800,
                ),
              ),
              Text(
                'Data Analysis & Insights',
                style: TextStyle(
                  fontSize: 11,
                  color: _neutral500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 1,
      surfaceTintColor: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      actions: [
        IconButton(
          icon: Icon(
            Iconsax.refresh,
            color: _neutral600,
            size: 20,
          ),
          onPressed: () {
            _showNotification('Refreshing reports...',
                type: NotificationType.info);
          },
          tooltip: 'Refresh Reports',
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  PreferredSizeWidget _buildDashboardAppBar() {
    return AppBar(
      title: Text(
        'Dashboard',
        style: TextStyle(fontWeight: FontWeight.w700, color: _neutral800),
      ),
      backgroundColor: Colors.white,
      elevation: 1,
      actions: [
        IconButton(
          icon: Icon(Iconsax.notification, color: _neutral600),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Iconsax.user, color: _neutral600),
          onPressed: () {},
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildTransactionsPage() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildFiltersPanel(),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                if (_filteredTransactions.isNotEmpty)
                  _buildPaginationControls(),
                if (_isLoading && _filteredTransactions.isEmpty)
                  _buildLoadingState()
                else if (_filteredTransactions.isEmpty)
                  _buildEmptyState()
                else
                  _buildTransactionsContent(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dbHelper == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> pages = [
      _buildDashboardPage(),
      _buildTransactionsPage(),
      ReportsScreen(dbHelper: _dbHelper!),
    ];

    final List<PreferredSizeWidget> appBars = [
      _buildDashboardAppBar(),
      _buildAppBar(),
      _buildReportsAppBar(),
    ];

    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: appBars[_selectedIndex],
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: _primaryColor,
        unselectedItemColor: _neutral500,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Iconsax.category),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.transaction_minus),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.document),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

enum SearchMode {
  mwNum,
  controlCode,
}

enum NotificationType {
  success,
  error,
  warning,
  info,
}
