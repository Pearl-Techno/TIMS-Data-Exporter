import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tims_data_exporter/data/database_helper.dart';
import 'package:iconsax/iconsax.dart';

class TopBuyer {
  final String buyerPin;
  final double totalSpent;
  final int transactionCount;

  TopBuyer({
    required this.buyerPin,
    required this.totalSpent,
    required this.transactionCount,
  });
}

class CustomerInsightsScreen extends StatefulWidget {
  final DatabaseHelper dbHelper;
  const CustomerInsightsScreen({super.key, required this.dbHelper});

  @override
  State<CustomerInsightsScreen> createState() => _CustomerInsightsScreenState();
}

class _CustomerInsightsScreenState extends State<CustomerInsightsScreen> {
  List<TopBuyer> _topBuyers = [];
  bool _isLoading = true;

  // Theme Colors from HomeScreen
  static const Color _accentColor = Color(0xFF8B5CF6);
  static const Color _surfaceColor = Color(0xFFF8FAFC);
  static const Color _neutral800 = Color(0xFF1E293B);
  static const Color _neutral500 = Color(0xFF64748B);
  static const Color _neutral200 = Color(0xFFE2E8F0);
  static const double _spacingM = 16.0;

  @override
  void initState() {
    super.initState();
    _loadTopBuyers();
  }

  Future<void> _loadTopBuyers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await widget.dbHelper.getTopBuyers(limit: 50);
      final buyers = data.map((item) {
        return TopBuyer(
          buyerPin: item['BuyerPIN'] as String,
          totalSpent: (item['total_spent'] as num?)?.toDouble() ?? 0.0,
          transactionCount: item['transaction_count'] as int? ?? 0,
        );
      }).toList();

      setState(() {
        _topBuyers = buyers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customer insights: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        title: const Text('Top Buyers'),
        backgroundColor: Colors.white,
        elevation: 1,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.black.withValues(alpha: 0.05),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _topBuyers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(_spacingM),
                  itemCount: _topBuyers.length,
                  itemBuilder: (context, index) {
                    final buyer = _topBuyers[index];
                    return _buildBuyerCard(buyer, index + 1);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.profile_2user, size: 60, color: _neutral500),
          const SizedBox(height: 20),
          Text(
            'No Customer Data Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _neutral800),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no transactions with Buyer PINs in the database.',
            style: TextStyle(color: _neutral500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerCard(TopBuyer buyer, int rank) {
    final currencyFormat = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: _spacingM),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _neutral200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_spacingM),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: _spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    buyer.buyerPin,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _neutral800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${buyer.transactionCount} transactions',
                    style: TextStyle(
                      fontSize: 13,
                      color: _neutral500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _spacingM),
            Text(
              currencyFormat.format(buyer.totalSpent),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}