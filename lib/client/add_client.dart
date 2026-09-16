import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../theme.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({Key? key}) : super(key: key);

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen>
    with SingleTickerProviderStateMixin {
  bool _isSaving = false;

  // Auto-generated Client ID (simulated for UI)
  String get _generatedClientId {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year;
    final random = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return "CLT-$year-$month$day-$random";
  }

  // --- Basic Tab Controllers ---
  final companyNameCtrl = TextEditingController();
  final websiteCtrl = TextEditingController();
  final gstCtrl = TextEditingController();
  final clientSinceCtrl = TextEditingController(text: "");
  String industry = 'IT / Software';
  String clientType = 'Enterprise';
  String status = 'Active';
  String rating = '5.0';
  List<File> _generalAttachments = [];

  // --- Contact Tab Controllers ---
  final priNameCtrl = TextEditingController();
  final priRoleCtrl = TextEditingController();
  final priEmailCtrl = TextEditingController();
  final priPhoneCtrl = TextEditingController();
  final priWaCtrl = TextEditingController();
  final priLinkedinCtrl = TextEditingController();
  final secNameCtrl = TextEditingController();
  final secRoleCtrl = TextEditingController();
  final secEmailCtrl = TextEditingController();
  final secPhoneCtrl = TextEditingController();

  // --- Contract Tab Controllers ---
  final contractValueCtrl = TextEditingController();
  final startDateCtrl = TextEditingController();
  final endDateCtrl = TextEditingController();
  final renewalDateCtrl = TextEditingController();
  String contractType = 'Fixed Price';
  String paymentTerms = 'Net 15';
  bool autoRenew = false;

  // Contract Documents
  File? _contractDocument;
  File? _ndaDocument;
  File? _msaDocument;

  // --- Billing Tab Controllers ---
  final hourlyRateCtrl = TextEditingController();
  final discountCtrl = TextEditingController();
  final lateFeeCtrl = TextEditingController();

  // --- Integration Tab Controllers ---
  final repoUrlCtrl = TextEditingController();
  final apiKeyCtrl = TextEditingController();
  final dashUrlCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  String gitProvider = 'GitHub';
  String serverProvider = 'AWS';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    // Set default client since date
    final now = DateTime.now();
    clientSinceCtrl.text = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    if (controller.text.trim().isNotEmpty) {
      try {
        initial = DateTime.parse(controller.text.trim());
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
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

    if (picked != null) {
      setState(() {
        controller.text =
        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _pickGeneralFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (result != null) {
      setState(() {
        _generalAttachments = result.paths.map((path) => File(path!)).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${_generalAttachments.length} file(s) selected"),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickDocument(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null) {
      setState(() {
        switch (type) {
          case 'contract':
            _contractDocument = File(result.paths.first!);
            break;
          case 'nda':
            _ndaDocument = File(result.paths.first!);
            break;
          case 'msa':
            _msaDocument = File(result.paths.first!);
            break;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${type.toUpperCase()} document selected"),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _saveClient() async {
    // --- STRICT VALIDATION CHECK ---
    if (companyNameCtrl.text.trim().isEmpty ||
        priNameCtrl.text.trim().isEmpty ||
        priEmailCtrl.text.trim().isEmpty ||
        priPhoneCtrl.text.trim().isEmpty) {
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
      // --- CHANGED: Fetch both IDs and check login type ---
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

      final String uniqueClientId = _generatedClientId;

      // Build payload with ONLY fields that exist in the database
      final Map<String, dynamic> payload = {
        'company_id': companyId,

        // --- CHANGED: Insert client_id_owner conditionally ---
        'client_id': isClient ? clientIdSession : null,

        'created_by': userId ?? '1',
        'unique_client_id': uniqueClientId,
        'company_name': companyNameCtrl.text.trim(),
        'website': websiteCtrl.text.trim(),
        'gst_pan': gstCtrl.text.trim(),
        'client_since': clientSinceCtrl.text.trim(),
        'industry': industry,
        'client_type': clientType,
        'status': status,
        'rating': rating,
        'primary_contact_name': priNameCtrl.text.trim(),
        'primary_contact_role': priRoleCtrl.text.trim(),
        'primary_contact_email': priEmailCtrl.text.trim(),
        'primary_contact_phone': priPhoneCtrl.text.trim(),
        'primary_contact_whatsapp': priWaCtrl.text.trim(),
        'primary_contact_linkedin': priLinkedinCtrl.text.trim(),
        'secondary_contact_name': secNameCtrl.text.trim(),
        'secondary_contact_role': secRoleCtrl.text.trim(),
        'secondary_contact_email': secEmailCtrl.text.trim(),
        'secondary_contact_phone': secPhoneCtrl.text.trim(),
        'contract_value': contractValueCtrl.text.trim(),
        'contract_start_date': startDateCtrl.text.trim(),
        'contract_end_date': endDateCtrl.text.trim(),
        'renewal_date': renewalDateCtrl.text.trim(),
        'contract_type': contractType,
        'payment_terms': paymentTerms,
        'auto_renew': autoRenew ? '1' : '0',
        'hourly_rate': hourlyRateCtrl.text.trim(),
        'discount_percentage': discountCtrl.text.trim(),
        'late_fee_percentage': lateFeeCtrl.text.trim(),
        'repo_url': repoUrlCtrl.text.trim(),
        'api_key': apiKeyCtrl.text.trim(),
        'dashboard_url': dashUrlCtrl.text.trim(),
        'notes': notesCtrl.text.trim(),
        'git_provider': gitProvider,
        'server_provider': serverProvider,
        // REMOVED: 'attachments_count' - this column doesn't exist in your database
        // Document filenames (only store the filename, not the full path)
        'contract_document': _contractDocument != null
            ? _contractDocument!.path.split('/').last
            : '',
        'nda_document': _ndaDocument != null
            ? _ndaDocument!.path.split('/').last
            : '',
        'msa_document': _msaDocument != null
            ? _msaDocument!.path.split('/').last
            : '',
      };

      // Clean the payload to remove any null values
      final Map<String, dynamic> cleanedPayload = {};
      payload.forEach((key, value) {
        if (value != null) {
          cleanedPayload[key] = value;
        }
      });

      final response = await http.post(
        Uri.parse(
            'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_clients'),
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
              content: Text("Client added successfully! ID: $uniqueClientId"),
              backgroundColor: AppColors.successGreen,
              behavior: SnackBarBehavior.floating),
        );
      } else {
        _showError(data['message'] ?? "API error saving client record.");
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
          behavior: SnackBarBehavior.floating),
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
        title: const Text("Add New Client Profile",
            style: TextStyle(
                color: AppColors.textWhite, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.accentCyan,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.accentCyan,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(icon: Icon(Icons.business_outlined), text: "Basic"),
            Tab(icon: Icon(Icons.people_outline), text: "Contact"),
            Tab(icon: Icon(Icons.description_outlined), text: "Contract"),
            Tab(icon: Icon(Icons.receipt_outlined), text: "Billing"),
            Tab(icon: Icon(Icons.integration_instructions_outlined), text: "Integration"),
          ],
        ),
      ),
      body: _isSaving
          ? const Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan))
          : Column(
        children: [
          // Unique Client ID Card
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
                  child: const Icon(Icons.tag, color: AppColors.accentCyan, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Client ID (Auto-generated)",
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _generatedClientId,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
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
                    style: TextStyle(
                      color: AppColors.successGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBasicTab(),
                _buildContactTab(),
                _buildContractTab(),
                _buildBillingTab(),
                _buildIntegrationTab(),
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
                  child: const Text("Cancel",
                      style:
                      TextStyle(color: AppColors.textMuted, fontSize: 16)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _saveClient,
                  child: const Text("Save System Client",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // TAB BUILDERS
  // ==========================================

  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Corporate Information", Icons.business),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("Company Name *", companyNameCtrl, isRequired: true),
            _buildDropdown("Industry", industry, [
              'IT / Software',
              'Healthcare',
              'Fintech',
              'Ecommerce',
              'Education',
              'Manufacturing',
              'Real Estate',
              'Other'
            ], (v) => setState(() => industry = v!)),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("Client (YYYY-MM-DD)", clientSinceCtrl, isDate: true),
            _buildDropdown("Client Type", clientType, [
              'Enterprise',
              'Startup',
              'Midsize Business',
              'Government'
            ], (v) => setState(() => clientType = v!)),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildDropdown("Status", status, ['Active', 'Inactive', 'Pending'],
                    (v) => setState(() => status = v!)),
            _buildDropdown("Rating", rating, ['1.0', '2.0', '3.0', '4.0', '5.0'],
                    (v) => setState(() => rating = v!)),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("Website", websiteCtrl, isUrl: true),
            _buildTextField("GST / PAN", gstCtrl),
          ]),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Primary Contact", Icons.person_outline),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("Full Name *", priNameCtrl, isRequired: true),
            _buildTextField("Role / Designation", priRoleCtrl),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("Email *", priEmailCtrl, isEmail: true, isRequired: true),
            _buildTextField("Phone *", priPhoneCtrl, isPhone: true, isRequired: true),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("WhatsApp", priWaCtrl, isPhone: true),
            _buildTextField("LinkedIn Profile", priLinkedinCtrl, isUrl: true),
          ]),
          const SizedBox(height: 32),
          _sectionHeader("Secondary Contact (opt)", Icons.person_outline),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("Full Name", secNameCtrl),
            _buildTextField("Role", secRoleCtrl),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("Email", secEmailCtrl, isEmail: true),
            _buildTextField("Phone", secPhoneCtrl, isPhone: true),
          ]),
        ],
      ),
    );
  }

  Widget _buildContractTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Contract Information", Icons.description_outlined),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildDropdown("Contract Type", contractType,
                ['Fixed Price', 'Time & Material', 'Retainer'],
                    (v) => setState(() => contractType = v!)),
            _buildTextField("Contract Value (₹)", contractValueCtrl, isNumber: true),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildDropdown("Payment Terms", paymentTerms,
                ['Net 15', 'Net 30', 'Net 45', 'Due on Receipt'],
                    (v) => setState(() => paymentTerms = v!)),
            _buildDateField("Renewal Date", renewalDateCtrl),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildDateField("Contract Start Date", startDateCtrl),
            _buildDateField("Contract End Date", endDateCtrl),
          ]),
          const SizedBox(height: 16),
          // Auto-renew Checkbox
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: autoRenew,
                  activeColor: AppColors.accentCyan,
                  onChanged: (val) => setState(() => autoRenew = val ?? false),
                ),
                const Text("Auto-renew contract",
                    style: TextStyle(color: AppColors.textWhite, fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader("Contract Documents", Icons.attach_file),
          const SizedBox(height: 16),
          // Contract Document Picker
          _buildDocumentPicker("Contract Document", _contractDocument, 'contract'),
          const SizedBox(height: 16),
          _buildDocumentPicker("NDA Document", _ndaDocument, 'nda'),
          const SizedBox(height: 16),
          _buildDocumentPicker("MSA Document", _msaDocument, 'msa'),
        ],
      ),
    );
  }


  Widget _buildDateField(String label, TextEditingController controller,
      {bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            if (isRequired)
              const Text(" *", style: TextStyle(color: AppColors.dangerRed)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: true, // prevents keyboard, forces picker
          onTap: () => _pickDate(controller),
          style: const TextStyle(color: AppColors.textWhite),
          decoration: _inputDeco("").copyWith(
            hintText: "YYYY-MM-DD",
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: const Icon(Icons.calendar_today,
                size: 18, color: AppColors.textMuted),
          ),
        ),
      ],
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
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textWhite,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Billing Configuration", Icons.receipt_outlined),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("Hourly  (₹)", hourlyRateCtrl, isNumber: true),
            _buildTextField("Discount (%)", discountCtrl, isNumber: true),
            _buildTextField("Late Fee (%)", lateFeeCtrl, isNumber: true),
          ]),
        ],
      ),
    );
  }

  Widget _buildIntegrationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Developer Tools", Icons.integration_instructions_outlined),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildDropdown("Git Provider", gitProvider,
                ['GitHub', 'GitLab', 'Bitbucket', 'Other'],
                    (v) => setState(() => gitProvider = v!)),
            _buildTextField("Repository URL", repoUrlCtrl, isUrl: true),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("API Key", apiKeyCtrl),
            _buildDropdown("Cloud Provider", serverProvider,
                ['AWS', 'Azure', 'GCP', 'DigitalOcean', 'Other'],
                    (v) => setState(() => serverProvider = v!)),
          ]),
          const SizedBox(height: 20),
          _buildTextField("Dashboard URL", dashUrlCtrl, isUrl: true),
          const SizedBox(height: 20),
          TextFormField(
            controller: notesCtrl,
            maxLines: 4,
            style: const TextStyle(color: AppColors.textWhite),
            decoration: _inputDeco("Additional Notes")
                .copyWith(alignLabelWithHint: true),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET HELPERS
  // ==========================================

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentCyan, size: 22),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Divider(
            color: AppColors.borderDark,
            thickness: 1,
          ),
        ),
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

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isRequired = false,
        bool isEmail = false,
        bool isPhone = false,
        bool isUrl = false,
        bool isNumber = false,
        bool isDate = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            if (isRequired)
              const Text(" *", style: TextStyle(color: AppColors.dangerRed)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: AppColors.textWhite),
          keyboardType: isNumber
              ? TextInputType.number
              : isEmail
              ? TextInputType.emailAddress
              : isPhone
              ? TextInputType.phone
              : isUrl
              ? TextInputType.url
              : isDate
              ? TextInputType.datetime
              : TextInputType.text,
          decoration: _inputDeco("").copyWith(
            hintText: isRequired ? "Required" : "Optional",
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      void Function(String?) onChanged) {
    String safeValue = items.contains(value) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: safeValue,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: AppColors.textWhite, fontSize: 14),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.accentCyan),
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
          items: items.map((e) {
            return DropdownMenuItem(
              value: e,
              child: Text(e,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
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
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accentCyan),
      ),
      filled: true,
      fillColor: AppColors.surface,
    );
  }
}