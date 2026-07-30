import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DbFilterDialog extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String tsNumFrom;
  final String tsNumTo;
  final String? mwNum;
  final String? controlCode;
  final FilterMode filterMode;

  const DbFilterDialog({
    super.key,
    this.startDate,
    this.endDate,
    this.tsNumFrom = '',
    this.tsNumTo = '',
    this.mwNum,
    this.controlCode,
    this.filterMode = FilterMode.mwNum,
  });

  @override
  State<DbFilterDialog> createState() => _DbFilterDialogState();
}

class _DbFilterDialogState extends State<DbFilterDialog> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late TextEditingController _tsNumFromController;
  late TextEditingController _tsNumToController;
  late TextEditingController _identifierController;
  late FilterMode _filterMode;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _tsNumFromController = TextEditingController(text: widget.tsNumFrom);
    _tsNumToController = TextEditingController(text: widget.tsNumTo);
    _filterMode = widget.filterMode;
    
    // Initialize identifier controller based on filter mode
    _identifierController = TextEditingController(
      text: _filterMode == FilterMode.mwNum 
          ? (widget.mwNum ?? '')
          : (widget.controlCode ?? ''),
    );
  }

  @override
  void dispose() {
    _tsNumFromController.dispose();
    _tsNumToController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _clearAllFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _tsNumFromController.clear();
      _tsNumToController.clear();
      _identifierController.clear();
    });
  }

  void _applyFilters() {
    final filter = DbFilter(
      startDate: _startDate,
      endDate: _endDate,
      tsNumFrom: _tsNumFromController.text.trim(),
      tsNumTo: _tsNumToController.text.trim(),
      mwNum: _filterMode == FilterMode.mwNum ? _identifierController.text.trim() : null,
      controlCode: _filterMode == FilterMode.controlCode ? _identifierController.text.trim() : null,
      filterMode: _filterMode,
    );
    Navigator.pop(context, filter);
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600]!,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onTap,
                    child: Text(
                      date != null ? _dateFormat.format(date) : 'Select date',
                      style: TextStyle(
                        fontSize: 16,
                        color: date != null ? Colors.black : Colors.grey[400]!,
                        fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (date != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            IconButton(
              icon: const Icon(Icons.calendar_today, size: 20),
              onPressed: onTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentifierFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Identifier Filter',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        // Filter mode selector
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('By MwNum'),
                selected: _filterMode == FilterMode.mwNum,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _filterMode = FilterMode.mwNum;
                      _identifierController.clear();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('By Control Code'),
                selected: _filterMode == FilterMode.controlCode,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _filterMode = FilterMode.controlCode;
                      _identifierController.clear();
                    });
                  }
                },
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Identifier input field
        TextField(
          controller: _identifierController,
          decoration: InputDecoration(
            labelText: _filterMode == FilterMode.mwNum ? 'MwNum' : 'Control Code',
            hintText: _filterMode == FilterMode.mwNum 
                ? 'Enter Machine/Control Number' 
                : 'Enter Control Code',
            border: const OutlineInputBorder(),
            prefixIcon: Icon(_filterMode == FilterMode.mwNum 
                ? Icons.confirmation_number 
                : Icons.qr_code),
            suffixIcon: _identifierController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () => _identifierController.clear(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : null,
          ),
        ),
        
        const SizedBox(height: 8),
        Text(
          _filterMode == FilterMode.mwNum
              ? 'Filter by Machine/Control Number'
              : 'Filter by Transaction Control Code',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Database Filters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set filters to query transactions from the database',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),

                // Date Range Section
                const Text(
                  'Date Range (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDatePickerField(
                        label: 'Start Date',
                        date: _startDate,
                        onTap: () => _selectStartDate(context),
                        onClear: () => setState(() => _startDate = null),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDatePickerField(
                        label: 'End Date',
                        date: _endDate,
                        onTap: () => _selectEndDate(context),
                        onClear: () => setState(() => _endDate = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_startDate != null && _endDate != null)
                  Text(
                    'Selected: ${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 24),

                // TsNum Range Section
                const Text(
                  'Transaction Number Range (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tsNumFromController,
                        decoration: const InputDecoration(
                          labelText: 'TsNum From',
                          hintText: 'e.g., INV001',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.code),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _tsNumToController,
                        decoration: const InputDecoration(
                          labelText: 'TsNum To',
                          hintText: 'e.g., INV100',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.code),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Identifier Filter Section
                _buildIdentifierFilterSection(),
                
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear All'),
                      onPressed: _clearAllFilters,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _applyFilters,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Apply Filters'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DbFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String tsNumFrom;
  final String tsNumTo;
  final String? mwNum;
  final String? controlCode;
  final FilterMode filterMode;

  DbFilter({
    this.startDate,
    this.endDate,
    required this.tsNumFrom,
    required this.tsNumTo,
    this.mwNum,
    this.controlCode,
    this.filterMode = FilterMode.mwNum,
  });
}

enum FilterMode {
  mwNum,
  controlCode,
}