import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';

import 'home_scrren.dart';
import 'theme.dart';

class SkyDevsLoginScreen extends StatefulWidget {
  const SkyDevsLoginScreen({Key? key}) : super(key: key);

  @override
  State<SkyDevsLoginScreen> createState() => _SkyDevsLoginScreenState();
}

class _SkyDevsLoginScreenState extends State<SkyDevsLoginScreen> {
  // API Data
  List<dynamic> _companies = [];
  List<dynamic> _allRoles = [];
  List<dynamic> _filteredRoles = [];
  List<dynamic> _allUsers = [];

  String? _selectedCompanyId;
  String? _selectedRoleId;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://skydevs.skynetproduct.com/skydevs_API.php?table=company_info')),
        http.get(Uri.parse('https://skydevs.skynetproduct.com/skydevs_API.php?table=admin_roles')),
        http.get(Uri.parse('https://skydevs.skynetproduct.com/skydevs_API.php?table=users1')),
      ]);

      if (mounted) {
        setState(() {
          final companyData = json.decode(responses[0].body);
          if (companyData['status'] == "success") _companies = companyData['data'] ?? [];

          final roleData = json.decode(responses[1].body);
          if (roleData['status'] == "success") _allRoles = roleData['data'] ?? [];

          final userData = json.decode(responses[2].body);
          if (userData['status'] == "success") _allUsers = userData['data'] ?? [];

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Connection error: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _onCompanySelected(String? companyId) {
    setState(() {
      _selectedCompanyId = companyId;
      _selectedRoleId = null;
      _filteredRoles = _allRoles.where((role) => role['company_id'] == companyId).toList();
    });
  }

  void _handleLogin() async {
    if (_selectedCompanyId == null || _selectedRoleId == null) {
      _showSnackbar("Select organization and role.", isError: true);
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showSnackbar("Enter credentials.", isError: true);
      return;
    }

    final matchedUser = _allUsers.cast<Map<String, dynamic>?>().firstWhere(
          (user) =>
      user!['company_id'] == _selectedCompanyId &&
          user['role_id'] == _selectedRoleId &&
          user['username'] == username,
      orElse: () => null,
    );

    if (matchedUser != null) {
      final String? hashedPassword = matchedUser['password'];
      bool isPasswordCorrect = false;

      if (hashedPassword != null && hashedPassword.isNotEmpty) {
        try {
          isPasswordCorrect = BCrypt.checkpw(password, hashedPassword);
        } catch (e) {
          print("Bcrypt error: $e");
        }
      } else {
        isPasswordCorrect = true;
      }

      if (isPasswordCorrect) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        // Save the company_id for filtering clients
        await prefs.setString('company_id', _selectedCompanyId.toString());

        // Also save other user info if needed
        await prefs.setString('user_id', matchedUser['id'].toString());
        await prefs.setString('username', username);
        await prefs.setString('role_id', _selectedRoleId.toString());

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SkyDevsHomeScreen()),
        );
      } else {
        _showSnackbar("Access Denied: Invalid password.", isError: true);
      }
    } else {
      _showSnackbar("Access Denied: Developer ID not found.", isError: true);
    }
  }
  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
        backgroundColor: isError ? Colors.redAccent : AppColors.accentCyan,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
            : Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Logo Header ---
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.code_rounded, color: Colors.white, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "SkyDevs",
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textWhite, fontFamily: 'sans-serif'),
                          ),
                          Text(
                            "by Skynet IT Solutions // v4.2.0",
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted.withOpacity(0.8)),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- Trust Badge ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.badgeBg,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.accentCyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: AppColors.accentCyan, shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: AppColors.background, size: 12, weight: 700,),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            "5000+",
                            style: TextStyle(color: AppColors.background, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Developers & DevOps Teams",
                          style: TextStyle(color: AppColors.accentCyan, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- Title ---
                  const Text(
                    "Admin sign in",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textWhite, fontFamily: 'sans-serif'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Enter credentials to access the developer console",
                    style: TextStyle(fontSize: 15, color: AppColors.textMuted, fontFamily: 'sans-serif'),
                  ),
                  const SizedBox(height: 32),

                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)),
                    ),

                  // --- Form Fields ---
                  _buildLabel("Organization"),
                  _buildDropdown(
                    hint: "Select organization",
                    icon: Icons.business_rounded,
                    value: _selectedCompanyId,
                    items: _companies,
                    itemLabelKey: 'company_name',
                    onChanged: (val) => _onCompanySelected(val as String?),
                  ),
                  const SizedBox(height: 24),

                  _buildLabel("Access Role"),
                  _buildDropdown(
                    hint: "Select role",
                    icon: Icons.admin_panel_settings_rounded,
                    value: _selectedRoleId,
                    items: _filteredRoles,
                    itemLabelKey: 'role',
                    onChanged: _selectedCompanyId == null ? null : (val) => setState(() => _selectedRoleId = val as String?),
                  ),
                  const SizedBox(height: 24),

                  _buildLabel("Developer ID / Username"),
                  _buildTextField(
                    hint: "e.g., dev.lead",
                    icon: Icons.person_rounded,
                    controller: _usernameController,
                  ),
                  const SizedBox(height: 24),

                  _buildLabel("SSH Key / Password"),
                  _buildTextField(
                    hint: "••••••••",
                    icon: Icons.lock_rounded,
                    controller: _passwordController,
                    isPassword: true,
                  ),
                  const SizedBox(height: 40),

                  // --- Login Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "Authenticate_User()",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textWhite, fontFamily: 'monospace'),
      ),
    );
  }

  Widget _buildDropdown({required String hint, required IconData icon, required String? value, required List<dynamic> items, required String itemLabelKey, required void Function(Object?)? onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: AppColors.surface,
      decoration: _inputDecoration(hint, icon),
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
      isExpanded: true,
      items: items.map<DropdownMenuItem<String>>((item) {
        return DropdownMenuItem<String>(
          value: item['id'].toString(),
          child: Text(item[itemLabelKey] ?? '', style: const TextStyle(color: AppColors.textWhite, fontSize: 15, fontFamily: 'sans-serif')),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTextField({required String hint, required IconData icon, required TextEditingController controller, bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      style: const TextStyle(color: AppColors.textWhite, fontSize: 15, fontFamily: 'sans-serif'),
      decoration: _inputDecoration(hint, icon).copyWith(
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted, size: 20),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5), fontSize: 15, fontFamily: 'sans-serif'),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderDark, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5),
      ),
      filled: true,
      fillColor: AppColors.surface,
    );
  }
}