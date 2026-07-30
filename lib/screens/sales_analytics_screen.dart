import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:tims_data_exporter/data/database_helper.dart';
import 'package:iconsax/iconsax.dart';

class DailySales {
  final DateTime date;
  final double totalSales;
  DailySales({required this.date, required this.totalSales});
}

class SalesAnalyticsScreen extends StatefulWidget {
  final DatabaseHelper dbHelper;
  const SalesAnalyticsScreen({super.key, required this.dbHelper});

  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen> {
  List<DailySales> _salesData = [];
  bool _isLoading = true;
  double _maxSales = 0;

  // Theme Colors from HomeScreen
  static const Color _primaryColor = Color(0xFF4F46E5);
  static const Color _surfaceColor = Color(0xFFF8FAFC);
  static const Color _neutral800 = Color(0xFF1E293B);
  static const Color _neutral500 = Color(0xFF64748B);
  static const Color _neutral200 = Color(0xFFE2E8F0);
  static const double _spacingM = 16.0;

  @override
  void initState() {
    super.initState();
    _loadSalesData();
  }

  Future<void> _loadSalesData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await widget.dbHelper.getDailySales();
      final sales = data.map((item) {
        return DailySales(
          date: DateTime.parse(item['sale_date']),
          totalSales: (item['total_sales'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      double maxVal = 0;
      if (sales.isNotEmpty) {
        maxVal = sales.map((s) => s.totalSales).reduce((a, b) => a > b ? a : b);
      }

      setState(() {
        _salesData = sales;
        _maxSales = maxVal;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final snackBar =
            SnackBar(content: Text('Error loading sales data: $e'));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        title: const Text('Sales Analytics'),
        backgroundColor: Colors.white,
        elevation: 1,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.black.withValues(alpha: 0.05),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _salesData.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.all(_spacingM),
                  children: [
                    _buildChartCard(),
                    const SizedBox(height: _spacingM),
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
          Icon(Iconsax.chart_fail, size: 60, color: _neutral500),
          const SizedBox(height: 20),
          Text(
            'No Sales Data Found',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: _neutral800),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no transactions with dates in the database.',
            style: TextStyle(color: _neutral500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _neutral200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Sales Volume',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _neutral800),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  maxY: _maxSales * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final day = _salesData[group.x.toInt()];
                        return BarTooltipItem(
                          '${DateFormat('MMM d').format(day.date)}\n',
                          const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          children: <TextSpan>[
                            TextSpan(
                              text: NumberFormat.currency(
                                      locale: 'en_KE', symbol: 'KES ')
                                  .format(day.totalSales),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= _salesData.length) {
                            return const SizedBox();
                          }
                          // Show fewer labels to avoid clutter
                          if (index % (_salesData.length > 10 ? 3 : 1) != 0) {
                            return const SizedBox();
                          }
                          final text = DateFormat('d MMM')
                              .format(_salesData[index].date);
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(text,
                                style: TextStyle(
                                    color: _neutral500, fontSize: 10)),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value >= _maxSales * 1.2) {
                            return const SizedBox();
                          }
                          final text = NumberFormat.compact().format(value);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(text,
                                style:
                                    TextStyle(color: _neutral500, fontSize: 10),
                                textAlign: TextAlign.left),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(color: _neutral200, strokeWidth: 1);
                    },
                  ),
                  barGroups: _salesData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final sales = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: sales.totalSales,
                          color: _primaryColor,
                          width: 12,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTableCard() {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

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
              'Daily Breakdown',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _neutral800),
            ),
          ),
          DataTable(
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Total Sales'), numeric: true),
            ],
            rows: _salesData.map((sales) {
              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dateFormat.format(sales.date),
                          style: TextStyle(
                              fontWeight: FontWeight.w500, color: _neutral800),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      currencyFormat.format(sales.totalSales),
                      style: TextStyle(
                          fontWeight: FontWeight.w500, color: _neutral800),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
