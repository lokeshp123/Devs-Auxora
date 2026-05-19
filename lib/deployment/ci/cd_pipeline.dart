import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme.dart';

class CICDPipelineScreen extends StatefulWidget {
  const CICDPipelineScreen({Key? key}) : super(key: key);

  @override
  State<CICDPipelineScreen> createState() => _CICDPipelineScreenState();
}

class _CICDPipelineScreenState extends State<CICDPipelineScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _deployments = [];
  List<dynamic> _projects = [];

  final String _apiUrl = 'https://skydevs.skynetproduct.com/skydevs_API.php?table=skydevs_deployments';
  final String _projectsApiUrl = 'https://skydevs.skynetproduct.com/skydevs_API.php?table=skydevs_projects';

  // Statistics
  int _totalDeployments = 0;
  int _successfulDeployments = 0;
  int _failedDeployments = 0;
  double _avgDuration = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _fetchDeployments();
  }

  Future<void> _fetchProjects() async {
    try {
      final response = await http.get(Uri.parse(_projectsApiUrl));
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _projects = data['data'] ?? [];
        });
      }
    } catch (e) {
      print("Error fetching projects: $e");
    }
  }

  String _getProjectName(String? projectId) {
    if (projectId == null) return 'N/A';
    final project = _projects.firstWhere(
          (p) => p['id'].toString() == projectId,
      orElse: () => null,
    );
    return project != null ? project['project_name'] ?? 'Unknown' : 'Unknown';
  }

  Future<void> _fetchDeployments() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      final response = await http.get(Uri.parse(_apiUrl));
      final data = json.decode(response.body);

      if (data['status'] == "success") {
        List<dynamic> allDeployments = data['data'] ?? [];

        setState(() {
          if (savedCompanyId != null && savedCompanyId.isNotEmpty) {
            _deployments = allDeployments.where((deployment) {
              return deployment['company_id']?.toString() == savedCompanyId;
            }).toList();
          } else {
            _deployments = allDeployments;
          }
          _errorMessage = '';
          _calculateStatistics();
        });
      } else {
        setState(() => _errorMessage = "Failed to load deployments.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Connection error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateStatistics() {
    _totalDeployments = _deployments.length;
    _successfulDeployments = _deployments.where((d) => d['status'] == 'success').length;
    _failedDeployments = _deployments.where((d) => d['status'] == 'failed').length;

    double totalDuration = _deployments.fold(0.0, (sum, d) {
      return sum + (double.tryParse(d['duration_minutes']?.toString() ?? '0') ?? 0);
    });
    _avgDuration = _totalDeployments > 0 ? totalDuration / _totalDeployments : 0.0;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success': return Colors.green;
      case 'failed': return Colors.red;
      case 'pending': return Colors.orange;
      case 'in_progress': return Colors.blue;
      default: return AppColors.textMuted;
    }
  }

  String _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'success': return '✅';
      case 'failed': return '❌';
      case 'pending': return '⏳';
      case 'in_progress': return '🔄';
      default: return '⚪';
    }
  }

  String _formatDate(String? dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final date = DateTime.parse(dateTime);
      return "${_getMonthAbbr(date.month)} ${date.day}, ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}";
    } catch (e) {
      return dateTime;
    }
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  void _showDeploymentDetails(Map<String, dynamic> deployment) {
    // CHANGED: Navigate to full screen instead of showing dialog
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeploymentDetailsScreen(
          deployment: deployment,
          projectName: _getProjectName(deployment['project_id']?.toString()),
        ),
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
        title: const Text("CI/CD Pipeline", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

    return RefreshIndicator(
      color: AppColors.accentCyan,
      backgroundColor: AppColors.surface,
      onRefresh: _fetchDeployments,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatisticsCards(),
            const SizedBox(height: 24),
            _buildDeploymentHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        _buildStatCard("Total", _totalDeployments.toString(), Icons.cloud_queue, Colors.blue),
        const SizedBox(width: 8),
        _buildStatCard("Success", _successfulDeployments.toString(), Icons.check_circle, Colors.green),
        const SizedBox(width: 8),
        _buildStatCard("Failed", _failedDeployments.toString(), Icons.error, Colors.red),
        const SizedBox(width: 8),
        _buildStatCard("Avg Dur.", "${_avgDuration.toStringAsFixed(0)}m", Icons.timer, Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textWhite),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeploymentHistory() {
    if (_deployments.isEmpty) {
      return const Center(
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text("No deployment history", style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Deployment History",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textWhite),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.resolveWith((states) => AppColors.surface),
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text("Build #", style: TextStyle(color: AppColors.textWhite, fontSize: 13))),
                DataColumn(label: Text("Code", style: TextStyle(color: AppColors.textWhite, fontSize: 13))),
                DataColumn(label: Text("Project", style: TextStyle(color: AppColors.textWhite, fontSize: 13))),
                DataColumn(label: Text("Status", style: TextStyle(color: AppColors.textWhite, fontSize: 13))),
                DataColumn(label: Text("Actions", style: TextStyle(color: AppColors.textWhite, fontSize: 13))),
              ],
              rows: _deployments.map((deployment) {
                final status = deployment['status'] ?? 'pending';
                final statusColor = _getStatusColor(status);

                return DataRow(cells: [
                  DataCell(Text("#${deployment['build_number'] ?? '1'}", style: const TextStyle(color: AppColors.textWhite))),
                  DataCell(Text(deployment['deployment_code'] ?? 'N/A', style: const TextStyle(color: AppColors.textWhite, fontFamily: 'monospace'))),
                  DataCell(Text(_getProjectName(deployment['project_id']?.toString()), style: const TextStyle(color: AppColors.textWhite))),
                  DataCell(
                    Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  DataCell(
                    InkWell(
                      onTap: () => _showDeploymentDetails(deployment),
                      child: const Icon(Icons.info_outline, color: AppColors.accentCyan, size: 20),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// DEPLOYMENT DETAILS SCREEN - FULL SCREEN VERSION
// ==========================================

class DeploymentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> deployment;
  final String projectName;

  const DeploymentDetailsScreen({
    Key? key,
    required this.deployment,
    required this.projectName,
  }) : super(key: key);

  @override
  State<DeploymentDetailsScreen> createState() => _DeploymentDetailsScreenState();
}

class _DeploymentDetailsScreenState extends State<DeploymentDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _deploymentLogs = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _parseDeploymentLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _parseDeploymentLogs() {
    final logs = widget.deployment['deployment_logs'];
    if (logs != null && logs.toString().isNotEmpty) {
      _deploymentLogs = logs.toString();
    } else {
      _deploymentLogs = "No deployment logs available.";
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final date = DateTime.parse(dateTime);
      return "${_getMonthAbbr(date.month)} ${date.day}, ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}";
    } catch (e) {
      return dateTime;
    }
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Color _getStageStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'passed': return Colors.green;
      case 'failed': return Colors.red;
      case 'pending': return Colors.orange;
      default: return AppColors.textMuted;
    }
  }

  String _getStageStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'passed': return '✅';
      case 'failed': return '❌';
      case 'pending': return '⏳';
      default: return '⚪';
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.deployment;
    final status = d['status'] ?? 'pending';
    final statusColor = status == 'success' ? Colors.green : (status == 'failed' ? Colors.red : Colors.orange);
    final stageStatuses = [
      {'stage': 'CODE', 'status': d['code_status']},
      {'stage': 'BUILD', 'status': d['build_status']},
      {'stage': 'TEST', 'status': d['test_status']},
      {'stage': 'STAGING', 'status': d['staging_status']},
      {'stage': 'UAT', 'status': d['uat_status']},
      {'stage': 'PRODUCTION', 'status': d['production_status']},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.premiumGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d['deployment_code'] ?? 'Deployment Details',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
            ),
            Text(
              widget.projectName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(status == 'success' ? '✅' : (status == 'failed' ? '❌' : '⏳'), style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.accentCyan,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.accentCyan,
              tabs: const [
                Tab(text: "Information"),
                Tab(text: "Stage Status"),
                Tab(text: "Test Results"),
                Tab(text: "Logs"),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInformationTab(),
                _buildStageStatusTab(stageStatuses),
                _buildTestResultsTab(),
                _buildLogsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationTab() {
    final d = widget.deployment;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow("Deployment Code", d['deployment_code'] ?? 'N/A'),
                  _infoRow("Build Number", "#${d['build_number'] ?? '1'}"),
                  _infoRow("Project", widget.projectName),
                  _infoRow("Triggered By", d['triggered_by'] ?? 'System'),
                  _infoRow("Branch", d['branch'] ?? 'develop'),
                  _infoRow("Commit Hash", d['commit_hash'] ?? 'N/A'),
                  _infoRow("Start Time", _formatDateTime(d['start_time'])),
                  _infoRow("End Time", _formatDateTime(d['end_time'])),
                  _infoRow("Duration", "${d['duration_minutes'] ?? '0'} minutes"),
                  _infoRow("Status", d['status']?.toString().toUpperCase() ?? 'PENDING'),
                  _infoRow("Stage", d['stage']?.toString().toUpperCase() ?? 'UNKNOWN'),
                  if (d['staging_url'] != null && d['staging_url'].toString().isNotEmpty)
                    _infoRow("Staging URL", d['staging_url'], isLink: true),
                  if (d['uat_url'] != null && d['uat_url'].toString().isNotEmpty)
                    _infoRow("UAT URL", d['uat_url'], isLink: true),
                  if (d['production_url'] != null && d['production_url'].toString().isNotEmpty)
                    _infoRow("Production URL", d['production_url'], isLink: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageStatusTab(List<Map<String, dynamic>> stageStatuses) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          children: stageStatuses.map((stage) {
            final statusColor = _getStageStatusColor(stage['status']);
            final statusIcon = _getStageStatusIcon(stage['status']);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderDark.withOpacity(0.5))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stage['stage'],
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textWhite),
                  ),
                  Row(
                    children: [
                      Text(statusIcon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        stage['status']?.toString().toUpperCase() ?? 'PENDING',
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTestResultsTab() {
    final d = widget.deployment;
    final unitPassed = int.tryParse(d['unit_tests_passed']?.toString() ?? '0') ?? 0;
    final unitFailed = int.tryParse(d['unit_tests_failed']?.toString() ?? '0') ?? 0;
    final integrationPassed = int.tryParse(d['integration_tests_passed']?.toString() ?? '0') ?? 0;
    final integrationFailed = int.tryParse(d['integration_tests_failed']?.toString() ?? '0') ?? 0;
    final testCoverage = double.tryParse(d['test_coverage']?.toString() ?? '0') ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          children: [
            _testResultRow("Unit Tests", unitPassed, unitFailed),
            _testResultRow("Integration Tests", integrationPassed, integrationFailed),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.borderDark.withOpacity(0.5))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Test Coverage",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textWhite),
                  ),
                  Text(
                    "${testCoverage.toStringAsFixed(2)}%",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: testCoverage >= 80 ? Colors.green : (testCoverage >= 60 ? Colors.orange : Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _testResultRow(String title, int passed, int failed) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderDark.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textWhite),
          ),
          Row(
            children: [
              Text(
                "$passed passed",
                style: const TextStyle(color: Colors.green, fontSize: 13),
              ),
              const SizedBox(width: 12),
              Text(
                "$failed failed",
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: SelectableText(
          _deploymentLogs,
          style: const TextStyle(
            color: AppColors.textWhite,
            fontSize: 12,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              "$label:",
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: isLink
                ? GestureDetector(
              onTap: () {
                // TODO: Add url_launcher package to open URLs
                // You can implement URL launching here
              },
              child: Text(
                value,
                style: const TextStyle(color: AppColors.accentCyan, fontSize: 13, decoration: TextDecoration.underline),
              ),
            )
                : Text(
              value,
              style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}