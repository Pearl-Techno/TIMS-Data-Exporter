import 'dart:math';
import 'package:flutter/foundation.dart';

class ItemDetail {
  final int id;
  final int trId;
  final int? rowType;
  final String description;
  String? itemCode; // Changed to non-final to allow modification in constructor
  final int? deptCode;
  double quantity;
  double unitPrice;
  double itemAmount;
  double? discountAmount;
  double? discountRate;
  final int? taxCode;

  ItemDetail({
    required this.id,
    required this.trId,
    this.rowType,
    required this.description,
    this.itemCode,
    this.deptCode,
    required this.quantity,
    required this.unitPrice,
    required this.itemAmount,
    this.discountAmount,
    this.discountRate,
    this.taxCode,
  }) {
    // Convert negative values to positive automatically
    quantity = quantity.abs();
    unitPrice = unitPrice.abs();
    itemAmount = itemAmount.abs();
    discountAmount = discountAmount?.abs();
    discountRate = discountRate?.abs();
  }

  factory ItemDetail.fromJson(Map<String, dynamic> json) {
    // Parse numeric values with null safety
    final idValue = json['Id'] as int? ?? 0;
    final trIdValue = json['TrId'] as int? ?? 0;
    final rowTypeValue = json['RowType'] as int?;

    // Parse quantity - handle both int and double
    double quantityValue = 0.0;
    if (json['Quantity'] != null) {
      if (json['Quantity'] is int) {
        quantityValue = (json['Quantity'] as int).toDouble();
      } else if (json['Quantity'] is double) {
        quantityValue = json['Quantity'] as double;
      } else if (json['Quantity'] is String) {
        quantityValue = double.tryParse(json['Quantity'] as String) ?? 0.0;
      }
    }

    // Parse unit price
    double unitPriceValue = 0.0;
    if (json['UnitPrice'] != null) {
      if (json['UnitPrice'] is num) {
        unitPriceValue = (json['UnitPrice'] as num).toDouble();
      } else if (json['UnitPrice'] is String) {
        unitPriceValue = double.tryParse(json['UnitPrice'] as String) ?? 0.0;
      }
    }

    // Parse item amount
    double itemAmountValue = 0.0;
    if (json['ItemAmount'] != null) {
      if (json['ItemAmount'] is num) {
        itemAmountValue = (json['ItemAmount'] as num).toDouble();
      } else if (json['ItemAmount'] is String) {
        itemAmountValue = double.tryParse(json['ItemAmount'] as String) ?? 0.0;
      }
    }

    // Parse optional fields
    double? discountAmountValue;
    if (json['DiscountAmount'] != null) {
      if (json['DiscountAmount'] is num) {
        discountAmountValue = (json['DiscountAmount'] as num).toDouble();
      } else if (json['DiscountAmount'] is String) {
        discountAmountValue = double.tryParse(json['DiscountAmount'] as String);
      }
    }

    double? discountRateValue;
    if (json['DiscountRate'] != null) {
      if (json['DiscountRate'] is num) {
        discountRateValue = (json['DiscountRate'] as num).toDouble();
      } else if (json['DiscountRate'] is String) {
        discountRateValue = double.tryParse(json['DiscountRate'] as String);
      }
    }

    // Parse item code - handle any type
    String? itemCodeValue;
    if (json['ItemCode'] != null) {
      itemCodeValue = json['ItemCode'].toString();
    }

    // Parse dept code - handle both int and string
    int? deptCodeValue;
    if (json['DeptCode'] != null) {
      if (json['DeptCode'] is int) {
        deptCodeValue = json['DeptCode'] as int;
      } else if (json['DeptCode'] is String) {
        deptCodeValue = int.tryParse(json['DeptCode'] as String);
      }
    }

    // Parse tax code - handle both int and string
    int? taxCodeValue;
    if (json['TaxCode'] != null) {
      if (json['TaxCode'] is int) {
        taxCodeValue = json['TaxCode'] as int;
      } else if (json['TaxCode'] is String) {
        taxCodeValue = int.tryParse(json['TaxCode'] as String);
      }
    }

    return ItemDetail(
      id: idValue,
      trId: trIdValue,
      rowType: rowTypeValue,
      description: json['Description']?.toString() ?? '',
      itemCode: itemCodeValue,
      deptCode: deptCodeValue,
      quantity: quantityValue.abs(),
      unitPrice: unitPriceValue.abs(),
      itemAmount: itemAmountValue.abs(),
      discountAmount: discountAmountValue?.abs(),
      discountRate: discountRateValue?.abs(),
      taxCode: taxCodeValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'Id': id,
        'TrId': trId,
        'RowType': rowType,
        'Description': description,
        'ItemCode': itemCode,
        'DeptCode': deptCode,
        'Quantity': quantity,
        'UnitPrice': unitPrice,
        'ItemAmount': itemAmount,
        'DiscountAmount': discountAmount,
        'DiscountRate': discountRate,
        'TaxCode': taxCode,
      };

  void roundAmounts({int precision = 2}) {
    final factor = pow(10, precision).toDouble();

    quantity = (quantity * factor).round() / factor;
    unitPrice = (unitPrice * factor).round() / factor;
    itemAmount = (itemAmount * factor).round() / factor;

    if (discountAmount != null) {
      discountAmount = (discountAmount! * factor).round() / factor;
    }

    if (discountRate != null) {
      discountRate = (discountRate! * factor).round() / factor;
    }
  }

  void validate() {
    if (id <= 0) {
      throw FormatException('Item ID must be positive.');
    }

    if (trId <= 0) {
      throw FormatException('Transaction ID must be positive.');
    }

    if (description.isEmpty) {
      throw FormatException('Description cannot be empty.');
    }

    if (quantity <= 0) {
      throw FormatException('Quantity must be greater than 0.');
    }

    if (unitPrice <= 0) {
      throw FormatException('Unit price must be greater than 0.');
    }

    if (itemAmount <= 0) {
      throw FormatException('Item amount must be greater than 0.');
    }

    if (discountRate != null && (discountRate! < 0 || discountRate! > 100)) {
      throw FormatException('Discount rate must be between 0 and 100.');
    }

    // Validate calculated values match
    final calculatedAmount = quantity * unitPrice;
    if ((itemAmount - calculatedAmount).abs() > 0.01) {
      if (kDebugMode) {
        print(
            'Warning: Item amount ($itemAmount) does not match calculated amount ($calculatedAmount)');
      }
    }
  }

  void ensurePositiveAmounts() {
    // Convert all numeric values to positive
    quantity = quantity.abs();
    unitPrice = unitPrice.abs();
    itemAmount = itemAmount.abs();

    if (discountAmount != null) {
      discountAmount = discountAmount!.abs();
    }

    if (discountRate != null) {
      discountRate = discountRate!.abs();
      // Cap discount rate at 100%
      if (discountRate! > 100) {
        discountRate = 100.0;
      }
    }
  }

  // ======== COMPUTED PROPERTIES ========

  // Calculate net amount after discount
  double get netAmount {
    return itemAmount - (discountAmount ?? 0);
  }

  // Calculate unit price after discount
  double get discountedUnitPrice {
    if (quantity <= 0) return unitPrice;
    return netAmount / quantity;
  }

  // Get discount percentage based on actual discount
  double get actualDiscountPercentage {
    if (itemAmount <= 0 || discountAmount == null || discountAmount! <= 0) {
      return 0;
    }
    return (discountAmount! / itemAmount * 100);
  }

  // Check if there's any discount
  bool get hasDiscount {
    return (discountAmount != null && discountAmount! > 0) ||
        (discountRate != null && discountRate! > 0);
  }

  // Get row type description
  String get rowTypeDescription {
    switch (rowType) {
      case 0:
        return 'Item';
      case 1:
        return 'Discount';
      case 2:
        return 'Tax';
      case 3:
        return 'Service Charge';
      case 4:
        return 'Shipping';
      case 5:
        return 'Fee';
      default:
        return 'Other';
    }
  }

  // Get tax code description
  String get taxCodeDescription {
    switch (taxCode) {
      case 0:
        return 'No Tax';
      case 1:
        return 'Standard VAT';
      case 2:
        return 'Zero Rated';
      case 3:
        return 'Exempt';
      case 4:
        return 'Reduced Rate';
      case 5:
        return 'Out of Scope';
      default:
        return 'Unknown';
    }
  }

  // Calculate tax amount if applicable
  double get taxAmount {
    // This depends on your tax calculation logic
    // You might need to adjust this based on actual tax rates
    if (taxCode == 1) {
      // Standard VAT
      // Assuming 16% VAT - adjust as needed
      return netAmount * 0.16;
    } else if (taxCode == 4) {
      // Reduced Rate
      // Assuming 8% reduced rate - adjust as needed
      return netAmount * 0.08;
    }
    return 0;
  }

  // Get total amount including tax
  double get totalAmount {
    return netAmount + taxAmount;
  }

  // Check if item has a valid item code
  bool get hasValidItemCode {
    return itemCode != null && itemCode!.isNotEmpty && itemCode != '0';
  }

  // Get department code as string
  String get deptCodeString {
    return deptCode?.toString() ?? 'N/A';
  }

  // Get formatted quantity
  String get formattedQuantity {
    if (quantity == quantity.truncateToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(2);
  }

  // Get formatted unit price
  String get formattedUnitPrice {
    return 'KES ${unitPrice.toStringAsFixed(2)}';
  }

  // Get formatted item amount
  String get formattedItemAmount {
    return 'KES ${itemAmount.toStringAsFixed(2)}';
  }

  // Get formatted discount amount
  String get formattedDiscountAmount {
    if (discountAmount == null || discountAmount == 0) {
      return 'KES 0.00';
    }
    return 'KES ${discountAmount!.toStringAsFixed(2)}';
  }

  // Get formatted discount rate
  String get formattedDiscountRate {
    if (discountRate == null || discountRate == 0) {
      return '0%';
    }
    return '${discountRate!.toStringAsFixed(1)}%';
  }

  // Calculate line total
  double get lineTotal {
    return itemAmount - (discountAmount ?? 0);
  }

  // Get formatted line total
  String get formattedLineTotal {
    return 'KES ${lineTotal.toStringAsFixed(2)}';
  }

  // Check if this is a valid item (not a discount/tax/service charge)
  bool get isRegularItem {
    return rowType == 0 || rowType == null;
  }

  // Get item summary for display
  String get summary {
    final List<String> parts = [];

    if (hasValidItemCode) {
      parts.add('Code: $itemCode');
    }

    parts.add('Qty: $formattedQuantity');
    parts.add('Price: $formattedUnitPrice');

    if (hasDiscount) {
      parts.add('Disc: $formattedDiscountAmount');
    }

    return parts.join(' | ');
  }
}
