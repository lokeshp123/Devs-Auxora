import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../theme.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({Key? key}) : super(key: key);

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _clients = [];

  final String _apiUrl = 'https://auxoradevs.auxorasystems.com/skydevs_API.php?table=skydevs_clients';

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCompanyId = prefs.getString('company_id');

      if (savedCompanyId == null) {
        setState(() {
          _errorMessage = "Company ID not found in session. Please log in again.";
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(Uri.parse(_apiUrl));
      final data = json.decode(response.body);

      if (data['status'] == "success") {
        List<dynamic> allClients = data['data'] ?? [];

        setState(() {
          _clients = allClients.where((client) {
            return client['company_id']?.toString() == savedCompanyId;
          }).toList();
          _errorMessage = '';
        });
      } else {
        setState(() => _errorMessage = "Failed to load clients.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Connection error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteClient(String id) async {
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
        _showSnackbar("Client deleted successfully.", isError: false);
        _fetchClients();
      } else {
        _showSnackbar(data['message'] ?? "Failed to delete.", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar("Error deleting client: $e", isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateClient(String id, Map<String, dynamic> updatedData) async {
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
        _showSnackbar("Client updated successfully.", isError: false);
        _fetchClients();
      } else {
        _showSnackbar(data['message'] ?? "Failed to update.", isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackbar("Error updating client: $e", isError: true);
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

  void _confirmDelete(Map<String, dynamic> client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Confirm Deletion", style: TextStyle(color: AppColors.textWhite)),
        content: Text("Delete ${client['company_name']}? This cannot be undone.", style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: () => _deleteClient(client['id'].toString()),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
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
        title: const Text("Client Roster", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.accentCyan));
    if (_errorMessage.isNotEmpty) return Center(child: Text(_errorMessage, style: const TextStyle(color: AppColors.dangerRed)));
    if (_clients.isEmpty) return const Center(child: Text("No clients found.", style: TextStyle(color: AppColors.textMuted)));

    return RefreshIndicator(
      color: AppColors.accentCyan,
      backgroundColor: AppColors.surface,
      onRefresh: _fetchClients,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _clients.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final client = _clients[index];
          final status = (client['status'] ?? '').toString().toLowerCase();
          Color statusColor = status == 'active' ? AppColors.successGreen : AppColors.dangerRed;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClientDetailsScreen(client: client),
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
                        child: Text(client['company_name'] ?? 'Unknown Company', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textWhite)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
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
                                builder: (context) => EditClientScreen(
                                  client: client,
                                  onSave: (updatedData) {
                                    _updateClient(client['id'].toString(), updatedData);
                                  },
                                ),
                              ),
                            );
                          }
                          if (value == 'delete') _confirmDelete(client);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, color: AppColors.textWhite, size: 18), SizedBox(width: 8), Text('Edit', style: TextStyle(color: AppColors.textWhite))])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: AppColors.dangerRed, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.dangerRed))])),
                        ],
                      ),
                    ],
                  ),
                  Text("ID: ${client['unique_client_id'] ?? 'N/A'}", style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderDark, height: 1),
                  const SizedBox(height: 16),

                  Row(
                      children: [
                        const Icon(Icons.person_rounded, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text("${client['primary_contact_name'] ?? 'N/A'} (${client['primary_contact_role'] ?? 'Role'})",
                              style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        )
                      ]
                  ),
                  const SizedBox(height: 8),
                  Row(
                      children: [
                        const Icon(Icons.email_rounded, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(client['primary_contact_email'] ?? 'N/A',
                              style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        )
                      ]
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
// CLIENT DETAILS SCREEN (NEWLY ADDED)
// ==========================================

class ClientDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> client;

  const ClientDetailsScreen({Key? key, required this.client}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.premiumGradient)),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Client Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER CARD ---
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
                  Text(
                    client['company_name'] ?? 'Unknown Company',
                    style: const TextStyle(color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "ID: ${client['unique_client_id'] ?? 'N/A'} | Industry: ${client['industry'] ?? 'N/A'}",
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Website: ${client['website'] ?? 'N/A'} | GST/PAN: ${client['gst_pan'] ?? 'N/A'}",
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- CORPORATE INFO ---
            _buildSection("Corporate Information", [
              _buildDetailRow("Client Type", client['client_type']),
              _buildDetailRow("Status", client['status']),
              _buildDetailRow("Rating", client['rating']),
              _buildDetailRow("Client Since", client['client_since']),
            ]),

            // --- PRIMARY CONTACT ---
            _buildSection("Primary Contact", [
              _buildDetailRow("Name", client['primary_contact_name']),
              _buildDetailRow("Role", client['primary_contact_role']),
              _buildDetailRow("Email", client['primary_contact_email']),
              _buildDetailRow("Phone", client['primary_contact_phone']),
              _buildDetailRow("WhatsApp", client['primary_contact_whatsapp']),
              _buildDetailRow("LinkedIn", client['primary_contact_linkedin']),
            ]),

            // --- SECONDARY CONTACT ---
            if ((client['secondary_contact_name'] ?? '').toString().isNotEmpty)
              _buildSection("Secondary Contact", [
                _buildDetailRow("Name", client['secondary_contact_name']),
                _buildDetailRow("Role", client['secondary_contact_role']),
                _buildDetailRow("Email", client['secondary_contact_email']),
                _buildDetailRow("Phone", client['secondary_contact_phone']),
              ]),

            // --- CONTRACT INFO ---
            _buildSection("Contract Information", [
              _buildDetailRow("Contract Type", client['contract_type']),
              _buildDetailRow("Contract Value", client['contract_value'] != null ? "₹${client['contract_value']}" : null),
              _buildDetailRow("Payment Terms", client['payment_terms']),
              _buildDetailRow("Start Date", client['contract_start_date']),
              _buildDetailRow("End Date", client['contract_end_date']),
              _buildDetailRow("Renewal Date", client['renewal_date']),
              _buildDetailRow("Auto Renew", client['auto_renew']?.toString() == '1' ? 'Yes' : 'No'),
              _buildDetailRow("Contract Document", client['contract_document']),
              _buildDetailRow("NDA Document", client['nda_document']),
              _buildDetailRow("MSA Document", client['msa_document']),
            ]),

            // --- BILLING CONFIG ---
            _buildSection("Billing Configuration", [
              _buildDetailRow("Hourly Rate", client['hourly_rate'] != null ? "₹${client['hourly_rate']}" : null),
              _buildDetailRow("Discount", client['discount_percentage'] != null ? "${client['discount_percentage']}%" : null),
              _buildDetailRow("Late Fee", client['late_fee_percentage'] != null ? "${client['late_fee_percentage']}%" : null),
            ]),

            // --- DEVELOPER TOOLS & INTEGRATION ---
            _buildSection("Developer Tools", [
              _buildDetailRow("Git Provider", client['git_provider']),
              _buildDetailRow("Repository URL", client['repo_url']),
              _buildDetailRow("API Key", client['api_key']),
              _buildDetailRow("Cloud Provider", client['server_provider']),
              _buildDetailRow("Dashboard URL", client['dashboard_url']),
            ]),

            // --- NOTES ---
            if ((client['notes'] ?? '').toString().isNotEmpty)
              _buildSection("Additional Notes", [
                Text(client['notes'], style: const TextStyle(color: AppColors.textWhite, fontSize: 13)),
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
      padding: const EdgeInsets.only(bottom: 10.0),
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
// EDIT CLIENT SCREEN (Unchanged)
// ==========================================

class EditClientScreen extends StatefulWidget {
  final Map<String, dynamic> client;
  final Function(Map<String, dynamic>) onSave;

  const EditClientScreen({Key? key, required this.client, required this.onSave}) : super(key: key);

  @override
  State<EditClientScreen> createState() => _EditClientScreenState();
}

class _EditClientScreenState extends State<EditClientScreen> with SingleTickerProviderStateMixin {
  late TextEditingController companyNameCtrl;
  late TextEditingController websiteCtrl;
  late TextEditingController gstCtrl;
  late TextEditingController clientSinceCtrl;
  String industry = 'IT / Software';
  String clientType = 'Enterprise';
  String status = 'Active';
  String rating = '5.0';

  late TextEditingController priNameCtrl;
  late TextEditingController priRoleCtrl;
  late TextEditingController priEmailCtrl;
  late TextEditingController priPhoneCtrl;
  late TextEditingController priWaCtrl;
  late TextEditingController priLinkedinCtrl;
  late TextEditingController secNameCtrl;
  late TextEditingController secRoleCtrl;
  late TextEditingController secEmailCtrl;
  late TextEditingController secPhoneCtrl;

  late TextEditingController contractValueCtrl;
  late TextEditingController startDateCtrl;
  late TextEditingController endDateCtrl;
  late TextEditingController renewalDateCtrl;
  String contractType = 'Fixed Price';
  String paymentTerms = 'Net 15';
  bool autoRenew = false;

  File? _contractDocument;
  File? _ndaDocument;
  File? _msaDocument;
  String? _existingContractDoc;
  String? _existingNdaDoc;
  String? _existingMsaDoc;

  late TextEditingController hourlyRateCtrl;
  late TextEditingController discountCtrl;
  late TextEditingController lateFeeCtrl;

  late TextEditingController repoUrlCtrl;
  late TextEditingController apiKeyCtrl;
  late TextEditingController dashUrlCtrl;
  late TextEditingController notesCtrl;
  String gitProvider = 'GitHub';
  String serverProvider = 'AWS';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    final c = widget.client;

    companyNameCtrl = TextEditingController(text: c['company_name'] ?? '');
    websiteCtrl = TextEditingController(text: c['website'] ?? '');
    gstCtrl = TextEditingController(text: c['gst_pan'] ?? '');
    clientSinceCtrl = TextEditingController(text: c['client_since'] ?? '');
    industry = _safeStr(c['industry'], 'IT / Software');
    clientType = _safeStr(c['client_type'], 'Enterprise');
    status = _safeStr(c['status'], 'Active');
    rating = _safeStr(c['rating'], '5.0');

    priNameCtrl = TextEditingController(text: c['primary_contact_name'] ?? '');
    priRoleCtrl = TextEditingController(text: c['primary_contact_role'] ?? '');
    priEmailCtrl = TextEditingController(text: c['primary_contact_email'] ?? '');
    priPhoneCtrl = TextEditingController(text: c['primary_contact_phone'] ?? '');
    priWaCtrl = TextEditingController(text: c['primary_contact_whatsapp'] ?? '');
    priLinkedinCtrl = TextEditingController(text: c['primary_contact_linkedin'] ?? '');
    secNameCtrl = TextEditingController(text: c['secondary_contact_name'] ?? '');
    secRoleCtrl = TextEditingController(text: c['secondary_contact_role'] ?? '');
    secEmailCtrl = TextEditingController(text: c['secondary_contact_email'] ?? '');
    secPhoneCtrl = TextEditingController(text: c['secondary_contact_phone'] ?? '');

    contractValueCtrl = TextEditingController(text: c['contract_value']?.toString() ?? '');
    startDateCtrl = TextEditingController(text: c['contract_start_date'] ?? '');
    endDateCtrl = TextEditingController(text: c['contract_end_date'] ?? '');
    renewalDateCtrl = TextEditingController(text: c['renewal_date'] ?? '');
    contractType = _safeStr(c['contract_type'], 'Fixed Price');
    paymentTerms = _safeStr(c['payment_terms'], 'Net 15');
    autoRenew = c['auto_renew']?.toString() == '1';

    hourlyRateCtrl = TextEditingController(text: c['hourly_rate']?.toString() ?? '');
    discountCtrl = TextEditingController(text: c['discount_percentage']?.toString() ?? '');
    lateFeeCtrl = TextEditingController(text: c['late_fee_percentage']?.toString() ?? '');

    repoUrlCtrl = TextEditingController(text: c['repo_url'] ?? '');
    apiKeyCtrl = TextEditingController(text: c['api_key'] ?? '');
    dashUrlCtrl = TextEditingController(text: c['dashboard_url'] ?? '');
    notesCtrl = TextEditingController(text: c['notes'] ?? '');
    gitProvider = _safeStr(c['git_provider'], 'GitHub');
    serverProvider = _safeStr(c['server_provider'], 'AWS');

    _existingContractDoc = c['contract_document'] ?? '';
    _existingNdaDoc = c['nda_document'] ?? '';
    _existingMsaDoc = c['msa_document'] ?? '';
  }

  String _safeStr(dynamic value, String fallback) {
    if (value == null || value.toString().isEmpty) return fallback;
    String str = value.toString();
    if (str == 'it') return 'IT / Software';
    if (str == 'finance') return 'Fintech';
    if (str == 'healthcare') return 'Healthcare';
    if (str == 'retail') return 'Ecommerce';
    if (str == 'enterprise') return 'Enterprise';
    if (str == 'mid_size') return 'Midsize Business';
    if (str == 'startup') return 'Startup';
    if (str == 'individual') return 'Government';
    if (str == 'fixed_price') return 'Fixed Price';
    if (str == 'time_material') return 'Time & Material';
    if (str == 'retainer') return 'Retainer';
    if (str == 'net_15') return 'Net 15';
    if (str == 'net_30') return 'Net 30';
    if (str == 'net_45') return 'Net 45';
    if (str == 'due_on_receipt') return 'Due on Receipt';
    return str;
  }

  String _mapToApiValue(String value) {
    if (value == 'IT / Software') return 'it';
    if (value == 'Fintech') return 'finance';
    if (value == 'Healthcare') return 'healthcare';
    if (value == 'Ecommerce') return 'retail';
    if (value == 'Enterprise') return 'enterprise';
    if (value == 'Midsize Business') return 'mid_size';
    if (value == 'Startup') return 'startup';
    if (value == 'Government') return 'individual';
    if (value == 'Fixed Price') return 'fixed_price';
    if (value == 'Time & Material') return 'time_material';
    if (value == 'Retainer') return 'retainer';
    if (value == 'Net 15') return 'net_15';
    if (value == 'Net 30') return 'net_30';
    if (value == 'Net 45') return 'net_45';
    if (value == 'Due on Receipt') return 'due_on_receipt';
    if (value == 'GitHub') return 'github';
    if (value == 'GitLab') return 'gitlab';
    if (value == 'Bitbucket') return 'bitbucket';
    if (value == 'AWS') return 'aws';
    if (value == 'Azure') return 'azure';
    if (value == 'GCP') return 'gcp';
    if (value == 'DigitalOcean') return 'digitalocean';
    return value.toLowerCase();
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

  void _submitForm() {
    Map<String, dynamic> payload = {
      'company_name': companyNameCtrl.text.trim(),
      'website': websiteCtrl.text.trim(),
      'gst_pan': gstCtrl.text.trim(),
      'client_since': clientSinceCtrl.text.trim(),
      'industry': _mapToApiValue(industry),
      'client_type': _mapToApiValue(clientType),
      'status': status.toLowerCase(),
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
      'contract_type': _mapToApiValue(contractType),
      'payment_terms': _mapToApiValue(paymentTerms),
      'auto_renew': autoRenew ? '1' : '0',

      'hourly_rate': hourlyRateCtrl.text.trim(),
      'discount_percentage': discountCtrl.text.trim(),
      'late_fee_percentage': lateFeeCtrl.text.trim(),

      'repo_url': repoUrlCtrl.text.trim(),
      'api_key': apiKeyCtrl.text.trim(),
      'dashboard_url': dashUrlCtrl.text.trim(),
      'notes': notesCtrl.text.trim(),
      'git_provider': _mapToApiValue(gitProvider),
      'server_provider': _mapToApiValue(serverProvider),

      'contract_document': _contractDocument != null
          ? _contractDocument!.path.split('/').last
          : (_existingContractDoc ?? ''),
      'nda_document': _ndaDocument != null
          ? _ndaDocument!.path.split('/').last
          : (_existingNdaDoc ?? ''),
      'msa_document': _msaDocument != null
          ? _msaDocument!.path.split('/').last
          : (_existingMsaDoc ?? ''),
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
        title: const Text("Edit Client Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submitForm,
                child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            _buildTextField("Client Since (YYYY-MM-DD)", clientSinceCtrl, isDate: true),
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
          _sectionHeader("Secondary Contact (Optional)", Icons.person_outline),
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
            _buildTextField("Renewal Date", renewalDateCtrl, isDate: true),
          ]),
          const SizedBox(height: 20),
          _buildTextFieldRow([
            _buildTextField("Contract Start Date", startDateCtrl, isDate: true),
            _buildTextField("Contract End Date", endDateCtrl, isDate: true),
          ]),
          const SizedBox(height: 16),
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
                const Expanded(
                  child: Text("Auto-renew contract",
                      style: TextStyle(color: AppColors.textWhite, fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader("Contract Documents", Icons.attach_file),
          const SizedBox(height: 16),
          _buildDocumentPicker("Contract Document", _contractDocument, 'contract', existingFile: _existingContractDoc),
          const SizedBox(height: 16),
          _buildDocumentPicker("NDA Document", _ndaDocument, 'nda', existingFile: _existingNdaDoc),
          const SizedBox(height: 16),
          _buildDocumentPicker("MSA Document", _msaDocument, 'msa', existingFile: _existingMsaDoc),
        ],
      ),
    );
  }

  Widget _buildDocumentPicker(String title, File? document, String type, {String? existingFile}) {
    String displayName = '';
    if (document != null) {
      displayName = document.path.split('/').last;
    } else if (existingFile != null && existingFile.isNotEmpty) {
      displayName = existingFile;
    }

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
                    displayName.isNotEmpty ? displayName : "No file chosen",
                    style: TextStyle(
                      color: displayName.isNotEmpty ? AppColors.accentCyan : AppColors.textMuted,
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
            _buildTextField("Hourly Rate (₹)", hourlyRateCtrl, isNumber: true),
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
            decoration: _inputDeco("Additional Notes").copyWith(alignLabelWithHint: true),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentCyan, size: 22),
        const SizedBox(width: 12),
        Flexible(
          child: Text(title,
              style: const TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 18),
              overflow: TextOverflow.ellipsis),
        ),
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
            Flexible(
              child: Text(label,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
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