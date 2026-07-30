import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tims_data_exporter/models/data_model.dart';
import 'package:tims_data_exporter/models/item_detail.dart';

class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
  @override
  String toString() => 'DatabaseException: $message';
}

class DatabaseHelper {
  late Future<Database> _database;
  String databasePath;

  DatabaseHelper({required this.databasePath}) {
    _database = _initDatabase();
  }

  Future<Database> _initDatabase() async {
    try {
      if (await databaseExists(databasePath)) {
        if (kDebugMode) {
          print('Database found at $databasePath');
        }
      } else {
        throw DatabaseException('Database not found at $databasePath');
      }
      final db = await openDatabase(databasePath, version: 1);
      return db;
    } catch (e) {
      throw DatabaseException('Error initializing database: $e');
    }
  }

  Future<bool> databaseExists(String path) async {
    return File(path).existsSync();
  }

  // ======== TABLE STRUCTURE METHODS ========
  Future<Map<String, dynamic>> getTableStructure() async {
    try {
      final db = await _database;

      final Map<String, dynamic> structure = {};

      // Get fb_transaction table structure
      final transactionColumns =
          await db.rawQuery('PRAGMA table_info(fb_transaction)');
      structure['fb_transaction'] = transactionColumns;

      // Get fb_transaction_item table structure
      final itemColumns =
          await db.rawQuery('PRAGMA table_info(fb_transaction_item)');
      structure['fb_transaction_item'] = itemColumns;

      return structure;
    } catch (e) {
      throw DatabaseException('Error getting table structure: $e');
    }
  }

  // ======== OPTIMIZED DATA FETCHING WITH ALL COLUMNS ========
  Future<List<DataModel>> getData(
    int offset,
    int limit, {
    DateTime? startDate,
    DateTime? endDate,
    String? tsNumFrom,
    String? tsNumTo,
  }) async {
    try {
      final db = await _database;

      // Using SELECT * to handle varying schemas (e.g., missing TotalRounding in older DBs)
      String query = 'SELECT * FROM fb_transaction';

      List<dynamic> args = [];
      List<String> conditions = [];

      if (startDate != null && endDate != null) {
        conditions.add('Date BETWEEN ? AND ?');
        args.add(startDate.toIso8601String());
        args.add(endDate.add(const Duration(days: 1)).toIso8601String());
      }

      if (tsNumFrom != null && tsNumFrom.isNotEmpty) {
        conditions.add('TsNum >= ?');
        args.add(tsNumFrom);
      }

      if (tsNumTo != null && tsNumTo.isNotEmpty) {
        conditions.add('TsNum <= ?');
        args.add(tsNumTo);
      }

      if (conditions.isNotEmpty) {
        query += ' WHERE ${conditions.join(' AND ')}';
      }

      query += ' ORDER BY Date DESC, Id DESC LIMIT ? OFFSET ?';
      args.add(limit);
      args.add(offset);

      final maps = await db.rawQuery(query, args);

      if (maps.isEmpty) return [];

      // Process data with all columns
      return await _processTransactionMapsComplete(maps);
    } catch (e) {
      throw DatabaseException('Error fetching data: $e');
    }
  }

