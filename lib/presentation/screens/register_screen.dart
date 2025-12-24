import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordRepeatController = TextEditingController();
  late final MaskTextInputFormatter _phoneMaskFormatter;
  bool _obscurePass = true;
  bool _obscurePassRepeat = true;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _phoneMaskFormatter = MaskTextInputFormatter(
      mask: '+# (###) ###-##-##',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordRepeatController.dispose();
    super.dispose();
  }

  bool _validatePassword(String value) {
    final hasMinLength = value.length >= 8;
    final hasLetter = value.contains(RegExp(r'[A-Za-zА-Яа-я]'));
    final hasDigit = value.contains(RegExp(r'\d'));
    return hasMinLength && hasLetter && hasDigit;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    final emailReg = RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}');
    if (!emailReg.hasMatch(value)) {
      return 'Неверный формат Email';
    }
    return null;
  }

  String? _passValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Пароль обязателен';
    }
    if (!_validatePassword(value)) {
      return 'Минимум 8 символов, минимум 1 буква и 1 цифра';
    }
    return null;
  }

  String? _repeatValidator(String? value) {
    if (value != _passwordController.text) {
      return 'Пароли не совпадают';
    }
    return null;
  }

  String? _fullNameValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    return null;
  }


  String? _addressValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    return null;
  }

  Future<void> _onRegister(BuildContext context) async {
    setState(() => _formError = null);

    // Проверяем валидацию формы
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }
    final auth = context.read<AuthProvider>();
    try {
      final email = _emailController.text.trim();
      final pass = _passwordController.text;

      if (email == 'admin@admin.ru' && pass == 'admin') {
        await auth.login(email, pass);
        if (mounted) Navigator.of(context).pop();
        return;
      }

      await auth.registerClient(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        email: email,
        password: pass,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      var message = e.toString();
      if (message.startsWith('Exception: ')) {
        message = message.substring('Exception: '.length);
      }
      setState(() => _formError = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'ФИО'),
                validator: _fullNameValidator,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  hintText: '+X (XXX) XXX-XX-XX',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Телефон обязателен';
                  }

                  // Проверяем что введены только цифры и допустимые символы
                  final phoneRegex = RegExp(r'^[\d\s\-\+\(\)]+$');
                  if (!phoneRegex.hasMatch(value.trim())) {
                    return 'Телефон должен содержать только цифры';
                  }

                  // Проверяем минимальную длину (без учета форматирования)
                  final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (digitsOnly.length < 10) {
                    return 'Введите полный номер телефона (минимум 10 цифр)';
                  }

                  return null;
                },
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  _phoneMaskFormatter,
                ],
                onChanged: (text) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Адрес'),
                validator: _addressValidator,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: _emailValidator,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                validator: _passValidator,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordRepeatController,
                obscureText: _obscurePassRepeat,
                decoration: InputDecoration(
                  labelText: 'Повтор пароля',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassRepeat ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassRepeat = !_obscurePassRepeat),
                  ),
                ),
                validator: _repeatValidator,
              ),
              if (_formError != null) ...[
                const SizedBox(height: 8),
                Text(_formError!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _onRegister(context),
                child: const Text('Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}