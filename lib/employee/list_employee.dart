import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'add_employee.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _employees = [];

  final String _apiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_employees';

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool isClient = prefs.getBool('isClient') ?? false;

      final response = await http.get(Uri.parse(_apiUrl));
      final data = json.decode(response.body);

      if (data['status'] == "success") {
        List<dynamic> allEmployees = data['data'] ?? [];

        if (isClient) {
          // ---------- CLIENT LOGIN ----------
          final String clientId = prefs.getString('clientId') ?? '';
          if (clientId.isNotEmpty) {
            allEmployees = allEmployees.where((employee) {
              return employee['client_id']?.toString() == clientId;
            }).toList();
          } else {
            allEmployees = [];
          }
        } else {
          // ---------- ADMIN LOGIN ----------
          final String companyId = prefs.getString('company_id') ?? '';
          if (companyId.isNotEmpty) {
            allEmployees = allEmployees.where((employee) {
              return employee['company_id']?.toString() == companyId;
            }).toList();
          } else {
            allEmployees = [];
          }
        }

        setState(() {
          _employees = allEmployees;
          _errorMessage = '';
        });
      } else {
        setState(() => _errorMessage = "Failed to load employees.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Connection error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  Future<void> _deleteEmployee(String id) async {
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"action": "delete", "id": id}),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        _showSnackbar("Employee deleted successfully.", isError: false);
        _fetchEmployees();
      } else {
        _showSnackbar(data['message'] ?? "Failed to delete.", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar("Error deleting employee: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateEmployee(String id, Map<String, dynamic> updatedData) async {
    setState(() => _isLoading = true);

    try {
      updatedData['id'] = id;

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode(updatedData),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        _showSnackbar("Employee updated successfully.", isError: false);
        _fetchEmployees();
      } else {
        _showSnackbar(data['message'] ?? "Failed to update.", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar("Error updating employee: $e", isError: true);
      setState(() => _isLoading = false);
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

  void _confirmDelete(Map<String, dynamic> employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Confirm Deletion", style: TextStyle(color: AppColors.textWhite)),
        content: Text("Delete employee '${employee['full_name']}'? This cannot be undone.",
            style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: () => _deleteEmployee(employee['id'].toString()),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return AppColors.successGreen;
      case 'inactive': return AppColors.dangerRed;
      case 'on leave': return AppColors.warningOrange;
      case 'terminated': return AppColors.textMuted;
      default: return AppColors.textMuted;
    }
  }

  String _getWorkModeIcon(String workMode) {
    switch (workMode.toLowerCase()) {
      case 'onsite': return '🏢';
      case 'remote': return '🏠';
      case 'hybrid': return '💻';
      default: return '📍';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.premiumGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Employee Directory", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: "Add Employee",
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddEmployeeScreen())
                ).then((_) => _fetchEmployees());
              },
            ),
          ),
        ],
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
    if (_employees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text("No employees found.", style: TextStyle(color: AppColors.textMuted)),
            SizedBox(height: 8),
            Text("Tap the + button to add your first employee",
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accentCyan,
      backgroundColor: AppColors.surface,
      onRefresh: _fetchEmployees,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _employees.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final employee = _employees[index];
          final status = (employee['status'] ?? 'active').toString().toLowerCase();
          final statusColor = _getStatusColor(status);
          final workModeIcon = _getWorkModeIcon(employee['work_mode'] ?? 'onsite');
          final designation = employee['designation'] ?? 'N/A';
          final department = employee['department'] ?? 'N/A';

          List<String> skills = [];
          try {
            dynamic primarySkills = employee['primary_skills'];
            if (primarySkills != null && primarySkills.isNotEmpty) {
              if (primarySkills is String) {
                skills = json.decode(primarySkills).cast<String>();
              }
            }
          } catch (e) {
            skills = [];
          }

          // CHANGED: Wrapped in GestureDetector to open details screen
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmployeeDetailsScreen(employee: employee),
                ),
              );
            },
            child: Container(
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
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.accentCyan.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Icon(Icons.person, color: AppColors.accentCyan, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    employee['full_name'] ?? 'Unknown',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textWhite
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$designation • $department",
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                        color: AppColors.surface,
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditEmployeeScreen(
                                  employee: employee,
                                  onSave: (updatedData) {
                                    _updateEmployee(employee['id'].toString(), updatedData);
                                  },
                                ),
                              ),
                            );
                          }
                          if (value == 'delete') _confirmDelete(employee);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_outlined, color: AppColors.textWhite, size: 18),
                                SizedBox(width: 8),
                                Text('Edit', style: TextStyle(color: AppColors.textWhite))
                              ])
                          ),
                          const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline, color: AppColors.dangerRed, size: 18),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: AppColors.dangerRed))
                              ])
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          employee['email'] ?? 'N/A',
                          style: const TextStyle(color: AppColors.textWhite, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        employee['phone'] ?? 'N/A',
                        style: const TextStyle(color: AppColors.textWhite, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(workModeIcon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "${employee['work_mode']?.toString().toUpperCase() ?? 'ONSITE'} • ${employee['employment_type']?.toString().toUpperCase() ?? 'PERMANENT'}",
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.calendar_today, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        "Joined: ${employee['joining_date'] ?? 'N/A'}",
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  if (skills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: skills.take(3).map((skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(color: AppColors.accentCyan, fontSize: 11),
                          ),
                        );
                      }).toList(),
                    ),
                    if (skills.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "+${skills.length - 3} more skills",
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                        ),
                      ),
                  ],
                  if (employee['employee_code'] != null && employee['employee_code'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        "Code: ${employee['employee_code']}",
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// EMPLOYEE DETAILS SCREEN (NEWLY ADDED)
// ==========================================
class EmployeeDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> employee;

  const EmployeeDetailsScreen({Key? key, required this.employee}) : super(key: key);

  List<dynamic> _parseJsonList(dynamic jsonInput) {
    if (jsonInput == null) return [];
    if (jsonInput is List) return jsonInput;
    if (jsonInput is String && jsonInput.isNotEmpty) {
      try {
        var parsed = json.decode(jsonInput);
        if (parsed is String) {
          parsed = json.decode(parsed); // Handle double-encoded JSON strings
        }
        if (parsed is List) return parsed;
        if (parsed is Map) return [parsed];
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final primarySkills = _parseJsonList(employee['primary_skills']);
    final skillMatrix = _parseJsonList(employee['skill_matrix']);
    final assignedProjects = _parseJsonList(employee['assigned_projects']);
    final emergencyContacts = _parseJsonList(employee['emergency_contacts']);
    final certifications = _parseJsonList(employee['certifications']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.premiumGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Employee Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER PROFILE CARD ---
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, size: 40, color: AppColors.accentCyan),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    employee['full_name'] ?? 'Unknown Employee',
                    style: const TextStyle(color: AppColors.textWhite, fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${employee['designation'] ?? 'N/A'} • ${employee['department'] ?? 'N/A'}",
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Text(
                      (employee['status'] ?? 'Active').toString().toUpperCase(),
                      style: const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- PERSONAL INFO ---
            _buildSection("Personal Information", [
              _buildDetailRow("Email", employee['email']),
              _buildDetailRow("Phone", employee['phone']),
              _buildDetailRow("Date of Birth", employee['date_of_birth']),
              _buildDetailRow("Gender", employee['gender']),
              _buildDetailRow("Blood Group", employee['blood_group']),
              _buildDetailRow("Marital Status", employee['marital_status']),
              _buildDetailRow("PAN Number", employee['pan_number']),
              _buildDetailRow("Aadhar Number", employee['aadhar_number']?.toString().isNotEmpty == true ? '[Aadhaar Redacted]' : null),
              _buildDetailRow("Current Address", employee['current_address']),
              _buildDetailRow("Permanent Address", employee['permanent_address']),
            ]),

            // --- EMERGENCY CONTACTS ---
            if (emergencyContacts.isNotEmpty)
              _buildSection("Emergency Contacts", emergencyContacts.map((contact) {
                final name = contact['name'] ?? 'Unknown';
                final relation = contact['relation'] ?? '';
                final phone = contact['phone'] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          "$name ${relation.isNotEmpty ? '($relation)' : ''}",
                          style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(phone, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                );
              }).toList()),

            // --- PROFESSIONAL INFO ---
            _buildSection("Professional Information", [
              _buildDetailRow("Employee Code", employee['employee_code']),
              _buildDetailRow("Reporting To", employee['reporting_to']),
              _buildDetailRow("Work Mode", employee['work_mode']),
              _buildDetailRow("Shift", employee['shift']),
              _buildDetailRow("Employment Type", employee['employment_type']),
              _buildDetailRow("Joining Date", employee['joining_date']),
              _buildDetailRow("Confirmation Date", employee['confirmation_date']),
            ]),

            // --- SKILLS & PROJECTS ---
            _buildSection("Skills & Projects", [
              if (primarySkills.isNotEmpty)
                _buildDetailRow("Primary Skills", primarySkills.join(", ")),

              if (skillMatrix.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text("Skill Matrix:", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                ...skillMatrix.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    "• ${s['skill'] ?? 'Unknown'} (Self: ${s['self_rating']}, Mgr: ${s['manager_rating']})",
                    style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
                  ),
                )).toList(),
              ],

              if (assignedProjects.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text("Assigned Projects:", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                ...assignedProjects.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    "• ${p['name'] ?? 'Unknown'} (${p['role'] ?? 'Member'}) - ${p['allocation']}%",
                    style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
                  ),
                )).toList(),
              ]
            ]),

            // --- CERTIFICATIONS ---
            if (certifications.isNotEmpty)
              _buildSection("Certifications", certifications.map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text("• ${c['name']} from ${c['issuer']} (${c['year']})", style: const TextStyle(color: AppColors.textWhite, fontSize: 13)),
                );
              }).toList()),

            // --- PAYROLL & BANK ---
            _buildSection("Payroll & Bank Details", [
              _buildDetailRow("CTC (Annual)", employee['ctc'] != null ? "₹${employee['ctc']}" : null),
              _buildDetailRow("Basic Salary", employee['basic_salary'] != null ? "₹${employee['basic_salary']}" : null),
              _buildDetailRow("Net Salary", employee['net_salary'] != null ? "₹${employee['net_salary']}" : null),
              _buildDetailRow("Bank Name", employee['bank_name']),
              _buildDetailRow("Account Number", employee['bank_account_number']),
              _buildDetailRow("IFSC Code", employee['ifsc_code']),
              _buildDetailRow("UAN Number", employee['uan_number']),
              _buildDetailRow("PF Number", employee['pf_number']),
              _buildDetailRow("ESI Number", employee['esi_number']),
            ]),

            // --- NOTES ---
            if (employee['notes'] != null && employee['notes'].toString().isNotEmpty)
              _buildSection("Additional Notes", [
                Text(employee['notes'], style: const TextStyle(color: AppColors.textWhite, fontSize: 13)),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(color: AppColors.textWhite, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
// ==========================================
// EDIT EMPLOYEE SCREEN (Unchanged)
// ==========================================

class EditEmployeeScreen extends StatefulWidget {
  final Map<String, dynamic> employee;
  final Function(Map<String, dynamic>) onSave;

  const EditEmployeeScreen({Key? key, required this.employee, required this.onSave}) : super(key: key);

  @override
  State<EditEmployeeScreen> createState() => _EditEmployeeScreenState();
}

class _EditEmployeeScreenState extends State<EditEmployeeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Personal Information
  late TextEditingController fullNameCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController dobCtrl;
  String gender = 'Male';
  String bloodGroup = 'Select';
  String maritalStatus = 'Single';
  late TextEditingController panNumberCtrl;
  late TextEditingController aadharNumberCtrl;
  late TextEditingController currentAddressCtrl;
  late TextEditingController permanentAddressCtrl;
  List<Map<String, String>> emergencyContacts = [];

  // Professional Details
  String designation = 'Select Designation';
  String reportingTo = 'Select Manager';
  late TextEditingController confirmationDateCtrl;
  String workMode = 'Onsite';
  String shift = 'General';
  String department = 'Select Department';
  late TextEditingController joiningDateCtrl;
  String employmentType = 'Permanent';
  String status = 'Active';

  // Skills
  List<String> selectedPrimarySkills = [];
  List<Map<String, dynamic>> skillMatrix = [];
  List<Map<String, String>> certifications = [];

  // Projects
  List<Map<String, String>> assignedProjects = [];

  // Payroll
  late TextEditingController ctcCtrl;
  late TextEditingController basicSalaryCtrl;
  late TextEditingController hraCtrl;
  late TextEditingController specialAllowanceCtrl;
  late TextEditingController netSalaryCtrl;
  late TextEditingController bankNameCtrl;
  late TextEditingController accountNumberCtrl;
  late TextEditingController ifscCodeCtrl;
  late TextEditingController uanNumberCtrl;
  late TextEditingController esiNumberCtrl;
  late TextEditingController pfNumberCtrl;

  // Documents
  late TextEditingController notesCtrl;

  final List<String> designationOptions = [
    'Project Manager', 'Tech Lead', 'Sr. Software Engineer', 'Software Engineer',
    'Jr. Software Engineer', 'QA Lead', 'QA Engineer', 'UI/UX Designer',
    'DevOps Engineer', 'Business Analyst', 'HR Manager'
  ];
  final List<String> departmentOptions = [
    'Engineering', 'Quality Assurance', 'Design', 'Product', 'DevOps',
    'Human Resources', 'Sales', 'Marketing', 'Finance'
  ];
  final List<String> workModeOptions = ['Onsite', 'Remote', 'Hybrid'];
  final List<String> shiftOptions = ['General', 'Morning', 'Evening', 'Night'];
  final List<String> employmentTypeOptions = ['Permanent', 'Contract', 'Trainee', 'Intern', 'Probation'];
  final List<String> statusOptions = ['Active', 'Inactive', 'On Leave', 'Terminated'];
  final List<String> genderOptions = ['Male', 'Female', 'Other'];
  final List<String> bloodGroupOptions = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  final List<String> maritalStatusOptions = ['Single', 'Married', 'Divorced'];
  final List<String> availableSkills = [
    'Python', 'Django', 'React', 'Angular', 'AWS', 'Azure',
    'Docker', 'Kubernetes', 'PostgreSQL', 'MongoDB', 'Redis', 'Elasticsearch'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadEmployeeData();
  }

  void _loadEmployeeData() {
    final e = widget.employee;

    fullNameCtrl = TextEditingController(text: e['full_name'] ?? '');
    emailCtrl = TextEditingController(text: e['email'] ?? '');
    phoneCtrl = TextEditingController(text: e['phone'] ?? '');
    dobCtrl = TextEditingController(text: e['date_of_birth'] ?? '');
    gender = _capitalize(e['gender'] ?? 'Male');
    bloodGroup = e['blood_group'] ?? 'Select';
    maritalStatus = _capitalize(e['marital_status'] ?? 'Single');
    panNumberCtrl = TextEditingController(text: e['pan_number'] ?? '');
    aadharNumberCtrl = TextEditingController(text: e['aadhar_number'] ?? '');
    currentAddressCtrl = TextEditingController(text: e['current_address'] ?? '');
    permanentAddressCtrl = TextEditingController(text: e['permanent_address'] ?? '');

    // Emergency contacts
    try {
      String emergStr = e['emergency_contacts'] ?? '[]';
      List<dynamic> emergList = json.decode(emergStr);
      emergencyContacts = emergList.map((item) => {
        'name': item['name']?.toString() ?? '',
        'relation': item['relation']?.toString() ?? '',
        'phone': item['phone']?.toString() ?? ''
      }).toList();
    } catch (e) {
      emergencyContacts = [];
    }

    designation = e['designation'] ?? 'Select Designation';
    reportingTo = e['reporting_to'] ?? 'Select Manager';
    confirmationDateCtrl = TextEditingController(text: e['confirmation_date'] ?? '');
    workMode = _capitalize(e['work_mode'] ?? 'Onsite');
    shift = _capitalize(e['shift'] ?? 'General');
    department = e['department'] ?? 'Select Department';
    joiningDateCtrl = TextEditingController(text: e['joining_date'] ?? '');
    employmentType = _capitalize(e['employment_type'] ?? 'Permanent');
    status = _capitalize(e['status'] ?? 'Active');

    // Primary skills
    try {
      String skillsStr = e['primary_skills'] ?? '[]';
      selectedPrimarySkills = json.decode(skillsStr).cast<String>();
    } catch (e) {
      selectedPrimarySkills = [];
    }

    // Skill matrix
    try {
      String matrixStr = e['skill_matrix'] ?? '[{"skill":"","self_rating":"","manager_rating":"","certification":""}]';
      List<dynamic> matrixList = json.decode(matrixStr);
      skillMatrix = matrixList.map((item) => {
        'skill': item['skill']?.toString() ?? '',
        'self_rating': item['self_rating']?.toString() ?? '',
        'manager_rating': item['manager_rating']?.toString() ?? '',
        'certification': item['certification']?.toString() ?? ''
      }).toList();
    } catch (e) {
      skillMatrix = [{'skill': '', 'self_rating': '', 'manager_rating': '', 'certification': ''}];
    }

    // Certifications
    try {
      String certStr = e['certifications'] ?? '[{"name":"","issuer":"","year":""}]';
      List<dynamic> certList = json.decode(certStr);
      certifications = certList.map((item) => {
        'name': item['name']?.toString() ?? '',
        'issuer': item['issuer']?.toString() ?? '',
        'year': item['year']?.toString() ?? ''
      }).toList();
    } catch (e) {
      certifications = [{'name': '', 'issuer': '', 'year': ''}];
    }

    // Assigned projects
    try {
      String projectsStr = e['assigned_projects'] ?? '[]';
      List<dynamic> projectsList = json.decode(projectsStr);
      assignedProjects = projectsList.map((item) => {
        'name': item['name']?.toString() ?? '',
        'role': item['role']?.toString() ?? '',
        'allocation': item['allocation']?.toString() ?? ''
      }).toList();
    } catch (e) {
      assignedProjects = [];
    }

    ctcCtrl = TextEditingController(text: e['ctc']?.toString() ?? '');
    basicSalaryCtrl = TextEditingController(text: e['basic_salary']?.toString() ?? '');
    hraCtrl = TextEditingController(text: e['hra']?.toString() ?? '');
    specialAllowanceCtrl = TextEditingController(text: e['special_allowance']?.toString() ?? '');
    netSalaryCtrl = TextEditingController(text: e['net_salary']?.toString() ?? '');
    bankNameCtrl = TextEditingController(text: e['bank_name'] ?? '');
    accountNumberCtrl = TextEditingController(text: e['bank_account_number'] ?? '');
    ifscCodeCtrl = TextEditingController(text: e['ifsc_code'] ?? '');
    uanNumberCtrl = TextEditingController(text: e['uan_number'] ?? '');
    esiNumberCtrl = TextEditingController(text: e['esi_number'] ?? '');
    pfNumberCtrl = TextEditingController(text: e['pf_number'] ?? '');
    notesCtrl = TextEditingController(text: e['notes'] ?? '');
  }

  String _capitalize(String? str) {
    if (str == null || str.isEmpty) return '';
    return str[0].toUpperCase() + str.substring(1);
  }

  void _calculateNetSalary() {
    double basic = double.tryParse(basicSalaryCtrl.text) ?? 0;
    double hra = double.tryParse(hraCtrl.text) ?? 0;
    double special = double.tryParse(specialAllowanceCtrl.text) ?? 0;
    double net = basic + hra + special;
    netSalaryCtrl.text = net.toStringAsFixed(2);
  }

  void _addEmergencyContact() {
    setState(() {
      emergencyContacts.add({'name': '', 'relation': '', 'phone': ''});
    });
  }

  void _removeEmergencyContact(int index) {
    setState(() {
      emergencyContacts.removeAt(index);
    });
  }

  void _addSkill() {
    setState(() {
      skillMatrix.add({'skill': '', 'self_rating': '', 'manager_rating': '', 'certification': ''});
    });
  }

  void _removeSkill(int index) {
    setState(() {
      skillMatrix.removeAt(index);
    });
  }

  void _addCertification() {
    setState(() {
      certifications.add({'name': '', 'issuer': '', 'year': ''});
    });
  }

  void _removeCertification(int index) {
    setState(() {
      certifications.removeAt(index);
    });
  }

  void _addAssignedProject() {
    setState(() {
      assignedProjects.add({'name': '', 'role': '', 'allocation': ''});
    });
  }

  void _removeAssignedProject(int index) {
    setState(() {
      assignedProjects.removeAt(index);
    });
  }

  void _submitForm() {
    String primarySkillsJson = json.encode(selectedPrimarySkills);
    String skillMatrixJson = json.encode(skillMatrix);
    String certificationsJson = json.encode(certifications);
    String assignedProjectsJson = json.encode(assignedProjects);
    String emergencyContactsJson = json.encode(emergencyContacts);

    Map<String, dynamic> payload = {
      'full_name': fullNameCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'date_of_birth': dobCtrl.text.trim().isEmpty ? null : dobCtrl.text.trim(),
      'blood_group': bloodGroup == 'Select' ? null : bloodGroup,
      'pan_number': panNumberCtrl.text.trim().isEmpty ? null : panNumberCtrl.text.trim(),
      'aadhar_number': aadharNumberCtrl.text.trim().isEmpty ? null : aadharNumberCtrl.text.trim(),
      'gender': gender.toLowerCase(),
      'marital_status': maritalStatus.toLowerCase(),
      'current_address': currentAddressCtrl.text.trim(),
      'permanent_address': permanentAddressCtrl.text.trim(),
      'designation': designation,
      'department': department,
      'reporting_to': reportingTo == 'Select Manager' ? null : reportingTo,
      'joining_date': joiningDateCtrl.text.trim(),
      'confirmation_date': confirmationDateCtrl.text.trim().isEmpty ? null : confirmationDateCtrl.text.trim(),
      'employment_type': employmentType.toLowerCase(),
      'work_mode': workMode.toLowerCase(),
      'shift': shift.toLowerCase(),
      'status': status.toLowerCase(),
      'primary_skills': primarySkillsJson,
      'skill_matrix': skillMatrixJson,
      'certifications': certificationsJson,
      'assigned_projects': assignedProjectsJson,
      'ctc': ctcCtrl.text.trim(),
      'basic_salary': basicSalaryCtrl.text.trim(),
      'hra': hraCtrl.text.trim(),
      'special_allowance': specialAllowanceCtrl.text.trim(),
      'net_salary': netSalaryCtrl.text.trim(),
      'bank_name': bankNameCtrl.text.trim(),
      'bank_account_number': accountNumberCtrl.text.trim(),
      'ifsc_code': ifscCodeCtrl.text.trim(),
      'uan_number': uanNumberCtrl.text.trim().isEmpty ? null : uanNumberCtrl.text.trim(),
      'pf_number': pfNumberCtrl.text.trim().isEmpty ? null : pfNumberCtrl.text.trim(),
      'esi_number': esiNumberCtrl.text.trim().isEmpty ? null : esiNumberCtrl.text.trim(),
      'notes': notesCtrl.text.trim(),
      'emergency_contacts': emergencyContactsJson,
    };

    Navigator.pop(context);
    widget.onSave(payload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.premiumGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Edit Employee", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            width: double.infinity,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.accentCyan,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.accentCyan,
              tabs: const [
                Tab(icon: Icon(Icons.person_outline), text: "Personal"),
                Tab(icon: Icon(Icons.work_outline), text: "Professional"),
                Tab(icon: Icon(Icons.code_outlined), text: "Skills"),
                Tab(icon: Icon(Icons.folder_outlined), text: "Projects"),
                Tab(icon: Icon(Icons.attach_money_outlined), text: "Payroll"),
                Tab(icon: Icon(Icons.description_outlined), text: "Documents"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPersonalTab(),
                _buildProfessionalTab(),
                _buildSkillsTab(),
                _buildProjectsTab(),
                _buildPayrollTab(),
                _buildDocumentsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.borderDark)),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted))
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submitForm,
                child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildTextFieldRow([
            _buildTextField("Full Name", fullNameCtrl, isRequired: true),
            _buildTextField("Email", emailCtrl, isEmail: true, isRequired: true),
            _buildTextField("Phone", phoneCtrl, isPhone: true, isRequired: true),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("Date of Birth", dobCtrl, isDate: true),
            _buildDropdown("Gender", gender, genderOptions, (v) => setState(() => gender = v!)),
            _buildDropdown("Blood Group", bloodGroup, bloodGroupOptions, (v) => setState(() => bloodGroup = v!)),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildDropdown("Marital Status", maritalStatus, maritalStatusOptions, (v) => setState(() => maritalStatus = v!)),
            _buildTextField("PAN Number", panNumberCtrl),
            _buildTextField("Aadhar Number", aadharNumberCtrl),
          ]),
          const SizedBox(height: 20),
          _buildTextField("Current Address", currentAddressCtrl),
          const SizedBox(height: 16),
          _buildTextField("Permanent Address", permanentAddressCtrl),
          const SizedBox(height: 24),
          const Text("Emergency Contacts", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...emergencyContacts.asMap().entries.map((entry) {
            int index = entry.key;
            var contact = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSimpleTextField("Name", contact['name'] ?? '', (v) => emergencyContacts[index]['name'] = v),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSimpleTextField("Relation", contact['relation'] ?? '', (v) => emergencyContacts[index]['relation'] = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSimpleTextField("Phone", contact['phone'] ?? '', (v) => emergencyContacts[index]['phone'] = v, isPhone: true),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed),
                        onPressed: () => _removeEmergencyContact(index),
                        tooltip: "Remove Contact",
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
          Center(child: TextButton.icon(onPressed: _addEmergencyContact, icon: const Icon(Icons.add), label: const Text("Add Emergency Contact"))),
        ],
      ),
    );
  }

  Widget _buildProfessionalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildTextFieldRow([
            _buildDropdown("Designation", designation, designationOptions, (v) => setState(() => designation = v!), isRequired: true),
            _buildDropdown("Reporting To", reportingTo, ['Select Manager', 'John Doe - CEO'], (v) => setState(() => reportingTo = v!)),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("Confirmation Date", confirmationDateCtrl, isDate: true),
            _buildDropdown("Work Mode", workMode, workModeOptions, (v) => setState(() => workMode = v!)),
            _buildDropdown("Shift", shift, shiftOptions, (v) => setState(() => shift = v!)),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildDropdown("Department", department, departmentOptions, (v) => setState(() => department = v!), isRequired: true),
            _buildTextField("Joining Date", joiningDateCtrl, isDate: true, isRequired: true),
            _buildDropdown("Employment Type", employmentType, employmentTypeOptions, (v) => setState(() => employmentType = v!)),
          ]),
          const SizedBox(height: 20),
          _buildDropdown("Status", status, statusOptions, (v) => setState(() => status = v!)),
        ],
      ),
    );
  }

  Widget _buildSkillsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Primary Skills", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableSkills.map((skill) {
              bool isSelected = selectedPrimarySkills.contains(skill);
              return FilterChip(
                label: Text(skill),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) selectedPrimarySkills.add(skill);
                    else selectedPrimarySkills.remove(skill);
                  });
                },
                backgroundColor: AppColors.surface,
                selectedColor: AppColors.accentCyan.withOpacity(0.3),
                labelStyle: TextStyle(color: isSelected ? AppColors.accentCyan : AppColors.textWhite),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          const Text("Skill Matrix", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.resolveWith((states) => AppColors.surface),
              columns: const [
                DataColumn(label: Text("Skill", style: TextStyle(color: AppColors.textWhite))),
                DataColumn(label: Text("Self Rating", style: TextStyle(color: AppColors.textWhite))),
                DataColumn(label: Text("Manager Rating", style: TextStyle(color: AppColors.textWhite))),
                DataColumn(label: Text("Actions", style: TextStyle(color: AppColors.textWhite))),
              ],
              rows: skillMatrix.asMap().entries.map((entry) {
                int index = entry.key;
                var skill = entry.value;
                return DataRow(cells: [
                  DataCell(SizedBox(width: 150, child: _buildSimpleTextField("", skill['skill'] ?? '', (v) => skillMatrix[index]['skill'] = v))),
                  DataCell(SizedBox(width: 100, child: _buildSimpleTextField("", skill['self_rating'] ?? '', (v) => skillMatrix[index]['self_rating'] = v, isNumber: true))),
                  DataCell(SizedBox(width: 100, child: _buildSimpleTextField("", skill['manager_rating'] ?? '', (v) => skillMatrix[index]['manager_rating'] = v, isNumber: true))),
                  DataCell(IconButton(icon: const Icon(Icons.delete, color: AppColors.dangerRed), onPressed: () => _removeSkill(index))),
                ]);
              }).toList(),
            ),
          ),
          Center(child: TextButton.icon(onPressed: _addSkill, icon: const Icon(Icons.add), label: const Text("Add Skill"))),
          const SizedBox(height: 24),
          const Text("Certifications", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...certifications.asMap().entries.map((entry) {
            int index = entry.key;
            var cert = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.borderDark)),
              child: Row(
                children: [
                  Expanded(child: _buildSimpleTextField("Name", cert['name'] ?? '', (v) => certifications[index]['name'] = v)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSimpleTextField("Issuer", cert['issuer'] ?? '', (v) => certifications[index]['issuer'] = v)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSimpleTextField("Year", cert['year'] ?? '', (v) => certifications[index]['year'] = v, isDate: true)),
                  IconButton(icon: const Icon(Icons.delete, color: AppColors.dangerRed), onPressed: () => _removeCertification(index)),
                ],
              ),
            );
          }).toList(),
          Center(child: TextButton.icon(onPressed: _addCertification, icon: const Icon(Icons.add), label: const Text("Add Certification"))),
        ],
      ),
    );
  }

  Widget _buildProjectsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ...assignedProjects.asMap().entries.map((entry) {
            int index = entry.key;
            var project = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.borderDark)),
              child: Row(
                children: [
                  Expanded(flex: 2, child: _buildSimpleTextField("Project Name", project['name'] ?? '', (v) => assignedProjects[index]['name'] = v)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSimpleTextField("Role", project['role'] ?? '', (v) => assignedProjects[index]['role'] = v)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSimpleTextField("Allocation %", project['allocation'] ?? '', (v) => assignedProjects[index]['allocation'] = v, isNumber: true)),
                  IconButton(icon: const Icon(Icons.delete, color: AppColors.dangerRed), onPressed: () => _removeAssignedProject(index)),
                ],
              ),
            );
          }).toList(),
          Center(child: TextButton.icon(onPressed: _addAssignedProject, icon: const Icon(Icons.add), label: const Text("Assign Project"))),
        ],
      ),
    );
  }

  Widget _buildPayrollTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildTextFieldRow([
            _buildTextField("CTC (Annual)", ctcCtrl, isNumber: true, onChanged: _calculateNetSalary),
            _buildTextField("Basic Salary", basicSalaryCtrl, isNumber: true, onChanged: _calculateNetSalary),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("HRA", hraCtrl, isNumber: true, onChanged: _calculateNetSalary),
            _buildTextField("Special Allowance", specialAllowanceCtrl, isNumber: true, onChanged: _calculateNetSalary),
          ]),
          const SizedBox(height: 20),
          _buildTextField("Net Salary", netSalaryCtrl, isNumber: true, readOnly: true),
          const SizedBox(height: 24),
          const Text("Bank Details", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildTextFieldRow([
            _buildTextField("Bank Name", bankNameCtrl),
            _buildTextField("Account Number", accountNumberCtrl),
            _buildTextField("IFSC Code", ifscCodeCtrl),
          ]),
          const SizedBox(height: 24),
          const Text("Statutory Details", style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildTextFieldRow([
            _buildTextField("UAN Number", uanNumberCtrl),
            _buildTextField("ESI Number", esiNumberCtrl),
            _buildTextField("PF Number", pfNumberCtrl),
          ]),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildTextField("Additional Notes", notesCtrl, maxLines: 4),
        ],
      ),
    );
  }

  Widget _buildTextFieldRow(List<Widget> children) {
    return Row(children: children.map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: w))).toList());
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isRequired = false, bool isNumber = false, bool isDate = false, bool isEmail = false, bool isPhone = false, bool readOnly = false, int maxLines = 1, VoidCallback? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (isRequired) const TextSpan(text: " *", style: TextStyle(color: AppColors.dangerRed)),
            ],
          ),
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          onChanged: (v) => onChanged?.call(),
          keyboardType: isNumber ? TextInputType.number : isEmail ? TextInputType.emailAddress : isPhone ? TextInputType.phone : isDate ? TextInputType.datetime : TextInputType.text,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.surface,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accentCyan)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, void Function(String?) onChanged, {bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (isRequired) const TextSpan(text: " *", style: TextStyle(color: AppColors.dangerRed)),
            ],
          ),
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.surface,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderDark)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSimpleTextField(String label, String value, Function(String) onChanged, {bool isNumber = false, bool isPhone = false, bool isDate = false}) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      keyboardType: isNumber ? TextInputType.number : isPhone ? TextInputType.phone : isDate ? TextInputType.datetime : TextInputType.text,
      style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
      decoration: InputDecoration(
        hintText: label,
        filled: true, fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.borderDark)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}