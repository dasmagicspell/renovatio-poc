import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/contact_us_service.dart';
import '../services/user_profile_service.dart';

Future<void> showUpgradeContactDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const _UpgradeContactDialog(),
  );
}

class _UpgradeContactDialog extends StatefulWidget {
  const _UpgradeContactDialog();

  @override
  State<_UpgradeContactDialog> createState() => _UpgradeContactDialogState();
}

class _UpgradeContactDialogState extends State<_UpgradeContactDialog> {
  static const _primary = Color(0xFF2F6F65);
  static const _secondary = Color(0xFFB8A4D4);
  static const _surface = Color(0xFFEDEAE6);
  static const _textPrimary = Color(0xFF2F2F2F);
  static const _textSecondary = Color(0xFF7A7570);
  static const _textTertiary = Color(0xFFA09890);
  static const _border = Color(0xFFD9D0C8);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoadingProfile = true;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileService.getProfile();
    if (!mounted) return;

    setState(() {
      _nameController.text = profile.name;
      _companyController.text = profile.company;
      _emailController.text = profile.email;
      _isLoadingProfile = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final submission = ContactUsSubmission(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      company: _companyController.text.trim(),
    );

    try {
      await ContactUsService.submitUpgradeRequest(submission);

      final profile = UserProfile(
        name: submission.name,
        company: submission.company,
        email: submission.email,
      );
      await UserProfileService.saveProfile(profile);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks! We\'ll be in touch about upgrading.'),
          backgroundColor: _primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    bool isOptional = false,
  }) {
    final labelText = isRequired
        ? '$label *'
        : isOptional
            ? '$label (optional)'
            : label;

    return InputDecoration(
      labelText: labelText,
      hintText: hint,
      labelStyle: const TextStyle(color: _textSecondary),
      hintStyle: const TextStyle(color: _textTertiary),
      prefixIcon: Icon(icon, color: _textSecondary, size: 22),
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFF3E4D7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.mail_outline_rounded, color: _secondary, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Contact Us to Upgrade',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: _isLoadingProfile
          ? const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(color: _primary),
              ),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Share your details and we\'ll reach out about premium Bio Monitor access.',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '* Name and email are required',
                      style: TextStyle(
                        color: _textTertiary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: _fieldDecoration(
                        label: 'Name',
                        hint: 'Enter your full name',
                        icon: Icons.badge_outlined,
                        isRequired: true,
                      ),
                      style: const TextStyle(color: _textPrimary),
                      textCapitalization: TextCapitalization.words,
                      enabled: !_isSubmitting,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: _fieldDecoration(
                        label: 'Email Address',
                        hint: 'Enter your email address',
                        icon: Icons.email_outlined,
                        isRequired: true,
                      ),
                      style: const TextStyle(color: _textPrimary),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isSubmitting,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return 'Email is required';
                        }
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                        if (!emailRegex.hasMatch(email)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _companyController,
                      decoration: _fieldDecoration(
                        label: 'Company',
                        hint: 'Enter your company',
                        icon: Icons.business_outlined,
                        isOptional: true,
                      ),
                      style: const TextStyle(color: _textPrimary),
                      textCapitalization: TextCapitalization.words,
                      enabled: !_isSubmitting,
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _submitError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: _textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoadingProfile || _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _secondary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
