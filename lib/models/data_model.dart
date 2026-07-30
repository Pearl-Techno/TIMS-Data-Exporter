import 'dart:math';

import 'package:flutter/foundation.dart';
import 'item_detail.dart';

class DataModel {
  final int id;
  final String tsNum;
  String? buyerPIN;
  double? totalAmount;
  double? convertedTotalAmount;
  List<ItemDetail>? itemDetails;
  String currency;

  // Original fields
  final String? mwNum;
  final String? controlCode;
  final DateTime? date;
  double? vatAmountA;
  final DateTime? sendDate;

  // New database fields from fb_transaction table
  final int? trType;
  double? totalRounding;
  double? vatAmountB;
  double? vatAmountC;
  double? vatAmountD;
  double? vatAmountE;
  final String? relevantMwNum;
  final String? typeNote;
  final String? serialNumber;
  final String? qrCode;

  // Raw text from PDF for template detection
  String? rawText;

  DataModel({
    required this.id,
    required this.tsNum,
    this.buyerPIN,
    double? totalAmount,
    double? convertedTotalAmount,
    this.itemDetails,
    this.currency = 'KES',

    // Original database fields
    this.mwNum,
    this.controlCode,
    this.date,
    this.vatAmountA,
    this.sendDate,

    // New database fields
    this.trType,
    this.totalRounding,
    this.vatAmountB,
    this.vatAmountC,
    this.vatAmountD,
    this.vatAmountE,
    this.relevantMwNum,
    this.typeNote,
    this.serialNumber,
    this.qrCode,
    this.rawText,
  }) {
    // Convert negative values to positive when setting
    this.totalAmount = totalAmount?.abs();
    this.convertedTotalAmount = convertedTotalAmount?.abs() ?? this.totalAmount;

    // Ensure other numeric fields are positive
    totalRounding = totalRounding?.abs();
    vatAmountA = vatAmountA?.abs();
    vatAmountB = vatAmountB?.abs();
    vatAmountC = vatAmountC?.abs();
    vatAmountD = vatAmountD?.abs();
    vatAmountE = vatAmountE?.abs();
  }

  factory DataModel.fromJson(Map<String, dynamic> json) {
    // Parse dates from database
    DateTime? parsedDate;
    if (json['Date'] != null) {
      try {
        parsedDate = DateTime.parse(json['Date'].toString());
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing Date: ${json['Date']}');
        }
      }
    }

