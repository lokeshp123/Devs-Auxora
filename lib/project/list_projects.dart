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

  final String _apiUrl = 'https://skydevs.skynetproduct.com/skydevs_API.php?table=skydevs_projects';

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      final response = await http.get(Uri.parse(_apiUrl));
      final data = json.decode(response.body);

      if (data['status'] == "success") {
        List<dynamic> allProjects = data['data'] ?? [];

        setState(() {
          if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
            _projects = allProjects.where((project) {
              return project['company_id']?.toString() == savedCompanyId;
            }).toList();
          } else {
            _projects = allProjects;
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

  Future<void> _updateProject(String id, Map<String, dynamic> updatedData) async {
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
        _showSnackbar("Project updated successfully.", isError: false);
        _fetchProjects();
      } else {
        _showSnackbar(data['message'] ?? "Failed to update.", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar("Error updating project: $e", isError: true);
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
        title: const Text("Confirm Deletion", style: TextStyle(color: AppColors.textWhite)),
        content: Text("Delete project '${project['project_name']}'? This cannot be undone.",
            style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: () => _deleteProject(project['id'].toString()),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'planning': return AppColors.warningYellow;
      case 'in_progress': return AppColors.infoBlue;
      case 'on_hold': return AppColors.warningOrange;
      case 'completed': return AppColors.successGreen;
      case 'archived': return AppColors.textMuted;
      default: return AppColors.textMuted;
    }
  }

  String _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return '🔴';
      case 'medium': return '🟡';
      case 'low': return '🟢';
      default: return '⚪';
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
        title: const Text("Project Portfolio", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: "Add Project",
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddProjectScreen())
                ).then((_) => _fetchProjects());
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
    if (_projects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code_off, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text("No projects found.", style: TextStyle(color: AppColors.textMuted)),
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
          final status = (project['status'] ?? 'planning').toString().toLowerCase();
          final priority = (project['priority'] ?? 'medium').toString().toLowerCase();
          final progress = (project['progress'] ?? '0').toString();

          Color statusColor = _getStatusColor(status);
          String priorityIcon = _getPriorityIcon(priority);

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
                          Text(
                            priorityIcon,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              project['project_name'] ?? 'Unknown Project',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textWhite
                              ),
                              overflow: TextOverflow.ellipsis,
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
                        status.toUpperCase().replaceAll('_', ' '),
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                      color: AppColors.surface,
                      onSelected: (value) {
                        if (value == 'edit') {
                          // CHANGED: Open as full screen instead of Dialog
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProjectScreen(
                                project: project,
                                onSave: (updatedData) {
                                  _updateProject(project['id'].toString(), updatedData);
                                },
                              ),
                            ),
                          );
                        }
                        if (value == 'delete') _confirmDelete(project);
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
                const SizedBox(height: 8),
                Text(
                  "ID: ${project['unique_project_id'] ?? 'N/A'}",
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                if (project['description'] != null && project['description'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      project['description'],
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderDark, height: 1),
                const SizedBox(height: 12),
                // Progress Bar
                Row(
                  children: [
                    const Text("Progress:", style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: double.tryParse(progress)! / 100,
                          backgroundColor: AppColors.borderDark,
                          color: AppColors.accentCyan,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text("$progress%", style: const TextStyle(color: AppColors.accentCyan, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      "Start: ${project['start_date'] ?? 'N/A'}",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.attach_money, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      "₹${project['project_budget'] ?? '0'}",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      "${project['estimated_hours'] ?? '0'} hrs",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                if (project['project_manager'] != null && project['project_manager'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.person_rounded, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          "PM: ${project['project_manager']}",
                          style: const TextStyle(color: AppColors.textWhite, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// EDIT PROJECT SCREEN (Changed from Dialog)
// ==========================================

class EditProjectScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  final Function(Map<String, dynamic>) onSave;

  const EditProjectScreen({Key? key, required this.project, required this.onSave}) : super(key: key);

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> with SingleTickerProviderStateMixin {
  // --- Basic Info Controllers ---
  late TextEditingController projectNameCtrl;
  late TextEditingController projectCodeCtrl;
  late TextEditingController descriptionCtrl;
  late TextEditingController startDateCtrl;
  late TextEditingController endDateCtrl;
  late TextEditingController progressCtrl;
  String projectType = 'Fixed Price';
  String methodology = 'Agile';
  String priority = 'Medium';
  String status = 'Planning';

  // --- Team Controllers ---
  late TextEditingController projectManagerCtrl;
  late TextEditingController techLeadCtrl;
  List<Map<String, String>> teamMembers = [];

  // --- Financial Controllers ---
  late TextEditingController projectBudgetCtrl;
  late TextEditingController hourlyRateCtrl;
  late TextEditingController estimatedHoursCtrl;
  late TextEditingController actualHoursCtrl;

  // --- Git Integration Controllers ---
  late TextEditingController repoUrlCtrl;
  late TextEditingController defaultBranchCtrl;

  // --- Deployment Controllers ---
  late TextEditingController devUrlCtrl;
  late TextEditingController stagingUrlCtrl;
  late TextEditingController productionUrlCtrl;
  late TextEditingController notesCtrl;

  late TabController _tabController;

  String _safeStr(dynamic value, String fallback) {
    if (value == null || value.toString().isEmpty) return fallback;
    String str = value.toString();
    // Map old values to display values
    if (str == 'fixed_price') return 'Fixed Price';
    if (str == 'time_material') return 'Time & Material';
    if (str == 'retainer') return 'Retainer';
    if (str == 'internal') return 'Internal';
    if (str == 'agile') return 'Agile';
    if (str == 'scrum') return 'Scrum';
    if (str == 'kanban') return 'Kanban';
    if (str == 'waterfall') return 'Waterfall';
    if (str == 'high') return 'High';
    if (str == 'medium') return 'Medium';
    if (str == 'low') return 'Low';
    if (str == 'planning') return 'Planning';
    if (str == 'in_progress') return 'In Progress';
    if (str == 'on_hold') return 'On Hold';
    if (str == 'completed') return 'Completed';
    if (str == 'archived') return 'Archived';
    return str;
  }

  String _mapToApiValue(String value) {
    if (value == 'Fixed Price') return 'fixed_price';
    if (value == 'Time & Material') return 'time_material';
    if (value == 'Retainer') return 'retainer';
    if (value == 'Internal') return 'internal';
    if (value == 'Agile') return 'agile';
    if (value == 'Scrum') return 'scrum';
    if (value == 'Kanban') return 'kanban';
    if (value == 'Waterfall') return 'waterfall';
    if (value == 'High') return 'high';
    if (value == 'Medium') return 'medium';
    if (value == 'Low') return 'low';
    if (value == 'Planning') return 'planning';
    if (value == 'In Progress') return 'in_progress';
    if (value == 'On Hold') return 'on_hold';
    if (value == 'Completed') return 'completed';
    if (value == 'Archived') return 'archived';
    return value.toLowerCase().replaceAll(' ', '_');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    final p = widget.project;

    projectNameCtrl = TextEditingController(text: p['project_name'] ?? '');
    projectCodeCtrl = TextEditingController(text: p['project_code'] ?? '');
    descriptionCtrl = TextEditingController(text: p['description'] ?? '');
    startDateCtrl = TextEditingController(text: p['start_date'] ?? '');
    endDateCtrl = TextEditingController(text: p['end_date'] ?? '');
    progressCtrl = TextEditingController(text: p['progress']?.toString() ?? '0');

    projectType = _safeStr(p['project_type'], 'Fixed Price');
    methodology = _safeStr(p['methodology'], 'Agile');
    priority = _safeStr(p['priority'], 'Medium');
    status = _safeStr(p['status'], 'Planning');

    projectManagerCtrl = TextEditingController(text: p['project_manager'] ?? '');
    techLeadCtrl = TextEditingController(text: p['tech_lead'] ?? '');

    // Parse team members JSON
    try {
      String teamMembersStr = p['team_members'] ?? '[]';
      List<dynamic> teamList = json.decode(teamMembersStr);
      teamMembers = teamList.map((member) => {
        'name': member['name']?.toString() ?? '',
        'role': member['role']?.toString() ?? '',
        'allocation': member['allocation']?.toString() ?? ''
      }).toList();
    } catch (e) {
      teamMembers = [];
    }

    projectBudgetCtrl = TextEditingController(text: p['project_budget']?.toString() ?? '');
    hourlyRateCtrl = TextEditingController(text: p['hourly_rate']?.toString() ?? '');
    estimatedHoursCtrl = TextEditingController(text: p['estimated_hours']?.toString() ?? '');
    actualHoursCtrl = TextEditingController(text: p['actual_hours']?.toString() ?? '');

    repoUrlCtrl = TextEditingController(text: p['repo_url'] ?? '');
    defaultBranchCtrl = TextEditingController(text: p['repo_branch'] ?? 'main');

    devUrlCtrl = TextEditingController(text: p['dev_url'] ?? '');
    stagingUrlCtrl = TextEditingController(text: p['staging_url'] ?? '');
    productionUrlCtrl = TextEditingController(text: p['production_url'] ?? '');
    notesCtrl = TextEditingController(text: p['notes'] ?? '');
  }

  void _addTeamMember() {
    setState(() {
      teamMembers.add({'name': '', 'role': '', 'allocation': ''});
    });
  }

  void _removeTeamMember(int index) {
    setState(() {
      teamMembers.removeAt(index);
    });
  }

  void _updateTeamMember(int index, String field, String value) {
    setState(() {
      teamMembers[index][field] = value;
    });
  }

  void _submitForm() {
    String teamMembersJson = json.encode(teamMembers.map((member) {
      return {
        'name': member['name'] ?? '',
        'role': member['role'] ?? '',
        'allocation': member['allocation'] ?? ''
      };
    }).toList());

    Map<String, dynamic> payload = {
      'project_name': projectNameCtrl.text.trim(),
      'project_code': projectCodeCtrl.text.trim(),
      'description': descriptionCtrl.text.trim(),
      'project_type': _mapToApiValue(projectType),
      'methodology': _mapToApiValue(methodology),
      'priority': _mapToApiValue(priority),
      'status': _mapToApiValue(status),
      'progress': progressCtrl.text.trim(),
      'start_date': startDateCtrl.text.trim(),
      'end_date': endDateCtrl.text.trim().isEmpty ? null : endDateCtrl.text.trim(),
      'project_budget': projectBudgetCtrl.text.trim(),
      'hourly_rate': hourlyRateCtrl.text.trim(),
      'estimated_hours': estimatedHoursCtrl.text.trim(),
      'actual_hours': actualHoursCtrl.text.trim(),
      'project_manager': projectManagerCtrl.text.trim(),
      'tech_lead': techLeadCtrl.text.trim(),
      'team_members': teamMembersJson,
      'repo_url': repoUrlCtrl.text.trim(),
      'repo_branch': defaultBranchCtrl.text.trim(),
      'dev_url': devUrlCtrl.text.trim(),
      'staging_url': stagingUrlCtrl.text.trim(),
      'production_url': productionUrlCtrl.text.trim(),
      'notes': notesCtrl.text.trim(),
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Edit Project", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            width: double.infinity,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.accentCyan,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.accentCyan,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(icon: Icon(Icons.info_outline), text: "Basic Info"),
                Tab(icon: Icon(Icons.people_outline), text: "Team"),
                Tab(icon: Icon(Icons.attach_money_outlined), text: "Financial"),
                Tab(icon: Icon(Icons.code_outlined), text: "Git Integration"),
                Tab(icon: Icon(Icons.cloud_outlined), text: "Deployment"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBasicInfoTab(),
                _buildTeamTab(),
                _buildFinancialTab(),
                _buildGitIntegrationTab(),
                _buildDeploymentTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.borderDark)),
        ),
        child: SafeArea(
          child: Row(
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
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submitForm,
                child: const Text("Save Changes",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Project Details", Icons.info_outline),
          const SizedBox(height: 20),
          _buildTextField("Project Name *", projectNameCtrl, isRequired: true),
          const SizedBox(height: 20),
          _buildTextField("Project Code", projectCodeCtrl, subtitle: "Optional internal reference code"),
          const SizedBox(height: 20),
          _buildTextArea("Description", descriptionCtrl),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildDropdown("Project Type", projectType,
                  ['Fixed Price', 'Time & Material', 'Retainer', 'Internal'], (v) => setState(() => projectType = v!))),
              const SizedBox(width: 16),
              Expanded(child: _buildDropdown("Methodology", methodology,
                  ['Agile', 'Scrum', 'Kanban', 'Waterfall'], (v) => setState(() => methodology = v!))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildDropdown("Priority", priority,
                  ['High', 'Medium', 'Low'], (v) => setState(() => priority = v!))),
              const SizedBox(width: 16),
              Expanded(child: _buildDropdown("Status", status,
                  ['Planning', 'In Progress', 'On Hold', 'Completed', 'Archived'], (v) => setState(() => status = v!))),
              const SizedBox(width: 20),
              Expanded(child: _buildTextField("Progres%", progressCtrl, isNumber: true)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildTextField("Start Date", startDateCtrl, isDate: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField("End Date", endDateCtrl, isDate: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Team Management", Icons.people_outline),
          const SizedBox(height: 20),
          _buildTextField("Project Manager", projectManagerCtrl, hint: "e.g., Rahul Sharma"),
          const SizedBox(height: 20),
          _buildTextField("Tech Lead", techLeadCtrl, hint: "e.g., Amit Patel"),
          const SizedBox(height: 32),
          const Text("Team Members", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 16),
          ...teamMembers.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, String> member = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: _buildSimpleTextField("Name", member['name'] ?? '',
                          (v) => _updateTeamMember(index, 'name', v))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _buildSimpleTextField("Role", member['role'] ?? '',
                          (v) => _updateTeamMember(index, 'role', v))),
                  const SizedBox(width: 12),
                  Expanded(flex: 1, child: _buildSimpleTextField("Allocation %", member['allocation'] ?? '',
                          (v) => _updateTeamMember(index, 'allocation', v), isNumber: true)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed),
                    onPressed: () => _removeTeamMember(index),
                  ),
                ],
              ),
            );
          }).toList(),
          Center(
            child: TextButton.icon(
              onPressed: _addTeamMember,
              icon: const Icon(Icons.add_circle_outline, color: AppColors.accentCyan),
              label: const Text("Add Team Member", style: TextStyle(color: AppColors.accentCyan)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Financial Details", Icons.attach_money_outlined),
          const SizedBox(height: 20),
          _buildTextField("Project Budget (₹)", projectBudgetCtrl, isNumber: true),
          const SizedBox(height: 20),
          _buildTextField("Hourly Rate (₹)", hourlyRateCtrl, isNumber: true),
          const SizedBox(height: 20),
          _buildTextField("Estimated Hours", estimatedHoursCtrl, isNumber: true),
          const SizedBox(height: 20),
          _buildTextField("Actual Hours", actualHoursCtrl, isNumber: true),
        ],
      ),
    );
  }

  Widget _buildGitIntegrationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Git Repository Set", Icons.code_outlined),
          const SizedBox(height: 20),
          _buildTextField("Repository URL", repoUrlCtrl, isUrl: true),
          const SizedBox(height: 20),
          _buildTextField("Default Branch", defaultBranchCtrl),
        ],
      ),
    );
  }

  Widget _buildDeploymentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Deploy Environment", Icons.cloud_outlined),
          const SizedBox(height: 20),
          _buildTextField("Development URL", devUrlCtrl, isUrl: true),
          const SizedBox(height: 20),
          _buildTextField("Staging URL", stagingUrlCtrl, isUrl: true),
          const SizedBox(height: 20),
          _buildTextField("Production URL", productionUrlCtrl, isUrl: true),
          const SizedBox(height: 24),
          _buildTextArea("Additional Notes", notesCtrl),
        ],
      ),
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

  Widget _buildTextField(String label, TextEditingController controller,
      {String hint = '', String subtitle = '', bool isRequired = false, bool isNumber = false, bool isDate = false, bool isUrl = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          if (isRequired) const Text(" *", style: TextStyle(color: AppColors.dangerRed)),
        ]),
        if (subtitle.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: AppColors.textWhite),
          keyboardType: isNumber ? TextInputType.number : (isUrl ? TextInputType.url : (isDate ? TextInputType.datetime : TextInputType.text)),
          decoration: _inputDeco("").copyWith(
            hintText: hint.isNotEmpty ? hint : (isRequired ? "Required" : "Optional"),
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea(String label, TextEditingController controller, {String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: _inputDeco("").copyWith(
            hintText: hint.isNotEmpty ? hint : "Optional",
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    String safeValue = items.contains(value) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: safeValue,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textWhite, fontSize: 14),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accentCyan)),
            filled: true,
            fillColor: AppColors.surface,
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSimpleTextField(String label, String value, Function(String) onChanged, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accentCyan)),
            filled: true,
            fillColor: AppColors.surface,
          ),
          onChanged: onChanged,
        ),
      ],
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