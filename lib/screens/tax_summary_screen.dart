import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tims_data_exporter/data/database_helper.dart';
import 'package:iconsax/iconsax.dart';

class DailyTaxSummary {
  final DateTime date;
  final double totalVatA;
  final double totalVatB;
  final double totalVatC;
  final double totalVatD;
  final double totalVatE;
  final double dailyTotalVat;

  DailyTaxSummary({
    required this.date,
    this.totalVatA = 0.0,
    this.totalVatB = 0.0,
    this.totalVatC = 0.0,
    this.totalVatD = 0.0,
    this.totalVatE = 0.0,
    this.dailyTotalVat = 0.0,
  });
}

class TaxSummaryScreen extends StatefulWidget {
  final DatabaseHelper dbHelper;
  const TaxSummaryScreen({super.key, required this.dbHelper});

  @override
  State<TaxSummaryScreen> createState() => _TaxSummaryScreenState();
}

class _TaxSummaryScreenState extends State<TaxSummaryScreen> {
  List<DailyTaxSummary> _taxData = [];
  bool _isLoading = true;

  // Theme Colors
  static const Color _primaryColor = Color(0xFFF59E0B);
  static const Color _surfaceColor = Color(0xFFF8FAFC);
  static const Color _neutral800 = Color(0xFF1E293B);
  static const Color _neutral500 = Color(0xFF64748B);
  static const Color _neutral200 = Color(0xFFE2E8F0);
  static const double _spacingM = 16.0;

  @override
  void initState() {
    super.initState();
    _loadTaxData();
  }

  Future<void> _loadTaxData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await widget.dbHelper.getDailyTaxSummary();
      final summaries = data.map((item) {
        return DailyTaxSummary(
          date: DateTime.parse(item['summary_date']),
          totalVatA: (item['total_vat_a'] as num?)?.toDouble() ?? 0.0,
          totalVatB: (item['total_vat_b'] as num?)?.toDouble() ?? 0.0,
          totalVatC: (item['total_vat_c'] as num?)?.toDouble() ?? 0.0,
          totalVatD: (item['total_vat_d'] as num?)?.toDouble() ?? 0.0,
          totalVatE: (item['total_vat_e'] as num?)?.toDouble() ?? 0.0,
          dailyTotalVat: (item['daily_total_vat'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      setState(() {
        _taxData = summaries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tax summary: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        title: const Text('Tax Summaries'),
        backgroundColor: Colors.white,
        elevation: 1,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.black.withValues(alpha: 0.05),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _taxData.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.all(_spacingM),
                  children: [
                    _buildDataTableCard(),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.money_remove, size: 60, color: _neutral500),
          const SizedBox(height: 20),
          Text(
            'No Tax Data Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _neutral800),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no transactions with VAT amounts in the database.',
            style: TextStyle(color: _neutral500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDataTableCard() {
    final currencyFormat = NumberFormat.currency(locale: 'en_KE', symbol: '', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _neutral200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(_spacingM),
            child: Text(
              'Daily VAT Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _neutral800),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_primaryColor.withValues(alpha: 0.05)),
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('VAT A (16%)'), numeric: true),
                DataColumn(label: Text('VAT B (8%)'), numeric: true),
                DataColumn(label: Text('VAT C (0%)'), numeric: true),
                DataColumn(label: Text('VAT D (Exempt)'), numeric: true),
                DataColumn(label: Text('VAT E'), numeric: true),
                DataColumn(label: Text('Total VAT'), numeric: true),
              ],
              rows: _taxData.map((summary) {
                return DataRow(
                  cells: [
                    DataCell(Text(dateFormat.format(summary.date))),
                    DataCell(Text(currencyFormat.format(summary.totalVatA))),
                    DataCell(Text(currencyFormat.format(summary.totalVatB))),
                    DataCell(Text(currencyFormat.format(summary.totalVatC))),
                    DataCell(Text(currencyFormat.format(summary.totalVatD))),
                    DataCell(Text(currencyFormat.format(summary.totalVatE))),
                    DataCell(Text(
                      currencyFormat.format(summary.dailyTotalVat),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}