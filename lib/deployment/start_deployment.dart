import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme.dart'; // Make sure this file contains your AppColors class
import 'ci/CICDPipelinesScreen.dart';
import 'ci/cd_pipeline.dart';

class StartDeploymentScreen extends StatefulWidget {
  const StartDeploymentScreen({Key? key}) : super(key: key);

  @override
  State<StartDeploymentScreen> createState() => _StartDeploymentScreenState();
}

class _StartDeploymentScreenState extends State<StartDeploymentScreen> {
  bool _isLoading = true;
  String _errorMessage = '';

  List<dynamic> _projects = [];
  List<dynamic> _deployments = [];
  List<dynamic> _filteredProjects = [];

  final TextEditingController _searchController = TextEditingController();

  final String _projectsApiUrl =
      'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_projects';
  final String _deploymentsApiUrl =
      'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_deployments';

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_filterProjects);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Determine login type
      final bool isClient = prefs.getBool('isClient') ?? false;

      // Fetch projects and deployments concurrently
      final responses = await Future.wait([
        http.get(Uri.parse(_projectsApiUrl)),
        http.get(Uri.parse(_deploymentsApiUrl)),
      ]);

      final projectsData = json.decode(responses[0].body);
      final deploymentsData = json.decode(responses[1].body);

      if (projectsData['status'] == 'success') {
        List<dynamic> allProjects = projectsData['data'] ?? [];
        List<dynamic> allDeployments = deploymentsData['data'] ?? [];

        if (isClient) {
          // ---------- CLIENT LOGIN ----------
          final String clientId = prefs.getString('clientId') ?? '';

          if (clientId.isNotEmpty) {
            allProjects = allProjects.where((p) {
              return p['client_id']?.toString() == clientId;
            }).toList();

            allDeployments = allDeployments.where((d) {
              return d['client_id']?.toString() == clientId;
            }).toList();
          } else {
            // No clientId → show nothing
            allProjects = [];
            allDeployments = [];
          }
        } else {
          // ---------- ADMIN LOGIN ----------
          final String companyId = prefs.getString('company_id') ?? '';

          if (companyId.isNotEmpty) {
            allProjects = allProjects.where((p) {
              return p['company_id']?.toString() == companyId;
            }).toList();

            allDeployments = allDeployments.where((d) {
              return d['company_id']?.toString() == companyId;
            }).toList();
          } else {
            // No company_id → show nothing
            allProjects = [];
            allDeployments = [];
          }
        }

        setState(() {
          _projects = allProjects;
          _deployments = allDeployments;
          _filteredProjects = allProjects;
          _errorMessage = '';
        });
      } else {
        setState(() => _errorMessage = "Failed to load projects.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Connection error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _filterProjects() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredProjects = _projects);
      return;
    }

    setState(() {
      _filteredProjects = _projects.where((project) {
        final name = (project['project_name'] ?? '').toString().toLowerCase();
        final id = (project['id'] ?? '').toString().toLowerCase();
        final code = (project['project_code'] ?? '').toString().toLowerCase();

        return name.contains(query) || id.contains(query) || code.contains(query);
      }).toList();
    });
  }

  // Find the latest deployment for a project
  Map<String, dynamic>? _getLastDeployment(String projectId) {
    final projectDeployments = _deployments.where((d) {
      return d['project_id']?.toString() == projectId;
    }).toList();

    if (projectDeployments.isEmpty) return null;

    // Returns the latest deployment record
    return projectDeployments.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _fetchData,
          color: AppColors.accentCyan,
          child: CustomScrollView(
            slivers: [
              _buildHeaderSliver(),
              _buildSearchBarSliver(),
              _buildProjectsGridSliver(),
            ],
          ),
        ),
      ),
    );
  }

  // Top banner with gradient and titles
  Widget _buildHeaderSliver() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 30), // Padding inside the header
        margin: const EdgeInsets.only(bottom: 30),
        decoration: const BoxDecoration(
          gradient: AppColors.premiumGradient,
        ),
        child: Column(
          children: const [
            Icon(Icons.rocket_launch_outlined, color: Colors.white70, size: 28),
            SizedBox(height: 8),
            Text(
              "CI/CD Pipeline",
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 6),
            Text(
              "Select a project to view its deployment pipeline",
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Floating Search Bar
  Widget _buildSearchBarSliver() {
    return SliverToBoxAdapter(
      child: Transform.translate(
        offset: const Offset(0, -22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Search by project name, ID, or code...",
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: AppColors.accentCyan),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Project Cards Grid
  Widget _buildProjectsGridSliver() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(_errorMessage, style: const TextStyle(color: AppColors.dangerRed)),
        ),
      );
    }

    if (_filteredProjects.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            "No projects found",
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 380,
          mainAxisExtent: 260,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final project = _filteredProjects[index];
            final lastDeployment = _getLastDeployment(project['id']?.toString() ?? '');
            return _buildProjectCard(project, lastDeployment);
          },
          childCount: _filteredProjects.length,
        ),
      ),
    );
  }

  // Single Project Card
  Widget _buildProjectCard(Map<String, dynamic> project, Map<String, dynamic>? lastDeployment) {
    final projectName = project['project_name'] ?? 'Untitled Project';
    final projectCode = project['project_code'] ?? 'PRJ-${project['id']}';
    final billingType = project['billing_type'] ?? 'Fixed Price';
    final methodology = project['methodology'] ?? 'Scrum';
    final status = (project['status'] ?? 'Active').toString().toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top: Icon + Title & Project Code
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accentCyan,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.hub_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      projectName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      // overflow: TextOverlay.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.local_offer_outlined, size: 12, color: AppColors.infoBlue),
                        const SizedBox(width: 4),
                        Text(
                          projectCode,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Badges: Billing Type, Methodology, Status
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildBadge(billingType, AppColors.infoBlue),
              _buildBadge(methodology, AppColors.warningOrange),
              _buildBadge(status, AppColors.successGreen),
            ],
          ),

          // Last Deployment Info (if available)
          if (lastDeployment != null)
            Row(
              children: [
                const Icon(Icons.history, size: 14, color: AppColors.infoBlue),
                const SizedBox(width: 4),
                Text(
                  "Last deployment: #${lastDeployment['build_number'] ?? '1'}",
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (lastDeployment['status'] == 'success')
                        ? AppColors.successGreen
                        : AppColors.dangerRed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (lastDeployment['status'] ?? 'SUCCESS').toString().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          else
            const SizedBox(height: 14),

          // View Pipeline Action Button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CICDPipelinesScreen(projectData: project),
                  ),
                );
              },
              icon: const Icon(Icons.rocket_launch, size: 16, color: Colors.white),
              label: const Text(
                "View Pipeline",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}