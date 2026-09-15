import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'add_invoice.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({Key? key}) : super(key: key);

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _invoices = [];
  List<dynamic> _clients = [];
  List<dynamic> _projects = [];

  final String _apiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_invoices';
  final String _clientsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_clients';
  final String _projectsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_projects';

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _fetchProjects();
    _fetchInvoices();
  }

  Future<void> _fetchClients() async {
    try {
      final response = await http.get(Uri.parse(_clientsApiUrl));
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _clients = data['data'] ?? [];
        });
      }
    } catch (e) {
      print("Error fetching clients: $e");
    }
  }

  Future<void> _fetchProjects() async {
    try {
      final response = await http.get(Uri.parse(_projectsApiUrl));
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _projects = data['data'] ?? [];
        });
      }
    } catch (e) {
      print("Error fetching projects: $e");
    }
  }

  String _getClientName(String? clientId) {
    if (clientId == null) return 'Unknown';
    final client = _clients.firstWhere(
          (c) => c['id'].toString() == clientId,
      orElse: () => null,
    );
    return client != null ? client['company_name'] ?? 'Unknown' : 'Unknown';
  }

  String _getProjectName(String? projectId) {
    if (projectId == null) return 'Not specified';
    final project = _projects.firstWhere(
          (p) => p['id'].toString() == projectId,
      orElse: () => null,
    );
    return project != null ? project['project_name'] ?? 'Unknown' : 'Unknown';
  }

  Future<void> _fetchInvoices() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      final response = await http.get(Uri.parse(_apiUrl));
      final data = json.decode(response.body);

      if (data['status'] == "success") {
        List<dynamic> allInvoices = data['data'] ?? [];

        setState(() {
          if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
            _invoices = allInvoices.where((invoice) {
              return invoice['company_id']?.toString() == savedCompanyId;
            }).toList();
          } else {
            _invoices = allInvoices;
          }
          _errorMessage = '';
        });
      } else {
        setState(() => _errorMessage = "Failed to load invoices.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Connection error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteInvoice(String id) async {
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"action": "delete", "id": id}),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        _showSnackbar("Invoice deleted successfully.", isError: false);
        _fetchInvoices();
      } else {
        _showSnackbar(data['message'] ?? "Failed to delete.", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar("Error deleting invoice: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateInvoiceStatus(String id, String newStatus) async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id": id, "status": newStatus}),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        _showSnackbar("Invoice status updated to $newStatus.", isError: false);
        _fetchInvoices();
      } else {
        _showSnackbar(data['message'] ?? "Failed to update status.", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar("Error updating status: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _editInvoice(Map<String, dynamic> invoice) async {
    // Navigate to create invoice screen with invoice data for editing
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateInvoiceScreen(invoiceData: invoice),
      ),
    );

    if (result == true) {
      _fetchInvoices();
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppColors.dangerRed : AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Confirm Deletion", style: TextStyle(color: AppColors.textWhite)),
        content: Text("Delete invoice '${invoice['invoice_number']}'? This cannot be undone.",
            style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: () => _deleteInvoice(invoice['id'].toString()),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft': return Colors.grey;
      case 'sent': return Colors.blue;
      case 'paid': return Colors.green;
      case 'overdue': return Colors.red;
      default: return AppColors.textMuted;
    }
  }

  String _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'draft': return '📝';
      case 'sent': return '📧';
      case 'paid': return '✅';
      case 'overdue': return '⚠️';
      default: return '📄';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.premiumGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Invoices", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: "Create Invoice",
              onPressed: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateInvoiceScreen(invoiceData: {},))
                );
                if (result == true) {
                  _fetchInvoices();
                }
              },
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentCyan));
    }
    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage, style: const TextStyle(color: AppColors.dangerRed)));
    }
    if (_invoices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_outlined, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text("No invoices found.", style: TextStyle(color: AppColors.textMuted)),
            SizedBox(height: 8),
            Text("Tap the + button to create your first invoice",
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accentCyan,
      backgroundColor: AppColors.surface,
      onRefresh: _fetchInvoices,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _invoices.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final invoice = _invoices[index];
          final status = (invoice['status'] ?? 'draft').toString().toLowerCase();
          final statusColor = _getStatusColor(status);
          final statusIcon = _getStatusIcon(status);
          final clientName = _getClientName(invoice['client_id']?.toString());
          final totalAmount = double.tryParse(invoice['total_amount']?.toString() ?? '0') ?? 0;
          final isOverdue = status == 'sent' &&
              invoice['due_date'] != null &&
              invoice['due_date'].toString() != '0000-00-00' &&
              DateTime.parse(invoice['due_date']).isBefore(DateTime.now());

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.receipt, color: statusColor, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invoice['invoice_number'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textWhite,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  clientName,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(statusIcon, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                      color: AppColors.surface,
                      onSelected: (value) {
                        if (value == 'view') {
                          _showInvoiceDetails(invoice);
                        }
                        if (value == 'edit') {
                          _editInvoice(invoice);
                        }
                        if (value == 'delete') _confirmDelete(invoice);
                        if (value == 'mark_sent') _updateInvoiceStatus(invoice['id'].toString(), 'sent');
                        if (value == 'mark_paid') _updateInvoiceStatus(invoice['id'].toString(), 'paid');
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'view',
                            child: Row(children: [
                              Icon(Icons.visibility_outlined, color: AppColors.textWhite, size: 18),
                              SizedBox(width: 8),
                              Text('View Details', style: TextStyle(color: AppColors.textWhite))
                            ])
                        ),
                        const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit_outlined, color: AppColors.textWhite, size: 18),
                              SizedBox(width: 8),
                              Text('Edit', style: TextStyle(color: AppColors.textWhite))
                            ])
                        ),
                        if (status == 'draft')
                          const PopupMenuItem(
                              value: 'mark_sent',
                              child: Row(children: [
                                Icon(Icons.send_outlined, color: Colors.blue, size: 18),
                                SizedBox(width: 8),
                                Text('Mark as Sent', style: TextStyle(color: Colors.blue))
                              ])
                          ),
                        if (status == 'sent')
                          const PopupMenuItem(
                              value: 'mark_paid',
                              child: Row(children: [
                                Icon(Icons.payments_outlined, color: Colors.green, size: 18),
                                SizedBox(width: 8),
                                Text('Mark as Paid', style: TextStyle(color: Colors.green))
                              ])
                          ),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete_outline, color: AppColors.dangerRed, size: 18),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: AppColors.dangerRed))
                            ])
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderDark),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      "Date: ${invoice['invoice_date'] ?? 'N/A'}",
                      style: const TextStyle(color: AppColors.textWhite, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.event_busy, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      "Due: ${invoice['due_date'] ?? 'N/A'}",
                      style: TextStyle(
                        color: isOverdue ? AppColors.dangerRed : AppColors.textWhite,
                        fontSize: 12,
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.attach_money, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      "Total: ₹${totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(color: AppColors.accentCyan, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.payment, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      "Paid: ₹${double.tryParse(invoice['amount_paid']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0'}",
                      style: const TextStyle(color: AppColors.textWhite, fontSize: 12),
                    ),
                  ],
                ),
                if (invoice['po_number'] != null && invoice['po_number'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "PO: ${invoice['po_number']}",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showInvoiceDetails(Map<String, dynamic> invoice) {
    final items = _parseItems(invoice['items']);
    final expenses = _parseExpenses(invoice['expenses']);
    final totalAmount = double.tryParse(invoice['total_amount']?.toString() ?? '0') ?? 0;
    final taxAmount = double.tryParse(invoice['tax_amount']?.toString() ?? '0') ?? 0;
    final discountAmount = double.tryParse(invoice['discount_amount']?.toString() ?? '0') ?? 0;
    final subtotal = double.tryParse(invoice['subtotal']?.toString() ?? '0') ?? 0;
    final expensesTotal = double.tryParse(invoice['expenses_total']?.toString() ?? '0') ?? 0;
    final projectName = _getProjectName(invoice['project_id']?.toString());

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderDark)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice['invoice_number'] ?? 'Invoice',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textWhite),
                          ),
                          Text(
                            _getClientName(invoice['client_id']?.toString()),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow("Invoice Date", invoice['invoice_date'] ?? 'N/A'),
                      _detailRow("Due Date", invoice['due_date'] ?? 'N/A'),
                      if (projectName != 'Not specified')
                        _detailRow("Project", projectName),
                      if (invoice['po_number'] != null && invoice['po_number'].toString().isNotEmpty)
                        _detailRow("PO Number", invoice['po_number']),
                      if (invoice['period_start'] != null && invoice['period_end'] != null)
                        _detailRow("Period", "${invoice['period_start']} to ${invoice['period_end']}"),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.borderDark),
                      const SizedBox(height: 8),
                      const Text("Items", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (items.isEmpty)
                        const Text("No items", style: TextStyle(color: AppColors.textMuted, fontSize: 12))
                      else
                        ...items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "${item['description']} (${item['quantity']} ${item['unit']} × ₹${item['unit_price']})",
                                  style: const TextStyle(color: AppColors.textWhite, fontSize: 12),
                                ),
                              ),
                              Text(
                                "₹${(double.tryParse(item['quantity']?.toString() ?? '0')! * double.tryParse(item['unit_price']?.toString() ?? '0')!).toStringAsFixed(2)}",
                                style: const TextStyle(color: AppColors.accentCyan, fontSize: 12),
                              ),
                            ],
                          ),
                        )),
                      const SizedBox(height: 16),
                      if (expenses.isNotEmpty) ...[
                        const Text("Expenses", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...expenses.map((expense) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(expense['description'] ?? 'Expense', style: const TextStyle(color: AppColors.textWhite, fontSize: 12)),
                              Text("₹${expense['amount'] ?? '0'}", style: const TextStyle(color: AppColors.accentCyan, fontSize: 12)),
                            ],
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],
                      const Divider(color: AppColors.borderDark),
                      _summaryRow("Subtotal", subtotal),
                      if (expensesTotal > 0) _summaryRow("Expenses", expensesTotal),
                      if (discountAmount > 0) _summaryRow("Discount", -discountAmount),
                      if (taxAmount > 0) _summaryRow("Tax (${invoice['tax_percentage']}%)", taxAmount),
                      const Divider(color: AppColors.borderDark),
                      _summaryRow("Total", totalAmount, isBold: true, isLarge: true),
                      const SizedBox(height: 16),
                      if (invoice['notes'] != null && invoice['notes'].toString().isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Notes", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(invoice['notes'], style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      const SizedBox(height: 12),
                      if (invoice['terms'] != null && invoice['terms'].toString().isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Terms", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(invoice['terms'], style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.borderDark)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close", style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _parseItems(dynamic items) {
    if (items == null || items.toString().isEmpty || items.toString() == '[]') return [];
    try {
      List<dynamic> list = json.decode(items);
      return list.map((item) => {
        'description': item['description'] ?? '',
        'quantity': item['quantity']?.toString() ?? '0',
        'unit': item['unit'] ?? '',
        'unit_price': item['unit_price']?.toString() ?? '0',
      }).toList();
    } catch (e) {
      return [];
    }
  }

  List<Map<String, dynamic>> _parseExpenses(dynamic expenses) {
    if (expenses == null || expenses.toString().isEmpty || expenses.toString() == '[]') return [];
    try {
      List<dynamic> list = json.decode(expenses);
      return list.map((expense) => {
        'description': expense['description'] ?? '',
        'amount': expense['amount']?.toString() ?? '0',
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text("$label:", style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.textWhite, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool isBold = false, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: isLarge ? 14 : 12)),
          Text(
            value >= 0 ? "₹${value.toStringAsFixed(2)}" : "-₹${(-value).toStringAsFixed(2)}",
            style: TextStyle(
              color: isLarge ? AppColors.accentCyan : (isBold ? AppColors.textWhite : AppColors.textWhite),
              fontSize: isLarge ? 18 : 12,
              fontWeight: isLarge ? FontWeight.bold : (isBold ? FontWeight.w600 : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
}