  // ======== PROCESS TRANSACTION WITH ALL COLUMNS ========
  Future<List<DataModel>> _processTransactionMapsComplete(
      List<Map<String, dynamic>> maps) async {
    if (maps.isEmpty) return [];

    final List<DataModel> dataModels = [];
    final List<int> trIds = [];

    // First pass: create DataModels without item details
    for (var map in maps) {
      try {
        // Convert negative values to positive
        final processedMap = _convertNegativesToPositive(map);

        final double totalVal =
            (processedMap['TotalAmount'] as num?)?.toDouble() ?? 0.0;
        // Map database column names to DataModel properties
        final model = DataModel(
          id: processedMap['Id'] as int? ?? 0,
          date: processedMap['Date'] != null
              ? DateTime.tryParse(processedMap['Date'].toString())
              : null,
          buyerPIN: processedMap['BuyerPIN']?.toString(),
          trType: processedMap['TrType'] as int?,
          tsNum: processedMap['TsNum']?.toString() ?? '',
          mwNum: processedMap['MwNum']?.toString(),
          totalRounding: (processedMap['TotalRounding'] as num?)?.toDouble(),
          totalAmount: totalVal,
          vatAmountA: (processedMap['VatAmountA'] as num?)?.toDouble(),
          vatAmountB: (processedMap['VatAmountB'] as num?)?.toDouble(),
          vatAmountC: (processedMap['VatAmountC'] as num?)?.toDouble(),
          vatAmountD: (processedMap['VatAmountD'] as num?)?.toDouble(),
          vatAmountE: (processedMap['VatAmountE'] as num?)?.toDouble(),
          controlCode: processedMap['ControlCode']?.toString(),
          sendDate: processedMap['SendDate'] != null
              ? DateTime.tryParse(processedMap['SendDate'].toString())
              : null,
          relevantMwNum: processedMap['RelevantMwNum']?.toString(),
          typeNote: processedMap['TypeNote']?.toString(),
          serialNumber: processedMap['SerialNumber']?.toString(),
          qrCode: processedMap['QrCode']?.toString(),
          convertedTotalAmount: totalVal,
        );

        model.ensurePositiveAmounts();
        dataModels.add(model);
        trIds.add(model.id);
      } catch (e) {
        if (kDebugMode) {
          print('Error processing transaction: $e');
        }
        // Add minimal model
        dataModels.add(DataModel(
          id: map['Id'] as int? ?? 0,
          tsNum: map['TsNum']?.toString() ?? 'UNKNOWN',
          totalAmount: 0.0,
          convertedTotalAmount: 0.0,
        ));
      }
    }

    return dataModels;
  }

  Future<List<ItemDetail>> getItemDetails(int trId) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps = await db.query(
        'fb_transaction_item',
        where: 'TrId = ?',
        whereArgs: [trId],
        orderBy: 'Id',
      );

