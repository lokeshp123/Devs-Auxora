import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class AddProjectScreen extends StatefulWidget {
  const AddProjectScreen({Key? key}) : super(key: key);

  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends State<AddProjectScreen>
    with SingleTickerProviderStateMixin {
  bool _isSaving = false;
  List<dynamic> _clients = [];
  bool _isLoadingClients = true;

  // Auto-generated Project ID
  String get _generatedProjectId {
    final now = DateTime.now();
    final year = now.year;
    final random = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return "PRJ-$year-$random";
  }

  // --- Basic Info Controllers ---
  final projectNameCtrl = TextEditingController();
  final projectCodeCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  String? selectedClientId;
  String selectedClientName = 'Select Client';
  String projectType = 'Fixed Price';
  String methodology = 'Agile';
  String priority = 'Medium';
  String status = 'Planning';
  final progressCtrl = TextEditingController(text: '0');
  final startDateCtrl = TextEditingController();
  final endDateCtrl = TextEditingController();

  // --- Team Controllers ---
  final projectManagerCtrl = TextEditingController();
  final techLeadCtrl = TextEditingController();
  List<Map<String, String>> teamMembers = [];

  // --- Financial Controllers ---
  final projectBudgetCtrl = TextEditingController();
  final hourlyRateCtrl = TextEditingController();
  final estimatedHoursCtrl = TextEditingController();
  final actualHoursCtrl = TextEditingController();

  // --- Git Integration Controllers ---
  final repoUrlCtrl = TextEditingController();
  final defaultBranchCtrl = TextEditingController(text: 'main');

  // --- Deployment Controllers ---
  final devUrlCtrl = TextEditingController();
  final stagingUrlCtrl = TextEditingController();
  final productionUrlCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchClients();
    // Set default start date
    final now = DateTime.now();
    startDateCtrl.text = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchClients() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      final response = await http.get(Uri.parse(
          'https://skydevs.skynetproduct.com/skydevs_API.php?table=skydevs_clients'));

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        List<dynamic> allClients = data['data'] ?? [];

        setState(() {
          // Filter clients by company_id if savedCompanyId exists
          if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
            _clients = allClients.where((client) {
              return client['company_id']?.toString() == savedCompanyId;
            }).toList();
          } else {
            // If no company_id in session, show all clients (or empty list)
            _clients = allClients;
          }
          _isLoadingClients = false;
        });

        // Debug print to verify clients are loaded
        print("Loaded ${_clients.length} clients");
      } else {
        setState(() => _isLoadingClients = false);
      }
    } catch (e) {
      print("Error fetching clients: $e");
      setState(() => _isLoadingClients = false);
    }
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

  String _mapProjectTypeToApi(String value) {
    if (value == 'Fixed Price') return 'fixed_price';
    if (value == 'Time & Material') return 'time_material';
    if (value == 'Retainer') return 'retainer';
    if (value == 'Internal') return 'internal';
    return value.toLowerCase().replaceAll(' ', '_');
  }

  String _mapMethodologyToApi(String value) {
    if (value == 'Agile') return 'agile';
    if (value == 'Scrum') return 'scrum';
    if (value == 'Kanban') return 'kanban';
    if (value == 'Waterfall') return 'waterfall';
    return value.toLowerCase();
  }

  String _mapPriorityToApi(String value) {
    return value.toLowerCase();
  }

  String _mapStatusToApi(String value) {
    if (value == 'Planning') return 'planning';
    if (value == 'In Progress') return 'in_progress';
    if (value == 'On Hold') return 'on_hold';
    if (value == 'Completed') return 'completed';
    if (value == 'Archived') return 'archived';
    return value.toLowerCase().replaceAll(' ', '_');
  }

  Future<void> _saveProject() async {
    // Validation
    if (projectNameCtrl.text.trim().isEmpty ||
        selectedClientId == null ||
        projectType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields (*) first.",
              style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');
      final String? userId = prefs.getString('user_id');
      final String uniqueProjectId = _generatedProjectId;

      // Prepare team members JSON
      String teamMembersJson = json.encode(teamMembers.map((member) {
        return {
          'name': member['name'] ?? '',
          'role': member['role'] ?? '',
          'allocation': member['allocation'] ?? ''
        };
      }).toList());

      final Map<String, dynamic> payload = {
        'company_id': savedCompanyId,
        'created_by': userId ?? '1',
        'unique_project_id': uniqueProjectId,
        'project_code': projectCodeCtrl.text.trim(),
        'project_name': projectNameCtrl.text.trim(),
        'description': descriptionCtrl.text.trim(),
        'client_id': selectedClientId,
        'project_client_id': selectedClientId,
        'project_type': _mapProjectTypeToApi(projectType),
        'methodology': _mapMethodologyToApi(methodology),
        'priority': _mapPriorityToApi(priority),
        'status': _mapStatusToApi(status),
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

      final response = await http.post(
        Uri.parse(
            'https://skydevs.skynetproduct.com/skydevs_API.php?table=skydevs_projects'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Project added successfully! ID: $uniqueProjectId"),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showError(data['message'] ?? "API error saving project record.");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: const Text("Add New Project",
            style: TextStyle(
                color: AppColors.textWhite, fontWeight: FontWeight.bold)),
        bottom: TabBar(
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
      body: _isSaving
          ? const Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan))
          : Column(
        children: [
          // Unique Project ID Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.code_rounded, color: AppColors.accentCyan, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Project ID (Auto-generated)",
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _generatedProjectId,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "NEW",
                    style: TextStyle(
                      color: AppColors.successGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
          // Fixed Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.borderDark)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel",
                      style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _saveProject,
                  child: const Text("Create Project",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // TAB BUILDERS
  // ==========================================

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Project Details", Icons.info_outline),
          const SizedBox(height: 20),
          _buildTextField("Project Name *", projectNameCtrl,
              hint: "e.g., E-Commerce Platform Development", isRequired: true),
          const SizedBox(height: 20),
          _buildTextField("Project Code", projectCodeCtrl,
              hint: "e.g., ECOM-001", subtitle: "Optional internal reference code"),
          const SizedBox(height: 20),
          _buildTextArea("Description", descriptionCtrl,
              hint: "Describe the project scope, objectives, and key deliverables..."),
          const SizedBox(height: 20),
          _buildClientDropdown(),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDropdown("Project Type *", projectType, [
                  'Fixed Price',
                  'Time & Material',
                  'Retainer',
                  'Internal'
                ], (v) => setState(() => projectType = v!), isRequired: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown("Methodology *", methodology, [
                  'Agile',
                  'Scrum',
                  'Kanban',
                  'Waterfall'
                ], (v) => setState(() => methodology = v!), isRequired: true),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDropdown("Priority *", priority, [
                  'High',
                  'Medium',
                  'Low'
                ], (v) => setState(() => priority = v!), isRequired: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown("Status *", status, [
                  'Planning',
                  'In Progress',
                  'On Hold',
                  'Completed',
                  'Archived'
                ], (v) => setState(() => status = v!), isRequired: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField("Initial  (%)", progressCtrl, isNumber: true),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField("Start Date *", startDateCtrl, isDate: true, isRequired: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField("End Date", endDateCtrl, isDate: true),
              ),
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
          _buildTextField("Project Manager", projectManagerCtrl,
              hint: "e.g., Rahul Sharma"),
          const SizedBox(height: 20),
          _buildTextField("Tech Lead", techLeadCtrl,
              hint: "e.g., Amit Patel"),
          const SizedBox(height: 32),
          const Text("Team Members",
              style: TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildSimpleTextField("Name", member['name'] ?? '',
                            (v) => _updateTeamMember(index, 'name', v),
                        hint: "e.g., John Doe"),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildSimpleTextField("Role", member['role'] ?? '',
                            (v) => _updateTeamMember(index, 'role', v),
                        hint: "e.g., Developer"),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _buildSimpleTextField("Allocation %", member['allocation'] ?? '',
                            (v) => _updateTeamMember(index, 'allocation', v),
                        hint: "e.g., 50", isNumber: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed),
                    onPressed: () => _removeTeamMember(index),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _addTeamMember,
              icon: const Icon(Icons.add_circle_outline, color: AppColors.accentCyan),
              label: const Text("Add Team Member",
                  style: TextStyle(color: AppColors.accentCyan)),
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
          _buildTextField("Actual Hours (Logged so far)", actualHoursCtrl, isNumber: true),
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
          _sectionHeader("Git Repository Settings", Icons.code_outlined),
          const SizedBox(height: 20),
          _buildTextField("Repository URL", repoUrlCtrl,
              hint: "https://github.com/your-org/your-repo", isUrl: true),
          const SizedBox(height: 20),
          _buildTextField("Default Branch", defaultBranchCtrl,
              hint: "main"),
        ],
      ),
    );
  }

  Widget _buildDeploymentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Deployment Environments", Icons.cloud_outlined),
          const SizedBox(height: 20),
          _buildTextField("Development URL", devUrlCtrl,
              hint: "https://dev.yourproject.com", isUrl: true),
          const SizedBox(height: 20),
          _buildTextField("Staging URL", stagingUrlCtrl,
              hint: "https://staging.yourproject.com", isUrl: true),
          const SizedBox(height: 20),
          _buildTextField("Production URL", productionUrlCtrl,
              hint: "https://yourproject.com", isUrl: true),
          const SizedBox(height: 24),
          _buildTextArea("Additional Notes", notesCtrl,
              hint: "Any additional information about the project..."),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET HELPERS
  // ==========================================

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentCyan, size: 22),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Divider(
            color: AppColors.borderDark,
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {String hint = '',
        String subtitle = '',
        bool isRequired = false,
        bool isEmail = false,
        bool isPhone = false,
        bool isUrl = false,
        bool isNumber = false,
        bool isDate = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            if (isRequired)
              const Text(" *", style: TextStyle(color: AppColors.dangerRed)),
          ],
        ),
        if (subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: AppColors.textWhite),
          keyboardType: isNumber
              ? TextInputType.number
              : isEmail
              ? TextInputType.emailAddress
              : isPhone
              ? TextInputType.phone
              : isUrl
              ? TextInputType.url
              : isDate
              ? TextInputType.datetime
              : TextInputType.text,
          decoration: _inputDeco("").copyWith(
            hintText: hint.isNotEmpty ? hint : (isRequired ? "Required" : "Optional"),
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea(String label, TextEditingController controller,
      {String hint = '', bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            if (isRequired)
              const Text(" *", style: TextStyle(color: AppColors.dangerRed)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: _inputDeco("").copyWith(
            hintText: hint.isNotEmpty ? hint : (isRequired ? "Required" : "Optional"),
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      void Function(String?) onChanged,
      {bool isRequired = false}) {
    String safeValue = items.contains(value) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            if (isRequired)
              const Text(" *", style: TextStyle(color: AppColors.dangerRed)),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: safeValue,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textWhite, fontSize: 14),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.accentCyan),
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
          items: items.map((e) {
            return DropdownMenuItem<String>(
              value: e,
              child: Text(e,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildClientDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Client *",
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const Text(" *", style: TextStyle(color: AppColors.dangerRed)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: _isLoadingClients
              ? const Padding(
            padding: EdgeInsets.all(14),
            child: Center(
                child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          )
              : DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedClientId,
              isExpanded: true,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(selectedClientName,
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textWhite),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text("Select Client",
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
                ..._clients.map((client) {
                  return DropdownMenuItem<String>(
                    value: client['id'].toString(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(client['company_name'] ?? 'Unknown',
                          style: const TextStyle(color: AppColors.textWhite)),
                    ),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  selectedClientId = value;
                  final selected = _clients.firstWhere(
                          (c) => c['id'].toString() == value,
                      orElse: () => null);
                  selectedClientName = selected != null
                      ? selected['company_name'] ?? 'Select Client'
                      : 'Select Client';
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleTextField(String label, String value,
      Function(String) onChanged,
      {String hint = '', bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.accentCyan),
            ),
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
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accentCyan),
      ),
      filled: true,
      fillColor: AppColors.surface,
    );
  }
}