import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final Map<String, dynamic>? invoiceData;

  const CreateInvoiceScreen({Key? key, this.invoiceData}) : super(key: key);

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  bool _isSaving = false;
  List<dynamic> _clients = [];
  List<dynamic> _projects = [];
  List<dynamic> _timesheetEntries = [];
  bool _isLoadingClients = true;
  bool _isLoadingProjects = true;
  bool _isLoadingTimesheets = false;

  String? _existingInvoiceNumber;

  // Auto-generated Invoice Number (or retains existing if editing)
  String get _invoiceNumber {
    if (_existingInvoiceNumber != null && _existingInvoiceNumber!.isNotEmpty) {
      return _existingInvoiceNumber!;
    }
    final now = DateTime.now();
    final yearMonth = "${now.year}${now.month.toString().padLeft(2, '0')}";
    final random = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return "INV-$yearMonth-$random";
  }

  // Invoice Details Controllers
  String? selectedClientId;
  String selectedClientName = 'Select Client';
  String? selectedProjectId;
  String selectedProjectName = 'Select Project (Optional)';
  final invoiceDateCtrl = TextEditingController();
  final dueDateCtrl = TextEditingController();
  final periodFromCtrl = TextEditingController();
  final periodToCtrl = TextEditingController();
  final poNumberCtrl = TextEditingController();

  // Manual Invoice Items
  List<Map<String, dynamic>> manualItems = [];

  // Additional Expenses
  List<Map<String, String>> expenses = [];

  // Tax & Discount
  final taxRateCtrl = TextEditingController(text: '18');
  final discountRateCtrl = TextEditingController(text: '0');

  // Notes & Terms
  final notesCtrl = TextEditingController();
  final termsCtrl = TextEditingController(text: 'Payment is due within 30 days. Please include invoice number with payment.');

  // Timesheet Selection
  DateTimeRange? _selectedDateRange;
  String? _timesheetProjectId;

  // Calculated totals
  double _timesheetTotal = 0.0;
  double _manualItemsTotal = 0.0;
  double _expensesTotal = 0.0;
  double _taxAmount = 0.0;
  double _discountAmount = 0.0;
  double _grandTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _fetchProjects();

    // Check if we are editing an existing invoice
    if (widget.invoiceData != null && widget.invoiceData!.isNotEmpty) {
      _loadExistingData(widget.invoiceData!);
    } else {
      // Set default dates for a new invoice
      final now = DateTime.now();
      invoiceDateCtrl.text = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      dueDateCtrl.text = "${now.year}-${now.month.toString().padLeft(2, '0')}-${(now.day + 30).toString().padLeft(2, '0')}";
    }
  }

  void _loadExistingData(Map<String, dynamic> d) {
    _existingInvoiceNumber = d['invoice_number']?.toString();
    selectedClientId = d['client_id']?.toString();
    selectedProjectId = d['project_id']?.toString();

    invoiceDateCtrl.text = d['invoice_date']?.toString() ?? '';
    dueDateCtrl.text = d['due_date']?.toString() ?? '';
    periodFromCtrl.text = d['period_start']?.toString() ?? '';
    periodToCtrl.text = d['period_end']?.toString() ?? '';
    poNumberCtrl.text = d['po_number']?.toString() ?? '';

    taxRateCtrl.text = d['tax_percentage']?.toString() ?? '18';
    discountRateCtrl.text = d['discount_percentage']?.toString() ?? '0';
    notesCtrl.text = d['notes']?.toString() ?? '';
    termsCtrl.text = d['terms']?.toString() ?? '';

    // Load Items
    if (d['items'] != null && d['items'].toString().isNotEmpty && d['items'].toString() != 'null') {
      try {
        List<dynamic> parsedItems = json.decode(d['items']);
        manualItems = parsedItems.map((item) => {
          'description': item['description']?.toString() ?? '',
          'quantity': item['quantity']?.toString() ?? '1',
          'unit': item['unit']?.toString() ?? 'hours',
          'unit_price': item['unit_price']?.toString() ?? '0',
          'amount': (double.tryParse(item['quantity']?.toString() ?? '0') ?? 0) *
              (double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0),
        }).toList();
      } catch (e) {}
    }

    // Load Expenses
    if (d['expenses'] != null && d['expenses'].toString().isNotEmpty && d['expenses'].toString() != 'null') {
      try {
        List<dynamic> parsedExp = json.decode(d['expenses']);
        expenses = parsedExp.map((exp) => {
          'description': exp['description']?.toString() ?? '',
          'amount': exp['amount']?.toString() ?? '0',
        }).toList();
      } catch (e) {}
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateTotals());
  }

  Future<void> _fetchClients() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      final response = await http.get(Uri.parse('https://skydevs.skynetproduct.com/skydevs_API.php?table=skydevs_clients'));
      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        List<dynamic> allClients = data['data'] ?? [];
        setState(() {
          if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
            _clients = allClients.where((client) => client['company_id']?.toString() == savedCompanyId).toList();
          } else {
            _clients = allClients;
          }

          if (selectedClientId != null) {
            final c = _clients.firstWhere((c) => c['id'].toString() == selectedClientId, orElse: () => null);
            if (c != null) selectedClientName = c['company_name'] ?? 'Select Client';
          }
          _isLoadingClients = false;
        });
      } else {
        setState(() => _isLoadingClients = false);
      }
    } catch (e) {
      setState(() => _isLoadingClients = false);
    }
  }

  Future<void> _fetchProjects() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      final response = await http.get(Uri.parse('https://skydevs.skynetproduct.com/skydevs_API.php?table=skydevs_projects'));
      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        List<dynamic> allProjects = data['data'] ?? [];
        setState(() {
          if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
            _projects = allProjects.where((project) => project['company_id']?.toString() == savedCompanyId).toList();
          } else {
            _projects = allProjects;
          }

          if (selectedProjectId != null) {
            final p = _projects.firstWhere((p) => p['id'].toString() == selectedProjectId, orElse: () => null);
            if (p != null) selectedProjectName = p['project_name'] ?? 'Select Project (Optional)';
          }
          _isLoadingProjects = false;
        });
      } else {
        setState(() => _isLoadingProjects = false);
      }
    } catch (e) {
      setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _fetchTimesheetEntries() async {
    if (_timesheetProjectId == null || _selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select both project and date range"),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingTimesheets = true;
      _timesheetEntries = [];
      _timesheetTotal = 0.0;
    });

    try {
      await Future.delayed(const Duration(seconds: 1));

      List<dynamic> mockEntries = [
        {
          'date': '2026-05-15',
          'employee': 'John Doe',
          'task': 'API Development',
          'description': 'Created REST API endpoints',
          'hours': 8,
          'rate': 50,
          'amount': 400,
        },
        {
          'date': '2026-05-16',
          'employee': 'Jane Smith',
          'task': 'Frontend Integration',
          'description': 'Integrated API with UI',
          'hours': 6,
          'rate': 45,
          'amount': 270,
        },
      ];

      setState(() {
        _timesheetEntries = mockEntries;
        _timesheetTotal = mockEntries.fold(0.0, (sum, entry) => sum + (entry['amount'] as double));
        _calculateTotals();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading timesheets: $e"),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoadingTimesheets = false);
    }
  }

  void _addManualItem() {
    setState(() {
      manualItems.add({
        'description': 'Development Services',
        'quantity': '1',
        'unit': 'hours',
        'unit_price': '0',
        'amount': 0,
      });
      _calculateTotals();
    });
  }

  void _removeManualItem(int index) {
    setState(() {
      manualItems.removeAt(index);
      _calculateTotals();
    });
  }

  void _updateManualItem(int index, String field, String value) {
    setState(() {
      manualItems[index][field] = value;
      if (field == 'quantity' || field == 'unit_price') {
        double qty = double.tryParse(manualItems[index]['quantity']?.toString() ?? '0') ?? 0;
        double price = double.tryParse(manualItems[index]['unit_price']?.toString() ?? '0') ?? 0;
        manualItems[index]['amount'] = qty * price;
      }
      _calculateTotals();
    });
  }

  void _addExpense() {
    setState(() {
      expenses.add({'description': '', 'amount': '0'});
      _calculateTotals();
    });
  }

  void _removeExpense(int index) {
    setState(() {
      expenses.removeAt(index);
      _calculateTotals();
    });
  }

  void _updateExpense(int index, String field, String value) {
    setState(() {
      expenses[index][field] = value;
      _calculateTotals();
    });
  }

  void _calculateTotals() {
    setState(() {
      _manualItemsTotal = manualItems.fold(0.0, (sum, item) {
        return sum + (double.tryParse(item['amount']?.toString() ?? '0') ?? 0);
      });

      _expensesTotal = expenses.fold(0.0, (sum, expense) {
        return sum + (double.tryParse(expense['amount']?.toString() ?? '0') ?? 0);
      });

      double subtotal = _timesheetTotal + _manualItemsTotal;
      double taxRate = double.tryParse(taxRateCtrl.text) ?? 0;
      double discountRate = double.tryParse(discountRateCtrl.text) ?? 0;

      _discountAmount = subtotal * (discountRate / 100);
      double discountedSubtotal = subtotal - _discountAmount;
      _taxAmount = discountedSubtotal * (taxRate / 100);

      _grandTotal = discountedSubtotal + _expensesTotal + _taxAmount;
    });
  }

  Future<void> _saveInvoice() async {
    if (selectedClientId == null) {
      _showError("Please select a client.");
      return;
    }
    if (invoiceDateCtrl.text.trim().isEmpty) {
      _showError("Please select invoice date.");
      return;
    }
    if (dueDateCtrl.text.trim().isEmpty) {
      _showError("Please select due date.");
      return;
    }

    setState(() => _isSaving = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');
      final String? userId = prefs.getString('user_id');

      String itemsJson = json.encode(manualItems.map((item) {
        return {
          'description': item['description'],
          'quantity': item['quantity'],
          'unit': item['unit'],
          'unit_price': item['unit_price'],
        };
      }).toList());

      String expensesJson = json.encode(expenses.map((expense) {
        return {
          'description': expense['description'],
          'amount': expense['amount'],
        };
      }).toList());

      double subtotal = _timesheetTotal + _manualItemsTotal;

      final Map<String, dynamic> payload = {
        'company_id': savedCompanyId,
        'created_by': userId ?? '1',
        'invoice_number': _invoiceNumber,
        'po_number': poNumberCtrl.text.trim().isEmpty ? null : poNumberCtrl.text.trim(),
        'client_id': selectedClientId,
        'project_id': selectedProjectId,
        'invoice_date': invoiceDateCtrl.text.trim(),
        'due_date': dueDateCtrl.text.trim(),
        'period_start': periodFromCtrl.text.trim().isEmpty ? null : periodFromCtrl.text.trim(),
        'period_end': periodToCtrl.text.trim().isEmpty ? null : periodToCtrl.text.trim(),
        'subtotal': subtotal.toStringAsFixed(2),
        'expenses_total': _expensesTotal.toStringAsFixed(2),
        'tax_percentage': taxRateCtrl.text.trim(),
        'tax_amount': _taxAmount.toStringAsFixed(2),
        'discount_percentage': discountRateCtrl.text.trim(),
        'discount_amount': _discountAmount.toStringAsFixed(2),
        'total_amount': _grandTotal.toStringAsFixed(2),
        'status': 'draft',
        'items': itemsJson,
        'expenses': expensesJson,
        'notes': notesCtrl.text.trim(),
        'terms': termsCtrl.text.trim(),
      };

      if (widget.invoiceData != null && widget.invoiceData!['id'] != null) {
        payload['id'] = widget.invoiceData!['id'].toString();
      }

      final response = await http.post(
        Uri.parse('https://skydevs.skynetproduct.com/skydevs_API.php?table=skydevs_invoices'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Invoice saved successfully!"),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showError(data['message'] ?? "API error saving invoice.");
      }
    } catch (e) {
      _showError("Connection network exception: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: AppColors.dangerRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentCyan,
              onPrimary: Colors.black,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        periodFromCtrl.text = "${picked.start.year}-${picked.start.month.toString().padLeft(2, '0')}-${picked.start.day.toString().padLeft(2, '0')}";
        periodToCtrl.text = "${picked.end.year}-${picked.end.month.toString().padLeft(2, '0')}-${picked.end.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: Text(widget.invoiceData != null && widget.invoiceData!.isNotEmpty ? "Edit Invoice" : "Create Invoice",
            style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold)),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInvoiceNumberCard(),
            const SizedBox(height: 24),
            _buildInvoiceDetailsSection(),
            const SizedBox(height: 32),
            _buildTimesheetSection(),
            const SizedBox(height: 32),
            _buildManualItemsSection(),
            const SizedBox(height: 32),
            _buildExpensesSection(),
            const SizedBox(height: 32),
            _buildTaxDiscountSection(),
            const SizedBox(height: 32),
            _buildInvoiceSummary(),
            const SizedBox(height: 32),
            _buildNotesTermsSection(),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceNumberCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accentCyan.withOpacity(0.15), AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentCyan.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt, color: AppColors.accentCyan, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Invoice Number", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(_invoiceNumber, style: const TextStyle(color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Invoice Details", Icons.receipt_outlined),
        const SizedBox(height: 20),
        _buildClientDropdown(),
        const SizedBox(height: 16),
        _buildProjectDropdown(),
        const SizedBox(height: 16),
        _buildTextFieldRow([
          _buildDateField("Invoice Date *", invoiceDateCtrl, isRequired: true),
          _buildDateField("Due Date *", dueDateCtrl, isRequired: true),
        ]),
        const SizedBox(height: 16),
        _buildTextFieldRow([
          _buildDateField("Period From", periodFromCtrl, onTap: _selectDateRange),
          _buildDateField("Period To", periodToCtrl, onTap: _selectDateRange),
        ]),
        const SizedBox(height: 16),
        _buildTextField("PO Number", poNumberCtrl, hint: "Purchase Order Number"),
      ],
    );
  }

  Widget _buildTimesheetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Timesheet Entries Optional", Icons.access_time),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderDark)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _buildTimesheetProjectDropdown()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTimesheetDateRangeButton()),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchTimesheetEntries,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCyan, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                child: const Text("Load Entries", style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 20),
              if (_isLoadingTimesheets)
                const Center(child: CircularProgressIndicator())
              else if (_timesheetEntries.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.resolveWith((states) => AppColors.surface),
                    columns: const [
                      DataColumn(label: Text("Date", style: TextStyle(color: AppColors.textWhite))),
                      DataColumn(label: Text("Employee", style: TextStyle(color: AppColors.textWhite))),
                      DataColumn(label: Text("Task", style: TextStyle(color: AppColors.textWhite))),
                      DataColumn(label: Text("Description", style: TextStyle(color: AppColors.textWhite))),
                      DataColumn(label: Text("Hours", style: TextStyle(color: AppColors.textWhite))),
                      DataColumn(label: Text("Rate", style: TextStyle(color: AppColors.textWhite))),
                      DataColumn(label: Text("Amount", style: TextStyle(color: AppColors.textWhite))),
                    ],
                    rows: _timesheetEntries.map((entry) {
                      return DataRow(cells: [
                        DataCell(Text(entry['date'] ?? '', style: const TextStyle(color: AppColors.textWhite))),
                        DataCell(Text(entry['employee'] ?? '', style: const TextStyle(color: AppColors.textWhite))),
                        DataCell(Text(entry['task'] ?? '', style: const TextStyle(color: AppColors.textWhite))),
                        DataCell(Text(entry['description'] ?? '', style: const TextStyle(color: AppColors.textWhite))),
                        DataCell(Text(entry['hours']?.toString() ?? '0', style: const TextStyle(color: AppColors.textWhite))),
                        DataCell(Text("₹${entry['rate'] ?? 0}", style: const TextStyle(color: AppColors.textWhite))),
                        DataCell(Text("₹${entry['amount'] ?? 0}", style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold))),
                      ]);
                    }).toList(),
                  ),
                )
              else
                const Text("No timesheet entries loaded. Select project and date range.", style: TextStyle(color: AppColors.textMuted)),
              if (_timesheetEntries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text("Total: ", style: TextStyle(color: AppColors.textWhite)),
                      Text("${_timesheetEntries.length} h  ", style: const TextStyle(color: AppColors.textWhite)),
                      Text("₹${_timesheetTotal.toStringAsFixed(2)}", style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Manual Invoice Items", Icons.add_shopping_cart),
        const SizedBox(height: 16),
        if (manualItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderDark)),
            child: const Center(child: Text("No manual items added", style: TextStyle(color: AppColors.textMuted))),
          )
        else
          ...manualItems.asMap().entries.map((entry) {
            int index = entry.key;
            var item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderDark)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSimpleTextField("Description", item['description'] ?? '', (v) => _updateManualItem(index, 'description', v))),
                      IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed), onPressed: () => _removeManualItem(index)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      SizedBox(width: 100, child: _buildSimpleTextField("Qty", item['quantity']?.toString() ?? '1', (v) => _updateManualItem(index, 'quantity', v), isNumber: true)),
                      SizedBox(width: 120, child: _buildSimpleTextField("Unit Price", item['unit_price']?.toString() ?? '0', (v) => _updateManualItem(index, 'unit_price', v), isNumber: true)),
                      Container(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Total", style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text("₹${item['amount']?.toStringAsFixed(2) ?? '0'}", style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: _addManualItem,
            icon: const Icon(Icons.add_circle_outline, color: AppColors.accentCyan),
            label: const Text("Add Item", style: TextStyle(color: AppColors.accentCyan)),
          ),
        ),
      ],
    );
  }

  Widget _buildExpensesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Additional Expenses", Icons.receipt_long),
        const SizedBox(height: 16),
        if (expenses.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderDark)),
            child: const Center(child: Text("No expenses added", style: TextStyle(color: AppColors.textMuted))),
          )
        else
          ...expenses.asMap().entries.map((entry) {
            int index = entry.key;
            var expense = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderDark)),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width > 400 ? 200 : double.infinity,
                    child: _buildSimpleTextField("Expense Description", expense['description'] ?? '', (v) => _updateExpense(index, 'description', v)),
                  ),
                  SizedBox(width: 120, child: _buildSimpleTextField("Amount", expense['amount']?.toString() ?? '0', (v) => _updateExpense(index, 'amount', v), isNumber: true)),
                  IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed), onPressed: () => _removeExpense(index)),
                ],
              ),
            );
          }).toList(),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: _addExpense,
            icon: const Icon(Icons.add_circle_outline, color: AppColors.accentCyan),
            label: const Text("Add Expense", style: TextStyle(color: AppColors.accentCyan)),
          ),
        ),
      ],
    );
  }

  Widget _buildTaxDiscountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Tax & Discount", Icons.percent),
        const SizedBox(height: 16),
        _buildTextFieldRow([
          _buildTextField("Tax Rate (%)", taxRateCtrl, isNumber: true, onChanged: (_) => _calculateTotals()),
          _buildTextField("Discount Rate (%)", discountRateCtrl, isNumber: true, onChanged: (_) => _calculateTotals()),
        ]),
      ],
    );
  }

  Widget _buildInvoiceSummary() {
    double subtotal = _timesheetTotal + _manualItemsTotal;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Invoice Summary", Icons.calculate),
          const SizedBox(height: 16),
          _summaryRow("Subtotal (Timesheet):", "₹${_timesheetTotal.toStringAsFixed(2)}"),
          _summaryRow("Manual Items:", "₹${_manualItemsTotal.toStringAsFixed(2)}"),
          _summaryRow("Total Subtotal:", "₹${subtotal.toStringAsFixed(2)}", isBold: true),
          const Divider(color: AppColors.borderDark),
          _summaryRow("Expenses:", "₹${_expensesTotal.toStringAsFixed(2)}"),
          _summaryRow("Discount:", "-₹${_discountAmount.toStringAsFixed(2)}"),
          _summaryRow("Tax (GST):", "₹${_taxAmount.toStringAsFixed(2)}"),
          const Divider(color: AppColors.borderDark),
          _summaryRow("Total:", "₹${_grandTotal.toStringAsFixed(2)}", isLarge: true),
        ],
      ),
    );
  }

  Widget _buildNotesTermsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Notes & Terms", Icons.description_outlined),
        const SizedBox(height: 16),
        _buildTextField("Notes", notesCtrl, hint: "Additional notes for the client...", maxLines: 3),
        const SizedBox(height: 16),
        _buildTextField("Terms & Conditions", termsCtrl, hint: "Payment terms...", maxLines: 3),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentCyan,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isSaving ? null : _saveInvoice,
          child: const Text("Save Invoice", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentCyan, size: 22),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w600, fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: AppColors.borderDark, thickness: 1)),
      ],
    );
  }

  Widget _buildTextFieldRow(List<Widget> children) {
    return Column(
      children: children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 16), child: w)).toList(),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {String hint = '', bool isRequired = false, bool isNumber = false, int maxLines = 1, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (isRequired) const TextSpan(text: " *", style: TextStyle(color: AppColors.dangerRed)),
            ],
          ),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: _inputDeco("").copyWith(
            hintText: hint.isNotEmpty ? hint : (isRequired ? "Required" : "Optional"),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, {bool isRequired = false, VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (isRequired) const TextSpan(text: " *", style: TextStyle(color: AppColors.dangerRed)),
            ],
          ),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap ?? () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.accentCyan,
                      onPrimary: Colors.black,
                      surface: AppColors.surface,
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              controller.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderDark),
              color: AppColors.surface,
            ),
            child: Row(
              children: [
                Expanded(child: Text(controller.text.isEmpty ? "Select Date" : controller.text, style: TextStyle(color: controller.text.isEmpty ? AppColors.textMuted : AppColors.textWhite))),
                const Icon(Icons.calendar_today, size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // FIX APPLIED HERE: Added safety logic for Dropdown value
  Widget _buildClientDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text.rich(
          TextSpan(
            text: "Client",
            children: [
              TextSpan(text: " *", style: TextStyle(color: AppColors.dangerRed)),
            ],
          ),
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderDark)),
          child: _isLoadingClients
              ? const Padding(padding: EdgeInsets.all(14), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))))
              : DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _clients.any((c) => c['id'].toString() == selectedClientId) ? selectedClientId : null,
              isExpanded: true,
              hint: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(selectedClientName, style: const TextStyle(color: AppColors.textMuted))),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textWhite),
              items: [
                const DropdownMenuItem<String>(value: null, child: Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Text("Select Client", style: TextStyle(color: AppColors.textMuted)))),
                ..._clients.map((client) => DropdownMenuItem<String>(
                  value: client['id'].toString(),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(client['company_name'] ?? 'Unknown Client')),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  selectedClientId = value;
                  final selected = _clients.firstWhere((c) => c['id'].toString() == value, orElse: () => null);
                  selectedClientName = selected != null ? selected['company_name'] ?? 'Select Client' : 'Select Client';
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // FIX APPLIED HERE: Added safety logic for Dropdown value
  Widget _buildProjectDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Project", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderDark)),
          child: _isLoadingProjects
              ? const Padding(padding: EdgeInsets.all(14), child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))))
              : DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _projects.any((p) => p['id'].toString() == selectedProjectId) ? selectedProjectId : null,
              isExpanded: true,
              hint: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(selectedProjectName, style: const TextStyle(color: AppColors.textMuted))),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textWhite),
              items: [
                const DropdownMenuItem<String>(value: null, child: Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Text("Select Project (Optional)"))),
                ..._projects.map((project) => DropdownMenuItem<String>(
                  value: project['id'].toString(),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(project['project_name'] ?? 'Unknown Project')),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  selectedProjectId = value;
                  final selected = _projects.firstWhere((p) => p['id'].toString() == value, orElse: () => null);
                  selectedProjectName = selected != null ? selected['project_name'] ?? 'Select Project (Optional)' : 'Select Project (Optional)';
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // FIX APPLIED HERE: Added safety logic for Dropdown value
  Widget _buildTimesheetProjectDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Project", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.borderDark)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _projects.any((p) => p['id'].toString() == _timesheetProjectId) ? _timesheetProjectId : null,
              isExpanded: true,
              hint: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("Select Project")),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
              items: [
                ..._projects.map((project) => DropdownMenuItem<String>(
                  value: project['id'].toString(),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(project['project_name'] ?? 'Unknown')),
                )),
              ],
              onChanged: (value) => setState(() => _timesheetProjectId = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimesheetDateRangeButton() {
    String dateText = "Select Range";
    if (_selectedDateRange != null) {
      String start = "${_selectedDateRange!.start.year}-${_selectedDateRange!.start.month.toString().padLeft(2, '0')}-${_selectedDateRange!.start.day.toString().padLeft(2, '0')}";
      String end = "${_selectedDateRange!.end.year}-${_selectedDateRange!.end.month.toString().padLeft(2, '0')}-${_selectedDateRange!.end.day.toString().padLeft(2, '0')}";
      dateText = "$start to $end";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Date Range", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _selectDateRange,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.borderDark), color: AppColors.surface),
            child: Row(
              children: [
                Expanded(child: Text(dateText, style: const TextStyle(color: AppColors.textWhite, fontSize: 12), overflow: TextOverflow.ellipsis)),
                const Icon(Icons.date_range, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleTextField(String label, String value, Function(String) onChanged, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.borderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.accentCyan)),
            filled: true,
            fillColor: AppColors.surface,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: isLarge ? 16 : 14))),
          Text(value, style: TextStyle(color: isLarge ? AppColors.accentCyan : AppColors.textWhite, fontSize: isLarge ? 20 : 14, fontWeight: isLarge ? FontWeight.bold : (isBold ? FontWeight.w600 : FontWeight.normal))),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accentCyan)),
      filled: true,
      fillColor: AppColors.surface,
    );
  }
}