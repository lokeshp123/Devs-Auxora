import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../theme.dart';

class AddBugScreen extends StatefulWidget {
  const AddBugScreen({Key? key}) : super(key: key);

  @override
  State<AddBugScreen> createState() => _AddBugScreenState();
}

class _AddBugScreenState extends State<AddBugScreen> {
  bool _isSaving = false;
  List<dynamic> _projects = [];
  List<dynamic> _employees = [];
  bool _isLoadingProjects = true;
  bool _isLoadingEmployees = true;

  // Auto-generated Bug ID
  String get _generatedBugId {
    final now = DateTime.now();
    final year = now.year;
    final random = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return "BUG-$year-$random";
  }

  // Controllers
  final titleCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final stepsToReproduceCtrl = TextEditingController();
  final browserOsCtrl = TextEditingController();

  // Dropdown values
  String? selectedProjectId;
  String selectedProjectName = 'Select Project';
  String? selectedAssignee;
  String selectedAssigneeName = 'Unassigned';
  String severity = 'Critical';
  String priority = 'High';
  String status = 'Open';
  String environment = 'Development';

  // Attachments
  List<File> _attachments = [];

  // Available options
  final List<String> severityOptions = ['Critical', 'Major', 'Minor', 'Trivial'];
  final List<String> priorityOptions = ['High', 'Medium', 'Low'];
  final List<String> statusOptions = ['Open', 'In Progress', 'Fixed', 'Closed'];
  final List<String> environmentOptions = ['Development', 'Staging', 'Production'];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _fetchEmployees();
  }

  Future<void> _fetchProjects() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      final response = await http.get(Uri.parse(
          'https://skydevs.skynetproduct.com/skydevs_API.php?table=skydevs_projects'));

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        List<dynamic> allProjects = data['data'] ?? [];

        setState(() {
          if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
            _projects = allProjects.where((project) {
              return project['company_id']?.toString() == savedCompanyId;
            }).toList();
          } else {
            _projects = allProjects;
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

  Future<void> _fetchEmployees() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      final response = await http.get(Uri.parse(
          'https://skydevs.skynetproduct.com/skydevs_API.php?table=skydevs_employees'));

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        List<dynamic> allEmployees = data['data'] ?? [];

        setState(() {
          if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
            _employees = allEmployees.where((emp) {
              return emp['company_id']?.toString() == savedCompanyId;
            }).toList();
          } else {
            _employees = allEmployees;
          }
          _isLoadingEmployees = false;
        });
      } else {
        setState(() => _isLoadingEmployees = false);
      }
    } catch (e) {
      setState(() => _isLoadingEmployees = false);
    }
  }

  Future<void> _pickAttachments() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'txt', 'log'],
    );
    if (result != null) {
      // Check file size (max 5MB each)
      bool valid = true;
      for (var file in result.files) {
        if (file.size > 5 * 1024 * 1024) {
          valid = false;
          _showError("File ${file.name} exceeds 5MB limit.");
          break;
        }
      }
      if (valid) {
        setState(() {
          _attachments = result.paths.map((path) => File(path!)).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${_attachments.length} file(s) selected"),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _saveBug() async {
    // Validation
    if (titleCtrl.text.trim().isEmpty ||
        selectedProjectId == null ||
        descriptionCtrl.text.trim().isEmpty) {
      _showError("Please fill all required fields (*) first.");
      return;
    }

    setState(() => _isSaving = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');
      final String? userId = prefs.getString('user_id');
      final String? userName = prefs.getString('user_name');
      final String bugCode = _generatedBugId;

      // Prepare attachments JSON
      List<Map<String, dynamic>> attachmentsList = [];
      for (var file in _attachments) {
        attachmentsList.add({
          'name': file.path.split('/').last,
          'path': 'bug-attachments/${DateTime.now().year}/${DateTime.now().month}/${file.path.split('/').last}',
          'size': await file.length(),
          'uploaded_at': DateTime.now().toIso8601String(),
        });
      }
      String attachmentsJson = json.encode(attachmentsList);

      final Map<String, dynamic> payload = {
        'company_id': savedCompanyId,
        'created_by': userId ?? '1',
        'reported_by': userName ?? 'System',
        'bug_code': bugCode,
        'title': titleCtrl.text.trim(),
        'description': descriptionCtrl.text.trim(),
        'steps_to_reproduce': stepsToReproduceCtrl.text.trim().isEmpty ? null : stepsToReproduceCtrl.text.trim(),
        'project_id': selectedProjectId,
        'severity': severity.toLowerCase(),
        'priority': priority.toLowerCase(),
        'status': status.toLowerCase().replaceAll(' ', '_'),
        'assigned_to': selectedAssigneeName == 'Unassigned' ? null : selectedAssigneeName,
        'environment': environment.toLowerCase(),
        'browser_os': browserOsCtrl.text.trim().isEmpty ? null : browserOsCtrl.text.trim(),
        'attachments': attachmentsJson,
        'comments': '[]',
      };

      final response = await http.post(
        Uri.parse('https://skydevs.skynetproduct.com/skydevs_API.php?table=skydevs_bugs'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bug reported successfully! ID: $bugCode"),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showError(data['message'] ?? "API error saving bug record.");
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
        title: const Text("Report New Bug",
            style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold)),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
          : Column(
        children: [
          // Unique Bug ID Card
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
                  child: const Icon(Icons.bug_report, color: AppColors.accentCyan, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Bug ID (Auto-generated)",
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _generatedBugId,
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
                    style: TextStyle(color: AppColors.successGreen, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBasicInfoSection(),
                  const SizedBox(height: 32),
                  _buildClassificationSection(),
                  const SizedBox(height: 32),
                  _buildStepsToReproduceSection(),
                  const SizedBox(height: 32),
                  _buildEnvironmentSection(),
                  const SizedBox(height: 32),
                  _buildAttachmentsSection(),
                ],
              ),
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
                  child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _saveBug,
                  child: const Text("Report Bug",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Basic Information", Icons.info_outline),
        const SizedBox(height: 20),
        _buildTextField("Bug Title *", titleCtrl,
            hint: "e.g., Login API returns 500 error on invalid token", isRequired: true),
        const SizedBox(height: 20),
        _buildProjectDropdown(),
        const SizedBox(height: 20),
        _buildAssigneeDropdown(),
        const SizedBox(height: 20),
        _buildTextField("Description *", descriptionCtrl,
            hint: "Describe the bug in detail...", isRequired: true, maxLines: 4),
      ],
    );
  }

  Widget _buildClassificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Classification", Icons.category_outlined),
        const SizedBox(height: 20),
        _buildTextFieldRow([
          _buildDropdown("Severity *", severity, severityOptions, (v) => setState(() => severity = v!), isRequired: true),
          _buildDropdown("Priority *", priority, priorityOptions, (v) => setState(() => priority = v!), isRequired: true),
          _buildDropdown("Status *", status, statusOptions, (v) => setState(() => status = v!), isRequired: true),
        ]),
      ],
    );
  }

  Widget _buildStepsToReproduceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Steps to Reproduce", Icons.format_list_numbered),
        const SizedBox(height: 8),
        Text(
          "Provide detailed steps to reproduce the bug",
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _buildTextField("Steps", stepsToReproduceCtrl,
            hint: "1. Call /api/login with valid credentials\n2. Get token\n3. Modify token (change last character)\n4. Call /api/user with modified token\n5. Expected: 401 Unauthorized, Actual: 500 Internal Server Error",
            maxLines: 6),
      ],
    );
  }

  Widget _buildEnvironmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Environment", Icons.computer_outlined),
        const SizedBox(height: 20),
        _buildTextFieldRow([
          _buildDropdown("Environment", environment, environmentOptions, (v) => setState(() => environment = v!)),
          _buildTextField("Browser / OS", browserOsCtrl, hint: "e.g., Chrome 122 / Windows 11"),
        ]),
      ],
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Attachments", Icons.attach_file),
        const SizedBox(height: 8),
        Text(
          "Upload screenshots, error logs, or any relevant files (Max 5MB each)",
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            children: [
              if (_attachments.isNotEmpty) ...[
                ..._attachments.asMap().entries.map((entry) {
                  int index = entry.key;
                  File file = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file, size: 20, color: AppColors.accentCyan),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            file.path.split('/').last,
                            style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.dangerRed),
                          onPressed: () => _removeAttachment(index),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const Divider(color: AppColors.borderDark),
              ],
              ElevatedButton.icon(
                onPressed: _pickAttachments,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text("Choose Files"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (_attachments.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    "No file chosen",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
            ],
          ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
          .map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 16), child: w)))
          .toList(),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {String hint = '', bool isRequired = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          if (isRequired) const Text(" *", style: TextStyle(color: AppColors.dangerRed)),
        ]),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: _inputDeco("").copyWith(
            hintText: hint.isNotEmpty ? hint : (isRequired ? "Required" : "Optional"),
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      void Function(String?) onChanged, {bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          if (isRequired) const Text(" *", style: TextStyle(color: AppColors.dangerRed)),
        ]),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : items.first,
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

  Widget _buildProjectDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text("Project *", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const Text(" *", style: TextStyle(color: AppColors.dangerRed)),
        ]),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: _isLoadingProjects
              ? const Padding(
            padding: EdgeInsets.all(14),
            child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          )
              : DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedProjectId,
              isExpanded: true,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(selectedProjectName, style: const TextStyle(color: AppColors.textMuted)),
              ),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textWhite),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text("Select Project", style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
                ..._projects.map((project) {
                  return DropdownMenuItem<String>(
                    value: project['id'].toString(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(project['project_name'] ?? 'Unknown Project', style: const TextStyle(color: AppColors.textWhite)),
                    ),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  selectedProjectId = value;
                  final selected = _projects.firstWhere(
                          (p) => p['id'].toString() == value,
                      orElse: () => null);
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

  Widget _buildAssigneeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Assigned To", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: _isLoadingEmployees
              ? const Padding(
            padding: EdgeInsets.all(14),
            child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          )
              : DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedAssignee,
              isExpanded: true,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(selectedAssigneeName, style: const TextStyle(color: AppColors.textMuted)),
              ),
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textWhite),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text("Unassigned", style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
                ..._employees.map((emp) {
                  return DropdownMenuItem<String>(
                    value: emp['id'].toString(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(emp['full_name'] ?? 'Unknown', style: const TextStyle(color: AppColors.textWhite)),
                    ),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  selectedAssignee = value;
                  final selected = _employees.firstWhere(
                          (e) => e['id'].toString() == value,
                      orElse: () => null);
                  selectedAssigneeName = selected != null
                      ? selected['full_name'] ?? 'Unassigned'
                      : 'Unassigned';
                });
              },
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
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accentCyan)),
      filled: true,
      fillColor: AppColors.surface,
    );
  }
}