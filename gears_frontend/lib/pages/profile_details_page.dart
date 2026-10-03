import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../theme/app_theme.dart';

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({super.key});

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  String? selectedGender;

  final List<String> genders = ["Male", "Female", "Other"];
  final maskDobFormatter = MaskTextInputFormatter(
    mask: '####-##-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      firstNameController.text = prefs.getString("first_name") ?? "";
      middleNameController.text = prefs.getString("middle_name") ?? "";
      lastNameController.text = prefs.getString("last_name") ?? "";
      emailController.text = prefs.getString("email") ?? "";
      dobController.text = prefs.getString("birthday") ?? "";
      selectedGender = prefs.getString("gender") ?? "Male";
    });
  }

  Future<void> _saveProfile() async {
    if (firstNameController.text.isEmpty ||
        lastNameController.text.isEmpty ||
        emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all required fields.")),
      );
      return;
    }

    setState(() => isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("first_name", firstNameController.text.trim());
    await prefs.setString("middle_name", middleNameController.text.trim());
    await prefs.setString("last_name", lastNameController.text.trim());
    await prefs.setString("email", emailController.text.trim());
    await prefs.setString("birthday", dobController.text.trim());
    await prefs.setString("gender", selectedGender ?? "Male");
    await prefs.setString(
        "name",
        "${firstNameController.text} "
        "${middleNameController.text.isNotEmpty ? middleNameController.text[0] + '.' : ''} "
        "${lastNameController.text}");

    await Future.delayed(const Duration(milliseconds: 700)); // Simulate smooth save

    if (!mounted) return;
    setState(() => isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile updated successfully!")),
    );
    Navigator.pop(context);
  }

  InputDecoration _inputDecoration(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2),
      ),
      labelStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.titleGradient,
          ),
        ),
        title: Text(
          "Edit Profile",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                "Update Your Information",
                style: GoogleFonts.hedvigLettersSerif(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: firstNameController,
                decoration: _inputDecoration("First Name"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: middleNameController,
                decoration: _inputDecoration("Middle Name"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastNameController,
                decoration: _inputDecoration("Last Name"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dobController,
                keyboardType: TextInputType.number,
                inputFormatters: [maskDobFormatter],
                decoration: _inputDecoration("Date of Birth (yyyy-mm-dd)"),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedGender,
                items: genders
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => selectedGender = v),
                decoration: _inputDecoration("Gender"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration("Email"),
              ),
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF9A825), Color(0xFFF44336)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              "Save Changes",
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
  