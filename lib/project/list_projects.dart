import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'add_projects.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({Key? key}) : super(key: key);

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _projects = [];

  final String _apiUrl =
      'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_projects';

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      final bool isClient = prefs.getBool('isClient') ?? false;
      final String companyId = prefs.getString('company_id') ?? '';
      final String clientId = prefs.getString('clientId') ?? '';

      final response = await http.get(Uri.parse(_apiUrl));
      final data = json.decode(response.body);

      if (data['status'] == "success") {
        List<dynamic> allProjects = data['data'] ?? [];

        setState(() {
          if (isClient) {
            if (clientId.isNotEmpty) {
              _projects = allProjects.where((project) {
                return project['client_id']?.toString() == clientId;
              }).toList();
            } else {
              _projects = [];
            }
          } else {
            if (companyId.isNotEmpty) {
              _projects = allProjects.where((project) {
                return project['company_id']?.toString() == companyId;
              }).toList();
            } else {
              _projects = [];
            }
          }
          _errorMessage = '';
        });
      } else {
        setState(() => _errorMessage = "Failed to load projects.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Connection error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProject(String id) async {
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
        _showSnackbar("Project deleted successfully.", isError: false);
        _fetchProjects();
      } else {
        _showSnackbar(data['message'] ?? "Failed to delete.", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar("Error deleting project: $e", isError: true);
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

  void _confirmDelete(Map<String, dynamic> project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Confirm Deletion",
            style: TextStyle(color: AppColors.textWhite)),
        content: Text(
            "Delete project '${project['project_name']}'? This cannot be undone.",
            style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel",
                  style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            style:
            ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: () => _deleteProject(project['id'].toString()),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'planning':
        return AppColors.warningYellow;
      case 'in_progress':
        return AppColors.infoBlue;
      case 'on_hold':
        return AppColors.warningOrange;
      case 'completed':
        return AppColors.successGreen;
      case 'archived':
        return AppColors.textMuted;
      default:
        return AppColors.textMuted;
    }
  }

  String _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return '🔴';
      case 'medium':
        return '🟡';
      case 'low':
        return '🟢';
      default:
        return '⚪';
    }
  }

  // ==========================================
  // OPEN ADD SCREEN
  // ==========================================
  void _openAddScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddProjectScreen()),
    ).then((_) => _fetchProjects());
  }

  // ==========================================
  // OPEN EDIT SCREEN (reuses AddProjectScreen)
  // ==========================================
  void _openEditScreen(Map<String, dynamic> project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProjectScreen(project: project),
      ),
    ).then((saved) {
      if (saved == true) _fetchProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.premiumGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Project Portfolio",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: "Add Project",
              onPressed: _openAddScreen,
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan));
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
          child: Text(_errorMessage,
              style: const TextStyle(color: AppColors.dangerRed)));
    }
    if (_projects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code_off, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text("No projects found.",
                style: TextStyle(color: AppColors.textMuted)),
            SizedBox(height: 8),
            Text("Tap the + button to create your first project",
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accentCyan,
      backgroundColor: AppColors.surface,
      onRefresh: _fetchProjects,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _projects.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final project = _projects[index];
          final status =
          (project['status'] ?? 'planning').toString().toLowerCase();
          final priority =
          (project['priority'] ?? 'medium').toString().toLowerCase();
          final progress = (project['progress'] ?? '0').toString();

          Color statusColor = _getStatusColor(status);
          String priorityIcon = _getPriorityIcon(priority);

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProjectDetailsScreen(project: project),
                ),
              );
            },
            child: Container(
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
                            Text(priorityIcon,
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                project['project_name'] ?? 'Unknown Project',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textWhite),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          status.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            color: AppColors.textMuted),
                        color: AppColors.surface,
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openEditScreen(project);
                          }
                          if (value == 'delete') _confirmDelete(project);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_outlined,
                                    color: AppColors.textWhite, size: 18),
                                SizedBox(width: 8),
                                Text('Edit',
                                    style: TextStyle(
                                        color: AppColors.textWhite))
                              ])),
                          const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline,
                                    color: AppColors.dangerRed, size: 18),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style:
                                    TextStyle(color: AppColors.dangerRed))
                              ])),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "ID: ${project['unique_project_id'] ?? 'N/A'}",
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                  if (project['description'] != null &&
                      project['description'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        project['description'],
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderDark, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text("Progress:",
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 10)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (double.tryParse(progress) ?? 0) / 100,
                            backgroundColor: AppColors.borderDark,
                            color: AppColors.accentCyan,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text("$progress%",
                          style: const TextStyle(
                              color: AppColors.accentCyan, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            "Start: ${project['start_date'] ?? 'N/A'}",
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_money,
                              size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            "₹${project['project_budget'] ?? '0'}",
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time,
                              size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            "${project['estimated_hours'] ?? '0'} hrs",
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// PROJECT DETAILS SCREEN (unchanged)
// ==========================================
class ProjectDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> project;

  const ProjectDetailsScreen({Key? key, required this.project})
      : super(key: key);

  List<dynamic> _parseJsonList(dynamic jsonInput) {
    if (jsonInput == null) return [];
    if (jsonInput is List) return jsonInput;
    if (jsonInput is String && jsonInput.isNotEmpty) {
      try {
        var parsed = json.decode(jsonInput);
        if (parsed is String) parsed = json.decode(parsed);
        if (parsed is List) return parsed;
        if (parsed is Map) return [parsed];
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final teamMembers = _parseJsonList(project['team_members']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
            decoration:
            const BoxDecoration(gradient: AppColors.premiumGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Project Details",
            style:
            TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project['project_name'] ?? 'Unknown Project',
                    style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "ID: ${project['unique_project_id'] ?? 'N/A'} | Code: ${project['project_code'] ?? 'N/A'}",
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontFamily: 'monospace'),
                  ),
                  if (project['description'] != null &&
                      project['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      project['description'],
                      style: const TextStyle(
                          color: AppColors.textWhite, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSection("Basic Information", [
              _buildDetailRow("Type", project['project_type']),
              _buildDetailRow("Methodology", project['methodology']),
              _buildDetailRow("Priority", project['priority']),
              _buildDetailRow("Status", project['status']),
              _buildDetailRow("Progress", "${project['progress'] ?? '0'}%"),
              _buildDetailRow("Start Date", project['start_date']),
              _buildDetailRow("End Date", project['end_date']),
            ]),
            _buildSection("Team Management", [
              _buildDetailRow("Project Manager", project['project_manager']),
              _buildDetailRow("Tech Lead", project['tech_lead']),
              if (teamMembers.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text("Team Members:",
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                ...teamMembers.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text(
                    "• ${m['name'] ?? 'Unknown'} (${m['role'] ?? 'Member'}) - ${m['allocation']}% allocation",
                    style: const TextStyle(
                        color: AppColors.textWhite, fontSize: 13),
                  ),
                )).toList(),
              ]
            ]),
            _buildSection("Financial Details", [
              _buildDetailRow(
                  "Project Budget",
                  project['project_budget'] != null
                      ? "₹${project['project_budget']}"
                      : null),
              _buildDetailRow(
                  "Hourly Rate",
                  project['hourly_rate'] != null
                      ? "₹${project['hourly_rate']}"
                      : null),
              _buildDetailRow(
                  "Estimated Hours",
                  project['estimated_hours'] != null
                      ? "${project['estimated_hours']} hrs"
                      : null),
              _buildDetailRow(
                  "Actual Hours",
                  project['actual_hours'] != null
                      ? "${project['actual_hours']} hrs"
                      : null),
            ]),
            _buildSection("Git Repository", [
              _buildDetailRow("Repository URL", project['repo_url']),
              _buildDetailRow("Default Branch", project['repo_branch']),
            ]),
            _buildSection("Deployment Environments", [
              _buildDetailRow("Dev URL", project['dev_url']),
              _buildDetailRow("Staging URL", project['staging_url']),
              _buildDetailRow("Production URL", project['production_url']),
            ]),
            if (project['notes'] != null &&
                project['notes'].toString().isNotEmpty)
              _buildSection("Additional Notes", [
                Text(project['notes'],
                    style: const TextStyle(
                        color: AppColors.textWhite, fontSize: 13)),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
                color: AppColors.accentCyan,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}