import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../core/constants/app_strings.dart';
import '../providers/auth_provider.dart';
import '../../domain/entities/user.dart';
import '../utils/russian_phone_operator.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  late final MaskTextInputFormatter _phoneMaskFormatter;
  UserRole? _role;
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneMaskFormatter = MaskTextInputFormatter(
      mask: '+7 (###) ###-##-##',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );

    final auth = context.read<AuthProvider>();
    _role = auth.role;
    _fullNameController = TextEditingController(text: auth.fullName ?? "");
    _phoneController = TextEditingController(text: auth.phone ?? "");
    _addressController = TextEditingController(text: auth.address ?? "");
    _emailController = TextEditingController(text: auth.email ?? "");
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    try {
      await auth.updateAccount(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(AppStrings.changesSaved)));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_role == UserRole.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.editProfile)),
        body: const Center(child: Text(AppStrings.cannotEditAdmin)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.editProfile)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'ФИО'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final detectedOperator = detectRussianOperator(_phoneController.text);
                  return TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Телефон',
                      hintText: '+7 (000) 000-00-00',
                      suffixIcon: detectedOperator != null
                          ? Tooltip(
                              message: detectedOperator,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(detectedOperator,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                            )
                          : null,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Телефон обязателен';
                      }
                      // Проверяем что номер введен полностью в формате +7 (XXX) XXX-XX-XX
                      final phoneRegex = RegExp(r'^\+7 \(\d{3}\) \d{3}-\d{2}-\d{2}$');
                      if (!phoneRegex.hasMatch(value.trim())) {
                        return 'Укажите номер полностью +7 (000) 000-00-00';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      _phoneMaskFormatter,
                    ],
                    onChanged: (text) {
                      setState(() {});
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Адрес'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Обязательное поле';
                  final emailReg = RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}');
                  if (!emailReg.hasMatch(v)) return 'Неверный формат Email';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'Новый пароль (необязательно)',
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final hasMinLength = v.length >= 8;
                    final hasLetter = v.contains(RegExp(r'[A-Za-zА-Яа-я]'));
                    final hasDigit = v.contains(RegExp(r'\d'));
                    if (!hasMinLength || !hasLetter || !hasDigit) {
                      return 'Минимум 8 символов, минимум 1 буква и 1 цифра';
                    }
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _onSave,
                child: const Text(AppStrings.saveChanges),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
