import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({Key? key}) : super(key: key);

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;

  List<dynamic> _projects = [];
  List<dynamic> _allBoards = [];
  List<dynamic> _filteredBoards = [];

  // Form selections
  String? _selectedProjectId;
  String? _selectedBoardId;
  String _selectedColumn = 'backlog';
  String _selectedPriority = 'medium';
  String? _selectedStoryPoints;
  DateTime? _selectedDueDate;

  // Controllers
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _assigneeCtrl = TextEditingController();
  final TextEditingController _timeEstimatedCtrl = TextEditingController();
  final TextEditingController _timeSpentCtrl = TextEditingController(text: '0'); // ADDED TIME SPENT CONTROLLER

  final String _projectsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_projects';
  final String _boardsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_kanban_boards';
  final String _tasksApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_kanban_tasks';

  // Column configuration
  final List<Map<String, dynamic>> _columns = [
    {'value': 'backlog', 'label': 'Backlog', 'icon': Icons.content_paste, 'color': Colors.orange},
    {'value': 'todo', 'label': 'To Do', 'icon': Icons.sync, 'color': Colors.blue},
    {'value': 'in_progress', 'label': 'In Progress', 'icon': Icons.settings, 'color': Colors.purple},
    {'value': 'review', 'label': 'Review', 'icon': Icons.visibility, 'color': Colors.indigo},
    {'value': 'done', 'label': 'Done', 'icon': Icons.check_box, 'color': Colors.green},
  ];

  final List<String> _storyPointOptions = ['1', '2', '3', '5', '8', '13', '21'];

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _assigneeCtrl.dispose();
    _timeEstimatedCtrl.dispose();
    _timeSpentCtrl.dispose(); // DISPOSE IT
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      final responses = await Future.wait([
        http.get(Uri.parse(_projectsApiUrl)),
        http.get(Uri.parse(_boardsApiUrl)),
      ]);

      final projectsData = json.decode(responses[0].body);
      final boardsData = json.decode(responses[1].body);

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

          if (boardsData['status'] == 'success') {
            _allBoards = boardsData['data'] ?? [];
          }
        });
      }
    } catch (e) {
      _showSnackbar("Failed to load projects and boards.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onProjectSelected(String? projectId) {
    if (projectId == null) return;

    setState(() {
      _selectedProjectId = projectId;
      _selectedBoardId = null;

      _filteredBoards = _allBoards.where((b) => b['project_id'].toString() == projectId).toList();

      if (_filteredBoards.isNotEmpty) {
        _selectedBoardId = _filteredBoards.first['id'].toString();
      }
    });
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
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
    if (picked != null && picked != _selectedDueDate) {
      setState(() => _selectedDueDate = picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBoardId == null) {
      _showSnackbar("Please select a Board", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String reporterName = prefs.getString('name') ?? 'System';

      final tempCode = 'TASK-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';

      final Map<String, dynamic> payload = {
        'task_code': tempCode,
        'project_id': _selectedProjectId,
        'board_id': _selectedBoardId,
        'title': _titleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
        'column_name': _selectedColumn,
        'priority': _selectedPriority,
        'assignee': _assigneeCtrl.text.trim().isEmpty ? null : _assigneeCtrl.text.trim(),
        'reporter': reporterName,
        'story_points': _selectedStoryPoints,
        'time_estimated': _timeEstimatedCtrl.text.trim().isEmpty ? null : _timeEstimatedCtrl.text.trim(),
        'time_spent': _timeSpentCtrl.text.trim().isEmpty ? '0' : _timeSpentCtrl.text.trim(), // SEND TIME SPENT
        'due_date': _selectedDueDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDueDate!) : null,
        'position': '0',
        'checklist': '[]',
        'comments': '[]',
        'attachments': '[]',
      };

      final response = await http.post(
        Uri.parse(_tasksApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        _showSnackbar("Task created successfully!");
        Navigator.pop(context, true);
      } else {
        _showSnackbar(data['message'] ?? 'Failed to create task.', isError: true);
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
        title: const Text("Create New Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              _buildSectionTitle("Placement"),
              _buildProjectDropdown(),
              const SizedBox(height: 16),
              _buildBoardDropdown(),
              const SizedBox(height: 24),

              _buildSectionTitle("Task Details"),
              _buildTextField("Task Title *", _titleCtrl, isRequired: true),
              const SizedBox(height: 16),

              const Text("Column Phase *", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 6),
              _buildColumnDropdown(),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _buildPriorityDropdown()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField("Assignee", _assigneeCtrl, icon: Icons.person_outline)),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle("Estimates & Scheduling"),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildStoryPointsDropdown()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField("Estimated Time (hours)", _timeEstimatedCtrl, isNumeric: true)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTextField("Time Spent (hours)", _timeSpentCtrl, isNumeric: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDueDatePicker()),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle("Description"),
              _buildTextField("Add details...", _descriptionCtrl, maxLines: 4),
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
                    : const Text("Save Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      validator: (value) => value == null ? 'Required' : null,
    );
  }

  Widget _buildBoardDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBoardId,
      isExpanded: true,
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textWhite),
      decoration: InputDecoration(
        labelText: "Select Board *",
        labelStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: const Icon(Icons.view_kanban_outlined, color: AppColors.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
      ),
      items: _filteredBoards.map((board) {
        return DropdownMenuItem<String>(
          value: board['id'].toString(),
          child: Text(board['name'] ?? 'Unknown Board'),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedBoardId = value),
      validator: (value) => value == null ? 'Required' : null,
    );
  }

  Widget _buildColumnDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedColumn,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          items: _columns.map((col) {
            return DropdownMenuItem<String>(
              value: col['value'],
              child: Row(
                children: [
                  Icon(col['icon'], color: col['color'], size: 20),
                  const SizedBox(width: 12),
                  Text(col['label'], style: const TextStyle(color: AppColors.textWhite, fontSize: 14)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedColumn = value);
          },
        ),
      ),
    );
  }

  Widget _buildPriorityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Priority", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedPriority,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
          ),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Low')),
            DropdownMenuItem(value: 'medium', child: Text('Medium')),
            DropdownMenuItem(value: 'high', child: Text('High')),
            DropdownMenuItem(value: 'critical', child: Text('Critical')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _selectedPriority = value);
          },
        ),
      ],
    );
  }

  Widget _buildStoryPointsDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Story Points", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedStoryPoints,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            hintText: "1, 2, 3, 5, 8",
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
          ),
          items: _storyPointOptions.map((points) {
            return DropdownMenuItem(value: points, child: Text(points));
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedStoryPoints = value);
          },
        ),
      ],
    );
  }

  Widget _buildDueDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Due Date", style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _selectDueDate(context),
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
                  _selectedDueDate != null ? DateFormat('dd-MM-yyyy').format(_selectedDueDate!) : 'dd-mm-yyyy',
                  style: TextStyle(
                      color: _selectedDueDate != null ? AppColors.textWhite : AppColors.textMuted,
                      fontSize: 15
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Modified TextField Builder to handle "Time Spent" appropriately
  Widget _buildTextField(String label, TextEditingController controller, {IconData? icon, bool isRequired = false, int maxLines = 1, bool isNumeric = false}) {
    bool isTimeField = label.contains('Estimated Time') || label.contains('Time Spent');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isTimeField)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: isNumeric ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))] : [],
          style: const TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            labelText: !isTimeField ? label : null,
            hintText: isTimeField ? 'Hours' : null,
            labelStyle: const TextStyle(color: AppColors.textMuted),
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            prefixIcon: icon != null ? Icon(icon, color: AppColors.textMuted) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentCyan)),
          ),
          validator: isRequired ? (value) => value == null || value.isEmpty ? 'Required field' : null : null,
        ),
      ],
    );
  }
}