import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../theme.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({Key? key}) : super(key: key);

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen>
    with SingleTickerProviderStateMixin {
  bool _isSaving = false;

  // Auto-generated Employee ID
  String get _generatedEmployeeId {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final random = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return "EMP-$year-$random";
  }

  String get _employeeCode {
    final now = DateTime.now();
    return "EMP${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.millisecondsSinceEpoch % 1000}";
  }

  // ==========================================
  // Personal Information Controllers
  // ==========================================
  final fullNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final dobCtrl = TextEditingController();
  String gender = 'Select';
  String bloodGroup = 'Select';
  String maritalStatus = 'Select';
  final panNumberCtrl = TextEditingController();
  final aadharNumberCtrl = TextEditingController();
  final currentAddressCtrl = TextEditingController();
  final permanentAddressCtrl = TextEditingController();
  List<Map<String, String>> emergencyContacts = [];

  // ==========================================
  // Professional Details Controllers
  // ==========================================
  String designation = 'Select Designation';
  String reportingTo = 'Select Manager';
  final confirmationDateCtrl = TextEditingController();
  String workMode = 'Onsite';
  String shift = 'General (9 AM - 6 PM)';
  String department = 'Select Department';
  final joiningDateCtrl = TextEditingController();
  String employmentType = 'Permanent';
  String status = 'Active';

  // ==========================================
  // Skills Tab Controllers
  // ==========================================
  List<String> selectedPrimarySkills = [];
  List<Map<String, dynamic>> skillMatrix = [];
  List<Map<String, String>> certifications = [];

  // Available skills list
  final List<String> availableSkills = [
    'Python', 'Django', 'React', 'Angular', 'AWS', 'Azure',
    'Docker', 'Kubernetes', 'PostgreSQL', 'MongoDB', 'Redis', 'Elasticsearch'
  ];

  // ==========================================
  // Projects Tab Controllers
  // ==========================================
  List<Map<String, String>> assignedProjects = [];

  // ==========================================
  // Payroll Tab Controllers
  // ==========================================
  final ctcCtrl = TextEditingController();
  final basicSalaryCtrl = TextEditingController();
  final hraCtrl = TextEditingController();
  final specialAllowanceCtrl = TextEditingController();
  final netSalaryCtrl = TextEditingController();
  final bankNameCtrl = TextEditingController();
  final accountNumberCtrl = TextEditingController();
  final ifscCodeCtrl = TextEditingController();
  final uanNumberCtrl = TextEditingController();
  final esiNumberCtrl = TextEditingController();
  final pfNumberCtrl = TextEditingController();

  // ==========================================
  // Documents Tab Controllers
  // =========================================  =
  File? _offerLetter;
  File? _idProof;
  final notesCtrl = TextEditingController();

  late TabController _tabController;

  // Dropdown options
  final List<String> genderOptions = ['Male', 'Female', 'Other'];
  final List<String> bloodGroupOptions = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  final List<String> maritalStatusOptions = ['Single', 'Married', 'Divorced'];
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
  final List<String> shiftOptions = ['General (9 AM - 6 PM)', 'Morning (6 AM - 2 PM)', 'Evening (2 PM - 10 PM)', 'Night (10 PM - 6 AM)'];
  final List<String> employmentTypeOptions = ['Permanent', 'Contract', 'Trainee', 'Intern', 'Probation'];
  final List<String> statusOptions = ['Active', 'Inactive', 'On Leave', 'Terminated'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    final now = DateTime.now();
    joiningDateCtrl.text = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    // Initialize skill matrix with empty skill
    _addSkill();
    _addCertification();
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
      skillMatrix.add({
        'skill': '',
        'self_rating': '',
        'manager_rating': '',
        'certification': ''
      });
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

  Future<void> _pickDocument(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (result != null) {
      setState(() {
        switch (type) {
          case 'offer_letter':
            _offerLetter = File(result.paths.first!);
            break;
          case 'id_proof':
            _idProof = File(result.paths.first!);
            break;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${type.toUpperCase().replaceAll('_', ' ')} selected"),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _calculateNetSalary() {
    double ctc = double.tryParse(ctcCtrl.text) ?? 0;
    double basic = double.tryParse(basicSalaryCtrl.text) ?? 0;
    double hra = double.tryParse(hraCtrl.text) ?? 0;
    double special = double.tryParse(specialAllowanceCtrl.text) ?? 0;

    double net = basic + hra + special;
    netSalaryCtrl.text = net.toStringAsFixed(2);
  }

  Future<void> _saveEmployee() async {
    // Validation
    if (fullNameCtrl.text.trim().isEmpty ||
        emailCtrl.text.trim().isEmpty ||
        phoneCtrl.text.trim().isEmpty ||
        designation == 'Select Designation' ||
        department == 'Select Department') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields (*) first.",
              style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Fetch both IDs and check login type
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isClient = prefs.getBool('isClient') ?? false;
      final String companyId = prefs.getString('company_id') ?? '';
      final String clientIdSession = prefs.getString('clientId') ?? '';
      final String? userId = prefs.getString('user_id');

      // Validate based on user type
      if (isClient && clientIdSession.isEmpty) {
        _showError("Session Error: Client ID missing. Please log out and log in again.");
        setState(() { _isSaving = false; });
        return;
      } else if (!isClient && companyId.isEmpty) {
        _showError("Session Error: Company ID missing. Please log out and log in again.");
        setState(() { _isSaving = false; });
        return;
      }

      final String uniqueEmployeeId = _generatedEmployeeId;
      final String employeeCode = _employeeCode;

      // Prepare JSON fields
      String primarySkillsJson = json.encode(selectedPrimarySkills);
      String skillMatrixJson = json.encode(skillMatrix.map((s) => {
        'skill': s['skill'],
        'self_rating': s['self_rating'],
        'manager_rating': s['manager_rating'],
        'certification': s['certification']
      }).toList());

      String certificationsJson = json.encode(certifications.map((c) => {
        'name': c['name'],
        'issuer': c['issuer'],
        'year': c['year']
      }).toList());

      String assignedProjectsJson = json.encode(assignedProjects.map((p) => {
        'name': p['name'],
        'role': p['role'],
        'allocation': p['allocation']
      }).toList());

      String emergencyContactsJson = json.encode(emergencyContacts.map((e) => {
        'name': e['name'],
        'relation': e['relation'],
        'phone': e['phone']
      }).toList());

      String documentsJson = json.encode({
        'offer_letter': _offerLetter?.path.split('/').last ?? '',
        'id_proof': _idProof?.path.split('/').last ?? '',
      });

      final Map<String, dynamic> payload = {
        'company_id': companyId,
        'created_by': userId ?? '1',

        // --- FIXED: Only using client_id (No client_id_owner) ---
        'client_id': isClient ? clientIdSession : null,

        'unique_employee_id': uniqueEmployeeId,
        'employee_code': employeeCode,
        'full_name': fullNameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'date_of_birth': dobCtrl.text.trim().isEmpty ? null : dobCtrl.text.trim(),
        'blood_group': bloodGroup == 'Select' ? null : bloodGroup,
        'pan_number': panNumberCtrl.text.trim().isEmpty ? null : panNumberCtrl.text.trim(),
        'aadhar_number': aadharNumberCtrl.text.trim().isEmpty ? null : aadharNumberCtrl.text.trim(),
        'gender': gender == 'Select' ? null : gender.toLowerCase(),
        'marital_status': maritalStatus == 'Select' ? null : maritalStatus.toLowerCase(),
        'current_address': currentAddressCtrl.text.trim(),
        'permanent_address': permanentAddressCtrl.text.trim(),
        'designation': designation,
        'department': department,
        'reporting_to': reportingTo == 'Select Manager' ? null : reportingTo,
        'joining_date': joiningDateCtrl.text.trim(),
        'confirmation_date': confirmationDateCtrl.text.trim().isEmpty ? null : confirmationDateCtrl.text.trim(),
        'employment_type': employmentType.toLowerCase(),
        'work_mode': workMode.toLowerCase(),
        'shift': shift.toLowerCase().split(' ')[0],
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
        'documents': documentsJson,
        'notes': notesCtrl.text.trim(),
        'emergency_contacts': emergencyContactsJson,
      };

      // Clean the payload to remove any null values
      final Map<String, dynamic> cleanedPayload = {};
      payload.forEach((key, value) {
        if (value != null) {
          cleanedPayload[key] = value;
        }
      });

      final response = await http.post(
        Uri.parse('https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_employees'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(cleanedPayload),
      );

      // Safe decoding logic to handle potential PHP warnings
      String responseBody = response.body.trim();
      int startIndex = responseBody.indexOf('{');
      if (startIndex > 0) {
        responseBody = responseBody.substring(startIndex);
      }

      final data = json.decode(responseBody);

      if (data['status'] == 'success') {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Employee added successfully! ID: $uniqueEmployeeId"),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showError(data['message'] ?? "API error saving employee record.");
      }
    } catch (e) {
      _showError("Connection network exception: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: AppColors.dangerRed,
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
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: const Text("Add New Employee",
            style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.accentCyan,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accentCyan,
          indicatorSize: TabBarIndicatorSize.label,
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
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
          : Column(
        children: [
          // Unique Employee ID Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accentCyan.withOpacity(0.15), AppColors.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accentCyan.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.badge, color: AppColors.accentCyan, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Employee ID (Auto-generated)",
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _generatedEmployeeId,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        "Code: $_employeeCode",
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "NEW",
                    style: TextStyle(color: AppColors.successGreen, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
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
          // Fixed Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.borderDark)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _saveEmployee,
                  child: const Text("Add Employee",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // PERSONAL TAB
  // ==========================================
  Widget _buildPersonalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Personal Information", Icons.person_outline),
          const SizedBox(height: 20),
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
          const SizedBox(height: 32),
          _sectionHeader("Emergency Contacts", Icons.contact_emergency),
          const SizedBox(height: 16),
          ...emergencyContacts.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, String> contact = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildSimpleTextField("Contact Name", contact['name'] ?? '',
                          (v) => _updateEmergencyContact(index, 'name', v))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSimpleTextField("Relation", contact['relation'] ?? '',
                          (v) => _updateEmergencyContact(index, 'relation', v))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSimpleTextField("Phone", contact['phone'] ?? '',
                          (v) => _updateEmergencyContact(index, 'phone', v), isPhone: true)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed),
                    onPressed: () => _removeEmergencyContact(index),
                  ),
                ],
              ),
            );
          }).toList(),
          Center(
            child: TextButton.icon(
              onPressed: _addEmergencyContact,
              icon: const Icon(Icons.add_circle_outline, color: AppColors.accentCyan),
              label: const Text("Add Emergency Contact", style: TextStyle(color: AppColors.accentCyan)),
            ),
          ),
        ],
      ),
    );
  }

  void _updateEmergencyContact(int index, String field, String value) {
    setState(() {
      emergencyContacts[index][field] = value;
    });
  }

  // ==========================================
  // PROFESSIONAL TAB
  // ==========================================
  Widget _buildProfessionalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Professional Details", Icons.work_outline),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildDropdown("Designation", designation, designationOptions, (v) => setState(() => designation = v!), isRequired: true),
            _buildDropdown("Reporting To", reportingTo, ['Select Manager', 'John Doe - CEO', 'Jane Smith - CTO'], (v) => setState(() => reportingTo = v!)),
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

  // ==========================================
  // SKILLS TAB
  // ==========================================
  Widget _buildSkillsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Primary Skills", Icons.code),
          const SizedBox(height: 16),
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
                    if (selected) {
                      selectedPrimarySkills.add(skill);
                    } else {
                      selectedPrimarySkills.remove(skill);
                    }
                  });
                },
                backgroundColor: AppColors.surface,
                selectedColor: AppColors.accentCyan.withOpacity(0.3),
                checkmarkColor: AppColors.accentCyan,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.accentCyan : AppColors.textWhite,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          _sectionHeader("Skill Matrix (Self Rating)", Icons.star_outline),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.resolveWith((states) => AppColors.surface),
              dataRowColor: WidgetStateProperty.resolveWith((states) => AppColors.background),
              columnSpacing: 16,
              columns: const [
                DataColumn(label: Text("Skill", style: TextStyle(color: AppColors.textWhite))),
                DataColumn(label: Text("Self Rating (1-5)", style: TextStyle(color: AppColors.textWhite))),
                DataColumn(label: Text("Manager Rating (1-5)", style: TextStyle(color: AppColors.textWhite))),
                DataColumn(label: Text("Certification", style: TextStyle(color: AppColors.textWhite))),
                DataColumn(label: Text("Actions", style: TextStyle(color: AppColors.textWhite))),
              ],
              rows: skillMatrix.asMap().entries.map((entry) {
                int index = entry.key;
                var skill = entry.value;
                return DataRow(cells: [
                  DataCell(SizedBox(
                    width: 150,
                    child: _buildSimpleTextField("", skill['skill'] ?? '',
                            (v) => _updateSkillMatrix(index, 'skill', v)),
                  )),
                  DataCell(SizedBox(
                    width: 120,
                    child: _buildSimpleTextField("", skill['self_rating'] ?? '',
                            (v) => _updateSkillMatrix(index, 'self_rating', v), isNumber: true),
                  )),
                  DataCell(SizedBox(
                    width: 120,
                    child: _buildSimpleTextField("", skill['manager_rating'] ?? '',
                            (v) => _updateSkillMatrix(index, 'manager_rating', v), isNumber: true),
                  )),
                  DataCell(SizedBox(
                    width: 150,
                    child: _buildSimpleTextField("", skill['certification'] ?? '',
                            (v) => _updateSkillMatrix(index, 'certification', v)),
                  )),
                  DataCell(IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed, size: 20),
                    onPressed: () => _removeSkill(index),
                  )),
                ]);
              }).toList(),
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: _addSkill,
              icon: const Icon(Icons.add_circle_outline, color: AppColors.accentCyan),
              label: const Text("Add Skill", style: TextStyle(color: AppColors.accentCyan)),
            ),
          ),
          const SizedBox(height: 32),
          _sectionHeader("Certifications", Icons.verified_outlined),
          const SizedBox(height: 16),
          ...certifications.asMap().entries.map((entry) {
            int index = entry.key;
            var cert = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildSimpleTextField("Certification Name", cert['name'] ?? '',
                          (v) => _updateCertification(index, 'name', v))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSimpleTextField("Issuer", cert['issuer'] ?? '',
                          (v) => _updateCertification(index, 'issuer', v))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSimpleTextField("Year", cert['year'] ?? '',
                          (v) => _updateCertification(index, 'year', v), isDate: true)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed),
                    onPressed: () => _removeCertification(index),
                  ),
                ],
              ),
            );
          }).toList(),
          Center(
            child: TextButton.icon(
              onPressed: _addCertification,
              icon: const Icon(Icons.add_circle_outline, color: AppColors.accentCyan),
              label: const Text("Add Certification", style: TextStyle(color: AppColors.accentCyan)),
            ),
          ),
        ],
      ),
    );
  }

  void _updateSkillMatrix(int index, String field, String value) {
    setState(() {
      skillMatrix[index][field] = value;
    });
  }

  void _updateCertification(int index, String field, String value) {
    setState(() {
      certifications[index][field] = value;
    });
  }

  // ==========================================
  // PROJECTS TAB
  // ==========================================
  Widget _buildProjectsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Assigned Projects", Icons.folder_outlined),
          const SizedBox(height: 16),
          ...assignedProjects.asMap().entries.map((entry) {
            int index = entry.key;
            var project = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: _buildSimpleTextField("Project Name", project['name'] ?? '',
                          (v) => _updateAssignedProject(index, 'name', v))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSimpleTextField("Role", project['role'] ?? '',
                          (v) => _updateAssignedProject(index, 'role', v))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSimpleTextField("Allocation %", project['allocation'] ?? '',
                          (v) => _updateAssignedProject(index, 'allocation', v), isNumber: true)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed),
                    onPressed: () => _removeAssignedProject(index),
                  ),
                ],
              ),
            );
          }).toList(),
          Center(
            child: TextButton.icon(
              onPressed: _addAssignedProject,
              icon: const Icon(Icons.add_circle_outline, color: AppColors.accentCyan),
              label: const Text("Assign Project", style: TextStyle(color: AppColors.accentCyan)),
            ),
          ),
        ],
      ),
    );
  }

  void _updateAssignedProject(int index, String field, String value) {
    setState(() {
      assignedProjects[index][field] = value;
    });
  }

  // ==========================================
  // PAYROLL TAB
  // ==========================================
  Widget _buildPayrollTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Salary Details", Icons.attach_money_outlined),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("CTC (Annual)", ctcCtrl, isNumber: true, onChanged: _calculateNetSalary),  // Remove (v) =>
            _buildTextField("Basic Salary (Monthly)", basicSalaryCtrl, isNumber: true, onChanged: _calculateNetSalary),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("HRA (Monthly)", hraCtrl, isNumber: true, onChanged: _calculateNetSalary),
            _buildTextField("Special Allowance", specialAllowanceCtrl, isNumber: true, onChanged: _calculateNetSalary),
          ]),
          const SizedBox(height: 20),
          _buildTextField("Net Salary (Monthly)", netSalaryCtrl, isNumber: true, readOnly: true),
          const SizedBox(height: 32),
          _sectionHeader("Bank Details", Icons.account_balance_outlined),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("Bank Name", bankNameCtrl),
            _buildTextField("Account Number", accountNumberCtrl),
            _buildTextField("IFSC Code", ifscCodeCtrl),
          ]),
          const SizedBox(height: 32),
          _sectionHeader("Statutory Details", Icons.description_outlined),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("UAN Number", uanNumberCtrl),
            _buildTextField("ESI Number", esiNumberCtrl),
            _buildTextField("PF Number", pfNumberCtrl),
          ]),
        ],
      ),
    );
  }
  // ==========================================
  // DOCUMENTS TAB
  // ==========================================
  Widget _buildDocumentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Upload Documents", Icons.upload_file_outlined),
          const SizedBox(height: 20),
          _buildDocumentPicker("Offer Letter", _offerLetter, 'offer_letter'),
          const SizedBox(height: 16),
          _buildDocumentPicker("ID Proof (Aadhar/PAN)", _idProof, 'id_proof'),
          const SizedBox(height: 32),
          _sectionHeader("Additional Notes", Icons.note_outlined),
          const SizedBox(height: 16),
          TextFormField(
            controller: notesCtrl,
            maxLines: 4,
            style: const TextStyle(color: AppColors.textWhite),
            decoration: _inputDeco("Notes").copyWith(
              hintText: "Any additional information about the employee...",
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPicker(String title, File? document, String type) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textWhite, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Text(
                    document != null ? document.path.split('/').last : "No file chosen",
                    style: TextStyle(
                      color: document != null ? AppColors.accentCyan : AppColors.textMuted,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _pickDocument(type),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text("Choose File"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentCyan, size: 22),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.w600, fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: AppColors.borderDark, thickness: 1)),
      ],
    );
  }

  Widget _buildTextFieldRow(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
          .map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 16), child: w)))
          .toList(),
    );
  }

  // FIX APPLIED HERE: Replaced Row with Text.rich to allow long labels to wrap
  Widget _buildTextField(String label, TextEditingController controller,
      {String hint = '', bool isRequired = false, bool isEmail = false, bool isPhone = false,
        bool isUrl = false, bool isNumber = false, bool isDate = false, bool readOnly = false,
        VoidCallback? onChanged}) {
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
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          style: const TextStyle(color: AppColors.textWhite),
          onChanged: (v) => onChanged?.call(),
          keyboardType: isNumber ? TextInputType.number :
          isEmail ? TextInputType.emailAddress :
          isPhone ? TextInputType.phone :
          isUrl ? TextInputType.url :
          isDate ? TextInputType.datetime : TextInputType.text,
          decoration: _inputDeco("").copyWith(
            hintText: hint.isNotEmpty ? hint : (isRequired ? "Required" : "Optional"),
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  // FIX APPLIED HERE: Replaced Row with Text.rich to allow long labels to wrap
  Widget _buildDropdown(String label, String value, List<String> items,
      void Function(String?) onChanged, {bool isRequired = false}) {
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
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textWhite, fontSize: 14),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accentCyan)),
            filled: true,
            fillColor: AppColors.surface,
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSimpleTextField(String label, String value, Function(String) onChanged,
      {bool isNumber = false, bool isPhone = false, bool isDate = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        if (label.isNotEmpty) const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
          keyboardType: isNumber ? TextInputType.number : isPhone ? TextInputType.phone : isDate ? TextInputType.datetime : TextInputType.text,
          decoration: InputDecoration(
            hintText: label.isEmpty ? "" : "Enter $label",
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderDark)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accentCyan)),
            filled: true,
            fillColor: AppColors.surface,
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderDark)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accentCyan)),
      filled: true,
      fillColor: AppColors.surface,
    );
  }
}