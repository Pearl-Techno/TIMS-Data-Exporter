import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:tims_data_exporter/models/data_model.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:tims_data_exporter/widgets/item_details_table.dart';
import 'package:tims_data_exporter/widgets/file_generator.dart';
import 'package:tims_data_exporter/screens/home_screen.dart';
import 'package:tims_data_exporter/widgets/csv_comparison_dialog.dart';
import 'package:tims_data_exporter/data/database_helper.dart';

class TransactionTable extends StatefulWidget {
  final List<DataModel> transactions;
  final List<DataModel> selectedTransactions;
  final Function(DataModel)? onSelectTransaction;
  final Future<void> Function(DataModel transaction)? onExpandTransaction;
  final Function(bool?)? onSelectAll;
  final bool showCheckboxColumn;
  final bool showPagination;
  final int? currentPage;
  final int? totalPages;
  final VoidCallback? onNextPage;
  final VoidCallback? onPreviousPage;
  final Function(int)? onPageChanged;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onFilterDuplicateTsNum;
  final bool isDuplicateFilterActive;
  final String? searchQuery;
  final DatabaseHelper? dbHelper; // Add dbHelper parameter

  const TransactionTable({
    super.key,
    required this.transactions,
    required this.selectedTransactions,
    this.onSelectTransaction,
    this.onExpandTransaction,
    this.onSelectAll,
    this.showCheckboxColumn = true,
    this.showPagination = false,
    this.currentPage,
    this.totalPages,
    this.onNextPage,
    this.onPreviousPage,
    this.onPageChanged,
    this.onSearchChanged,
    this.onFilterDuplicateTsNum,
    this.isDuplicateFilterActive = false,
    this.searchQuery,
    this.dbHelper, // Add dbHelper parameter
  });

  @override
  State<TransactionTable> createState() => _TransactionTableState();
}

class _TransactionTableState extends State<TransactionTable> {
  final Set<int> _expandedRows = {};
  final ScrollController _horizontalScrollController = ScrollController();
  final TextEditingController _pageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _startTsController = TextEditingController();
  final TextEditingController _endTsController = TextEditingController();

  bool _isLoadingExpansion = false;
  List<DataModel> _filteredTransactions = [];
  bool _localIsDuplicateFilterActive = false;
  final Set<int> _individualActionsLoading = {};
  DateTimeRange? _dateRange;

  // Pagination state
  int _rowsPerPage = 50;
  final List<int> _rowsPerPageOptions = [
    10,
    25,
    50,
    100,
    200,
    500,
    1000,
    2000,
    -1
  ];
  int _localCurrentPage = 1;

