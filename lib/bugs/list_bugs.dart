import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'add_bugs.dart';

class BugListScreen extends StatefulWidget {
  const BugListScreen({Key? key}) : super(key: key);

  @override
  State<BugListScreen> createState() => _BugListScreenState();
}

class _BugListScreenState extends State<BugListScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _bugs = [];
  List<dynamic> _projects = [];

  final String _apiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_bugs';
  final String _projectsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_projects';

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _fetchBugs();
  }


  Future<void> _fetchProjects() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool isClient = prefs.getBool('isClient') ?? false;

      final response = await http.get(Uri.parse(_projectsApiUrl));
      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        List<dynamic> allProjects = data['data'] ?? [];

        if (isClient) {
          // ---------- CLIENT LOGIN ----------
          final String clientId = prefs.getString('clientId') ?? '';
          if (clientId.isNotEmpty) {
            allProjects = allProjects.where((p) {
              return p['client_id']?.toString() == clientId;
            }).toList();
          } else {
            allProjects = [];
          }
        } else {
          // ---------- ADMIN LOGIN ----------
          final String companyId = prefs.getString('company_id') ?? '';
          if (companyId.isNotEmpty) {
            allProjects = allProjects.where((p) {
              return p['company_id']?.toString() == companyId;
            }).toList();
          } else {
            allProjects = [];
          }
        }

        setState(() {
          _projects = allProjects;
        });
      }
    } catch (e) {
      print("Error fetching projects: $e");
    }
  }

  Future<void> _fetchBugs() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool isClient = prefs.getBool('isClient') ?? false;

      final response = await http.get(Uri.parse(_apiUrl));
      final data = json.decode(response.body);

      if (data['status'] == "success") {
        List<dynamic> allBugs = data['data'] ?? [];

        if (isClient) {
          // ---------- CLIENT LOGIN ----------
          final String clientId = prefs.getString('clientId') ?? '';
          if (clientId.isNotEmpty) {
            allBugs = allBugs.where((bug) {
              return bug['client_id']?.toString() == clientId;
            }).toList();
          } else {
            allBugs = [];
          }
        } else {
          // ---------- ADMIN LOGIN ----------
          final String companyId = prefs.getString('company_id') ?? '';
          if (companyId.isNotEmpty) {
            allBugs = allBugs.where((bug) {
              return bug['company_id']?.toString() == companyId;
            }).toList();
          } else {
            allBugs = [];
          }
        }

        setState(() {
          _bugs = allBugs;
          _errorMessage = '';
        });
      } else {
        setState(() => _errorMessage = "Failed to load bugs.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Connection error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getProjectName(String? projectId) {
    if (projectId == null) return 'Unknown';
    final project = _projects.firstWhere(
          (p) => p['id'].toString() == projectId,
      orElse: () => null,
    );
    return project != null ? project['project_name'] ?? 'Unknown' : 'Unknown';
  }


  Future<void> _deleteBug(String id) async {
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
        _showSnackbar("Bug deleted successfully.", isError: false);
        _fetchBugs();
      } else {
        _showSnackbar(data['message'] ?? "Failed to delete.", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar("Error deleting bug: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateBug(String id, Map<String, dynamic> updatedData) async {
    setState(() => _isLoading = true);

    try {
      updatedData['id'] = id;

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode(updatedData),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        _showSnackbar("Bug updated successfully.", isError: false);
        _fetchBugs();
      } else {
        _showSnackbar(data['message'] ?? "Failed to update.", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar("Error updating bug: $e", isError: true);
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

  void _confirmDelete(Map<String, dynamic> bug) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Confirm Deletion", style: TextStyle(color: AppColors.textWhite)),
        content: Text("Delete bug '${bug['title']}'? This cannot be undone.",
            style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: () => _deleteBug(bug['id'].toString()),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical': return Colors.red;
      case 'major': return Colors.orange;
      case 'minor': return Colors.blue;
      case 'trivial': return Colors.green;
      default: return AppColors.textMuted;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.green;
      default: return AppColors.textMuted;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'fixed': return Colors.green;
      case 'closed': return AppColors.textMuted;
      default: return AppColors.textMuted;
    }
  }

  String _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'open': return '🔴';
      case 'in_progress': return '🟡';
      case 'fixed': return '✅';
      case 'closed': return '❌';
      default: return '⚪';
    }
  }

  // ==== NEW: Method to show all bug details in a bottom sheet ====
  void _showBugDetails(Map<String, dynamic> bug) {
    final severity = (bug['severity'] ?? 'minor').toString().toLowerCase();
    final priority = (bug['priority'] ?? 'medium').toString().toLowerCase();
    final status = (bug['status'] ?? 'open').toString().toLowerCase();

    final severityColor = _getSeverityColor(severity);
    final priorityColor = _getPriorityColor(priority);
    final statusColor = _getStatusColor(status);
    final projectName = _getProjectName(bug['project_id']?.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85, // 85% of screen height
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Bug Code & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Text(
                      "BUG-ID: ${bug['bug_code'] ?? 'N/A'}",
                      style: const TextStyle(color: AppColors.textMuted, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title & Project
              Text(
                bug['title'] ?? 'Unknown Bug',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textWhite),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.hub_outlined, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text("Project: $projectName", style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 20),

              // Badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip("Status", status.toUpperCase(), statusColor),
                  _buildChip("Severity", severity.toUpperCase(), severityColor),
                  _buildChip("Priority", priority.toUpperCase(), priorityColor),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.borderDark),
              const SizedBox(height: 16),

              // Scrollable Details
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection("Description", bug['description'] ?? 'No description provided.'),
                      _buildDetailSection("Steps to Reproduce", bug['steps_to_reproduce'] ?? 'N/A'),

                      const SizedBox(height: 8),
                      const Divider(color: AppColors.borderDark),
                      const SizedBox(height: 16),

                      _buildInfoRow("Environment", bug['environment'] ?? 'N/A'),
                      _buildInfoRow("Browser / OS", bug['browser_os'] ?? 'N/A'),
                      _buildInfoRow("Reported By", bug['reported_by'] ?? 'System'),
                      _buildInfoRow("Assigned To", bug['assigned_to'] ?? 'Unassigned'),
                      _buildInfoRow("Created At", bug['created_at']?.toString() ?? 'N/A'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper for the Bottom Sheet
  Widget _buildDetailSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Text(
              content,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for the Bottom Sheet
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          ),
          Expanded(
            child: Text(
                value.isEmpty ? 'N/A' : value,
                style: const TextStyle(color: AppColors.textWhite, fontSize: 14, fontWeight: FontWeight.w500)
            ),
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
        title: const Text("Bug Tracker", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: "Report Bug",
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddBugScreen())
                ).then((_) => _fetchBugs());
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
    if (_bugs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bug_report_outlined, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text("No bugs reported.", style: TextStyle(color: AppColors.textMuted)),
            SizedBox(height: 8),
            Text("Tap the + button to report your first bug",
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accentCyan,
      backgroundColor: AppColors.surface,
      onRefresh: _fetchBugs,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _bugs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final bug = _bugs[index];
          final severity = (bug['severity'] ?? 'minor').toString().toLowerCase();
          final priority = (bug['priority'] ?? 'medium').toString().toLowerCase();
          final status = (bug['status'] ?? 'open').toString().toLowerCase();
          final severityColor = _getSeverityColor(severity);
          final priorityColor = _getPriorityColor(priority);
          final statusColor = _getStatusColor(status);
          final statusIcon = _getStatusIcon(status);
          final projectName = _getProjectName(bug['project_id']?.toString());

          return Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _showBugDetails(bug), // <--- ADDED ON TAP EVENT
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
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
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: severityColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.bug_report, color: severityColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bug['title'] ?? 'Unknown Bug',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textWhite
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "$statusIcon $projectName",
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                          color: AppColors.surface,
                          onSelected: (value) {
                            if (value == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditBugScreen(
                                    bug: bug,
                                    projects: _projects,
                                    onSave: (updatedData) {
                                      _updateBug(bug['id'].toString(), updatedData);
                                    },
                                  ),
                                ),
                              );
                            }
                            if (value == 'delete') _confirmDelete(bug);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit_outlined, color: AppColors.textWhite, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit', style: TextStyle(color: AppColors.textWhite))
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
                    const SizedBox(height: 12),
                    if (bug['description'] != null && bug['description'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          bug['description'],
                          style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const Divider(color: AppColors.borderDark),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip("Severity", severity.toUpperCase(), severityColor),
                        _buildChip("Priority", priority.toUpperCase(), priorityColor),
                        if (bug['assigned_to'] != null && bug['assigned_to'].toString().isNotEmpty)
                          _buildChip("Assigned", bug['assigned_to'], AppColors.accentCyan),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.code, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Bug ID: ${bug['bug_code'] ?? 'N/A'}",
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Reported by: ${bug['reported_by'] ?? 'System'}",
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (bug['created_at'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Created: ${bug['created_at']?.toString().split(' ')[0] ?? 'N/A'}",
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.comment_outlined, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Comments: ${_getCommentCount(bug['comments'])}",
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  int _getCommentCount(dynamic comments) {
    if (comments == null) return 0;
    try {
      List<dynamic> commentsList = json.decode(comments);
      return commentsList.length;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        "$label: $value",
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ==========================================
// EDIT BUG SCREEN
// ==========================================

class EditBugScreen extends StatefulWidget {
  final Map<String, dynamic> bug;
  final List<dynamic> projects;
  final Function(Map<String, dynamic>) onSave;

  const EditBugScreen({
    Key? key,
    required this.bug,
    required this.projects,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EditBugScreen> createState() => _EditBugScreenState();
}

class _EditBugScreenState extends State<EditBugScreen> {
  late TextEditingController titleCtrl;
  late TextEditingController descriptionCtrl;
  late TextEditingController stepsToReproduceCtrl;
  late TextEditingController browserOsCtrl;

  String? selectedProjectId;
  String selectedProjectName = 'Select Project';
  String? selectedAssignee;
  String selectedAssigneeName = 'Unassigned';
  String severity = 'Critical';
  String priority = 'High';
  String status = 'Open';
  String environment = 'Development';

  final List<String> severityOptions = ['Critical', 'Major', 'Minor', 'Trivial'];
  final List<String> priorityOptions = ['High', 'Medium', 'Low'];
  final List<String> statusOptions = ['Open', 'In Progress', 'Fixed', 'Closed'];
  final List<String> environmentOptions = ['Development', 'Staging', 'Production'];

  @override
  void initState() {
    super.initState();
    _loadBugData();
  }

  void _loadBugData() {
    final b = widget.bug;

    titleCtrl = TextEditingController(text: b['title'] ?? '');
    descriptionCtrl = TextEditingController(text: b['description'] ?? '');
    stepsToReproduceCtrl = TextEditingController(text: b['steps_to_reproduce'] ?? '');
    browserOsCtrl = TextEditingController(text: b['browser_os'] ?? '');

    String? rawProjectId = b['project_id']?.toString();
    bool projectExists = widget.projects.any((p) => p['id'].toString() == rawProjectId);

    if (projectExists) {
      selectedProjectId = rawProjectId;
      final project = widget.projects.firstWhere((p) => p['id'].toString() == rawProjectId);
      selectedProjectName = project['project_name'] ?? 'Select Project';
    } else {
      selectedProjectId = null;
      selectedProjectName = 'Select Project';
    }

    selectedAssigneeName = b['assigned_to'] ?? 'Unassigned';
    selectedAssignee = selectedAssigneeName == 'Unassigned' ? null : selectedAssigneeName;

    severity = _capitalize(b['severity'] ?? 'Critical');
    priority = _capitalize(b['priority'] ?? 'High');
    status = _formatStatus(b['status'] ?? 'open');
    environment = _capitalize(b['environment'] ?? 'Development');
  }

  String _capitalize(String? str) {
    if (str == null || str.isEmpty) return '';
    return str[0].toUpperCase() + str.substring(1);
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'open': return 'Open';
      case 'in_progress': return 'In Progress';
      case 'fixed': return 'Fixed';
      case 'closed': return 'Closed';
      default: return 'Open';
    }
  }

  String _mapStatusToApi(String status) {
    switch (status) {
      case 'Open': return 'open';
      case 'In Progress': return 'in_progress';
      case 'Fixed': return 'fixed';
      case 'Closed': return 'closed';
      default: return 'open';
    }
  }

  void _submitForm() {
    final Map<String, dynamic> payload = {
      'title': titleCtrl.text.trim(),
      'description': descriptionCtrl.text.trim(),
      'steps_to_reproduce': stepsToReproduceCtrl.text.trim().isEmpty ? null : stepsToReproduceCtrl.text.trim(),
      'project_id': selectedProjectId,
      'severity': severity.toLowerCase(),
      'priority': priority.toLowerCase(),
      'status': _mapStatusToApi(status),
      'assigned_to': selectedAssigneeName == 'Unassigned' ? null : selectedAssigneeName,
      'environment': environment.toLowerCase(),
      'browser_os': browserOsCtrl.text.trim().isEmpty ? null : browserOsCtrl.text.trim(),
    };

    Navigator.pop(context);
    widget.onSave(payload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.premiumGradient)),
        title: const Text("Edit Bug Report", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField("Bug Title", titleCtrl, isRequired: true),
            const SizedBox(height: 20),
            _buildProjectDropdown(),
            const SizedBox(height: 20),
            _buildAssigneeField(),
            const SizedBox(height: 20),
            _buildTextField("Description", descriptionCtrl, isRequired: true, maxLines: 4),
            const SizedBox(height: 24),
            _sectionHeader("Classification", Icons.category_outlined),
            const SizedBox(height: 16),
            _buildTextFieldRow([
              _buildDropdown("Severity", severity, severityOptions, (v) => setState(() => severity = v!)),
              _buildDropdown("Priority", priority, priorityOptions, (v) => setState(() => priority = v!)),
              _buildDropdown("Status", status, statusOptions, (v) => setState(() => status = v!)),
            ]),
            const SizedBox(height: 24),
            _sectionHeader("Environment", Icons.computer_outlined),
            const SizedBox(height: 16),
            _buildTextFieldRow([
              _buildDropdown("Environment", environment, environmentOptions, (v) => setState(() => environment = v!)),
              _buildTextField("Browser / OS", browserOsCtrl),
            ]),
            const SizedBox(height: 20),
            _buildTextField("Steps to Reproduce", stepsToReproduceCtrl, maxLines: 5),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.borderDark)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted))),
              const SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submitForm,
                child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentCyan, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w600, fontSize: 16)),
      ],
    );
  }

  Widget _buildTextFieldRow(List<Widget> children) {
    return Row(
      children: children.map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: w))).toList(),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isRequired = false, int maxLines = 1}) {
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
          style: const TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accentCyan)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderDark)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildProjectDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text.rich(
          TextSpan(
            text: "Project",
            children: [
              TextSpan(text: " *", style: TextStyle(color: AppColors.dangerRed)),
            ],
          ),
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedProjectId,
              isExpanded: true,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(selectedProjectName, style: const TextStyle(color: AppColors.textMuted)),
              ),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textWhite),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text("Select Project", style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
                ...widget.projects.map((project) {
                  return DropdownMenuItem<String>(
                    value: project['id'].toString(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(project['project_name'] ?? 'Unknown Project'),
                    ),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  selectedProjectId = value;
                  final selected = widget.projects.firstWhere(
                        (p) => p['id'].toString() == value,
                    orElse: () => null,
                  );
                  selectedProjectName = selected != null
                      ? selected['project_name'] ?? 'Select Project'
                      : 'Select Project';
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssigneeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Assigned To", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderDark),
            color: AppColors.surface,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedAssigneeName,
                  style: const TextStyle(color: AppColors.textWhite),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                onPressed: () {
                  setState(() {
                    selectedAssigneeName = 'Unassigned';
                    selectedAssignee = null;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}