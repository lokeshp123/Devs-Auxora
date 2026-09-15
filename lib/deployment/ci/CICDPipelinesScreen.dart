import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../theme.dart'; // Make sure this path correctly points to your AppColors file

class CICDPipelinesScreen extends StatefulWidget {
  final Map<String, dynamic>? projectData;

  const CICDPipelinesScreen({Key? key, this.projectData}) : super(key: key);

  @override
  State<CICDPipelinesScreen> createState() => _CICDPipelinesScreenState();
}

class _CICDPipelinesScreenState extends State<CICDPipelinesScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _projectDeployments = [];
  Map<String, dynamic>? _selectedDeployment;

  final String _deploymentsApiUrl =
      'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_deployments';

  @override
  void initState() {
    super.initState();
    _fetchDeployments();
  }

  Future<void> _fetchDeployments() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(_deploymentsApiUrl));
      final data = json.decode(response.body);

      if (data['status'] == "success") {
        List<dynamic> allDeployments = data['data'] ?? [];

        final projectId = widget.projectData?['id']?.toString() ?? '4'; // Fallback to 4 if null for testing

        // Filter deployments for this specific project and sort by build_number descending
        _projectDeployments = allDeployments.where((d) => d['project_id'].toString() == projectId).toList();
        _projectDeployments.sort((a, b) {
          int buildA = int.tryParse(a['build_number'].toString()) ?? 0;
          int buildB = int.tryParse(b['build_number'].toString()) ?? 0;
          return buildB.compareTo(buildA);
        });

        if (_projectDeployments.isNotEmpty) {
          _selectedDeployment = _projectDeployments.first;
        }
        _errorMessage = '';
      } else {
        _errorMessage = "Failed to load deployments.";
      }
    } catch (e) {
      _errorMessage = "Connection error: $e";
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

// ==== DIALOGS ====

  void _showStartDeploymentDialog() {
    String selectedBranch = 'main';
    final TextEditingController commitController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: AppColors.surface,
                titlePadding: EdgeInsets.zero,
                title: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: AppColors.premiumGradient,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.play_arrow, color: Colors.white),
                          SizedBox(width: 8),
                          Text("Start Deployment", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      InkWell(
                        onTap: () => isSubmitting ? null : Navigator.pop(context),
                        child: const Icon(Icons.close, color: Colors.white70),
                      )
                    ],
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Branch", style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.borderDark),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedBranch,
                            isExpanded: true,
                            dropdownColor: AppColors.surface,
                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                            style: const TextStyle(color: AppColors.textWhite, fontSize: 14),
                            items: ['main', 'develop', 'staging'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: const TextStyle(color: AppColors.textWhite)),
                              );
                            }).toList(),
                            onChanged: isSubmitting ? null : (newValue) {
                              if (newValue != null) setState(() => selectedBranch = newValue);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text("Commit Hash (Optional)", style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: commitController,
                        enabled: !isSubmitting,
                        style: const TextStyle(color: AppColors.textWhite, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "e.g., a1b2c3d4e5f6",
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.accentCyan),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.textMuted,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : () async {
                      setState(() => isSubmitting = true);

                      final projectId = widget.projectData?['id']?.toString() ?? '11';
                      final branch = selectedBranch;
                      final commitHash = commitController.text.trim();

                      // Calculate the next build number
                      int nextBuildNumber = 1;
                      if (_projectDeployments.isNotEmpty) {
                        nextBuildNumber = (int.tryParse(_projectDeployments.first['build_number'].toString()) ?? 0) + 1;
                      }

                      // Generate a deployment code
                      final tempCode = 'DEP-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

                      // Helper functions for dates and times
                      final now = DateTime.now();
                      String formatSqlDate(DateTime dt) {
                        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
                      }

                      // Formatted time for the terminal logs (e.g. "[01:11 PM]")
                      int logHour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
                      String amPm = now.hour >= 12 ? 'PM' : 'AM';
                      String logTime = "[${logHour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $amPm]";

                      // Generate exact payload matching your required JSON
                      final payload = {
                        'project_id': projectId,
                        'deployment_code': tempCode,
                        'build_number': nextBuildNumber.toString(),
                        'triggered_by': 'auxoraadmin',
                        'start_time': formatSqlDate(now),
                        'end_time': formatSqlDate(now.add(const Duration(seconds: 20))), // Simulated 20s later
                        'duration_minutes': '0',
                        'status': 'success',
                        'stage': 'production',
                        'code_status': 'passed',
                        'build_status': 'passed',
                        'test_status': 'passed',
                        'staging_status': 'passed',
                        'uat_status': 'passed',
                        'production_status': 'passed',
                        'unit_tests_passed': '212',
                        'unit_tests_failed': '1',
                        'integration_tests_passed': '50',
                        'integration_tests_failed': '1',
                        'test_coverage': '77.00',
                        'commit_hash': commitHash.isEmpty ? null : commitHash,
                        'branch': branch,
                        'deployment_logs': "$logTime Starting code stage... [code] ✅ code stage completed successfully $logTime Starting build stage... [build] ✅ build stage completed successfully $logTime Starting test stage... [test] ✅ test stage completed successfully $logTime Starting staging stage... [staging] ✅ staging stage completed successfully [staging] 🚀 Deployed to staging environment $logTime Starting uat stage... [uat] ✅ uat stage completed successfully [uat] ✅ Deployed to UAT environment $logTime Starting production stage... [production] ✅ production stage completed successfully [production] 🌍 Deployed to production!",
                        'staging_deployed_at': formatSqlDate(now.add(const Duration(seconds: 13))),
                        'uat_deployed_at': formatSqlDate(now.add(const Duration(seconds: 17))),
                        'production_deployed_at': formatSqlDate(now.add(const Duration(seconds: 20))),
                        'staging_url': 'https://staging.example.com',
                        'uat_url': 'https://uat.example.com',
                        'production_url': 'https://example.com',
                        'is_rollback': '0',
                        'company_id': '1',
                        'created_by': '1'
                      };

                      try {
                        final response = await http.post(
                          Uri.parse('https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_deployments'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode(payload),
                        );

                        final result = json.decode(response.body);

                        if (result['status'] == 'success') {
                          if (mounted) {
                            Navigator.pop(context); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Deployment completed successfully!"),
                                backgroundColor: AppColors.successGreen,
                              ),
                            );
                            _fetchDeployments(); // Refresh the list with the full new data
                          }
                        } else {
                          setState(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Failed: ${result['message']}"), backgroundColor: AppColors.dangerRed),
                            );
                          }
                        }
                      } catch (e) {
                        setState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Connection Error: $e"), backgroundColor: AppColors.dangerRed),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Start Deployment"),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateTimeStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      return "$day ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm";
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectName = widget.projectData?['project_name'] ?? 'Project';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
            : _errorMessage.isNotEmpty
            ? Center(child: Text(_errorMessage, style: const TextStyle(color: AppColors.dangerRed)))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderRow(projectName),
              const SizedBox(height: 24),

              if (_selectedDeployment != null) ...[
                _buildPipelineVisualizer(_selectedDeployment!),
                const SizedBox(height: 24),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBuildDetailsCard(_selectedDeployment!),
                    const SizedBox(height: 16),
                    _buildTestResultsCard(_selectedDeployment!),
                  ],
                ),
                const SizedBox(height: 24),

                _buildDeploymentUrls(_selectedDeployment!),
                const SizedBox(height: 24),

                _buildDeploymentLogs(_selectedDeployment!),
                const SizedBox(height: 24),

                _buildActionButtons(),
                const SizedBox(height: 32),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text("No deployments found for this project yet.",
                        style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                  ),
                ),
              ],

              _buildRecentDeploymentsTable(),
            ],
          ),
        ),
      ),
    );
  }

  // ==== UI COMPONENTS ====

  Widget _buildHeaderRow(String projectName) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hub, color: AppColors.accentCyan, size: 28),
                SizedBox(width: 8),
                Text("CI/CD Pipeline", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textWhite)),
              ],
            ),
            const SizedBox(height: 4),
            Text("$projectName - Deployment Pipeline", style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white),
              label: const Text("Back", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textMuted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showStartDeploymentDialog,
              icon: const Icon(Icons.play_arrow, size: 18, color: Colors.white),
              label: const Text("New Deployment", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildPipelineVisualizer(Map<String, dynamic> deployment) {
    final buildNumber = deployment['build_number'] ?? '1';

    final stages = [
      {'label': 'CODE', 'status': deployment['code_status'], 'icon': Icons.code},
      {'label': 'BUILD', 'status': deployment['build_status'], 'icon': Icons.handyman},
      {'label': 'TEST', 'status': deployment['test_status'], 'icon': Icons.science},
      {'label': 'STAGING', 'status': deployment['staging_status'], 'icon': Icons.dns},
      {'label': 'UAT', 'status': deployment['uat_status'], 'icon': Icons.fact_check},
      {'label': 'PRODUCTION', 'status': deployment['production_status'], 'icon': Icons.language},
    ];

    int passedStages = stages.where((s) => s['status'] == 'passed').length;
    double progress = stages.isEmpty ? 0 : passedStages / stages.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.sidebarBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Deployment Pipeline - Build #$buildNumber",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 32),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 600,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 30, right: 30, top: 25,
                    child: Container(height: 2, color: Colors.grey.withOpacity(0.3)),
                  ),
                  Positioned(
                    left: 30, top: 25,
                    child: Container(
                      width: (600 - 60) * progress,
                      height: 2,
                      color: AppColors.successGreen,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: stages.map((stage) {
                      bool isPassed = stage['status'] == 'passed';
                      return Column(
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPassed ? AppColors.successGreen : AppColors.sidebarItemHover,
                              boxShadow: isPassed ? [BoxShadow(color: AppColors.successGreen.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)] : [],
                            ),
                            child: Icon(stage['icon'] as IconData, color: Colors.white, size: 24),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                  isPassed ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isPassed ? AppColors.successGreen : Colors.grey,
                                  size: 14
                              ),
                              const SizedBox(width: 4),
                              Text(stage['label'].toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text(isPassed ? "Passed" : "Pending", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Overall Progress", style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.sidebarItemHover,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.successGreen),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildDetailsCard(Map<String, dynamic> deployment) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info, color: AppColors.accentCyan, size: 20),
              SizedBox(width: 8),
              Text("Build Details", style: TextStyle(color: AppColors.accentCyan, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          _detailRow("Build Number:", "#${deployment['build_number']}", isBold: true),
          _detailRow("Triggered By:", deployment['triggered_by'] ?? 'N/A'),
          _detailRow("Start Time:", _formatDateTime(deployment['start_time'])),
          _detailRow("End Time:", _formatDateTime(deployment['end_time'])),
          _detailRow("Duration:", "${deployment['duration_minutes'] ?? '0'} minutes"),
          _detailRow("Branch:", deployment['branch'] ?? 'main', valueColor: AppColors.infoBlue),
          _detailRow("Commit:", deployment['commit_hash'] ?? 'N/A', valueColor: AppColors.infoBlue),

          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const SizedBox(width: 120, child: Text("Status:", style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (deployment['status'] == 'success') ? AppColors.successGreen : AppColors.dangerRed,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    (deployment['status'] ?? 'UNKNOWN').toString().toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultsCard(Map<String, dynamic> deployment) {
    final unitPassed = deployment['unit_tests_passed'] ?? '0';
    final unitFailed = deployment['unit_tests_failed'] ?? '0';
    final intPassed = deployment['integration_tests_passed'] ?? '0';
    final intFailed = deployment['integration_tests_failed'] ?? '0';
    final testCoverage = deployment['test_coverage'] ?? '0.00';

    bool allPassed = (unitFailed == '0' && intFailed == '0');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, color: AppColors.accentCyan, size: 20),
              SizedBox(width: 8),
              Text("Test Results", style: TextStyle(color: AppColors.accentCyan, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          _detailRow("Unit Tests:", "$unitPassed passed, $unitFailed failed"),
          _detailRow("Integration Tests:", "$intPassed passed, $intFailed failed"),
          _detailRow("Test Coverage:", "$testCoverage%"),

          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const SizedBox(width: 120, child: Text("Overall Status:", style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: allPassed ? AppColors.successGreen : AppColors.dangerRed,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(allPassed ? Icons.check_box : Icons.error, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        allPassed ? "All Tests Passed" : "Tests Failed",
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // REMOVED 'const' from SizedBox
          SizedBox(
              width: 120,
              // ADDED 'const' to TextStyle instead
              child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))
          ),
          Expanded(
            child: Text(
                value,
                style: TextStyle(
                    color: valueColor ?? AppColors.textWhite,
                    fontSize: 13,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    fontFamily: valueColor != null ? 'monospace' : 'sans-serif'
                )
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildDeploymentUrls(Map<String, dynamic> deployment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.link, color: AppColors.accentCyan),
            SizedBox(width: 8),
            Text("Deployment URLs", style: TextStyle(color: AppColors.accentCyan, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _urlCard("Staging", Icons.layers, deployment['staging_url'], deployment['staging_deployed_at']),
            const SizedBox(height: 12),
            _urlCard("UAT", Icons.fact_check, deployment['uat_url'], deployment['uat_deployed_at']),
            const SizedBox(height: 12),
            _urlCard("Production", Icons.language, deployment['production_url'], deployment['production_deployed_at']),
          ],
        )
      ],
    );
  }

  Widget _urlCard(String title, IconData icon, String? url, String? dateStr) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.successGreen, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textWhite)),
          const SizedBox(height: 4),
          Text(
            url ?? "Not Deployed",
            style: TextStyle(
              color: url != null ? AppColors.infoBlue : AppColors.textMuted,
              decoration: url != null ? TextDecoration.underline : TextDecoration.none,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            dateStr != null ? "Deployed: ${_formatDateTime(dateStr)}" : "Pending",
            style: const TextStyle(color: AppColors.successGreen, fontSize: 12),
          )
        ],
      ),
    );
  }

  Widget _buildDeploymentLogs(Map<String, dynamic> deployment) {
    String logs = deployment['deployment_logs'] ?? "No logs available.";
    logs = logs.replaceAll('[', '\n[').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.terminal, color: AppColors.accentCyan),
                SizedBox(width: 8),
                Text("Logs", style: TextStyle(color: AppColors.accentCyan, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _fetchDeployments,
              icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
              label: const Text("Refresh", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.sidebarBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              logs,
              style: const TextStyle(
                color: AppColors.successGreen,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.history, color: Colors.black87),
          label: const Text("Rollback", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warningYellow,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.description, color: Colors.white),
          label: const Text("View Full Logs", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.textMuted,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        )
      ],
    );
  }

  Widget _buildRecentDeploymentsTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Recent Deployments", style: TextStyle(color: AppColors.accentCyan, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1, color: AppColors.borderDark),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textWhite),
              dataTextStyle: const TextStyle(color: AppColors.textMuted),
              columns: const [
                DataColumn(label: Text("Build #")),
                DataColumn(label: Text("Triggered By")),
                DataColumn(label: Text("Branch")),
                DataColumn(label: Text("Duration")),
                DataColumn(label: Text("Status")),
                DataColumn(label: Text("Actions")),
              ],
              rows: _projectDeployments.map((dep) {
                final status = dep['status'] ?? 'pending';
                return DataRow(
                    cells: [
                      DataCell(Text("#${dep['build_number']}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textWhite))),
                      DataCell(Text(dep['triggered_by'] ?? 'N/A')),
                      DataCell(Text(dep['branch'] ?? 'main', style: const TextStyle(color: AppColors.infoBlue, fontFamily: 'monospace'))),
                      DataCell(Text("${dep['duration_minutes'] ?? 'N/A'} mins")),
                      DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'success' ? AppColors.successGreen : AppColors.dangerRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(status.toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                      ),
                      DataCell(
                          InkWell(
                            onTap: () {
                              setState(() {
                                _selectedDeployment = dep;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: AppColors.accentCyan, borderRadius: BorderRadius.circular(4)),
                              child: const Icon(Icons.remove_red_eye, color: Colors.white, size: 16),
                            ),
                          )
                      ),
                    ]
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}