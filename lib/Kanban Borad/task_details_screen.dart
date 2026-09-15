import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
class TaskDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTaskUpdated;

  const TaskDetailsScreen({
    Key? key,
    required this.task,
    required this.onTaskUpdated,
  }) : super(key: key);

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late Map<String, dynamic> _currentTask;
  bool _isDeleting = false;

  final String _tasksApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_kanban_tasks';

  @override
  void initState() {
    super.initState();
    _currentTask = Map<String, dynamic>.from(widget.task);
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return AppColors.textMuted;
    }
  }

  String _formatColumnName(String? name) {
    if (name == null || name.isEmpty) return 'N/A';
    return name.split('_').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '').join(' ');
  }

  // ==== API LOGIC FOR DELETION ====
  Future<void> _deleteTask() async {
    Navigator.pop(context); // Close the confirmation dialog
    setState(() => _isDeleting = true);

    try {
      final response = await http.post(
        Uri.parse(_tasksApiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "action": "delete",
          "id": _currentTask['id'].toString()
        }),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Task deleted successfully!"),
              backgroundColor: AppColors.successGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true); // Go back to Kanban Board and pass 'true' to trigger refresh
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Failed to delete task.'),
              backgroundColor: AppColors.dangerRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _isDeleting = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection error: $e"),
            backgroundColor: AppColors.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _isDeleting = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Confirm Deletion", style: TextStyle(color: AppColors.textWhite)),
        content: Text(
          "Are you sure you want to delete '${_currentTask['title']}'? This action cannot be undone.",
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: _deleteTask,
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final priority = _currentTask['priority'] ?? 'medium';
    final priorityColor = _getPriorityColor(priority);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.premiumGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _currentTask['task_code'] ?? 'Task Details',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
        actions: [
          // EDIT BUTTON
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            tooltip: "Edit Task",
            onPressed: _isDeleting ? null : () async {
              final updatedTask = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditTaskScreen(task: _currentTask),
                ),
              );

              if (updatedTask != null && updatedTask is Map<String, dynamic>) {
                setState(() {
                  _currentTask = updatedTask;
                });
                widget.onTaskUpdated();
              }
            },
          ),
          // DELETE BUTTON
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: "Delete Task",
            onPressed: _isDeleting ? null : _confirmDelete,
          ),
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator(color: AppColors.dangerRed))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Status Header
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.accentCyan.withOpacity(0.3)),
                        ),
                        child: Text(
                          _formatColumnName(_currentTask['column_name']),
                          style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: priorityColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          priority.toString().toUpperCase(),
                          style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentTask['title'] ?? 'Untitled Task',
                    style: const TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Metrics & Estimations Grid
            _buildSectionHeader("Estimates & Tracking"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  _detailRow("Story Points", _currentTask['story_points']?.toString() ?? 'Not Set'),
                  const Divider(color: AppColors.borderDark, height: 24),
                  _detailRow("Estimated Time", _currentTask['time_estimated'] != null ? "${_currentTask['time_estimated']} hrs" : 'N/A'),
                  const Divider(color: AppColors.borderDark, height: 24),
                  _detailRow("Time Spent", "${_currentTask['time_spent'] ?? '0'} hrs"),
                  const Divider(color: AppColors.borderDark, height: 24),
                  _detailRow("Due Date", _currentTask['due_date'] ?? 'No deadline set'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Assignment
            _buildSectionHeader("People"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  _detailRow("Assignee", _currentTask['assignee'] ?? 'Unassigned'),
                  const Divider(color: AppColors.borderDark, height: 24),
                  _detailRow("Reporter", _currentTask['reporter'] ?? 'System'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Description
            _buildSectionHeader("Description"),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Text(
                (_currentTask['description'] != null && _currentTask['description'].toString().trim().isNotEmpty)
                    ? _currentTask['description']
                    : "No description provided.",
                style: const TextStyle(color: AppColors.textWhite, fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(color: AppColors.accentCyan, fontSize: 14, fontWeight: FontWeight.bold),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppColors.textWhite, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ==========================================
// EDIT TASK SCREEN
// ==========================================

class EditTaskScreen extends StatefulWidget {
  final Map<String, dynamic> task;

  const EditTaskScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
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
  late TextEditingController _titleCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _assigneeCtrl;
  late TextEditingController _timeEstimatedCtrl;
  late TextEditingController _timeSpentCtrl; // ADDED TIME SPENT CONTROLLER

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
    _initializeData();
    _fetchDropdownData();
  }

  void _initializeData() {
    final t = widget.task;

    _titleCtrl = TextEditingController(text: t['title'] ?? '');
    _descriptionCtrl = TextEditingController(text: t['description'] ?? '');
    _assigneeCtrl = TextEditingController(text: t['assignee'] ?? '');
    _timeEstimatedCtrl = TextEditingController(text: t['time_estimated']?.toString() ?? '');
    _timeSpentCtrl = TextEditingController(text: t['time_spent']?.toString() ?? '0'); // INIT TIME SPENT

    _selectedColumn = (t['column_name'] ?? 'backlog').toString().toLowerCase();
    _selectedPriority = (t['priority'] ?? 'medium').toString().toLowerCase();

    final sp = t['story_points']?.toString();
    if (sp != null && _storyPointOptions.contains(sp)) {
      _selectedStoryPoints = sp;
    }

    if (t['due_date'] != null && t['due_date'].toString().isNotEmpty) {
      try {
        _selectedDueDate = DateTime.parse(t['due_date'].toString());
      } catch (_) {}
    }
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

          final String? existingProjectId = widget.task['project_id']?.toString();
          final String? existingBoardId = widget.task['board_id']?.toString();

          if (existingProjectId != null && _projects.any((p) => p['id'].toString() == existingProjectId)) {
            _selectedProjectId = existingProjectId;
            _filteredBoards = _allBoards.where((b) => b['project_id'].toString() == existingProjectId).toList();

            if (existingBoardId != null && _filteredBoards.any((b) => b['id'].toString() == existingBoardId)) {
              _selectedBoardId = existingBoardId;
            }
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
      final Map<String, dynamic> payload = {
        'id': widget.task['id'].toString(),
        'project_id': _selectedProjectId,
        'board_id': _selectedBoardId,
        'title': _titleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
        'column_name': _selectedColumn,
        'priority': _selectedPriority,
        'assignee': _assigneeCtrl.text.trim().isEmpty ? null : _assigneeCtrl.text.trim(),
        'story_points': _selectedStoryPoints,
        'time_estimated': _timeEstimatedCtrl.text.trim().isEmpty ? null : _timeEstimatedCtrl.text.trim(),
        'time_spent': _timeSpentCtrl.text.trim().isEmpty ? '0' : _timeSpentCtrl.text.trim(), // SEND TIME SPENT
        'due_date': _selectedDueDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDueDate!) : null,
      };

      final response = await http.post(
        Uri.parse(_tasksApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        _showSnackbar("Task updated successfully!");

        Map<String, dynamic> updatedTask = Map<String, dynamic>.from(widget.task);
        updatedTask.addAll(payload);

        Navigator.pop(context, updatedTask);
      } else {
        _showSnackbar(data['message'] ?? 'Failed to update task.', isError: true);
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
        title: Text("Edit ${widget.task['task_code'] ?? 'Task'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    : const Text("Update Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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