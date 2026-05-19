import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skydevs/project/add_projects.dart';
import 'package:skydevs/project/list_projects.dart';

import 'bugs/add_bugs.dart';
import 'bugs/list_bugs.dart';
import 'client/add_client.dart';
import 'client/client_list.dart';
import 'deployment/ci/cd_pipeline.dart';
import 'employee/add_employee.dart';
import 'employee/list_employee.dart';
import 'invoice/add_invoice.dart';
import 'invoice/list_invoice.dart';
import 'login_scrren.dart';
import 'theme.dart';

class SkyDevsHomeScreen extends StatefulWidget {
  const SkyDevsHomeScreen({Key? key}) : super(key: key);

  @override
  State<SkyDevsHomeScreen> createState() => _SkyDevsHomeScreenState();
}

class _SkyDevsHomeScreenState extends State<SkyDevsHomeScreen> {
  // --- State Variables ---
  List<dynamic> _sidebarHeaders = [];
  List<dynamic> _sidebarSubmenus = [];
  List<dynamic> _sidebarSubSubmenus = [];
  bool _isSidebarLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSidebarData();
  }

  // ==========================================
  // API CALLS
  // ==========================================
  Future<void> _fetchSidebarData() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://skydevs.skynetproduct.com/skydevs_API.php?table=sidebar_header')),
        http.get(Uri.parse('https://skydevs.skynetproduct.com/skydevs_API.php?table=sidebar_submenu')),
        http.get(Uri.parse('https://skydevs.skynetproduct.com/skydevs_API.php?table=sidebar_submenu_submenus')),
      ]);

      if (mounted) {
        setState(() {
          final headerData = json.decode(responses[0].body);
          if (headerData['status'] == "success") _sidebarHeaders = headerData['data'] ?? [];

          final submenuData = json.decode(responses[1].body);
          if (submenuData['status'] == "success") _sidebarSubmenus = submenuData['data'] ?? [];

          final subSubmenuData = json.decode(responses[2].body);
          if (subSubmenuData['status'] == "success") _sidebarSubSubmenus = subSubmenuData['data'] ?? [];

          _isSidebarLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSidebarLoading = false);
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SkyDevsLoginScreen())
      );
    }
  }

  // ==========================================
  // UI - MAIN BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.terminal_rounded, color: AppColors.accentCyan, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "SkyDevs Console",
                style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'sans-serif'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.exit_to_app_rounded, color: AppColors.textWhite),
              tooltip: "Logout",
              onPressed: _logout,
            ),
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  // ==========================================
  // UI - DRAWER & NAVIGATION
  // ==========================================
  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // --- Drawer Header ---
            Container(
              height: 100,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderDark, width: 1)),
                color: AppColors.background,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.code_rounded, color: AppColors.background, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "SkyDevs",
                          style: TextStyle(color: AppColors.textWhite, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'sans-serif'),
                        ),
                        Text(
                          "Admin Menu",
                          style: TextStyle(color: AppColors.accentCyan, fontSize: 13, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- Dynamic Sidebar List ---
            Expanded(
              child: _isSidebarLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _sidebarHeaders.length,
                itemBuilder: (context, index) {
                  final header = _sidebarHeaders[index];
                  final headerId = header['id'].toString();

                  final submenus = _sidebarSubmenus.where((s) => s['sidebar_header_id'].toString() == headerId).toList();

                  if (submenus.isEmpty) {
                    return _buildSidebarListTile(
                      title: header['sidebar_header_name'] ?? 'Unknown',
                      icon: Icons.folder_outlined,
                      onTap: () => Navigator.pop(context),
                    );
                  }

                  return Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
                      child: ExpansionTile(
                        iconColor: AppColors.accentCyan,
                        collapsedIconColor: AppColors.textMuted,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: const Icon(Icons.snippet_folder_rounded, color: AppColors.textMuted, size: 22),
                        title: Text(
                          header['sidebar_header_name'] ?? 'Unknown',
                          style: const TextStyle(color: AppColors.textWhite, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'sans-serif'),
                        ),
                        children: submenus.map((submenu) {
                          final submenuId = submenu['id'].toString();
                          final subSubmenus = _sidebarSubSubmenus.where((ss) => ss['sidebar_submenu_id'].toString() == submenuId).toList();

                          if (subSubmenus.isEmpty) {
                            return _buildSubmenuTile(
                              title: submenu['sidebar_submenu_name'] ?? 'Unknown',
                              onTap: () {
                                Navigator.pop(context); // Close drawer

                                // --- FIXED ROUTING LOGIC ---
                                final menuTitle = (submenu['sidebar_submenu_name'] ?? '').toString().toLowerCase();

                                // Check for Add Client first
                                if (menuTitle.contains('add') && menuTitle.contains('client')) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AddClientScreen()));
                                }
                                // Check for Client List (Broad match to catch "Clients", "Client List", etc.)
                                else if (menuTitle.contains('client')) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientListScreen()));
                                }
                                else if (menuTitle.contains('project') && menuTitle.contains('add')) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProjectScreen()));
                                }
                                else if (menuTitle.contains('project') && menuTitle.contains('list')) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProjectListScreen()));
                                }
                                else if (menuTitle.contains('employee') && menuTitle.contains('add')) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEmployeeScreen()));
                                }
                                else if (menuTitle.contains('employee') && menuTitle.contains('list')) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeListScreen()));
                                }
                                else if (menuTitle.contains('bug') && menuTitle.contains('add')) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AddBugScreen()));
                                }
                                else if (menuTitle.contains('bug') && menuTitle.contains('all')) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const BugListScreen()));
                                }
                                else if (menuTitle.contains('invoice') && (menuTitle.contains('create') || menuTitle.contains('add'))) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateInvoiceScreen(invoiceData: {},)));
                                }
                                else if (menuTitle.contains('invoice') && menuTitle.contains('list')) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const InvoiceListScreen()));
                                }
                                else if (menuTitle.contains('pipeline') || (menuTitle.contains('ci') && menuTitle.contains('cd'))) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CICDPipelineScreen()));
                                }
                              },
                            );
                          }

                          return ExpansionTile(
                            iconColor: AppColors.accentCyan,
                            collapsedIconColor: AppColors.textMuted,
                            title: Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Text(
                                submenu['sidebar_submenu_name'] ?? 'Unknown',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontFamily: 'sans-serif'),
                              ),
                            ),
                            children: subSubmenus.map((subSubmenu) {
                              return _buildSubmenuTile(
                                title: submenu['sidebar_submenu_name'] ?? 'Unknown',
                                onTap: () {
                                  Navigator.pop(context); // Close drawer

                                  // --- FIXED ROUTING LOGIC ---
                                  final menuTitle = (submenu['sidebar_submenu_name'] ?? '').toString().toLowerCase();

                                  // Check for Add Client first
                                  if (menuTitle.contains('add') && menuTitle.contains('client')) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AddClientScreen()));
                                  }
                                  // Check for Client List (Broad match to catch "Clients", "Client List", etc.)
                                  else if (menuTitle.contains('client')) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ClientListScreen()));
                                  }
                                  // Check for Add Project
                                  else if (menuTitle.contains('add') && menuTitle.contains('project')) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProjectScreen()));
                                  }
                                  else if (menuTitle.contains('project') && menuTitle.contains('list')) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProjectListScreen()));
                                  }
                                  else if (menuTitle.contains('employee') && menuTitle.contains('add')) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEmployeeScreen()));
                                  }
                                  else if (menuTitle.contains('employee') && menuTitle.contains('list')) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeListScreen()));
                                  }
                                  else if (menuTitle.contains('bug') && menuTitle.contains('add')) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AddBugScreen()));
                                  }
                                  else if (menuTitle.contains('bug') && menuTitle.contains('all')) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const BugListScreen()));
                                  }
                                  else if (menuTitle.contains('invoice') && (menuTitle.contains('create') || menuTitle.contains('add'))) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateInvoiceScreen(invoiceData: {},)));
                                  }
                                  else if (menuTitle.contains('invoice') && menuTitle.contains('list')) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const InvoiceListScreen()));
                                  }
                                  else if (menuTitle.contains('pipeline') || (menuTitle.contains('ci') && menuTitle.contains('cd'))) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CICDPipelineScreen()));
                                  }
                                },
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),

            // --- Logout Button Footer ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.borderDark, width: 1)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _logout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 22),
                        SizedBox(width: 12),
                        Text(
                          "Kill_Session();",
                          style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarListTile({required String title, required IconData icon, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: AppColors.textMuted, size: 22),
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textWhite, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'sans-serif'),
        ),
        onTap: onTap,
        hoverColor: AppColors.background,
      ),
    );
  }

  Widget _buildSubmenuTile({required String title, bool isSubSub = false, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: EdgeInsets.only(left: isSubSub ? 72.0 : 56.0, right: 16.0),
        title: Text(
          title,
          style: TextStyle(color: AppColors.textWhite.withOpacity(0.7), fontSize: 13, fontFamily: 'sans-serif'),
        ),
        onTap: onTap,
        hoverColor: AppColors.background,
      ),
    );
  }

  // ==========================================
  // UI - CLEAN DASHBOARD BODY
  // ==========================================
  Widget _buildBody() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.code_rounded, size: 64, color: AppColors.borderDark),
          const SizedBox(height: 16),
          const Text(
              "System_Ready();",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textWhite, fontFamily: 'monospace')
          ),
          const SizedBox(height: 8),
          Text(
              "Access modules via the sidebar",
              style: TextStyle(fontSize: 15, color: AppColors.textMuted.withOpacity(0.7), fontFamily: 'sans-serif')
          ),
        ],
      ),
    );
  }
}