  // Modern Color Palette
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1D4ED8);
  static const Color _success = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _error = Color(0xFFEF4444);
  static const Color _info = Color(0xFF3B82F6);

  // Neutral Colors
  static const Color _surface = Colors.white;
  static const Color _surfaceVariant = Color(0xFFF3F4F6);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _textTertiary = Color(0xFF9CA3AF);

  // Spacing
  static const double _spacingXs = 4.0;
  static const double _spacingSm = 8.0;
  static const double _spacingMd = 16.0;
  static const double _spacingLg = 24.0;

  // Border Radius
  static const double _radiusSm = 6.0;
  static const double _radiusMd = 8.0;
  static const double _radiusLg = 12.0;

  // Get current page data
  List<DataModel> get _currentPageTransactions {
    final bool isAdvancedFilterActive = _dateRange != null ||
        _startTsController.text.isNotEmpty ||
        _endTsController.text.isNotEmpty ||
        _searchController.text.isNotEmpty;
    if (!widget.showPagination ||
        _rowsPerPage == -1 ||
        isAdvancedFilterActive) {
      return _filteredTransactions;
    }

    final startIndex = (_localCurrentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    if (startIndex >= _filteredTransactions.length) return [];
    if (endIndex >= _filteredTransactions.length) {
      return _filteredTransactions.sublist(startIndex);
    }
    return _filteredTransactions.sublist(startIndex, endIndex);
  }

  int get _totalPages => _rowsPerPage == -1
      ? 1
      : (_filteredTransactions.length / _rowsPerPage).ceil();

  @override
  void initState() {
    super.initState();
    _pageController.text = (widget.currentPage ?? 1).toString();
    _searchController.text = widget.searchQuery ?? '';
    _localIsDuplicateFilterActive = widget.isDuplicateFilterActive;
    _localCurrentPage = widget.currentPage ?? 1;
    _applyFilters();
  }

  @override
  void didUpdateWidget(TransactionTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPage != oldWidget.currentPage &&
        widget.currentPage != null) {
      _localCurrentPage = widget.currentPage!;
      _pageController.text = _localCurrentPage.toString();
    }
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery ?? '';
    }
    if (widget.transactions != oldWidget.transactions) {
      _applyFilters();
    }
    if (widget.isDuplicateFilterActive != oldWidget.isDuplicateFilterActive) {
      _localIsDuplicateFilterActive = widget.isDuplicateFilterActive;
      _applyFilters();
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _pageController.dispose();
    _searchController.dispose();
    _startTsController.dispose();
    _endTsController.dispose();
    super.dispose();
  }

  Future<void> _applyFilters() async {
    final query = _searchController.text.toLowerCase();
    final startRange = _startTsController.text.trim();
    final endRange = _endTsController.text.trim();
    final startNum = int.tryParse(startRange.replaceAll(RegExp(r'[^0-9]'), ''));
    final endNum = int.tryParse(endRange.replaceAll(RegExp(r'[^0-9]'), ''));

    final bool isAdvancedFilterActive =
        _dateRange != null || startNum != null || endNum != null;

    List<DataModel> result;

    if (isAdvancedFilterActive && widget.dbHelper != null) {
      setState(() => _isLoadingExpansion = true);
      try {
        // Fetch all transactions from the database for the selected date range
        // to ensure we bypass pagination and show all records for the period.
        result = await widget.dbHelper!.getFilteredData(
          startDate: _dateRange?.start,
          endDate: _dateRange?.end,
        );
      } catch (e) {
        result = widget.transactions;
      } finally {
        if (mounted) setState(() => _isLoadingExpansion = false);
      }
    } else {
      result = widget.transactions;
    }

    // Apply search filter locally
    if (query.isNotEmpty) {
      result = result
          .where((t) =>
              t.tsNum.toLowerCase().contains(query) ||
              (t.buyerPIN?.toLowerCase().contains(query) ?? false) ||
              (t.totalAmount?.toString().contains(query) ?? false) ||
              (t.controlCode?.toLowerCase().contains(query) ?? false) ||
              (t.mwNum?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    // Apply duplicate filter locally
    if (_localIsDuplicateFilterActive) {
      final counts = <String, int>{};
      for (var t in result) {
        counts[t.tsNum] = (counts[t.tsNum] ?? 0) + 1;
      }
      result = result.where((t) => (counts[t.tsNum] ?? 0) > 1).toList();
    }

    // Apply TS-Num range locally
    if (startNum != null || endNum != null) {
      result = result.where((t) {
        final tsNumOnly =
            int.tryParse(t.tsNum.replaceAll(RegExp(r'[^0-9]'), ''));
        if (tsNumOnly == null) return false;
        if (startNum != null && tsNumOnly < startNum) return false;
        if (endNum != null && tsNumOnly > endNum) return false;
        return true;
      }).toList();
    }

    if (mounted) {
      setState(() {
        _filteredTransactions = result;
        _localCurrentPage = 1;
        _pageController.text = '1';
      });
      if (widget.onPageChanged != null && widget.showPagination) {
        widget.onPageChanged!(1);
      }
    }
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() {
      _localCurrentPage = page;
      _pageController.text = page.toString();
    });
    if (widget.onPageChanged != null && widget.showPagination) {
      widget.onPageChanged!(page);
    }
  }

  void _nextPage() {
    if (_localCurrentPage < _totalPages) {
      _goToPage(_localCurrentPage + 1);
      if (widget.onNextPage != null && widget.showPagination) {
        widget.onNextPage!();
      }
    }
  }

  void _previousPage() {
    if (_localCurrentPage > 1) {
      _goToPage(_localCurrentPage - 1);
      if (widget.onPreviousPage != null && widget.showPagination) {
        widget.onPreviousPage!();
      }
    }
  }

  void _showStatusSnackBar(String message,
      {NotificationType type = NotificationType.info}) {
    if (!mounted) return;

    if (type == NotificationType.error) {
      debugPrint('Credit Note Generation Error: $message');
    }

    Color backgroundColor;
    switch (type) {
      case NotificationType.success:
        backgroundColor = _success;
        break;
      case NotificationType.error:
        backgroundColor = _error;
        break;
      case NotificationType.warning:
        backgroundColor = _warning;
        break;
      case NotificationType.info:
        backgroundColor = _info;
    }
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    });
  }

  Future<void> _generateCreditNotes() async {
    try {
      for (final transaction in widget.selectedTransactions) {
        if (!mounted) return;
        final transactionWithDetails =
            await _ensureItemDetailsAreLoaded(transaction);
        if (!mounted) return;
        await FileGenerator.generateCreditNote(
          context: context,
          item: transactionWithDetails,
          showSnackBar: _showStatusSnackBar,
          getOutputDirectory: FileGenerator.getOutputDirectory,
          pdfPath: '',
          processWithDb: false,
        );
      }
    } catch (e, s) {
      _showErrorDialog(
        'Bulk Generation Error',
        'An unexpected error occurred during bulk generation:\n$e',
      );
      debugPrint('--- UNCAUGHT ERROR in _generateCreditNotes loop ---');
      debugPrint('Exception: $e\nStack Trace: $s');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title,
            style: const TextStyle(color: _error, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: SelectableText(message,
              style: const TextStyle(fontFamily: 'Roboto Mono', fontSize: 13)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              _showStatusSnackBar(
                'Error copied to clipboard',
                type: NotificationType.info,
              );
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

  Future<DataModel> _ensureItemDetailsAreLoaded(DataModel transaction) async {
    if (transaction.itemDetails?.isNotEmpty ?? false) {
      return transaction;
    }

    if (widget.onExpandTransaction != null) {
      await widget.onExpandTransaction!(transaction);

      try {
        return _filteredTransactions.firstWhere((t) => t.id == transaction.id);
      } catch (e) {
        try {
          return widget.transactions.firstWhere((t) => t.id == transaction.id);
        } catch (e2) {
          debugPrint(
              "Could not find transaction ${transaction.id} after loading details.");
          return transaction;
        }
      }
    }

    return transaction;
  }

  Future<void> _generateSingleCreditNote(DataModel transaction) async {
    setState(() => _individualActionsLoading.add(transaction.id));
    try {
      final transactionWithDetails =
          await _ensureItemDetailsAreLoaded(transaction);
      if (!mounted) return;
      await FileGenerator.generateCreditNote(
        context: context,
        item: transactionWithDetails,
        showSnackBar: _showStatusSnackBar,
        getOutputDirectory: FileGenerator.getOutputDirectory,
        pdfPath: '',
        processWithDb: false,
      );
    } catch (e, s) {
      if (!mounted) return;
      _showErrorDialog(
        'Credit Note Generation Failed',
        'Error generating credit note for ${transaction.tsNum}:\n$e',
      );
      debugPrint(
          '--- UNCAUGHT ERROR in _generateSingleCreditNote for ${transaction.tsNum} ---');
      debugPrint('Exception: $e\nStack Trace: $s');
    } finally {
      if (mounted) {
        setState(() => _individualActionsLoading.remove(transaction.id));
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_filteredTransactions.isEmpty) {
      _showStatusSnackBar('No data to export', type: NotificationType.warning);
      return;
    }

    final outputDirs = await FileGenerator.getOutputDirectory();
    final String timestamp =
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final String fileName = 'Transactions_Export_$timestamp.csv';
    final String filePath = '${outputDirs['textFiles']}/$fileName';

    final dataToExport = widget.selectedTransactions.isNotEmpty
        ? widget.selectedTransactions
        : _currentPageTransactions;

    try {
      await FileGenerator.exportToExcel(
        data: dataToExport,
        filePath: filePath,
      );
      _showStatusSnackBar('Exported successfully to $fileName',
          type: NotificationType.success);
    } catch (e) {
      _showErrorDialog('Export Failed', e.toString());
    }
  }

  void _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Advanced Filters'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Date Range'),
                subtitle: Text(_dateRange == null
                    ? 'Not selected'
                    : '${DateFormat('dd/MM/yyyy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}'),
                trailing: const Icon(Iconsax.calendar),
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: _dateRange,
                  );
                  if (picked != null) {
                    setState(() => _dateRange = picked);
                  }
                },
              ),
              const Divider(),
              TextField(
                controller: _startTsController,
                decoration: const InputDecoration(
                    labelText: 'Start TS-Num (Numeric part)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _endTsController,
                decoration: const InputDecoration(
                    labelText: 'End TS-Num (Numeric part)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _dateRange = null;
                _startTsController.clear();
                _endTsController.clear();
              });
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showCSVComparisonDialog() async {
    await showDialog(
      context: context,
      builder: (context) => CSVComparisonDialog(
        dbHelper: widget.dbHelper, // Pass dbHelper instead of transactions
        monthFilter: _dateRange?.start,
      ),
    );
  }

  Widget _buildIndividualActions(DataModel transaction) {
    final isLoading = _individualActionsLoading.contains(transaction.id);

    return SizedBox(
      width: 80,
      height: 30,
      child: isLoading
          ? const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              ),
            )
          : TextButton.icon(
              onPressed: () => _generateSingleCreditNote(transaction),
              icon: const Icon(Iconsax.document_text_1, size: 16),
              label: const Text('Credit'),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                backgroundColor: _primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(
                    horizontal: _spacingSm, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radiusSm),
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTableHeader(),
        const SizedBox(height: _spacingMd),
        _buildSearchAndFilterBar(),
        const SizedBox(height: _spacingSm),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(_radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 64,
              ),
              child: _buildDataTable(),
            ),
          ),
        ),
        if (widget.showPagination) _buildPagination(),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _spacingXs),
      child: Row(
        children: [
          if (widget.showCheckboxColumn)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: _spacingSm,
                vertical: _spacingXs,
              ),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(_radiusLg),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.tick_circle, size: 16, color: _primary),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.selectedTransactions.length} selected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            ),

          if (widget.selectedTransactions.isNotEmpty) ...[
            const SizedBox(width: _spacingSm),
            TextButton.icon(
              onPressed: _generateCreditNotes,
              icon: const Icon(Iconsax.document_text, size: 16),
              label: const Text('Credit Note'),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                backgroundColor: _primary.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(
                    horizontal: _spacingMd, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radiusLg),
                ),
              ),
            ),
          ],

          const SizedBox(width: _spacingSm),
          TextButton.icon(
            onPressed: _exportToExcel,
            icon: const Icon(Iconsax.export, size: 16),
            label: const Text('Excel'),
            style: TextButton.styleFrom(
              foregroundColor: _success,
              backgroundColor: _success.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(
                  horizontal: _spacingMd, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radiusLg),
              ),
            ),
          ),

          const Spacer(),

          // Rows per page selector
          if (_dateRange == null &&
              _startTsController.text.isEmpty &&
              _endTsController.text.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: _spacingSm),
              decoration: BoxDecoration(
                color: _surfaceVariant,
                borderRadius: BorderRadius.circular(_radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.row_vertical,
                      size: 16, color: _textSecondary),
                  const SizedBox(width: 4),
                  DropdownButton<int>(
                    value: _rowsPerPage,
                    underline: const SizedBox(),
                    icon: const Icon(Iconsax.arrow_down_1, size: 16),
                    style: TextStyle(
                      fontSize: 13,
                      color: _textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _rowsPerPage = value;
                          _localCurrentPage = 1;
                        });
                        if (widget.onPageChanged != null &&
                            widget.showPagination) {
                          widget.onPageChanged!(1);
                        }
                      }
                    },
                    items: _rowsPerPageOptions.map((value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value == -1 ? 'All' : '$value / page'),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _spacingSm),
          ],

          // Table Info
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: _spacingSm,
              vertical: _spacingXs,
            ),
            decoration: BoxDecoration(
              color: _surfaceVariant,
              borderRadius: BorderRadius.circular(_radiusLg),
            ),
            child: Text(
              '${_filteredTransactions.length} transactions',
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(width: _spacingSm),

          // Scroll Controls
          IconButton(
            icon: Icon(Iconsax.arrow_left, size: 18, color: _textSecondary),
            onPressed: () {
              _horizontalScrollController.animateTo(
                _horizontalScrollController.offset - 300,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: _surfaceVariant,
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radiusSm),
              ),
            ),
          ),
          const SizedBox(width: _spacingXs),
          IconButton(
            icon: Icon(Iconsax.arrow_right, size: 18, color: _textSecondary),
            onPressed: () {
              _horizontalScrollController.animateTo(
                _horizontalScrollController.offset + 300,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: _surfaceVariant,
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radiusSm),
              ),
            ),
          ),

          const SizedBox(width: _spacingSm),

          // CSV Comparison Button
          IconButton(
            onPressed: _showCSVComparisonDialog,
            icon: Icon(Iconsax.status_up, size: 20, color: _textSecondary),
            tooltip: 'Compare with CSV',
            style: IconButton.styleFrom(
              backgroundColor: _surfaceVariant,
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radiusMd),
              ),
            ),
          ),

          const SizedBox(width: _spacingSm),

          IconButton(
            onPressed: _showFilterDialog,
            icon: Icon(Iconsax.setting_4, size: 20, color: _textSecondary),
            tooltip: 'Advanced Filters',
            style: IconButton.styleFrom(
              backgroundColor: _surfaceVariant,
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radiusMd),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _spacingXs),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _applyFilters();
                if (widget.onSearchChanged != null) {
                  widget.onSearchChanged!(value);
                }
              },
              decoration: InputDecoration(
                hintText: 'Search by TS-Num, Buyer PIN, etc.',
                prefixIcon: const Icon(Iconsax.search_normal_1,
                    size: 18, color: _textSecondary),
                filled: true,
                fillColor: _surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_radiusMd),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 0, horizontal: _spacingMd),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14, color: _textPrimary),
            ),
          ),
          const SizedBox(width: _spacingSm),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _localIsDuplicateFilterActive = !_localIsDuplicateFilterActive;
              });
              _applyFilters();
              if (widget.onFilterDuplicateTsNum != null) {
                widget.onFilterDuplicateTsNum!();
              }
            },
            icon: Icon(
              _localIsDuplicateFilterActive
                  ? Iconsax.filter_remove
                  : Iconsax.filter,
              size: 16,
            ),
            label: const Text('Duplicates'),
            style: TextButton.styleFrom(
              foregroundColor:
                  _localIsDuplicateFilterActive ? _primary : _textSecondary,
              backgroundColor: _localIsDuplicateFilterActive
                  ? _primary.withValues(alpha: 0.1)
                  : _surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radiusMd),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: _spacingMd, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    final displayTransactions = widget.showPagination
        ? _currentPageTransactions
        : _filteredTransactions;

    return DataTable(
      columns: _buildColumns(),
      rows: _buildRows(displayTransactions),
      headingRowColor: WidgetStateProperty.all(_surfaceVariant),
      headingTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: _textPrimary,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
      showCheckboxColumn:
          widget.onSelectTransaction != null && widget.showCheckboxColumn,
      checkboxHorizontalMargin: _spacingMd,
      columnSpacing: 24,
      horizontalMargin: _spacingMd,
      dividerThickness: 0,
      dataRowMinHeight: 56,
      dataRowMaxHeight: double.infinity,
      headingRowHeight: 48,
      border: TableBorder(
        horizontalInside: BorderSide(
          color: _border,
          width: 1,
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    final columns = <DataColumn>[];

    if (widget.onSelectTransaction != null && widget.showCheckboxColumn) {
      columns.add(DataColumn(
        label: Checkbox(
          value: _filteredTransactions.isNotEmpty &&
              widget.selectedTransactions.length ==
                  _filteredTransactions.length,
          tristate: widget.selectedTransactions.isNotEmpty &&
              widget.selectedTransactions.length < _filteredTransactions.length,
          onChanged: widget.onSelectAll,
          activeColor: _primary,
          checkColor: Colors.white,
          side: BorderSide(color: _border),
        ),
      ));
    }

    columns.addAll([
      DataColumn(
        label: _buildSortableHeader('TS-NUM', Iconsax.hashtag),
        tooltip: 'Transaction Number',
      ),
      DataColumn(
        label: _buildSortableHeader('BUYER', Iconsax.profile_2user),
        tooltip: 'Buyer Tax Identification Number',
      ),
      DataColumn(
        label: _buildSortableHeader('DATE', Iconsax.calendar),
        tooltip: 'Transaction Date',
      ),
      DataColumn(
        label: _buildSortableHeader('MW-NUM', Iconsax.code),
        tooltip: 'Machine/Control Number',
      ),
      DataColumn(
        label: _buildSortableHeader('REL. MW', Iconsax.code_1),
        tooltip: 'Relevant Machine/Control Number',
      ),
      DataColumn(
        label: _buildSortableHeader('TOTAL', Iconsax.money),
        tooltip: 'Total Amount',
        numeric: true,
      ),
      DataColumn(
        label: _buildSortableHeader('VAT', Iconsax.receipt_item),
        tooltip: 'Total VAT Amount',
        numeric: true,
      ),
      DataColumn(
        label: _buildSortableHeader('CONTROL', Iconsax.key),
        tooltip: 'Transaction Control Code',
      ),
      DataColumn(
        label: _buildSortableHeader('ITEMS', Iconsax.box),
        tooltip: 'Number of Items',
        numeric: true,
      ),
      const DataColumn(
        label: Text(''),
      ),
      const DataColumn(
        label: Text('ACTIONS'),
      ),
    ]);

    return columns;
  }

  Widget _buildSortableHeader(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _textSecondary),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  List<DataRow> _buildRows(List<DataModel> transactions) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'KES ',
      decimalDigits: 2,
    );

    final List<DataRow> rows = [];

    for (var i = 0; i < transactions.length; i++) {
      final transaction = transactions[i];
      final isSelected =
          widget.selectedTransactions.any((t) => t.id == transaction.id);
      final isExpanded = _expandedRows.contains(transaction.id);

      rows.add(DataRow(
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return _primary.withValues(alpha: 0.05);
          }
          return i.isEven ? _surface : _surfaceVariant.withValues(alpha: 0.3);
        }),
        selected: isSelected,
        onSelectChanged: widget.onSelectTransaction != null
            ? (selected) {
                if (selected != null) {
                  widget.onSelectTransaction!(transaction);
                }
              }
            : null,
        cells: [
          if (widget.onSelectTransaction != null && widget.showCheckboxColumn)
            DataCell(
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  if (value != null) {
                    widget.onSelectTransaction!(transaction);
                  }
                },
                activeColor: _primary,
                checkColor: Colors.white,
                side: BorderSide(color: _border),
              ),
            ),
          DataCell(
            _buildCellContent(
              child: Text(
                transaction.tsNum,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              tooltip: transaction.tsNum,
            ),
          ),
          DataCell(
            _buildCellContent(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: transaction.buyerPIN?.isNotEmpty == true
                      ? _surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(_radiusSm),
                ),
                child: Text(
                  transaction.buyerPIN ?? '—',
                  style: TextStyle(
                    color: transaction.buyerPIN?.isNotEmpty == true
                        ? _textPrimary
                        : _textTertiary,
                    fontStyle: transaction.buyerPIN?.isNotEmpty == true
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                ),
              ),
              tooltip: transaction.buyerPIN ?? 'No buyer PIN',
            ),
          ),
          DataCell(
            _buildCellContent(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.calendar, size: 12, color: _textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    transaction.date != null
                        ? dateFormat.format(transaction.date!)
                        : '—',
                  ),
                ],
              ),
              tooltip: transaction.date != null
                  ? dateFormat.format(transaction.date!)
                  : 'No date',
            ),
          ),
          DataCell(
            _buildCellContent(
              child: transaction.mwNum != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(_radiusLg),
                      ),
                      child: Text(
                        transaction.mwNum!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : Text('—', style: TextStyle(color: _textTertiary)),
              tooltip: transaction.mwNum ?? 'No machine number',
            ),
          ),
          DataCell(
            _buildCellContent(
              child: transaction.relevantMwNum != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(_radiusLg),
                      ),
                      child: Text(
                        transaction.relevantMwNum!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : Text('—', style: TextStyle(color: _textTertiary)),
              tooltip:
                  transaction.relevantMwNum ?? 'No relevant machine number',
            ),
          ),
          DataCell(
            _buildCellContent(
              child: Text(
                currencyFormat.format(transaction.totalAmount ?? 0),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _primaryDark,
                ),
              ),
              tooltip: currencyFormat.format(transaction.totalAmount ?? 0),
            ),
          ),
          DataCell(
            _buildCellContent(
              child: Text(
                currencyFormat.format(transaction.totalVat),
                style: TextStyle(
                  color: _textSecondary,
                ),
              ),
              tooltip: currencyFormat.format(transaction.totalVat),
            ),
          ),
          DataCell(
            _buildCellContent(
              child: Tooltip(
                message: transaction.controlCode ?? 'No control code',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: transaction.controlCode != null
                        ? _info.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(_radiusSm),
                  ),
                  child: Text(
                    transaction.controlCode != null
                        ? '${transaction.controlCode!.substring(0, 8)}...'
                        : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: transaction.controlCode != null
                          ? _info
                          : _textTertiary,
                      fontFamily: 'RobotoMono',
                    ),
                  ),
                ),
              ),
              tooltip: transaction.controlCode ?? 'No control code',
            ),
          ),
          DataCell(
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (transaction.itemCount) > 0
                      ? _success.withValues(alpha: 0.1)
                      : _surfaceVariant,
                  borderRadius: BorderRadius.circular(_radiusLg),
                  border: Border.all(
                    color: (transaction.itemCount) > 0
                        ? _success.withValues(alpha: 0.2)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  '${transaction.itemCount}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color:
                        (transaction.itemCount) > 0 ? _success : _textSecondary,
                  ),
                ),
              ),
            ),
          ),
          DataCell(
            _buildExpandButton(transaction, isExpanded),
          ),
          DataCell(
            _buildIndividualActions(transaction),
          ),
        ],
      ));

      if (isExpanded) {
        rows.add(_buildExpandedRow(transaction, i));
      }
    }

    return rows;
  }

  Widget _buildCellContent({required Widget child, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: child,
    );
  }

  Widget _buildExpandButton(DataModel transaction, bool isExpanded) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: IconButton(
        splashRadius: 24,
        icon: AnimatedRotation(
          duration: const Duration(milliseconds: 200),
          turns: isExpanded ? 0.5 : 0.0,
          child: Icon(
            Iconsax.arrow_down_1,
            size: 18,
            color: isExpanded ? _primary : _textSecondary,
          ),
        ),
        onPressed: () => _handleExpandToggle(transaction),
        style: IconButton.styleFrom(
          backgroundColor:
              isExpanded ? _primary.withValues(alpha: 0.1) : _surfaceVariant,
          padding: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusSm),
          ),
        ),
      ),
    );
  }

  Future<void> _handleExpandToggle(DataModel transaction) async {
    final isCurrentlyExpanded = _expandedRows.contains(transaction.id);

    if (isCurrentlyExpanded) {
      setState(() => _expandedRows.remove(transaction.id));
    } else {
      if (transaction.itemDetails == null &&
          widget.onExpandTransaction != null) {
        setState(() => _isLoadingExpansion = true);
        try {
          await widget.onExpandTransaction!(transaction);
        } catch (e) {
          _showErrorDialog('Error Loading Items', e.toString());
        } finally {
          if (mounted) {
            _applyFilters();
            setState(() => _isLoadingExpansion = false);
          }
        }
      }

      if (mounted) setState(() => _expandedRows.add(transaction.id));
    }
  }

  DataRow _buildExpandedRow(DataModel transaction, int index) {
    return DataRow(
      color: WidgetStateProperty.all(_surfaceVariant.withValues(alpha: 0.3)),
      cells: [
        if (widget.onSelectTransaction != null && widget.showCheckboxColumn)
          DataCell(Container(color: _surfaceVariant)),
        DataCell(
          Container(
            padding: const EdgeInsets.all(_spacingLg),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: _border),
                bottom: BorderSide(color: _border),
              ),
            ),
            child: _buildExpandedContent(transaction),
          ),
        ),
        ...List.generate(
          _buildColumns().length - (widget.showCheckboxColumn ? 2 : 1),
          (_) => DataCell(Container(color: _surfaceVariant)),
        ),
      ],
    );
  }

  Widget _buildExpandedContent(DataModel transaction) {
    if (_isLoadingExpansion) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(_spacingLg),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (transaction.itemDetails?.isEmpty ?? true) {
      return Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(_spacingLg),
              decoration: BoxDecoration(
                color: _surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.box_remove, size: 32, color: _textTertiary),
            ),
            const SizedBox(height: _spacingMd),
            Text(
              'No item details available',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: _spacingXs),
            Text(
              'This transaction has no associated items',
              style: TextStyle(color: _textTertiary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(_radiusLg),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.box, size: 14, color: _primary),
                  const SizedBox(width: 6),
                  Text(
                    'Items (${transaction.itemDetails!.length})',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(_radiusLg),
              ),
              child: Text(
                'Total: KES ${transaction.totalAmount?.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: _spacingMd),
        ItemDetailsTable(
          items: transaction.itemDetails!,
          showRowNumbers: true,
          evenRowColor: _surface,
          oddRowColor: _surfaceVariant,
        ),
      ],
    );
  }

  Widget _buildPagination() {
    if (_rowsPerPage == -1 ||
        _dateRange != null ||
        _startTsController.text.isNotEmpty ||
        _endTsController.text.isNotEmpty ||
        _searchController.text.isNotEmpty ||
        (_totalPages <= 1 && _filteredTransactions.length <= _rowsPerPage)) {
      return const SizedBox();
    }

    // Calculate displayed range
    final startIndex = (_localCurrentPage - 1) * _rowsPerPage + 1;
    final endIndex =
        (_localCurrentPage * _rowsPerPage) > _filteredTransactions.length
            ? _filteredTransactions.length
            : _localCurrentPage * _rowsPerPage;

    return Container(
      margin: const EdgeInsets.only(top: _spacingMd),
      padding: const EdgeInsets.all(_spacingMd),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(_radiusLg),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // Range info
          Container(
            margin: const EdgeInsets.only(bottom: _spacingSm),
            child: Text(
              'Showing ${startIndex.toInt()} - ${endIndex.toInt()} of ${_filteredTransactions.length} transactions',
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous Button
              IconButton(
                onPressed: _localCurrentPage > 1 ? _previousPage : null,
                icon: Icon(Iconsax.arrow_left, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: _localCurrentPage > 1
                      ? _primary.withValues(alpha: 0.1)
                      : _surfaceVariant,
                  foregroundColor:
                      _localCurrentPage > 1 ? _primary : _textTertiary,
                  padding: const EdgeInsets.all(10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_radiusSm),
                  ),
                ),
              ),

              const SizedBox(width: _spacingMd),

              // Page Info
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: _spacingMd, vertical: 8),
                decoration: BoxDecoration(
                  color: _surfaceVariant,
                  borderRadius: BorderRadius.circular(_radiusMd),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _pageController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: _localCurrentPage.toString(),
                          hintStyle:
                              TextStyle(color: _textTertiary, fontSize: 14),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        onSubmitted: (value) {
                          final page = int.tryParse(value);
                          if (page != null &&
                              page >= 1 &&
                              page <= _totalPages) {
                            _goToPage(page);
                          } else {
                            _pageController.text = _localCurrentPage.toString();
                          }
                        },
                      ),
                    ),
                    Text(
                      ' of $_totalPages',
                      style: TextStyle(color: _textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: _spacingMd),

              // Next Button
              IconButton(
                onPressed: _localCurrentPage < _totalPages ? _nextPage : null,
                icon: Icon(Iconsax.arrow_right, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: _localCurrentPage < _totalPages
                      ? _primary.withValues(alpha: 0.1)
                      : _surfaceVariant,
                  foregroundColor: _localCurrentPage < _totalPages
                      ? _primary
                      : _textTertiary,
                  padding: const EdgeInsets.all(10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_radiusSm),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
