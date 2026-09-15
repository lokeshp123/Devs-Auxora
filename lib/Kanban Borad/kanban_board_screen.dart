import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
// ADD THESE IMPORTS FOR PRINTING
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:skydevs/Kanban%20Borad/task_details_screen.dart';
import '../theme.dart';
import 'add_task_screen.dart';
import 'add_sprint_screen.dart';

class KanbanBoardScreen extends StatefulWidget {
  const KanbanBoardScreen({Key? key}) : super(key: key);

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  bool _isLoading = true;
  String _errorMessage = '';

  List<dynamic> _projects = [];
  List<dynamic> _boards = [];
  List<dynamic> _tasks = [];

  String? _selectedBoardId;

  final String _projectsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_projects';
  final String _boardsApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_kanban_boards';
  final String _tasksApiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_kanban_tasks';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');
      final bool isClient = prefs.getBool('isClient') ?? false;
      final String? clientId = prefs.getString('clientId');

      final responses = await Future.wait([
        http.get(Uri.parse(_projectsApiUrl)),
        http.get(Uri.parse(_boardsApiUrl)),
        http.get(Uri.parse(_tasksApiUrl)),
      ]);

      final projectsData = json.decode(responses[0].body);
      final boardsData = json.decode(responses[1].body);
      final tasksData = json.decode(responses[2].body);

      if (mounted) {
        setState(() {
          if (projectsData['status'] == 'success') {
            List<dynamic> allProjects = projectsData['data'] ?? [];
            if (isClient && clientId != null && clientId.isNotEmpty) {
              _projects = allProjects.where((p) => p['client_id']?.toString() == clientId).toList();
            } else if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
              _projects = allProjects.where((p) => p['company_id']?.toString() == savedCompanyId).toList();
            } else {
              _projects = allProjects;
            }
          }

          Set<String> validProjectIds = _projects.map((p) => p['id'].toString()).toSet();

          if (boardsData['status'] == 'success') {
            List<dynamic> allBoards = boardsData['data'] ?? [];
            _boards = allBoards.where((b) => validProjectIds.contains(b['project_id'].toString())).toList();

            if (_boards.isNotEmpty && _selectedBoardId == null) {
              _selectedBoardId = _boards.first['id'].toString();
            }
          }

          if (tasksData['status'] == 'success') {
            _tasks = tasksData['data'] ?? [];
          }

          _errorMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Connection error: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _parseColumns(String? columnsJson) {
    if (columnsJson == null || columnsJson.isEmpty) {
      return ["backlog", "todo", "in_progress", "review", "done"];
    }
    try {
      List<dynamic> parsed = json.decode(columnsJson);
      return parsed.map((e) => e.toString()).toList();
    } catch (e) {
      return ["backlog", "todo", "in_progress", "review", "done"];
    }
  }

  String _formatColumnName(String name) {
    return name.split('_').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '').join(' ');
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.green;
      default: return AppColors.textMuted;
    }
  }

  // ==== ACTUAL PRINT LOGIC ====
  Future<void> _exportBoard() async {
    final selectedBoard = _boards.firstWhere(
          (b) => b['id'].toString() == _selectedBoardId,
      orElse: () => null,
    );

    if (selectedBoard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No board selected to print.")),
      );
      return;
    }

    final columns = _parseColumns(selectedBoard['columns']);
    final boardName = selectedBoard['name'] ?? 'Kanban Board';
    final printDate = DateTime.now().toString().split('.')[0];

    // Create the PDF document
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  boardName,
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                ),
                pw.Text(
                  "Printed: $printDate",
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          List<pw.Widget> content = [];

          content.add(pw.SizedBox(height: 16));

          for (String column in columns) {
            final columnTasks = _tasks.where((t) =>
            t['board_id'].toString() == _selectedBoardId &&
                t['column_name'] == column
            ).toList();

            // Column Header Banner
            content.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const pw.EdgeInsets.only(top: 14, bottom: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      _formatColumnName(column).toUpperCase(),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.black),
                    ),
                    pw.Text(
                      "${columnTasks.length} Tasks",
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            );

            if (columnTasks.isEmpty) {
              content.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                  child: pw.Text("No tasks in this phase.", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                ),
              );
            } else {
              // Task Table for this column
              content.add(
                pw.TableHelper.fromTextArray(
                  headers: ['Task Code', 'Title', 'Priority', 'Assignee', 'Time Spent'],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellHeight: 22,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.center,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.center,
                  },
                  data: columnTasks.map((task) {
                    return [
                      task['task_code'] ?? 'TASK',
                      task['title'] ?? 'Untitled',
                      (task['priority'] ?? 'medium').toString().toUpperCase(),
                      task['assignee'] ?? 'Unassigned',
                      task['time_spent'] != null ? "${task['time_spent']}h" : '0h',
                    ];
                  }).toList(),
                ),
              );
            }
          }

          return content;
        },
      ),
    );

    // Immediately launches the native Print / PDF Preview screen
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: "${boardName.replaceAll(' ', '_')}_Export.pdf",
    );
  }

  void _showShareDialog() {
    final selectedBoard = _boards.firstWhere((b) => b['id'].toString() == _selectedBoardId, orElse: () => null);
    if (selectedBoard == null) return;

    final String projectId = selectedBoard['project_id'].toString();
    final String boardName = selectedBoard['name'] ?? 'Kanban Board';
    final String boardUrl = "https://auxoradevs.auxorasystems.com/skydevs/projects/$projectId/kanban";

    TextEditingController emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF6B4EE6),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.share, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text("Share Board", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, color: Colors.white70, size: 20),
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Board URL", style: TextStyle(color: Colors.black87, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(boardUrl, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: boardUrl));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("URL Copied!")));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1B6DF9),
                                  borderRadius: BorderRadius.horizontal(right: Radius.circular(5)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.copy, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text("Copy", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text("Share via Email", style: TextStyle(color: Colors.black87, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: emailCtrl,
                                decoration: const InputDecoration(
                                  hintText: "colleague@example.com",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                final email = emailCtrl.text.trim();
                                if (email.isNotEmpty) {
                                  final Uri emailLaunchUri = Uri(
                                    scheme: 'mailto',
                                    path: email,
                                    query: 'subject=Kanban Board Link&body=Here is the link to the Kanban Board: $boardUrl',
                                  );
                                  launchUrl(emailLaunchUri);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00C7D9),
                                  borderRadius: BorderRadius.horizontal(right: Radius.circular(5)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.email, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text("Send", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Divider(),
                      const SizedBox(height: 12),

                      // Social Share
                      const Center(child: Text("Or share directly:", style: TextStyle(color: Colors.black87))),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ============ WHATSAPP ============
                          OutlinedButton.icon(
                            onPressed: () async {
                              // Build the message text
                              final String message = "$boardName\n$boardUrl";
                              final String encodedText = Uri.encodeComponent(message);

                              // ✅ api.whatsapp.com — opens WhatsApp app directly on phone,
                              // falls back to WhatsApp Web in browser if app not installed.
                              final Uri whatsappUri = Uri.parse(
                                "https://api.whatsapp.com/send/?text=$encodedText&type=custom_url&app_absent=0",
                              );

                              try {
                                debugPrint("🔍 Opening WhatsApp: $whatsappUri");
                                final bool launched = await launchUrl(
                                  whatsappUri,
                                  mode: LaunchMode.externalApplication,
                                );
                                debugPrint("🔍 WhatsApp launched: $launched");
                              } catch (e) {
                                debugPrint("❌ WhatsApp error: $e");
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Could not open WhatsApp: $e")),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 18),
                            label: const Text("WhatsApp", style: TextStyle(color: Color(0xFF1B6DF9))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF1B6DF9)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // ============ LINKEDIN ============
                          OutlinedButton.icon(
                            onPressed: () async {
                              final String encodedUrl = Uri.encodeComponent(boardUrl);

                              // Official LinkedIn share URL — opens LinkedIn app via App Links,
                              // or the browser if not installed.
                              final Uri linkedinUri = Uri.parse(
                                "https://www.linkedin.com/sharing/share-offsite/?url=$encodedUrl",
                              );

                              try {
                                debugPrint("🔍 Opening LinkedIn: $linkedinUri");
                                final bool launched = await launchUrl(
                                  linkedinUri,
                                  mode: LaunchMode.externalApplication,
                                );
                                debugPrint("🔍 LinkedIn launched: $launched");
                              } catch (e) {
                                debugPrint("❌ LinkedIn error: $e");
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Could not open LinkedIn: $e")),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.work, color: Color(0xFF0A66C2), size: 18),
                            label: const Text("LinkedIn", style: TextStyle(color: Color(0xFF0A66C2))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0A66C2)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        title: const Text("Kanban Boards", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.run_circle_outlined, color: Colors.white),
            tooltip: "Create Sprint",
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddSprintScreen()));
              if (result == true) _fetchData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh Data",
            onPressed: _fetchData,
          )
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentCyan,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: "Create Task",
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddTaskScreen()));
          if (result == true) _fetchData();
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentCyan));
    }
    if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage, style: const TextStyle(color: AppColors.dangerRed)));
    }
    if (_boards.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.view_kanban_outlined, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text("No Kanban boards available.", style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    final selectedBoard = _boards.firstWhere((b) => b['id'].toString() == _selectedBoardId, orElse: () => _boards.first);
    final columns = _parseColumns(selectedBoard['columns']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.borderDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBoardId,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textWhite),
                  style: const TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
                  items: _boards.map((board) {
                    return DropdownMenuItem<String>(
                      value: board['id'].toString(),
                      child: Text(board['name'] ?? 'Untitled Board'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedBoardId = value);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _exportBoard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E8449),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text("Export Board", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showShareDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1C40F),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text("Share Board", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            itemCount: columns.length,
            itemBuilder: (context, index) {
              final columnName = columns[index];
              final columnTasks = _tasks.where((t) =>
              t['board_id'].toString() == _selectedBoardId &&
                  t['column_name'] == columnName
              ).toList();

              columnTasks.sort((a, b) {
                int posA = int.tryParse(a['position']?.toString() ?? '0') ?? 0;
                int posB = int.tryParse(b['position']?.toString() ?? '0') ?? 0;
                return posA.compareTo(posB);
              });

              return _buildKanbanColumn(columnName, columnTasks);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKanbanColumn(String columnKey, List<dynamic> columnTasks) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: AppColors.borderDark)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatColumnName(columnKey),
                  style: const TextStyle(color: AppColors.textWhite, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    columnTasks.length.toString(),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: columnTasks.length,
              itemBuilder: (context, index) {
                return _buildTaskCard(columnTasks[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final priority = task['priority'] ?? 'medium';
    final priorityColor = _getPriorityColor(priority);
    final assignee = task['assignee'];

    int commentsCount = 0;
    try {
      List<dynamic> parsedComments = json.decode(task['comments'] ?? '[]');
      commentsCount = parsedComments.length;
    } catch (_) {}

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailsScreen(
              task: task,
              onTaskUpdated: () => _fetchData(),
            ),
          ),
        );
        if (result == true) _fetchData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderDark),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task['task_code'] ?? 'TASK',
                  style: const TextStyle(color: AppColors.accentCyan, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
                Container(width: 32, height: 4, decoration: BoxDecoration(color: priorityColor, borderRadius: BorderRadius.circular(2))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task['title'] ?? 'Untitled Task',
              style: const TextStyle(color: AppColors.textWhite, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task['description'],
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.background,
                      child: Icon(Icons.person, size: 14, color: assignee != null ? AppColors.accentCyan : AppColors.textMuted),
                    ),
                    const SizedBox(width: 6),
                    Text(assignee ?? 'Unassigned', style: TextStyle(color: assignee != null ? AppColors.textWhite : AppColors.textMuted, fontSize: 11)),
                  ],
                ),
                Row(
                  children: [
                    if (commentsCount > 0) ...[
                      const Icon(Icons.chat_bubble_outline, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(commentsCount.toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 8),
                    ],
                    if (task['time_spent'] != null && task['time_spent'] != '0') ...[
                      const Icon(Icons.timer_outlined, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text("${task['time_spent']}h", style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ]
                  ],
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

