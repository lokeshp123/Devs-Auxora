import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String _errorMessage = '';

  // Data lists
  List<dynamic> _clients = [];
  List<dynamic> _projects = [];
  List<dynamic> _employees = [];

  // Filtered data
  List<dynamic> _filteredClients = [];
  List<dynamic> _filteredProjects = [];
  List<dynamic> _filteredEmployees = [];

  // Date range filter
  String _selectedDateRange = 'This Year';
  final List<String> _dateRangeOptions = [
    'This Week',
    'This Month',
    'Last Month',
    'This Quarter',
    'This Year',
    'Last Year',
    'All Time'
  ];

  // API URLs
  final String _clientsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_clients';
  final String _projectsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_projects';
  final String _employeesApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_employees';
  final String _invoicesApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_invoices';
  final String _bugsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_bugs';

  // Additional data for reports
  List<dynamic> _invoices = [];
  List<dynamic> _bugs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- SAFE DECODE HELPER ---
  dynamic _safeDecode(String responseBody) {
    String cleanBody = responseBody.trim();
    int startIndex = cleanBody.indexOf('{');
    if (startIndex > 0) {
      cleanBody = cleanBody.substring(startIndex);
    }
    return json.decode(cleanBody);
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      // Fetch all data in parallel
      final results = await Future.wait([
        http.get(Uri.parse(_clientsApiUrl)),
        http.get(Uri.parse(_projectsApiUrl)),
        http.get(Uri.parse(_employeesApiUrl)),
        http.get(Uri.parse(_invoicesApiUrl)),
        http.get(Uri.parse(_bugsApiUrl)),
      ]);

      // --- APPLIED SAFE DECODING HERE ---
      final clientsData = _safeDecode(results[0].body);
      final projectsData = _safeDecode(results[1].body);
      final employeesData = _safeDecode(results[2].body);
      final invoicesData = _safeDecode(results[3].body);
      final bugsData = _safeDecode(results[4].body);

      if (mounted) {
        setState(() {
          // Filter by company
          if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
            _clients = (clientsData['data'] ?? []).where((c) => c['company_id']?.toString() == savedCompanyId).toList();
            _projects = (projectsData['data'] ?? []).where((p) => p['company_id']?.toString() == savedCompanyId).toList();
            _employees = (employeesData['data'] ?? []).where((e) => e['company_id']?.toString() == savedCompanyId).toList();
            _invoices = (invoicesData['data'] ?? []).where((i) => i['company_id']?.toString() == savedCompanyId).toList();
            _bugs = (bugsData['data'] ?? []).where((b) => b['company_id']?.toString() == savedCompanyId).toList();
          } else {
            _clients = clientsData['data'] ?? [];
            _projects = projectsData['data'] ?? [];
            _employees = employeesData['data'] ?? [];
            _invoices = invoicesData['data'] ?? [];
            _bugs = bugsData['data'] ?? [];
          }

          _applyDateFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Connection error: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _applyDateFilter() {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedDateRange) {
      case 'This Week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'Last Month':
        startDate = DateTime(now.year, now.month - 1, 1);
        break;
      case 'This Quarter':
        int quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        startDate = DateTime(now.year, quarterStartMonth, 1);
        break;
      case 'This Year':
        startDate = DateTime(now.year, 1, 1);
        break;
      case 'Last Year':
        startDate = DateTime(now.year - 1, 1, 1);
        break;
      default:
        startDate = DateTime(2000);
    }

    // Filter clients by creation date
    _filteredClients = _clients.where((client) {
      final createdAt = client['created_at'];
      if (createdAt == null) return true;
      try {
        final date = DateTime.parse(createdAt);
        return date.isAfter(startDate);
      } catch (e) {
        return true;
      }
    }).toList();

    // Filter projects by creation date
    _filteredProjects = _projects.where((project) {
      final createdAt = project['created_at'];
      if (createdAt == null) return true;
      try {
        final date = DateTime.parse(createdAt);
        return date.isAfter(startDate);
      } catch (e) {
        return true;
      }
    }).toList();

    // Filter employees by joining date
    _filteredEmployees = _employees.where((employee) {
      final joiningDate = employee['joining_date'];
      if (joiningDate == null) return true;
      try {
        final date = DateTime.parse(joiningDate);
        return date.isAfter(startDate);
      } catch (e) {
        return true;
      }
    }).toList();
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  double _calculateProjectBurnRate(Map<String, dynamic> project) {
    final budget = double.tryParse(project['project_budget']?.toString() ?? '0') ?? 0;
    final burned = double.tryParse(project['actual_hours']?.toString() ?? '0') ?? 0;
    final hourlyRate = double.tryParse(project['hourly_rate']?.toString() ?? '0') ?? 0;
    final burnedAmount = burned * hourlyRate;
    return budget > 0 ? (burnedAmount / budget) * 100 : 0;
  }

  String _getProjectHealth(double burnRate) {
    if (burnRate < 50) return 'On Track';
    if (burnRate < 80) return 'At Risk';
    return 'Critical';
  }

  Color _getHealthColor(String health) {
    switch (health) {
      case 'On Track': return Colors.green;
      case 'At Risk': return Colors.orange;
      case 'Critical': return Colors.red;
      default: return AppColors.textMuted;
    }
  }

  void _showClientDetails(Map<String, dynamic> client) {
    showDialog(
      context: context,
      builder: (context) => ClientReportDialog(client: client),
    );
  }

  void _showProjectDetails(Map<String, dynamic> project) {
    showDialog(
      context: context,
      builder: (context) => ProjectReportDialog(project: project),
    );
  }

  void _showEmployeeDetails(Map<String, dynamic> employee) {
    showDialog(
      context: context,
      builder: (context) => EmployeeReportDialog(employee: employee),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.premiumGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Reports & Analytics", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentCyan,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accentCyan,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: "Clients"),
            Tab(icon: Icon(Icons.code), text: "Projects"),
            Tab(icon: Icon(Icons.people), text: "Employees"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date Range Filter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.borderDark)),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_alt, color: AppColors.accentCyan, size: 20),
                const SizedBox(width: 12),
                const Text("Date Range:", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDateRange,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: AppColors.textWhite),
                        items: _dateRangeOptions.map((option) {
                          return DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedDateRange = value;
                              _applyDateFilter();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
                : _errorMessage.isNotEmpty
                ? Center(child: Text(_errorMessage, style: const TextStyle(color: AppColors.dangerRed)))
                : TabBarView(
              controller: _tabController,
              children: [
                _buildClientReport(),
                _buildProjectReport(),
                _buildEmployeeReport(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CLIENT REPORT TAB
  // ==========================================
  Widget _buildClientReport() {
    if (_filteredClients.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 48, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text("No clients found for selected period", style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAllData,
      color: AppColors.accentCyan,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.resolveWith((states) => AppColors.surface),
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text("Client Name", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Industry", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Type", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Status", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Rating", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Projects", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Total Invoiced", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Actions", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
            ],
            rows: _filteredClients.map((client) {
              final clientId = client['id'].toString();
              final clientProjects = _projects.where((p) => p['client_id']?.toString() == clientId).toList();
              final clientInvoices = _invoices.where((i) => i['client_id']?.toString() == clientId).toList();
              final totalInvoiced = clientInvoices.fold(0.0, (sum, inv) {
                return sum + (double.tryParse(inv['total_amount']?.toString() ?? '0') ?? 0);
              });

              return DataRow(cells: [
                DataCell(Text(client['company_name'] ?? 'N/A', style: const TextStyle(color: AppColors.textWhite))),
                DataCell(Text(client['industry']?.toString().toUpperCase() ?? 'N/A', style: const TextStyle(color: AppColors.textWhite))),
                DataCell(Text(client['client_type']?.toString().toUpperCase() ?? 'N/A', style: const TextStyle(color: AppColors.textWhite))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: client['status'] == 'active' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      client['status']?.toString().toUpperCase() ?? 'N/A',
                      style: TextStyle(color: client['status'] == 'active' ? Colors.green : Colors.red, fontSize: 12),
                    ),
                  ),
                ),
                DataCell(Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(client['rating']?.toString() ?? 'N/A', style: const TextStyle(color: AppColors.textWhite)),
                  ],
                )),
                DataCell(Text(clientProjects.length.toString(), style: const TextStyle(color: AppColors.textWhite))),
                DataCell(Text(_formatCurrency(totalInvoiced), style: const TextStyle(color: AppColors.accentCyan))),
                DataCell(
                  TextButton(
                    onPressed: () => _showClientDetails(client),
                    style: TextButton.styleFrom(foregroundColor: AppColors.accentCyan),
                    child: const Text("View", style: TextStyle(fontSize: 12)),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // PROJECT REPORT TAB
  // ==========================================
  Widget _buildProjectReport() {
    if (_filteredProjects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code, size: 48, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text("No projects found for selected period", style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAllData,
      color: AppColors.accentCyan,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.resolveWith((states) => AppColors.surface),
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text("Project Name", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Progress", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Budget (₹)", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Burned (₹)", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Burn %", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Health", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Status", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Actions", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
            ],
            rows: _filteredProjects.map((project) {
              final budget = double.tryParse(project['project_budget']?.toString() ?? '0') ?? 0;
              final burnedHours = double.tryParse(project['actual_hours']?.toString() ?? '0') ?? 0;
              final hourlyRate = double.tryParse(project['hourly_rate']?.toString() ?? '0') ?? 0;
              final burnedAmount = burnedHours * hourlyRate;
              final burnRate = budget > 0 ? (burnedAmount / budget) * 100 : 0.0;
              final health = _getProjectHealth(burnRate);

              return DataRow(cells: [
                DataCell(Text(project['project_name'] ?? 'N/A', style: const TextStyle(color: AppColors.textWhite))),
                DataCell(
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (double.tryParse(project['progress']?.toString() ?? '0') ?? 0) / 100,
                            backgroundColor: AppColors.borderDark,
                            color: AppColors.accentCyan,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("${project['progress'] ?? '0'}%", style: const TextStyle(color: AppColors.textWhite, fontSize: 12)),
                    ],
                  ),
                ),
                DataCell(Text(_formatCurrency(budget), style: const TextStyle(color: AppColors.textWhite))),
                DataCell(Text(_formatCurrency(burnedAmount), style: const TextStyle(color: Colors.orange))),
                DataCell(Text("${burnRate.toStringAsFixed(1)}%", style: const TextStyle(color: AppColors.textWhite))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getHealthColor(health).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(health, style: TextStyle(color: _getHealthColor(health), fontSize: 12)),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: project['status'] == 'in_progress' ? Colors.blue.withOpacity(0.1) :
                      (project['status'] == 'completed' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      project['status']?.toString().toUpperCase().replaceAll('_', ' ') ?? 'N/A',
                      style: TextStyle(
                        color: project['status'] == 'in_progress' ? Colors.blue :
                        (project['status'] == 'completed' ? Colors.green : Colors.orange),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  TextButton(
                    onPressed: () => _showProjectDetails(project),
                    style: TextButton.styleFrom(foregroundColor: AppColors.accentCyan),
                    child: const Text("View", style: TextStyle(fontSize: 12)),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );  }

  // ==========================================
  // EMPLOYEE REPORT TAB
  // ==========================================
  Widget _buildEmployeeReport() {
    if (_filteredEmployees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 48, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text("No employees found for selected period", style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAllData,
      color: AppColors.accentCyan,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.resolveWith((states) => AppColors.surface),
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text("Employee Name", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Designation", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Department", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Status", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Work Mode", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Projects", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Bugs Fixed", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Actions", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold))),
            ],
            rows: _filteredEmployees.map((employee) {
              final employeeName = employee['full_name'] ?? 'N/A';
              final assignedBugs = _bugs.where((b) => b['assigned_to'] == employeeName).toList();
              final fixedBugs = assignedBugs.where((b) => b['status'] == 'fixed' || b['status'] == 'closed').toList();

              return DataRow(cells: [
                DataCell(Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person, size: 18, color: AppColors.accentCyan),
                    ),
                    const SizedBox(width: 8),
                    Text(employeeName, style: const TextStyle(color: AppColors.textWhite)),
                  ],
                )),
                DataCell(Text(employee['designation'] ?? 'N/A', style: const TextStyle(color: AppColors.textWhite))),
                DataCell(Text(employee['department'] ?? 'N/A', style: const TextStyle(color: AppColors.textWhite))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: employee['status'] == 'active' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      employee['status']?.toString().toUpperCase() ?? 'N/A',
                      style: TextStyle(color: employee['status'] == 'active' ? Colors.green : Colors.orange, fontSize: 11),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      Text(employee['work_mode'] == 'onsite' ? '🏢' : (employee['work_mode'] == 'remote' ? '🏠' : '💻'), style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(employee['work_mode']?.toString().toUpperCase() ?? 'N/A', style: const TextStyle(color: AppColors.textWhite, fontSize: 12)),
                    ],
                  ),
                ),
                DataCell(Text(assignedBugs.length.toString(), style: const TextStyle(color: AppColors.textWhite))),
                DataCell(Text(fixedBugs.length.toString(), style: const TextStyle(color: AppColors.accentCyan))),
                DataCell(
                  TextButton(
                    onPressed: () => _showEmployeeDetails(employee),
                    style: TextButton.styleFrom(foregroundColor: AppColors.accentCyan),
                    child: const Text("View", style: TextStyle(fontSize: 12)),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// CLIENT REPORT DETAILS DIALOG
// ==========================================
// CLIENT REPORT DETAILS DIALOG
// ==========================================
class ClientReportDialog extends StatelessWidget {
  final Map<String, dynamic> client;

  const ClientReportDialog({Key? key, required this.client}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.business, color: AppColors.accentCyan, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client['company_name'] ?? 'Client Details',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textWhite),
                          ),
                          Text(
                            "ID: ${client['unique_client_id'] ?? 'N/A'}",
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
                const SizedBox(height: 24),
                _detailRow("Industry", client['industry']?.toString().toUpperCase() ?? 'N/A'),
                _detailRow("Client Type", client['client_type']?.toString().toUpperCase() ?? 'N/A'),
                _detailRow("Status", client['status']?.toString().toUpperCase() ?? 'N/A'),
                _detailRow("Rating", client['rating']?.toString() ?? 'N/A'),
                _detailRow("Client Since", client['client_since'] ?? 'N/A'),
                _detailRow("Website", client['website'] ?? 'N/A'),
                _detailRow("GST/PAN", client['gst_pan'] ?? 'N/A'),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderDark),
                const SizedBox(height: 16),
                const Text("Primary Contact", style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _detailRow("Name", client['primary_contact_name'] ?? 'N/A'),
                _detailRow("Email", client['primary_contact_email'] ?? 'N/A'),
                _detailRow("Phone", client['primary_contact_phone'] ?? 'N/A'),
                if (client['secondary_contact_name'] != null && client['secondary_contact_name'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text("Secondary Contact", style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _detailRow("Name", client['secondary_contact_name'] ?? 'N/A'),
                  _detailRow("Email", client['secondary_contact_email'] ?? 'N/A'),
                  _detailRow("Phone", client['secondary_contact_phone'] ?? 'N/A'),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Close", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text("$label:", style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PROJECT REPORT DETAILS DIALOG
// ==========================================
class ProjectReportDialog extends StatelessWidget {
  final Map<String, dynamic> project;

  const ProjectReportDialog({Key? key, required this.project}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final budget = double.tryParse(project['project_budget']?.toString() ?? '0') ?? 0;
    final burnedHours = double.tryParse(project['actual_hours']?.toString() ?? '0') ?? 0;
    final hourlyRate = double.tryParse(project['hourly_rate']?.toString() ?? '0') ?? 0;
    final burnedAmount = burnedHours * hourlyRate;
    final burnRate = budget > 0 ? (burnedAmount / budget) * 100 : 0;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.code, color: AppColors.accentCyan, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project['project_name'] ?? 'Project Details',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textWhite),
                          ),
                          Text(
                            "ID: ${project['unique_project_id'] ?? 'N/A'}",
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
                const SizedBox(height: 24),
                _detailRow("Project Type", project['project_type']?.toString().toUpperCase().replaceAll('_', ' ') ?? 'N/A'),
                _detailRow("Methodology", project['methodology']?.toString().toUpperCase() ?? 'N/A'),
                _detailRow("Priority", project['priority']?.toString().toUpperCase() ?? 'N/A'),
                _detailRow("Status", project['status']?.toString().toUpperCase().replaceAll('_', ' ') ?? 'N/A'),
                _detailRow("Progress", "${project['progress'] ?? '0'}%"),
                _detailRow("Start Date", project['start_date'] ?? 'N/A'),
                _detailRow("End Date", project['end_date'] ?? 'N/A'),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderDark),
                const SizedBox(height: 16),
                const Text("Financial Summary", style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _detailRow("Budget", _formatCurrency(budget)),
                _detailRow("Burned (Hours)", "${burnedHours.toStringAsFixed(0)} hrs"),
                _detailRow("Burned (Amount)", _formatCurrency(burnedAmount)),
                _detailRow("Burn Rate", "${burnRate.toStringAsFixed(1)}%"),
                _detailRow("Hourly Rate", _formatCurrency(hourlyRate)),
                if (project['project_manager'] != null && project['project_manager'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderDark),
                  const SizedBox(height: 16),
                  const Text("Team", style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _detailRow("Project Manager", project['project_manager'] ?? 'N/A'),
                  _detailRow("Tech Lead", project['tech_lead'] ?? 'N/A'),
                ],
                if (project['description'] != null && project['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderDark),
                  const SizedBox(height: 16),
                  const Text("Description", style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    project['description'],
                    style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Close", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text("$label:", style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// EMPLOYEE REPORT DETAILS DIALOG
// ==========================================
class EmployeeReportDialog extends StatelessWidget {
  final Map<String, dynamic> employee;

  const EmployeeReportDialog({Key? key, required this.employee}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final salary = double.tryParse(employee['net_salary']?.toString() ?? '0') ?? 0;
    final ctc = double.tryParse(employee['ctc']?.toString() ?? '0') ?? 0;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person, color: AppColors.accentCyan, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee['full_name'] ?? 'Employee Details',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textWhite),
                          ),
                          Text(
                            employee['designation'] ?? 'N/A',
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
                const SizedBox(height: 24),
                const Text("Personal Information", style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _detailRow("Employee Code", employee['employee_code'] ?? 'N/A'),
                _detailRow("Email", employee['email'] ?? 'N/A'),
                _detailRow("Phone", employee['phone'] ?? 'N/A'),
                _detailRow("Department", employee['department'] ?? 'N/A'),
                _detailRow("Joining Date", employee['joining_date'] ?? 'N/A'),
                _detailRow("Employment Type", employee['employment_type']?.toString().toUpperCase() ?? 'N/A'),
                _detailRow("Work Mode", employee['work_mode']?.toString().toUpperCase() ?? 'N/A'),
                _detailRow("Status", employee['status']?.toString().toUpperCase() ?? 'N/A'),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderDark),
                const SizedBox(height: 16),
                const Text("Salary Details", style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _detailRow("CTC (Annual)", _formatCurrency(ctc)),
                _detailRow("Net Salary (Monthly)", _formatCurrency(salary)),
                if (employee['bank_name'] != null && employee['bank_name'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderDark),
                  const SizedBox(height: 16),
                  const Text("Bank Details", style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _detailRow("Bank Name", employee['bank_name'] ?? 'N/A'),
                  _detailRow("Account Number", employee['bank_account_number'] ?? 'N/A'),
                  _detailRow("IFSC Code", employee['ifsc_code'] ?? 'N/A'),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Close", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text("$label:", style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
