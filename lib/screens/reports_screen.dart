import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:tims_data_exporter/data/database_helper.dart';
import 'package:tims_data_exporter/screens/sales_analytics_screen.dart';
import 'package:tims_data_exporter/screens/customer_insights_screen.dart';
import 'package:tims_data_exporter/screens/tax_summary_screen.dart';

class ReportsScreen extends StatelessWidget {
  final DatabaseHelper dbHelper;
  const ReportsScreen({super.key, required this.dbHelper});

  // Theme Colors from HomeScreen
  static const Color _primaryColor = Color(0xFF4F46E5);
  static const Color _secondaryColor = Color(0xFF06B6D4);
  static const Color _accentColor = Color(0xFF8B5CF6);
  static const Color _cardBgColor = Colors.white;
  static const Color _surfaceColor = Color(0xFFF8FAFC);
  static const Color _neutral800 = Color(0xFF1E293B);
  static const Color _neutral500 = Color(0xFF64748B);
  static const double _borderRadius = 16.0;
  static const double _spacingM = 16.0;
  static const double _spacingL = 24.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surfaceColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(_spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReportCard(
              context,
              icon: Iconsax.chart_1,
              title: 'Sales Analytics',
              subtitle: 'View sales trends and performance.',
              color: _primaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SalesAnalyticsScreen(dbHelper: dbHelper),
                  ),
                );
              },
            ),
            const SizedBox(height: _spacingM),
            _buildReportCard(
              context,
              icon: Iconsax.box,
              title: 'Inventory Reports',
              subtitle: 'Track item stock and movement.',
              color: _secondaryColor,
            ),
            const SizedBox(height: _spacingM),
            _buildReportCard(
              context,
              icon: Iconsax.profile_2user,
              title: 'Customer Insights',
              subtitle: 'Analyze customer purchasing behavior.',
              color: _accentColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CustomerInsightsScreen(dbHelper: dbHelper),
                  ),
                );
              },
            ),
            const SizedBox(height: _spacingM),
            _buildReportCard(
              context,
              icon: Iconsax.money_recive,
              title: 'Tax Summaries',
              subtitle: 'Generate VAT and other tax reports.',
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TaxSummaryScreen(dbHelper: dbHelper),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      VoidCallback? onTap}) {
    return Card(
      elevation: 0,
      color: _cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () {
          // Placeholder for navigation or action
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                    content: Text('$title report is not yet implemented.'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                margin: const EdgeInsets.all(_spacingM)));
        },
        borderRadius: BorderRadius.circular(_borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(_spacingL),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: _spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _neutral800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: _neutral500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Iconsax.arrow_right_3, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}