    DateTime? parsedSendDate;
    if (json['SendDate'] != null) {
      try {
        parsedSendDate = DateTime.parse(json['SendDate'].toString());
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing SendDate: ${json['SendDate']}');
        }
      }
    }

    // Parse item details
    List<ItemDetail>? parsedItemDetails;
    if (json['ItemDetails'] != null) {
      if (json['ItemDetails'] is List) {
        parsedItemDetails = (json['ItemDetails'] as List<dynamic>)
            .map((item) => ItemDetail.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    // Get values and ensure they're positive
    final totalAmountValue = (json['TotalAmount'] as num?)?.toDouble().abs();
    final convertedTotalAmountValue =
        (json['ConvertedTotalAmount'] as num?)?.toDouble().abs();

    return DataModel(
      id: json['Id'] as int? ?? 0,
      tsNum: json['TsNum']?.toString() ?? '',
      buyerPIN: json['BuyerPIN'] as String?,
      totalAmount: totalAmountValue,
      convertedTotalAmount: convertedTotalAmountValue ?? totalAmountValue,
      itemDetails: parsedItemDetails,
      currency: json['Currency'] as String? ?? 'KES',

      // Original database fields
      mwNum: json['MwNum'] as String?,
      controlCode: json['ControlCode'] as String?,
      date: parsedDate,
      vatAmountA: (json['VatAmountA'] as num?)?.toDouble().abs(),
      sendDate: parsedSendDate,

      // New database fields
      trType: json['TrType'] as int?,
      totalRounding: (json['TotalRounding'] as num?)?.toDouble().abs(),
      vatAmountB: (json['VatAmountB'] as num?)?.toDouble().abs(),
      vatAmountC: (json['VatAmountC'] as num?)?.toDouble().abs(),
      vatAmountD: (json['VatAmountD'] as num?)?.toDouble().abs(),
      vatAmountE: (json['VatAmountE'] as num?)?.toDouble().abs(),
      relevantMwNum: json['RelevantMwNum'] as String?,
      typeNote: json['TypeNote'] as String?,
      serialNumber: json['SerialNumber'] as String?,
      qrCode: json['QrCode'] as String?,
      rawText: json['RawText'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'Id': id,
        'TsNum': tsNum,
        'BuyerPIN': buyerPIN,
        'TotalAmount': totalAmount,
        'ConvertedTotalAmount': convertedTotalAmount,
        'ItemDetails': itemDetails?.map((item) => item.toJson()).toList(),
        'Currency': currency,

        // Original database fields
        'MwNum': mwNum,
        'ControlCode': controlCode,
        'Date': date?.toIso8601String(),
        'VatAmountA': vatAmountA,
        'SendDate': sendDate?.toIso8601String(),

        // New database fields
        'TrType': trType,
        'TotalRounding': totalRounding,
        'VatAmountB': vatAmountB,
        'VatAmountC': vatAmountC,
        'VatAmountD': vatAmountD,
        'VatAmountE': vatAmountE,
        'RelevantMwNum': relevantMwNum,
        'TypeNote': typeNote,
        'SerialNumber': serialNumber,
        'QrCode': qrCode,
        'RawText': rawText,
      };

  void roundAmounts({int precision = 2}) {
    final factor = pow(10, precision).toDouble();

    // Round main amounts
    totalAmount =
        totalAmount != null ? (totalAmount! * factor).round() / factor : null;
    convertedTotalAmount = convertedTotalAmount != null
        ? (convertedTotalAmount! * factor).round() / factor
        : null;

    // Round other numeric amounts
    totalRounding = totalRounding != null
        ? (totalRounding! * factor).round() / factor
        : null;
    vatAmountA =
        vatAmountA != null ? (vatAmountA! * factor).round() / factor : null;
    vatAmountB =
        vatAmountB != null ? (vatAmountB! * factor).round() / factor : null;
    vatAmountC =
        vatAmountC != null ? (vatAmountC! * factor).round() / factor : null;
    vatAmountD =
        vatAmountD != null ? (vatAmountD! * factor).round() / factor : null;
    vatAmountE =
        vatAmountE != null ? (vatAmountE! * factor).round() / factor : null;

    // Round item details
    itemDetails?.forEach((item) => item.roundAmounts(precision: precision));
  }

  void validate() {
    if (id <= 0) {
      throw FormatException('Invalid transaction ID.');
    }
    if (tsNum.isEmpty) {
      throw FormatException('Transaction number cannot be empty.');
    }
    if (currency.isEmpty) {
      throw FormatException('Currency cannot be empty.');
    }
    if (totalAmount == null) {
      throw FormatException('TotalAmount cannot be null.');
    }
    if (convertedTotalAmount == null) {
      throw FormatException('ConvertedTotalAmount cannot be null.');
    }
  }

  // Helper method to ensure all amounts are positive
  void ensurePositiveAmounts() {
    if (totalAmount != null && totalAmount! < 0) {
      totalAmount = totalAmount!.abs();
    }
    if (convertedTotalAmount != null && convertedTotalAmount! < 0) {
      convertedTotalAmount = convertedTotalAmount!.abs();
    }
    if (totalRounding != null && totalRounding! < 0) {
      totalRounding = totalRounding!.abs();
    }
    if (vatAmountA != null && vatAmountA! < 0) {
      vatAmountA = vatAmountA!.abs();
    }
    if (vatAmountB != null && vatAmountB! < 0) {
      vatAmountB = vatAmountB!.abs();
    }
    if (vatAmountC != null && vatAmountC! < 0) {
      vatAmountC = vatAmountC!.abs();
    }
    if (vatAmountD != null && vatAmountD! < 0) {
      vatAmountD = vatAmountD!.abs();
    }
    if (vatAmountE != null && vatAmountE! < 0) {
      vatAmountE = vatAmountE!.abs();
    }

    itemDetails?.forEach((item) => item.ensurePositiveAmounts());
  }

  // Calculate total VAT (sum of all VAT amounts)
  double get totalVat {
    return vatAmountA ?? 0.0;
  }

  // Calculate net amount (total minus VAT minus rounding)
  double get netAmount {
    double net = (totalAmount ?? 0) - totalVat;
    if (totalRounding != null) net -= totalRounding!;
    return net;
  }

  // Get transaction type as string
  String get transactionType {
    switch (trType) {
      case 0:
        return 'Normal';
      case 1:
        return 'Credit Note';
      case 2:
        return 'Debit Note';
      default:
        return 'Unknown';
    }
  }

  // Check if transaction has QR code
  bool get hasQrCode => qrCode != null && qrCode!.isNotEmpty;

  // Get machine numbers (both MwNum and RelevantMwNum)
  List<String> get machineNumbers {
    final List<String> machines = [];
    if (mwNum != null && mwNum!.isNotEmpty) {
      machines.add(mwNum!);
    }
    if (relevantMwNum != null && relevantMwNum!.isNotEmpty) {
      machines.add(relevantMwNum!);
    }
    return machines;
  }

  // Get formatted date string
  String get formattedDate {
    if (date == null) return 'N/A';
    return '${date!.day.toString().padLeft(2, '0')}/'
        '${date!.month.toString().padLeft(2, '0')}/'
        '${date!.year}';
  }

  // Get formatted send date string
  String get formattedSendDate {
    if (sendDate == null) return 'N/A';
    return '${sendDate!.day.toString().padLeft(2, '0')}/'
        '${sendDate!.month.toString().padLeft(2, '0')}/'
        '${sendDate!.year}';
  }

  // Check if transaction was sent
  bool get wasSent => sendDate != null;

  // Get item count
  int get itemCount => itemDetails?.length ?? 0;

  // Get total quantity of all items
  double get totalQuantity {
    if (itemDetails == null) return 0;
    return itemDetails!.fold(0, (sum, item) => sum + item.quantity);
  }

  // Get total discount amount
  double get totalDiscount {
    if (itemDetails == null) return 0;
    return itemDetails!
        .fold(0, (sum, item) => sum + (item.discountAmount ?? 0));
  }

  // Get unique item codes
  List<String> get uniqueItemCodes {
    if (itemDetails == null) return [];
    final codes = <String>{};
    for (final item in itemDetails!) {
      if (item.itemCode != null && item.itemCode!.isNotEmpty) {
        codes.add(item.itemCode!);
      }
    }
    return codes.toList();
  }

  // Helper to check if this is a Sleek Kenya document
  bool get isSleekDocument {
    if (rawText == null) return false;
    return rawText!.contains('Sleek Kenya') ||
        rawText!.contains('SLEEK KENYA') ||
        rawText!.contains('Sleek Kenya Ltd') ||
        rawText!.contains('Sleek Kenya Limited');
  }
}