      if (maps.isNotEmpty) {
        return maps.map((item) {
          final processedMap = _convertNegativesToPositive(item);
          return ItemDetail.fromJson(processedMap);
        }).toList();
      }
      return [];
    } catch (e) {
      throw DatabaseException(
          'Error fetching item details for transaction $trId: $e');
    }
  }

  // ======== COMPLETE ITEM DETAILS FETCHING ========
  Future<Map<int, List<ItemDetail>>> getItemDetailsForIdsComplete(
      List<int> trIds) async {
    if (trIds.isEmpty) return {};

    try {
      final db = await _database;

      // Process in smaller batches to avoid too many parameters
      const batchSize = 100;
      final Map<int, List<ItemDetail>> result = {};

      for (var i = 0; i < trIds.length; i += batchSize) {
        final batch = trIds.sublist(
          i,
          i + batchSize < trIds.length ? i + batchSize : trIds.length,
        );

        final placeholders = List.filled(batch.length, '?').join(',');
        final maps = await db.rawQuery(
          'SELECT * FROM fb_transaction_item WHERE TrId IN ($placeholders) ORDER BY Id',
          batch,
        );

        for (var map in maps) {
          final trId = map['TrId'] as int;
          result[trId] ??= [];

          try {
            final processedMap = _convertNegativesToPositive(map);
            final item = ItemDetail(
              id: processedMap['Id'] as int? ?? 0,
              trId: processedMap['TrId'] as int? ?? 0,
              rowType: processedMap['RowType'] as int?,
              description: processedMap['Description']?.toString() ?? '',
              itemCode: processedMap['ItemCode']?.toString(),
              deptCode: processedMap['DeptCode'] as int?,
              quantity: (processedMap['Quantity'] as num?)?.toDouble() ?? 0.0,
              unitPrice: (processedMap['UnitPrice'] as num?)?.toDouble() ?? 0.0,
              itemAmount:
                  (processedMap['ItemAmount'] as num?)?.toDouble() ?? 0.0,
              discountAmount:
                  (processedMap['DiscountAmount'] as num?)?.toDouble(),
              discountRate: (processedMap['DiscountRate'] as num?)?.toDouble(),
              taxCode: processedMap['TaxCode'] as int?,
            );

            item.ensurePositiveAmounts();
            result[trId]!.add(item);
          } catch (e) {
            if (kDebugMode) {
              print('Error processing item for transaction $trId: $e');
            }
          }
        }

        // Give UI thread a chance to breathe
        await Future.delayed(const Duration(milliseconds: 10));
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching item details: $e');
      }
      return {};
    }
  }

  // ======== FILTERED DATA FETCHING ========
  Future<List<DataModel>> getFilteredData({
    DateTime? startDate,
    DateTime? endDate,
    double minAmount = 0,
    double maxAmount = double.infinity,
    String? mwNum,
    String? controlCode,
    int? trType,
  }) async {
    try {
      final db = await _database;

      String query = 'SELECT * FROM fb_transaction WHERE 1=1';

      List<dynamic> args = [];

      if (startDate != null) {
        query += ' AND Date >= ?';
        args.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        // Add one day to include the end date fully
        final nextDay = endDate.add(const Duration(days: 1));
        query += ' AND Date < ?';
        args.add(nextDay.toIso8601String());
      }

      if (minAmount > 0) {
        query += ' AND TotalAmount >= ?';
        args.add(minAmount);
      }

      if (maxAmount != double.infinity) {
        query += ' AND TotalAmount <= ?';
        args.add(maxAmount);
      }

      if (mwNum != null && mwNum.isNotEmpty) {
        query += ' AND MwNum LIKE ?';
        args.add('%$mwNum%');
      }

      if (controlCode != null && controlCode.isNotEmpty) {
        query += ' AND ControlCode LIKE ?';
        args.add('%$controlCode%');
      }

      if (trType != null) {
        query += ' AND TrType = ?';
        args.add(trType);
      }

      query += ' ORDER BY Date DESC';

      final maps = await db.rawQuery(query, args);
      return await _processTransactionMapsComplete(maps);
    } catch (e) {
      throw DatabaseException('Error fetching filtered data: $e');
    }
  }

  // ======== OPTIMIZED SEARCH METHODS ========
  Future<List<DataModel>> searchByMwNumOptimized(String mwNum,
      {int limit = 100}) async {
    try {
      final db = await _database;

      final maps = await db.rawQuery(
        'SELECT * FROM fb_transaction WHERE MwNum LIKE ? ORDER BY Date DESC LIMIT ?',
        ['%$mwNum%', limit],
      );

      return await _processTransactionMapsComplete(maps);
    } catch (e) {
      throw DatabaseException('Error searching by MwNum: $e');
    }
  }

  Future<List<DataModel>> searchByControlCodeOptimized(String controlCode,
      {int limit = 100}) async {
    try {
      final db = await _database;

      final maps = await db.rawQuery(
        'SELECT * FROM fb_transaction WHERE ControlCode LIKE ? ORDER BY Date DESC LIMIT ?',
        ['%$controlCode%', limit],
      );

      return await _processTransactionMapsComplete(maps);
    } catch (e) {
      throw DatabaseException('Error searching by ControlCode: $e');
    }
  }

  Future<List<DataModel>> searchByTsNum(String tsNum, {int limit = 100}) async {
    try {
      final db = await _database;

      final maps = await db.rawQuery(
        'SELECT * FROM fb_transaction WHERE TsNum LIKE ? ORDER BY Date DESC LIMIT ?',
        ['%$tsNum%', limit],
      );

      return await _processTransactionMapsComplete(maps);
    } catch (e) {
      throw DatabaseException('Error searching by TsNum: $e');
    }
  }

  // ======== CSV COMPARISON OPTIMIZED METHODS ========

  /// Get all distinct control codes from the database (fast query - only returns control codes)
  Future<List<String>> getAllControlCodes() async {
    try {
      final db = await _database;
      final result = await db.rawQuery('''
        SELECT DISTINCT ControlCode 
        FROM fb_transaction 
        WHERE ControlCode IS NOT NULL AND ControlCode != ''
      ''');

      return result.map((row) => row['ControlCode'] as String).toList();
    } catch (e) {
      throw DatabaseException('Error getting control codes: $e');
    }
  }

  /// Get transactions by list of control codes (for matched records)
  Future<Map<String, DataModel>> getTransactionsByControlCodes(
      List<String> controlCodes) async {
    if (controlCodes.isEmpty) return {};

    try {
      final db = await _database;

      // Process in batches to avoid too many parameters
      const batchSize = 500;
      final Map<String, DataModel> result = {};

      for (var i = 0; i < controlCodes.length; i += batchSize) {
        final batch = controlCodes.sublist(
          i,
          i + batchSize < controlCodes.length
              ? i + batchSize
              : controlCodes.length,
        );

        final placeholders = List.filled(batch.length, '?').join(',');
        final maps = await db.rawQuery(
          'SELECT * FROM fb_transaction WHERE ControlCode IN ($placeholders)',
          batch,
        );

        for (var map in maps) {
          final processedMap = _convertNegativesToPositive(map);
          final double totalVal =
              (processedMap['TotalAmount'] as num?)?.toDouble() ?? 0.0;
          final model = DataModel(
            id: processedMap['Id'] as int? ?? 0,
            date: processedMap['Date'] != null
                ? DateTime.tryParse(processedMap['Date'].toString())
                : null,
            buyerPIN: processedMap['BuyerPIN']?.toString(),
            trType: processedMap['TrType'] as int?,
            tsNum: processedMap['TsNum']?.toString() ?? '',
            mwNum: processedMap['MwNum']?.toString(),
            totalRounding: (processedMap['TotalRounding'] as num?)?.toDouble(),
            totalAmount: totalVal,
            vatAmountA: (processedMap['VatAmountA'] as num?)?.toDouble(),
            vatAmountB: (processedMap['VatAmountB'] as num?)?.toDouble(),
            vatAmountC: (processedMap['VatAmountC'] as num?)?.toDouble(),
            vatAmountD: (processedMap['VatAmountD'] as num?)?.toDouble(),
            vatAmountE: (processedMap['VatAmountE'] as num?)?.toDouble(),
            controlCode: processedMap['ControlCode']?.toString(),
            sendDate: processedMap['SendDate'] != null
                ? DateTime.tryParse(processedMap['SendDate'].toString())
                : null,
            relevantMwNum: processedMap['RelevantMwNum']?.toString(),
            typeNote: processedMap['TypeNote']?.toString(),
            serialNumber: processedMap['SerialNumber']?.toString(),
            qrCode: processedMap['QrCode']?.toString(),
            convertedTotalAmount: totalVal,
          );

          model.ensurePositiveAmounts();
          if (model.controlCode != null) {
            result[model.controlCode!] = model;
          }
        }
      }

      return result;
    } catch (e) {
      throw DatabaseException(
          'Error getting transactions by control codes: $e');
    }
  }

  // ======== GET SINGLE TRANSACTION WITH COMPLETE DATA ========
  Future<DataModel?> getTransactionDetails(int id) async {
    try {
      final db = await _database;

      final transactionMap = await db.rawQuery(
        'SELECT * FROM fb_transaction WHERE Id = ?',
        [id],
      );

      if (transactionMap.isEmpty) return null;

      final processedMap = _convertNegativesToPositive(transactionMap.first);
      final double totalVal =
          (processedMap['TotalAmount'] as num?)?.toDouble() ?? 0.0;
      final model = DataModel(
        id: processedMap['Id'] as int? ?? 0,
        date: processedMap['Date'] != null
            ? DateTime.tryParse(processedMap['Date'].toString())
            : null,
        buyerPIN: processedMap['BuyerPIN']?.toString(),
        trType: processedMap['TrType'] as int?,
        tsNum: processedMap['TsNum']?.toString() ?? '',
        mwNum: processedMap['MwNum']?.toString(),
        totalRounding: (processedMap['TotalRounding'] as num?)?.toDouble(),
        totalAmount: totalVal,
        vatAmountA: (processedMap['VatAmountA'] as num?)?.toDouble(),
        vatAmountB: (processedMap['VatAmountB'] as num?)?.toDouble(),
        vatAmountC: (processedMap['VatAmountC'] as num?)?.toDouble(),
        vatAmountD: (processedMap['VatAmountD'] as num?)?.toDouble(),
        vatAmountE: (processedMap['VatAmountE'] as num?)?.toDouble(),
        controlCode: processedMap['ControlCode']?.toString(),
        sendDate: processedMap['SendDate'] != null
            ? DateTime.tryParse(processedMap['SendDate'].toString())
            : null,
        relevantMwNum: processedMap['RelevantMwNum']?.toString(),
        typeNote: processedMap['TypeNote']?.toString(),
        serialNumber: processedMap['SerialNumber']?.toString(),
        qrCode: processedMap['QrCode']?.toString(),
        convertedTotalAmount: totalVal,
      );

      // Load item details
      final itemMaps = await db.rawQuery(
        'SELECT * FROM fb_transaction_item WHERE TrId = ? ORDER BY Id',
        [id],
      );

      final itemDetails = <ItemDetail>[];
      for (var map in itemMaps) {
        final processedItemMap = _convertNegativesToPositive(map);
        final item = ItemDetail(
          id: processedItemMap['Id'] as int? ?? 0,
          trId: processedItemMap['TrId'] as int? ?? 0,
          rowType: processedItemMap['RowType'] as int?,
          description: processedItemMap['Description']?.toString() ?? '',
          itemCode: processedItemMap['ItemCode']?.toString(),
          deptCode: processedItemMap['DeptCode'] as int?,
          quantity: (processedItemMap['Quantity'] as num?)?.toDouble() ?? 0.0,
          unitPrice: (processedItemMap['UnitPrice'] as num?)?.toDouble() ?? 0.0,
          itemAmount:
              (processedItemMap['ItemAmount'] as num?)?.toDouble() ?? 0.0,
          discountAmount:
              (processedItemMap['DiscountAmount'] as num?)?.toDouble(),
          discountRate: (processedItemMap['DiscountRate'] as num?)?.toDouble(),
          taxCode: processedItemMap['TaxCode'] as int?,
        );

        item.ensurePositiveAmounts();
        itemDetails.add(item);
      }

      model.itemDetails = itemDetails;
      model.ensurePositiveAmounts();

      return model;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading transaction details: $e');
      }
      return null;
    }
  }

  // ======== STATISTICS AND ANALYTICS ========
  Future<Map<String, dynamic>> getTransactionStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await _database;

      String whereClause = '';
      List<dynamic> args = [];

      if (startDate != null && endDate != null) {
        whereClause = 'WHERE Date BETWEEN ? AND ?';
        args.add(startDate.toIso8601String());
        args.add(endDate.add(const Duration(days: 1)).toIso8601String());
      }

      final stats = await db.rawQuery('''
        SELECT 
          COUNT(*) as totalTransactions,
          SUM(TotalAmount) as totalAmount,
          AVG(TotalAmount) as averageAmount,
          MIN(TotalAmount) as minAmount,
          MAX(TotalAmount) as maxAmount,
          COUNT(DISTINCT MwNum) as uniqueMachines,
          COUNT(DISTINCT BuyerPIN) as uniqueBuyers
        FROM fb_transaction
        $whereClause
      ''', args);

      final firstRow = stats.isNotEmpty ? stats.first : {};

      // Get item statistics
      final itemStats = await db.rawQuery('''
        SELECT 
          COUNT(*) as totalItems,
          SUM(Quantity) as totalQuantity,
          AVG(UnitPrice) as averageUnitPrice,
          SUM(DiscountAmount) as totalDiscount,
          COUNT(DISTINCT ItemCode) as uniqueItems
        FROM fb_transaction_item i
        JOIN fb_transaction t ON i.TrId = t.Id
        $whereClause
      ''', args);

      final itemRow = itemStats.isNotEmpty ? itemStats.first : {};

      return {
        'transactions': firstRow,
        'items': itemRow,
        'period': {
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
        }
      };
    } catch (e) {
      throw DatabaseException('Error getting statistics: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTopBuyers({int limit = 20}) async {
    final db = await _database;

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT
        BuyerPIN,
        SUM(TotalAmount) as total_spent,
        COUNT(*) as transaction_count
      FROM fb_transaction
      WHERE BuyerPIN IS NOT NULL AND BuyerPIN != ''
      GROUP BY BuyerPIN
      ORDER BY total_spent DESC
      LIMIT ?
    ''', [limit]);

    return result;
  }

  Future<List<Map<String, dynamic>>> getDailySales(
      {DateTime? startDate, DateTime? endDate}) async {
    final db = await _database;

    String whereClause = 'WHERE Date IS NOT NULL';
    List<dynamic> whereArgs = [];

    // Add date range filtering
    if (startDate != null) {
      whereClause += ' AND Date >= ?';
      whereArgs.add('${startDate.toIso8601String().substring(0, 10)} 00:00:00');
    }
    if (endDate != null) {
      whereClause += ' AND Date <= ?';
      whereArgs.add('${endDate.toIso8601String().substring(0, 10)} 23:59:59');
    }

    final List<Map<String, dynamic>> result = await db.rawQuery('''
    SELECT
      strftime('%Y-%m-%d', Date) as sale_date,
      SUM(TotalAmount) as total_sales
    FROM fb_transaction
    $whereClause
    GROUP BY sale_date
    ORDER BY sale_date DESC
  ''', whereArgs);

    return result;
  }

  Future<List<Map<String, dynamic>>> getDailyTaxSummary(
      {int limit = 30}) async {
    final db = await _database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT
        strftime('%Y-%m-%d', Date) as summary_date,
        SUM(COALESCE(VatAmountA, 0)) as total_vat_a,
        SUM(COALESCE(VatAmountB, 0)) as total_vat_b,
        SUM(COALESCE(VatAmountC, 0)) as total_vat_c,
        SUM(COALESCE(VatAmountD, 0)) as total_vat_d,
        SUM(COALESCE(VatAmountE, 0)) as total_vat_e,
        SUM(COALESCE(VatAmountA, 0) + COALESCE(VatAmountB, 0) + COALESCE(VatAmountC, 0) + COALESCE(VatAmountD, 0) + COALESCE(VatAmountE, 0)) as daily_total_vat
      FROM fb_transaction
      WHERE Date IS NOT NULL
      GROUP BY summary_date
      ORDER BY summary_date DESC
      LIMIT ?
    ''', [limit]);
    return result;
  }

  // ======== HELPER METHODS ========
  Map<String, dynamic> _convertNegativesToPositive(Map<String, dynamic> map) {
    final processedMap = Map<String, dynamic>.from(map);

    // List of numeric columns to convert
    const numericColumns = [
      'TotalRounding',
      'TotalAmount',
      'VatAmountA',
      'VatAmountB',
      'VatAmountC',
      'VatAmountD',
      'VatAmountE',
      'Quantity',
      'UnitPrice',
      'ItemAmount',
      'DiscountAmount',
      'DiscountRate'
    ];

    // Convert numeric fields to positive
    processedMap.forEach((key, value) {
      final lowerKey = key.toLowerCase();
      if (numericColumns.any((c) => c.toLowerCase() == lowerKey) &&
          value is num) {
        processedMap[key] = value.abs();
      }
    });

    return processedMap;
  }

  // ======== COUNT METHODS ========
  Future<int> getTransactionCount({
    DateTime? startDate,
    DateTime? endDate,
    String? mwNum,
    String? controlCode,
  }) async {
    try {
      final db = await _database;

      String query = 'SELECT COUNT(*) as count FROM fb_transaction WHERE 1=1';
      List<dynamic> args = [];

      if (startDate != null && endDate != null) {
        query += ' AND Date BETWEEN ? AND ?';
        args.add(startDate.toIso8601String());
        args.add(endDate.add(const Duration(days: 1)).toIso8601String());
      }

      if (mwNum != null && mwNum.isNotEmpty) {
        query += ' AND MwNum LIKE ?';
        args.add('%$mwNum%');
      }

      if (controlCode != null && controlCode.isNotEmpty) {
        query += ' AND ControlCode LIKE ?';
        args.add('%$controlCode%');
      }

      final result = await db.rawQuery(query, args);
      return result.first['count'] as int;
    } catch (e) {
      if (kDebugMode) print('Error getting transaction count: $e');
      return 0;
    }
  }

  // ======== PERFORMANCE OPTIMIZATION ========
  Future<void> createIndexes() async {
    try {
      final db = await _database;

      // Create indexes for faster searches on fb_transaction
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_transaction_date 
        ON fb_transaction(Date DESC)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_transaction_tsnum 
        ON fb_transaction(TsNum)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_transaction_mwnum 
        ON fb_transaction(MwNum)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_transaction_controlcode 
        ON fb_transaction(ControlCode)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_transaction_totalamount 
        ON fb_transaction(TotalAmount)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_transaction_trtype 
        ON fb_transaction(TrType)
      ''');

      // Create indexes for faster searches on fb_transaction_item
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_item_trid 
        ON fb_transaction_item(TrId)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_item_itemcode 
        ON fb_transaction_item(ItemCode)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_item_deptcode 
        ON fb_transaction_item(DeptCode)
      ''');

      if (kDebugMode) {
        print('Database indexes created for better performance');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating indexes: $e');
      }
    }
  }

  // ======== DATA VALIDATION ========
  Future<Map<String, dynamic>> validateDataIntegrity() async {
    try {
      final db = await _database;

      final results = <String, dynamic>{};

      // Check for orphaned items (items without parent transaction)
      final orphanedItems = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM fb_transaction_item i
        LEFT JOIN fb_transaction t ON i.TrId = t.Id
        WHERE t.Id IS NULL
      ''');

      results['orphanedItems'] = orphanedItems.first['count'] as int;

      // Check for transactions without items
      final emptyTransactions = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM fb_transaction t
        LEFT JOIN fb_transaction_item i ON t.Id = i.TrId
        WHERE i.Id IS NULL
      ''');

      results['emptyTransactions'] = emptyTransactions.first['count'] as int;

      // Check for negative amounts that should be positive
      final negativeAmounts = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM fb_transaction 
        WHERE TotalAmount < 0 
           OR VatAmountA < 0 
           OR VatAmountB < 0 
           OR VatAmountC < 0 
           OR VatAmountD < 0 
           OR VatAmountE < 0
      ''');

      results['negativeAmounts'] = negativeAmounts.first['count'] as int;

      return results;
    } catch (e) {
      throw DatabaseException('Error validating data integrity: $e');
    }
  }

  Future<bool> testConnection() async {
    try {
      final db = await _database;
      await db.rawQuery('SELECT 1');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> closeDatabase() async {
    try {
      final db = await _database;
      await db.close();
      if (kDebugMode) {
        print('Database closed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error closing database: $e');
      }
    }
  }
}
