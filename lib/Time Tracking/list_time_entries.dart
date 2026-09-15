import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart'; // Ensure this points to your theme file
import 'add_time_entry.dart'; // IMPORT YOUR ADD TIME ENTRY SCREEN HERE

class TimeEntriesScreen extends StatefulWidget {
  const TimeEntriesScreen({Key? key}) : super(key: key);

  @override
  State<TimeEntriesScreen> createState() => _TimeEntriesScreenState();
}

class _TimeEntriesScreenState extends State<TimeEntriesScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _timeEntries = [];
  List<dynamic> _projects = [];

  final String _apiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_time_entries';
  final String _projectsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_projects';

  // Statistics
  double _totalHours = 0.0;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');
      final bool isClient = prefs.getBool('isClient') ?? false;
      final String? clientId = prefs.getString('clientId');

      // Fetch both projects and time entries concurrently
      final responses = await Future.wait([
        http.get(Uri.parse(_projectsApiUrl)),
        http.get(Uri.parse(_apiUrl)),
      ]);

      final projectsData = json.decode(responses[0].body);
      final entriesData = json.decode(responses[1].body);

      if (projectsData['status'] == 'success') {
        _projects = projectsData['data'] ?? [];
      }

      if (entriesData['status'] == 'success') {
        List<dynamic> allEntries = entriesData['data'] ?? [];

        // Apply filters based on logged-in user type
        setState(() {
          if (isClient && clientId != null && clientId.isNotEmpty) {
            _timeEntries = allEntries.where((entry) {
              return entry['client_id']?.toString() == clientId;
            }).toList();
          } else if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
            _timeEntries = allEntries.where((entry) {
              return entry['company_id']?.toString() == savedCompanyId;
            }).toList();
          } else {
            _timeEntries = allEntries;
          }
          _errorMessage = '';
          _calculateTotals();
        });
      } else {
        setState(() => _errorMessage = "Failed to load time entries.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Connection error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateTotals() {
    _totalHours = 0.0;
    _totalAmount = 0.0;
    for (var entry in _timeEntries) {
      _totalHours += double.tryParse(entry['hours']?.toString() ?? '0') ?? 0.0;
      _totalAmount += double.tryParse(entry['amount']?.toString() ?? '0') ?? 0.0;
    }
  }

  String _getProjectName(String? projectId) {
    if (projectId == null) return 'Unknown Project';
    final project = _projects.firstWhere(
          (p) => p['id'].toString() == projectId,
      orElse: () => null,
    );
    return project != null ? project['project_name'] ?? 'Unknown Project' : 'Unknown Project';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      default: return AppColors.textMuted;
    }
  }

  // UPDATE ENTRY STATUS (APPROVE / REJECT)
  Future<void> _updateEntryStatus(String id, String newStatus) async {
    setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String userId = prefs.getString('user_id') ?? '1';

      final now = DateTime.now();
      String formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      final Map<String, dynamic> payload = {
        'id': id,
        'status': newStatus,
      };

      if (newStatus == 'approved') {
        payload['approved_by'] = userId;
        payload['approved_at'] = formattedDate;
      } else if (newStatus == 'rejected') {
        payload['approved_by'] = null;
        payload['approved_at'] = null;
      }

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );
      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        _showSnackbar("Time entry $newStatus successfully.", isError: false);
        _fetchData();
      } else {
        _showSnackbar(data['message'] ?? "Failed to update status.", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar("Error updating status: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEntry(String id) async {
    Navigator.pop(context); // Close the dialog
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"action": "delete", "id": id}),
      );
      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        _showSnackbar("Time entry deleted successfully.", isError: false);
        _fetchData();
      } else {
        _showSnackbar(data['message'] ?? "Failed to delete.", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar("Error deleting entry: $e", isError: true);
      setState(() => _isLoading = false);
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

  void _confirmDelete(Map<String, dynamic> entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Confirm Deletion", style: TextStyle(color: AppColors.textWhite)),
        content: const Text("Are you sure you want to delete this time entry? This cannot be undone.",
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: () => _deleteEntry(entry['id'].toString()),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
        title: const Text("Time Logs", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentCyan,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTimeEntryScreen()),
          );
          if (result == true) {
            _fetchData();
          }
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentCyan));
    }
    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage, style: const TextStyle(color: AppColors.dangerRed)));
    }

    return RefreshIndicator(
      color: AppColors.accentCyan,
      backgroundColor: AppColors.surface,
      onRefresh: _fetchData,
      child: CustomScrollView(
        slivers: [
          if (_timeEntries.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildSummaryCards(),
              ),
            ),

          if (_timeEntries.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_off_outlined, size: 64, color: AppColors.textMuted),
                    SizedBox(height: 16),
                    Text("No time entries found.", style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildTimeEntryCard(_timeEntries[index]),
                  ),
                  childCount: _timeEntries.length,
                ),
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
              children: [
                const Icon(Icons.schedule, color: AppColors.accentCyan, size: 24),
                const SizedBox(height: 8),
                Text(
                  "${_totalHours.toStringAsFixed(1)}h",
                  style: const TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text("Total Hours", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
              children: [
                const Icon(Icons.attach_money, color: Colors.green, size: 24),
                const SizedBox(height: 8),
                Text(
                  "\$${_totalAmount.toStringAsFixed(2)}",
                  style: const TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text("Total Amount", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeEntryCard(Map<String, dynamic> entry) {
    final status = entry['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final projectName = _getProjectName(entry['project_id']?.toString());
    final isBillable = entry['is_billable'] == '1';
    final entryId = entry['id'].toString();

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
          // Header: Username & Actions (Approve, Reject, Delete)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.accentCyan.withOpacity(0.1),
                radius: 20,
                child: const Icon(Icons.person, color: AppColors.accentCyan, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry['user_name'] ?? 'Unknown User',
                      style: const TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry['date'] ?? 'N/A',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),

              // APPROVE BUTTON (Check / Write icon)
              // APPROVE BUTTON (Check / Write icon)
              if (status.toLowerCase() != 'approved')
                Tooltip(
                  message: "Approve",
                  child: InkWell(
                    onTap: () => _updateEntryStatus(entryId, 'approved'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(Icons.check_circle_outline, color: Colors.green, size: 22),
                    ),
                  ),
                ),

              // REJECT BUTTON (Wrong / Cross icon)
              if (status.toLowerCase() != 'rejected')
                Tooltip(
                  message: "Reject",
                  child: InkWell(
                    onTap: () => _updateEntryStatus(entryId, 'rejected'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(Icons.cancel_outlined, color: Colors.orange, size: 22),
                    ),
                  ),
                ),

              // DELETE BUTTON
              Tooltip(
                message: "Delete",
                child: InkWell(
                  onTap: () => _confirmDelete(entry),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Icon(Icons.delete_outline, color: AppColors.dangerRed, size: 22),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.borderDark, height: 1),
          const SizedBox(height: 16),

          // Project Row
          Row(
            children: [
              const Icon(Icons.work_outline, color: AppColors.textMuted, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  projectName,
                  style: const TextStyle(color: AppColors.textWhite, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              if (isBillable)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text("BILLABLE", style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Time & Money Info Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn("Hours", "${entry['hours'] ?? '0'}h", Icons.timer_outlined),
                _buildInfoColumn("Rate", "\$${entry['hourly_rate'] ?? '0'}/h", Icons.payments_outlined),
                _buildInfoColumn("Total", "\$${entry['amount'] ?? '0'}", Icons.account_balance_wallet_outlined, highlight: true),
              ],
            ),
          ),

          // Description (If available)
          if (entry['description'] != null && entry['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text("Notes:", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              entry['description'],
              style: const TextStyle(color: AppColors.textWhite, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, IconData icon, {bool highlight = false}) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppColors.accentCyan : AppColors.textWhite,
            fontSize: 14,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}