import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              color: Theme.of(context).primaryColor,
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                    ],
                  ),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white,
                    tabs: const [
                      Tab(text: 'Вход'),
                      Tab(text: 'Регистрация'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                LoginTab(),
                RegisterTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LoginTab extends StatefulWidget {
  const LoginTab({super.key});

  @override
  State<LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<LoginTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePass = true;
  String? _formError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email обязательный';
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
    return null;
  }

  Future<void> _onLogin(BuildContext context) async {
    setState(() => _formError = null);
    if (_formKey.currentState?.validate() != true) return;
    final auth = context.read<AuthProvider>();
    try {
      final email = _emailController.text.trim();
      final pass = _passwordController.text;
      await auth.login(email, pass);
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
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
            if (_formError != null) ...[
              const SizedBox(height: 8),
              Text(_formError!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _onLogin(context),
              child: const Text('Войти'),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterTab extends StatefulWidget {
  const RegisterTab({super.key});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordRepeatController = TextEditingController();
  bool _obscurePass = true;
  bool _obscurePassRepeat = true;
  String? _formError;

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
      return 'Email обязательный';
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
      return 'ФИО обязательно';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Телефон обязателен';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Только цифры';
    }
    return null;
  }

  String? _addressValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Адрес обязателен';
    }
    return null;
  }

  Future<void> _onRegister(BuildContext context) async {
    setState(() => _formError = null);
    if (_formKey.currentState?.validate() != true) return;
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'ФИО'),
              validator: _fullNameValidator,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Телефон'),
              validator: _phoneValidator,
              keyboardType: TextInputType.phone,
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
    );
  }
}

