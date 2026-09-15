import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart'; // Ensure this points to your theme file

class AddSprintScreen extends StatefulWidget {
  const AddSprintScreen({Key? key}) : super(key: key);

  @override
  State<AddSprintScreen> createState() => _AddSprintScreenState();
}

class _AddSprintScreenState extends State<AddSprintScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;

  List<dynamic> _projects = [];

  // Form selections
  String? _selectedProjectId;
  DateTime? _startDate;
  DateTime? _endDate;

  // Controllers
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _goalsCtrl = TextEditingController();

  final String _projectsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_projects';
  final String _sprintsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_sprints';

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _goalsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      final response = await http.get(Uri.parse(_projectsApiUrl));
      final projectsData = json.decode(response.body);

      if (mounted) {
        setState(() {
          // Process Projects
          if (projectsData['status'] == 'success') {
            List<dynamic> allProj = projectsData['data'] ?? [];
            if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
              _projects = allProj.where((p) => p['company_id']?.toString() == savedCompanyId).toList();
            } else {
              _projects = allProj;
            }
          }
        });
      }
    } catch (e) {
      _showSnackbar("Failed to load projects.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? (_startDate ?? DateTime.now())),
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

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Auto-adjust end date if it's before the new start date
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate!.add(const Duration(days: 14)); // Default 2-week sprint
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      _showSnackbar("Please select both Start and End dates", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String userId = prefs.getString('user_id') ?? '1';

      // Construct Payload exactly matching the skydevs_sprints database schema
      final Map<String, dynamic> payload = {
        'project_id': _selectedProjectId,
        'sprint_number': '1', // Defaulting to 1 for new sprints
        'name': _nameCtrl.text.trim(),
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        'status': 'planned', // Matching your API format
        'goals': _goalsCtrl.text.trim().isEmpty ? null : _goalsCtrl.text.trim(),
        'total_tasks': '0',
        'completed_tasks': '0',
        'created_by': userId,
      };

      final response = await http.post(
        Uri.parse(_sprintsApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        _showSnackbar("Sprint created successfully!");
        Navigator.pop(context, true); // Return true to refresh parent screen
      } else {
        _showSnackbar(data['message'] ?? 'Failed to create sprint.', isError: true);
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
        title: const Text("Create New Sprint", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              // --- PROJECT SELECTION ---
              _buildSectionTitle("Placement"),
              _buildProjectDropdown(),
              const SizedBox(height: 24),

              // --- SPRINT DETAILS ---
              _buildSectionTitle("Sprint Details"),
              _buildTextField("Sprint Name *", _nameCtrl, isRequired: true, icon: Icons.run_circle_outlined),
              const SizedBox(height: 24),

              // --- SCHEDULE ---
              _buildSectionTitle("Schedule"),
              Row(
                children: [
                  Expanded(child: _buildDatePickerField("Start Date *", _startDate, true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDatePickerField("End Date *", _endDate, false)),
                ],
              ),
              const SizedBox(height: 24),

              // --- GOALS ---
              _buildSectionTitle("Sprint Goals"),
              _buildTextField("Define the goals for this sprint...", _goalsCtrl, maxLines: 4),
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
                    : const Text("Start Sprint", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      onChanged: (value) => setState(() => _selectedProjectId = value),
      validator: (value) => value == null ? 'Required' : null,
    );
  }

  Widget _buildDatePickerField(String label, DateTime? dateValue, bool isStartDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _selectDate(context, isStartDate),
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
                const Icon(Icons.calendar_month, color: AppColors.textMuted, size: 20),
                const SizedBox(width: 12),
                Text(
                  dateValue != null ? DateFormat('dd MMM yyyy').format(dateValue) : 'Select Date',
                  style: TextStyle(
                      color: dateValue != null ? AppColors.textWhite : AppColors.textMuted,
                      fontSize: 14
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {IconData? icon, bool isRequired = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: icon != null ? Icon(icon, color: AppColors.textMuted) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentCyan)),
      ),
      validator: isRequired ? (value) => value == null || value.trim().isEmpty ? 'Required field' : null : null,
    );
  }
}