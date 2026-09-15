import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart'; // Adjust path based on your structure

class AddTimeEntryScreen extends StatefulWidget {
  const AddTimeEntryScreen({Key? key}) : super(key: key);

  @override
  State<AddTimeEntryScreen> createState() => _AddTimeEntryScreenState();
}

class _AddTimeEntryScreenState extends State<AddTimeEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;

  List<dynamic> _projects = [];
  List<dynamic> _allTasks = [];
  List<dynamic> _filteredTasks = [];

  // Form Field Controllers & Variables
  String? _selectedProjectId;
  String? _selectedTaskId;
  String? _selectedTaskCode;
  DateTime _selectedDate = DateTime.now();
  bool _isBillable = true;

  final TextEditingController _hoursCtrl = TextEditingController();
  final TextEditingController _hourlyRateCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController(text: "0.00");
  final TextEditingController _descriptionCtrl = TextEditingController();

  final String _projectsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_projects';
  final String _tasksApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_kanban_tasks';
  final String _timeEntriesApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_time_entries';

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();

    // Auto-calculate amount when hours or rate changes
    _hoursCtrl.addListener(_calculateAmount);
    _hourlyRateCtrl.addListener(_calculateAmount);
  }

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _hourlyRateCtrl.dispose();
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _calculateAmount() {
    final hours = double.tryParse(_hoursCtrl.text) ?? 0.0;
    final rate = double.tryParse(_hourlyRateCtrl.text) ?? 0.0;
    final amount = hours * rate;

    // Prevent infinite loop by checking if text is different
    final newText = amount.toStringAsFixed(2);
    if (_amountCtrl.text != newText) {
      _amountCtrl.text = newText;
    }
  }

  Future<void> _fetchDropdownData() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      final responses = await Future.wait([
        http.get(Uri.parse(_projectsApiUrl)),
        http.get(Uri.parse(_tasksApiUrl)),
      ]);

      final projectsData = json.decode(responses[0].body);
      final tasksData = json.decode(responses[1].body);

      if (mounted) {
        setState(() {
          if (projectsData['status'] == 'success') {
            List<dynamic> allProj = projectsData['data'] ?? [];
            if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
              _projects = allProj.where((p) => p['company_id']?.toString() == savedCompanyId).toList();
            } else {
              _projects = allProj;
            }
          }

          if (tasksData['status'] == 'success') {
            _allTasks = tasksData['data'] ?? [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar("Failed to load projects and tasks.", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onProjectSelected(String? projectId) {
    if (projectId == null) return;

    setState(() {
      _selectedProjectId = projectId;
      _selectedTaskId = null; // Reset task when project changes
      _selectedTaskCode = null;

      // FIXED: Safely check both 'project_id' and 'projects_id' keys to handle different API schemas
      _filteredTasks = _allTasks.where((task) {
        final tProjId = task['project_id']?.toString() ?? task['projects_id']?.toString();
        return tProjId == projectId;
      }).toList();

      // Find the project data and auto-fill the hourly rate
      final selectedProject = _projects.firstWhere((p) => p['id'].toString() == projectId, orElse: () => null);
      if (selectedProject != null) {
        final rate = selectedProject['hourly_rate'] ?? selectedProject['rate'] ?? '0.00';
        _hourlyRateCtrl.text = rate.toString();
        _calculateAmount();
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.accentCyan,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textWhite,
            ),
            dialogBackgroundColor: AppColors.background,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String companyId = prefs.getString('company_id') ?? '';
      final String userId = prefs.getString('user_id') ?? '1';
      final String userName = prefs.getString('name') ?? 'Admin';
      final String clientId = prefs.getString('clientId') ?? '';

      final Map<String, dynamic> payload = {
        'user_id': userId,
        'user_name': userName,
        'project_id': _selectedProjectId,
        'task_id': _selectedTaskId,
        'task_code': _selectedTaskCode, // Properly assigned task code
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'hours': _hoursCtrl.text.trim(),
        'hourly_rate': _hourlyRateCtrl.text.trim(),
        'amount': _amountCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'is_billable': _isBillable ? '1' : '0',
        'status': 'pending',
        'company_id': companyId.isNotEmpty ? companyId : null,
        'client_id': clientId.isNotEmpty ? clientId : null,
        'created_by': userId,
      };

      final response = await http.post(
        Uri.parse(_timeEntriesApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        _showSnackbar("Time entry added successfully!");
        Navigator.pop(context, true);
      } else {
        _showSnackbar(data['message'] ?? 'Failed to add time entry.', isError: true);
      }
    } catch (e) {
      _showSnackbar("Connection error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.premiumGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Log Time Entry", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project Selection
              _buildSectionTitle("Project & Task"),
              _buildProjectDropdown(),
              const SizedBox(height: 16),
              _buildTaskDropdown(),
              const SizedBox(height: 24),

              // Date & Billable Status
              _buildSectionTitle("Details"),
              _buildDatePicker(),
              const SizedBox(height: 16),
              _buildBillableSwitch(),
              const SizedBox(height: 24),

              // Financials & Time
              _buildSectionTitle("Time & Cost"),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField("Hours", _hoursCtrl,
                        icon: Icons.timer,
                        isNumeric: true,
                        isRequired: true
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField("Hourly Rate (\$)", _hourlyRateCtrl,
                        icon: Icons.attach_money,
                        isNumeric: true,
                        isRequired: true
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField("Total Amount (\$)", _amountCtrl,
                  icon: Icons.account_balance_wallet,
                  isReadOnly: true
              ),
              const SizedBox(height: 24),

              // Description
              _buildSectionTitle("Notes"),
              _buildTextField("Description", _descriptionCtrl,
                  icon: Icons.notes,
                  maxLines: 3
              ),
            ],
          ),
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
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Save Entry", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==== UI COMPONENT BUILDERS ====

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(color: AppColors.accentCyan, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProjectDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedProjectId,
      isExpanded: true,
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textWhite),
      decoration: InputDecoration(
        labelText: "Select Project *",
        labelStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: const Icon(Icons.folder_outlined, color: AppColors.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
      ),
      items: _projects.map((project) {
        return DropdownMenuItem<String>(
          value: project['id'].toString(),
          child: Text(project['project_name'] ?? 'Unknown Project'),
        );
      }).toList(),
      onChanged: _onProjectSelected,
      validator: (value) => value == null ? 'Please select a project' : null,
    );
  }

  Widget _buildTaskDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedTaskId,
      isExpanded: true,
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textWhite),
      decoration: InputDecoration(
        labelText: "Select Task (Optional)",
        labelStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: const Icon(Icons.assignment_outlined, color: AppColors.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
      ),
      items: _filteredTasks.map((task) {
        final taskCode = task['task_code'] ?? '';
        final taskTitle = task['title'] ?? task['task_name'] ?? 'Unknown Task';
        return DropdownMenuItem<String>(
          value: task['id'].toString(),
          child: Text(taskCode.isNotEmpty ? "[$taskCode] $taskTitle" : taskTitle),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedTaskId = value;
          if (value != null) {
            final selectedTask = _filteredTasks.firstWhere((t) => t['id'].toString() == value, orElse: () => null);
            _selectedTaskCode = selectedTask?['task_code'];
          } else {
            _selectedTaskCode = null;
          }
        });
      },
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () => _selectDate(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 12),
            Text(
              DateFormat('MMM dd, yyyy').format(_selectedDate),
              style: const TextStyle(color: AppColors.textWhite, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillableSwitch() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Billable", style: TextStyle(color: AppColors.textWhite, fontSize: 15)),
          Switch(
            value: _isBillable,
            activeColor: AppColors.accentCyan,
            onChanged: (val) => setState(() => _isBillable = val),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {IconData? icon, bool isNumeric = false, bool isRequired = false, bool isReadOnly = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      readOnly: isReadOnly,
      maxLines: maxLines,
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: isNumeric ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))] : [],
      style: TextStyle(
        color: isReadOnly ? AppColors.textMuted : AppColors.textWhite,
        fontWeight: isReadOnly ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        labelText: label + (isRequired ? " *" : ""),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: isReadOnly ? AppColors.background : AppColors.surface,
        prefixIcon: icon != null ? Icon(icon, color: AppColors.textMuted) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentCyan)),
      ),
      validator: isRequired ? (value) => value == null || value.isEmpty ? 'Required' : null : null,
    );
  }
}