import 'package:flutter/material.dart';
import 'package:tims_data_exporter/models/item_detail.dart';

class ItemDetailsTable extends StatelessWidget {
  final List<ItemDetail> items;
  final bool showRowNumbers;
  final Color? headerColor;
  final Color? evenRowColor;
  final Color? oddRowColor;

  const ItemDetailsTable({
    super.key,
    required this.items,
    this.showRowNumbers = true,
    this.headerColor,
    this.evenRowColor,
    this.oddRowColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final borderColor = theme.dividerColor;
    
    final screenWidth = MediaQuery.of(context).size.width;

    // Use a threshold to decide which layout to use.
    // 800 is a reasonable breakpoint for switching from a compact list to a full table.
    if (screenWidth < 800) {
      return CompactItemDetailsTable(
        items: items,
        showRowNumbers: showRowNumbers,
      );
    } else {
      // This is the existing DataTable implementation
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columnSpacing: 24.0,
              horizontalMargin: 16.0,
              dataRowMinHeight: 52.0,
              dataRowMaxHeight: 52.0,
              headingRowHeight: 56.0,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: borderColor.withValues(alpha: 0.2),
                ),
                bottom: BorderSide(
                  color: borderColor.withValues(alpha: 0.3),
                ),
              ),
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.8),
                fontSize: 12,
                letterSpacing: 0.5,
              ),
              dataTextStyle: TextStyle(
                fontSize: 13,
                color: textColor.withValues(alpha: 0.9),
              ),
              columns: [
                if (showRowNumbers)
                  DataColumn(
                    label: _buildColumnHeader('#'),
                    numeric: true,
                  ),
                DataColumn(
                  label: _buildColumnHeader('Description'),
                  tooltip: 'Item Description',
                ),
                DataColumn(
                  label: _buildColumnHeader('Item Code'),
                  tooltip: 'Item Code/SKU',
                ),
                DataColumn(
                  label: _buildColumnHeader('Dept'),
                  numeric: true,
                  tooltip: 'Department Code',
                ),
                DataColumn(
                  label: _buildColumnHeader('Qty'),
                  numeric: true,
                  tooltip: 'Quantity',
                ),
                DataColumn(
                  label: _buildColumnHeader('Unit Price'),
                  numeric: true,
                  tooltip: 'Price per unit (KES)',
                ),
                DataColumn(
                  label: _buildColumnHeader('Amount'),
                  numeric: true,
                  tooltip: 'Line total amount (KES)',
                ),
                DataColumn(
                  label: _buildColumnHeader('Discount'),
                  numeric: true,
                  tooltip: 'Discount amount (KES)',
                ),
                DataColumn(
                  label: _buildColumnHeader('Disc %'),
                  numeric: true,
                  tooltip: 'Discount percentage',
                ),
                DataColumn(
                  label: _buildColumnHeader('Tax'),
                  tooltip: 'Tax code',
                ),
                DataColumn(
                  label: _buildColumnHeader('Net Amt'),
                  numeric: true,
                  tooltip: 'Net amount after discount (KES)',
                ),
              ],
              rows: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;

                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return theme.colorScheme.primary
                            .withValues(alpha: 0.08);
                      }
                      return index % 2 == 0
                          ? (evenRowColor ?? Colors.grey[50])
                          : (oddRowColor ?? Colors.white);
                    },
                  ),
                  cells: [
                    if (showRowNumbers)
                      DataCell(
                        Center(
                          child: Text(
                            (index + 1).toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Tooltip(
                          message: item.description,
                          child: Text(
                            item.description,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      _buildCellContent(
                        value: item.itemCode,
                        emptyText: 'N/A',
                        isNumeric: false,
                        maxWidth: 100,
                      ),
                    ),
                    DataCell(
                      Center(
                        child: _buildCellContent(
                          value: item.deptCode?.toString(),
                          emptyText: '-',
                          isNumeric: true,
                        ),
                      ),
                    ),
                    DataCell(
                      Center(
                        child: _buildCellContent(
                          value: item.formattedQuantity,
                          isNumeric: true,
                        ),
                      ),
                    ),
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildCellContent(
                          value:
                              item.formattedUnitPrice.replaceAll('KES ', ''),
                          isNumeric: true,
                          isCurrency: true,
                        ),
                      ),
                    ),
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildCellContent(
                          value: item.formattedItemAmount
                              .replaceAll('KES ', ''),
                          isNumeric: true,
                          isCurrency: true,
                        ),
                      ),
                    ),
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildCellContent(
                          value: item.formattedDiscountAmount
                              .replaceAll('KES ', ''),
                          isNumeric: true,
                          isCurrency: true,
                          isDiscount: item.discountAmount != null &&
                              item.discountAmount! > 0,
                        ),
                      ),
                    ),
                    DataCell(
                      Center(
                        child: _buildCellContent(
                          value: item.formattedDiscountRate
                              .replaceAll('%', ''),
                          isNumeric: true,
                          isPercentage: true,
                          isDiscount: item.discountRate != null &&
                              item.discountRate! > 0,
                        ),
                      ),
                    ),
                    DataCell(
                      Center(
                        child: Tooltip(
                          message: item.taxCodeDescription,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getTaxCodeColor(item.taxCode)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getTaxCodeColor(item.taxCode)
                                    .withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              item.taxCode?.toString() ?? 'N/A',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getTaxCodeColor(item.taxCode),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'KES ${item.netAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildColumnHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCellContent({
    required String? value,
    String emptyText = '',
    bool isNumeric = false,
    bool isCurrency = false,
    bool isPercentage = false,
    bool isDiscount = false,
    double maxWidth = double.infinity,
  }) {
    final displayText = value?.isNotEmpty == true ? value! : emptyText;
    
    Widget textWidget = Text(
      isCurrency && displayText != emptyText
          ? 'KES $displayText'
          : isPercentage && displayText != emptyText
          ? '$displayText%'
          : displayText,
      textAlign: isNumeric ? TextAlign.center : TextAlign.left,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: isNumeric ? FontWeight.w500 : FontWeight.normal,
        color: isDiscount 
            ? Colors.green[700]
            : displayText == emptyText
            ? Colors.grey[500]
            : null,
        fontFamily: isNumeric ? 'RobotoMono' : null,
      ),
    );
    
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Tooltip(
        message: displayText,
        child: textWidget,
      ),
    );
  }

  Color _getTaxCodeColor(int? taxCode) {
    switch (taxCode) {
      case 0: // No Tax
        return Colors.grey[600]!;
      case 1: // Standard VAT
        return Colors.blue[700]!;
      case 2: // Zero Rated
        return Colors.green[600]!;
      case 3: // Exempt
        return Colors.orange[600]!;
      case 4: // Reduced Rate
        return Colors.purple[600]!;
      case 5: // Out of Scope
        return Colors.red[600]!;
      default:
        return Colors.grey[400]!;
    }
  }
}

// Alternative compact version for mobile/small screens
class CompactItemDetailsTable extends StatelessWidget {
  final List<ItemDetail> items;
  final bool showRowNumbers;

  const CompactItemDetailsTable({
    super.key,
    required this.items,
    this.showRowNumbers = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: index % 2 == 0 ? Colors.white : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    if (showRowNumbers)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (index + 1).toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.description,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'KES ${item.netAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Details grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  childAspectRatio: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 4,
                  children: [
                    _buildDetailItem('Item Code', item.itemCode ?? 'N/A'),
                    _buildDetailItem('Dept', item.deptCode?.toString() ?? '-'),
                    _buildDetailItem('Qty', item.formattedQuantity),
                    _buildDetailItem('Unit Price', item.formattedUnitPrice),
                    _buildDetailItem('Amount', item.formattedItemAmount),
                    if (item.hasDiscount)
                      _buildDetailItem(
                        'Discount',
                        '${item.formattedDiscountAmount} (${item.formattedDiscountRate})',
                        isDiscount: true,
                      ), // Fixed: Added missing comma
                    _buildDetailItem('Tax Code', item.taxCodeDescription),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isDiscount = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDiscount ? Colors.green[700] : Colors.grey[800],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}