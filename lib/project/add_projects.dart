import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class AddProjectScreen extends StatefulWidget {
  /// Pass a project map for Edit mode, or null for Add mode.
  final Map<String, dynamic>? project;

  const AddProjectScreen({Key? key, this.project}) : super(key: key);

  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends State<AddProjectScreen>
    with SingleTickerProviderStateMixin {
  bool _isSaving = false;

  bool get isEditMode => widget.project != null;

  // ---------------- Clients ----------------
  List<dynamic> _clients = [];
  bool _isLoadingClients = true;

  // ---------------- Employees (from HRM API) ----------------
  List<dynamic> _employees = [];
  bool _isLoadingEmployees = true;

  String? _selectedProjectManagerId;
  String? _selectedTechLeadId;
  List<String> _selectedTeamMemberIds = [];

  final String _employeesApiUrl =
      'https://auxorahrm.auxorasystems.com/hrm_api.php?table=employees';

  // Auto-generated Project ID (only used in Add mode)
  String get _generatedProjectId {
    final now = DateTime.now();
    final year = now.year;
    final random =
    (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
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

  // ==========================================
  // INIT
  // ==========================================
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    // Default start date
    final now = DateTime.now();
    startDateCtrl.text =
    "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // IMPORTANT ORDER:
    // 1. Prefill basic fields (controllers)
    // 2. Prefill team IDs (so _fetchEmployees can inject missing employees)
    // 3. Then fetch clients + employees
    if (isEditMode) {
      _prefillBasicFields();
      _prefillTeamData();
    }

    _fetchClients();
    _fetchEmployees();
  }

  // ==========================================
  // PREFILL — BASIC FIELDS
  // ==========================================
  void _prefillBasicFields() {
    final p = widget.project!;
    projectNameCtrl.text = p['project_name'] ?? '';
    projectCodeCtrl.text = p['project_code'] ?? '';
    descriptionCtrl.text = p['description'] ?? '';

    selectedClientId = p['project_client_id']?.toString();
    selectedClientName = p['project_client_name'] ??
        p['client_name'] ??
        'Select Client';

    projectType = _mapProjectTypeFromApi(p['project_type']);
    methodology = _mapMethodologyFromApi(p['methodology']);
    priority = _mapPriorityFromApi(p['priority']);
    status = _mapStatusFromApi(p['status']);

    progressCtrl.text = p['progress']?.toString() ?? '0';
    startDateCtrl.text = p['start_date'] ?? startDateCtrl.text;
    endDateCtrl.text = p['end_date'] ?? '';

    projectBudgetCtrl.text = p['project_budget']?.toString() ?? '';
    hourlyRateCtrl.text = p['hourly_rate']?.toString() ?? '';
    estimatedHoursCtrl.text = p['estimated_hours']?.toString() ?? '';
    actualHoursCtrl.text = p['actual_hours']?.toString() ?? '';

    repoUrlCtrl.text = p['repo_url'] ?? '';
    defaultBranchCtrl.text = p['repo_branch'] ?? 'main';

    devUrlCtrl.text = p['dev_url'] ?? '';
    stagingUrlCtrl.text = p['staging_url'] ?? '';
    productionUrlCtrl.text = p['production_url'] ?? '';
    notesCtrl.text = p['notes'] ?? '';
  }

  // ==========================================
  // PREFILL — TEAM (must run BEFORE _fetchEmployees)
  // ==========================================
  void _prefillTeamData() {
    final p = widget.project!;

    _selectedProjectManagerId = p['project_manager_id']?.toString();
    _selectedTechLeadId = p['tech_lead_id']?.toString();

    final rawTeam = p['team_member_ids'];
    if (rawTeam != null && rawTeam.toString().trim().isNotEmpty) {
      try {
        final decoded = json.decode(rawTeam.toString());
        if (decoded is List) {
          _selectedTeamMemberIds =
              decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        _selectedTeamMemberIds = rawTeam
            .toString()
            .split(',')
            .map((e) => e
            .trim()
            .replaceAll('"', '')
            .replaceAll('[', '')
            .replaceAll(']', ''))
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
  }

  // ==========================================
  // DATE PICKER
  // ==========================================
  Future<String?> _pickDate(String currentValue, {String? minDate}) async {
    DateTime initialDate = DateTime.now();
    if (currentValue.trim().isNotEmpty) {
      try {
        initialDate = DateTime.parse(currentValue.trim());
      } catch (_) {}
    }

    DateTime firstDate = DateTime(initialDate.year - 5);

    if (minDate != null && minDate.trim().isNotEmpty) {
      try {
        final m = DateTime.parse(minDate.trim());
        if (m.isAfter(firstDate)) firstDate = m;
      } catch (_) {}
    }

    final DateTime lastDate = DateTime(initialDate.year + 10);

    DateTime safeInitial = initialDate;
    if (safeInitial.isBefore(firstDate)) safeInitial = firstDate;
    if (safeInitial.isAfter(lastDate)) safeInitial = lastDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentCyan,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textWhite,
            ),
            dialogBackgroundColor: AppColors.surface,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentCyan,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return null;

    final y = picked.year.toString().padLeft(4, '0');
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  // ==========================================
  // EMPLOYEE FETCH
  // ==========================================
  Future<void> _fetchEmployees() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool isClient = prefs.getBool('isClient') ?? false;
      final String companyId = prefs.getString('company_id') ?? '';
      final String clientId = prefs.getString('clientId') ?? '';

      print("=== _fetchEmployees START ===");
      print("ALL PREFS → isClient=$isClient, "
          "company_id='$companyId', "
          "clientId='$clientId', "
          "user_id='${prefs.getString('user_id')}'");

      final response = await http.get(Uri.parse(_employeesApiUrl));
      print("HTTP status: ${response.statusCode}");

      if (response.statusCode != 200) {
        print("!! Non-200 status. Aborting.");
        setState(() => _isLoadingEmployees = false);
        return;
      }

      final data = json.decode(response.body);
      print("data['status'] : ${data['status']}");

      if (data['status'] != 'success') {
        print("!! API status != success. Aborting.");
        setState(() => _isLoadingEmployees = false);
        return;
      }

      List<dynamic> allEmployees = data['data'] ?? [];
      print("Total employees from API : ${allEmployees.length}");

      allEmployees = allEmployees
          .where((e) =>
      (e['status'] ?? 'active').toString().toLowerCase() == 'active')
          .toList();
      print("Active employees         : ${allEmployees.length}");

      final bool treatAsClient =
          isClient || (clientId.isNotEmpty && clientId != '0');

      if (treatAsClient) {
        print("→ Client branch (treatAsClient=$treatAsClient)");

        List<dynamic> clientEmployees = [];
        if (clientId.isNotEmpty && clientId != '0') {
          clientEmployees = allEmployees.where((employee) {
            return employee['client_id']?.toString() == clientId;
          }).toList();
        }

        if (clientEmployees.isNotEmpty) {
          allEmployees = clientEmployees;
          print("→ Matched by client_id: ${allEmployees.length}");
        } else {
          print("→ No direct client_id match. Trying company_id fallback...");
          if (companyId.isNotEmpty) {
            allEmployees = allEmployees.where((employee) {
              return employee['company_id']?.toString() == companyId;
            }).toList();
            print("→ Matched by company_id: ${allEmployees.length}");
          } else {
            print("→ No company_id either. Showing ALL active employees.");
          }
        }
      } else {
        print("→ Admin branch");
        if (companyId.isNotEmpty) {
          allEmployees = allEmployees.where((employee) {
            return employee['company_id']?.toString() == companyId;
          }).toList();
        } else {
          allEmployees = [];
        }
      }

      print("Filtered employees       : ${allEmployees.length}");
      print("=== _fetchEmployees END ===");

      setState(() {
        _employees = allEmployees;
        _isLoadingEmployees = false;
      });
    } catch (e, stack) {
      print("!! EXCEPTION in _fetchEmployees: $e");
      print(stack);
      setState(() => _isLoadingEmployees = false);
    }
  }

  // ==========================================
  // CLIENT FETCH
  // ==========================================
  Future<void> _fetchClients() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      final response = await http.get(Uri.parse(
          'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_clients'));

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        List<dynamic> allClients = data['data'] ?? [];

        setState(() {
          if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
            _clients = allClients.where((client) {
              return client['company_id']?.toString() == savedCompanyId;
            }).toList();
          } else {
            _clients = allClients;
          }
          _isLoadingClients = false;
        });

        print("Loaded ${_clients.length} clients");
      } else {
        setState(() => _isLoadingClients = false);
      }
    } catch (e) {
      print("Error fetching clients: $e");
      setState(() => _isLoadingClients = false);
    }
  }

  // ==========================================
  // MAP HELPERS (UI → API)
  // ==========================================
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

  String _mapPriorityToApi(String value) => value.toLowerCase();

  String _mapStatusToApi(String value) {
    if (value == 'Planning') return 'planning';
    if (value == 'In Progress') return 'in_progress';
    if (value == 'On Hold') return 'on_hold';
    if (value == 'Completed') return 'completed';
    if (value == 'Archived') return 'archived';
    return value.toLowerCase().replaceAll(' ', '_');
  }

  // ==========================================
  // MAP HELPERS (API → UI)
  // ==========================================
  String _mapProjectTypeFromApi(dynamic v) {
    final s = v?.toString() ?? '';
    switch (s) {
      case 'fixed_price':
        return 'Fixed Price';
      case 'time_material':
        return 'Time & Material';
      case 'retainer':
        return 'Retainer';
      case 'internal':
        return 'Internal';
      default:
        return 'Fixed Price';
    }
  }

  String _mapMethodologyFromApi(dynamic v) {
    final s = v?.toString() ?? '';
    switch (s) {
      case 'agile':
        return 'Agile';
      case 'scrum':
        return 'Scrum';
      case 'kanban':
        return 'Kanban';
      case 'waterfall':
        return 'Waterfall';
      default:
        return 'Agile';
    }
  }

  String _mapPriorityFromApi(dynamic v) {
    final s = (v?.toString() ?? 'medium').toLowerCase();
    if (s == 'high') return 'High';
    if (s == 'low') return 'Low';
    return 'Medium';
  }

  String _mapStatusFromApi(dynamic v) {
    final s = v?.toString() ?? '';
    switch (s) {
      case 'planning':
        return 'Planning';
      case 'in_progress':
        return 'In Progress';
      case 'on_hold':
        return 'On Hold';
      case 'completed':
        return 'Completed';
      case 'archived':
        return 'Archived';
      default:
        return 'Planning';
    }
  }

  // ==========================================
  // SAVE (Add + Edit)
  // ==========================================
  Future<void> _saveProject() async {
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
      bool isClient = prefs.getBool('isClient') ?? false;
      String companyId = prefs.getString('company_id') ?? '';
      String clientId = prefs.getString('clientId') ?? '';
      final String? userId = prefs.getString('user_id');

      final bool treatAsClient =
          isClient || (clientId.isNotEmpty && clientId != '0');

      if (treatAsClient && clientId.isEmpty) {
        _showError(
            "Session Error: Client ID missing. Please log out and log in again.");
        setState(() => _isSaving = false);
        return;
      } else if (!treatAsClient && companyId.isEmpty) {
        _showError(
            "Session Error: Company ID missing. Please log out and log in again.");
        setState(() => _isSaving = false);
        return;
      }

      final String uniqueProjectId = isEditMode
          ? (widget.project!['unique_project_id'] ?? _generatedProjectId)
          : _generatedProjectId;

      final Map<String, dynamic> payload = {
        if (isEditMode) 'id': widget.project!['id'],
        'company_id': companyId,
        'client_id': treatAsClient ? clientId : null,
        'created_by': userId ?? '1',

        'unique_project_id': uniqueProjectId,
        'project_code': projectCodeCtrl.text.trim(),
        'project_name': projectNameCtrl.text.trim(),
        'description': descriptionCtrl.text.trim(),
        'project_client_id': selectedClientId,
        'project_type': _mapProjectTypeToApi(projectType),
        'methodology': _mapMethodologyToApi(methodology),
        'priority': _mapPriorityToApi(priority),
        'status': _mapStatusToApi(status),
        'progress': progressCtrl.text.trim(),
        'start_date': startDateCtrl.text.trim(),
        'end_date':
        endDateCtrl.text.trim().isEmpty ? null : endDateCtrl.text.trim(),
        'project_budget': projectBudgetCtrl.text.trim(),
        'hourly_rate': hourlyRateCtrl.text.trim(),
        'estimated_hours': estimatedHoursCtrl.text.trim(),
        'actual_hours': actualHoursCtrl.text.trim(),

        'project_manager_id': _selectedProjectManagerId,
        'tech_lead_id': _selectedTechLeadId,
        'team_member_ids': _selectedTeamMemberIds.isEmpty
            ? null
            : json.encode(_selectedTeamMemberIds),

        'repo_url': repoUrlCtrl.text.trim(),
        'repo_branch': defaultBranchCtrl.text.trim(),
        'dev_url': devUrlCtrl.text.trim(),
        'staging_url': stagingUrlCtrl.text.trim(),
        'production_url': productionUrlCtrl.text.trim(),
        'notes': notesCtrl.text.trim(),
      };

      final Map<String, dynamic> cleanedPayload = {};
      payload.forEach((key, value) {
        if (value != null) cleanedPayload[key] = value;
      });

      final response = await http.post(
        Uri.parse(
            'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_projects'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(cleanedPayload),
      );

      String responseBody = response.body.trim();
      int startIndex = responseBody.indexOf('{');
      if (startIndex > 0) {
        responseBody = responseBody.substring(startIndex);
      }

      final data = json.decode(responseBody);

      if (data['status'] == 'success') {
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditMode
                ? "Project updated successfully! ID: $uniqueProjectId"
                : "Project added successfully! ID: $uniqueProjectId"),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showError(data['message'] ??
            "API error ${isEditMode ? 'updating' : 'saving'} project record.");
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

  // ==========================================
  // BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: Text(
          isEditMode ? "Edit Project" : "Add New Project",
          style: const TextStyle(
              color: AppColors.textWhite, fontWeight: FontWeight.bold),
        ),
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
          // ---------------- HEADER CARD ----------------
          Container(
            margin: const EdgeInsets.all(16),
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentCyan.withOpacity(0.15),
                  AppColors.surface
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.accentCyan.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.code_rounded,
                      color: AppColors.accentCyan, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditMode
                            ? "Project ID"
                            : "Project ID (Auto-generated)",
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEditMode
                            ? (widget.project!['unique_project_id'] ??
                            _generatedProjectId)
                            : _generatedProjectId,
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isEditMode
                        ? AppColors.accentCyan
                        : AppColors.successGreen)
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isEditMode ? "EDIT" : "NEW",
                    style: TextStyle(
                      color: isEditMode
                          ? AppColors.accentCyan
                          : AppColors.successGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------------- TAB CONTENT ----------------
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

          // ---------------- BOTTOM ACTIONS ----------------
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border:
              Border(top: BorderSide(color: AppColors.borderDark)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel",
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 16)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _saveProject,
                  child: Text(
                    isEditMode ? "Update Project" : "Create Project",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
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
              hint: "e.g., ECOM-001",
              subtitle: "Optional internal reference code"),
          const SizedBox(height: 20),
          _buildTextArea("Description", descriptionCtrl,
              hint:
              "Describe the project scope, objectives, and key deliverables..."),
          const SizedBox(height: 20),
          _buildClientDropdown(),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDropdown(
                    "Project Type *",
                    projectType,
                    ['Fixed Price', 'Time & Material', 'Retainer', 'Internal'],
                        (v) => setState(() => projectType = v!),
                    isRequired: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown(
                    "Methodology *",
                    methodology,
                    ['Agile', 'Scrum', 'Kanban', 'Waterfall'],
                        (v) => setState(() => methodology = v!),
                    isRequired: true),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDropdown("Priority *", priority,
                    ['High', 'Medium', 'Low'],
                        (v) => setState(() => priority = v!),
                    isRequired: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown(
                    "Status *",
                    status,
                    [
                      'Planning',
                      'In Progress',
                      'On Hold',
                      'Completed',
                      'Archived'
                    ],
                        (v) => setState(() => status = v!),
                    isRequired: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField("Initial  (%)", progressCtrl,
                    isNumber: true),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField("Start Date *", startDateCtrl,
                    isDate: true, isRequired: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  "End Date",
                  endDateCtrl,
                  isDate: true,
                  minDate: startDateCtrl.text,
                ),
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

          _buildEmployeeDropdown(
            label: "Project Manager",
            selectedId: _selectedProjectManagerId,
            onChanged: (v) =>
                setState(() => _selectedProjectManagerId = v),
          ),
          const SizedBox(height: 20),

          _buildEmployeeDropdown(
            label: "Tech Lead",
            selectedId: _selectedTechLeadId,
            onChanged: (v) => setState(() => _selectedTechLeadId = v),
          ),
          const SizedBox(height: 32),

          const Text("Team Members",
              style: TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
          const SizedBox(height: 8),
          const Text("Tap to select / deselect team members",
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 12),

          if (_isLoadingEmployees)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accentCyan),
              ),
            )
          else if (_employees.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "No employees available for your account.\nPlease contact your administrator.",
                style: TextStyle(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _employees.map((emp) {
                final id = emp['id'].toString();
                final name = emp['name'] ?? 'Unknown';
                final code = emp['employee_id'] ?? '';
                final isSelected = _selectedTeamMemberIds.contains(id);

                return FilterChip(
                  label: Text(
                    code.isNotEmpty ? "$name ($code)" : name,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.accentCyan
                          : AppColors.textWhite,
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTeamMemberIds.add(id);
                      } else {
                        _selectedTeamMemberIds.remove(id);
                      }
                    });
                  },
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.accentCyan.withOpacity(0.25),
                  checkmarkColor: AppColors.accentCyan,
                  side: const BorderSide(color: AppColors.borderDark),
                );
              }).toList(),
            ),

          if (_selectedTeamMemberIds.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              "Selected: ${_selectedTeamMemberIds.length} member(s)",
              style:
              const TextStyle(color: AppColors.accentCyan, fontSize: 12),
            ),
          ],
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
          _buildTextField("Project Budget (₹)", projectBudgetCtrl,
              isNumber: true),
          const SizedBox(height: 20),
          _buildTextField("Hourly Rate (₹)", hourlyRateCtrl, isNumber: true),
          const SizedBox(height: 20),
          _buildTextField("Estimated Hours", estimatedHoursCtrl,
              isNumber: true),
          const SizedBox(height: 20),
          _buildTextField("Actual Hours (Logged so far)", actualHoursCtrl,
              isNumber: true),
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
          _buildTextField("Default Branch", defaultBranchCtrl, hint: "main"),
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
          child: Divider(color: AppColors.borderDark, thickness: 1),
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
        bool isDate = false,
        String? minDate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13)),
            if (isRequired)
              const Text(" *", style: TextStyle(color: AppColors.dangerRed)),
          ],
        ),
        if (subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
          ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: isDate,
          onTap: isDate
              ? () async {
            final picked =
            await _pickDate(controller.text, minDate: minDate);
            if (picked != null) {
              controller.text = picked;
            }
          }
              : null,
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
            hintText:
            hint.isNotEmpty ? hint : (isRequired ? "Required" : "Optional"),
            hintStyle:
            const TextStyle(color: AppColors.textMuted, fontSize: 12),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: isDate
                ? const Icon(Icons.calendar_today,
                color: AppColors.textMuted, size: 18)
                : null,
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
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13)),
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
            hintText:
            hint.isNotEmpty ? hint : (isRequired ? "Required" : "Optional"),
            hintStyle:
            const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13)),
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
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    final List<DropdownMenuItem<String>> items = [
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
            child: Text(
              client['client_name'] ??
                  client['name'] ??
                  client['company_name'] ??
                  'Unknown',
              style: const TextStyle(color: AppColors.textWhite),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }),
    ];

    String? safeValue = selectedClientId;
    final hasMatch = items.any((it) => it.value == selectedClientId);
    if (selectedClientId != null && !hasMatch) {
      items.insert(
        1,
        DropdownMenuItem<String>(
          value: selectedClientId,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              selectedClientName,
              style: const TextStyle(color: AppColors.textWhite),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    if (selectedClientId != null &&
        !items.any((it) => it.value == selectedClientId)) {
      safeValue = null;
    }

    if (safeValue != null && _clients.isNotEmpty) {
      final match = _clients.firstWhere(
            (c) => c['id'].toString() == safeValue,
        orElse: () => null,
      );
      if (match != null) {
        selectedClientName = match['company_name'] ??
            match['name'] ??
            match['client_name'] ??
            'Select Client';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text("Client",
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            Text(" *", style: TextStyle(color: AppColors.dangerRed)),
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
              value: safeValue,
              isExpanded: true,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(selectedClientName,
                    style:
                    const TextStyle(color: AppColors.textMuted)),
              ),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textWhite),
              items: items,
              onChanged: (value) {
                setState(() {
                  selectedClientId = value;
                  final selected = _clients.firstWhere(
                          (c) => c['id'].toString() == value,
                      orElse: () => null);
                  selectedClientName = selected != null
                      ? (selected['company_name'] ??
                      selected['name'] ??
                      selected['client_name'] ??
                      'Select Client')
                      : 'Select Client';
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeDropdown({
    required String label,
    required String? selectedId,
    required void Function(String?) onChanged,
  }) {
    final List<DropdownMenuItem<String>> items = _employees.map((emp) {
      final name = emp['name'] ?? 'Unknown';
      final code = emp['employee_id'] ?? '';
      return DropdownMenuItem<String>(
        value: emp['id'].toString(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            code.isNotEmpty ? "$name ($code)" : name,
            style: const TextStyle(color: AppColors.textWhite),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }).toList();

    String? safeValue = selectedId;
    if (selectedId != null && !items.any((it) => it.value == selectedId)) {
      safeValue = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: _isLoadingEmployees
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
              value: safeValue,
              isExpanded: true,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text("Select $label",
                    style:
                    const TextStyle(color: AppColors.textMuted)),
              ),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textWhite),
              items: items,
              onChanged: onChanged,
            ),
          ),
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