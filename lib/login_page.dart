import 'dart:convert'; // Для конвертации строки в байты
import 'package:crypto/crypto.dart'; // Для хеширования пароля
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoginMode = true; // Переменная для отслеживания режима (вход/регистрация)

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Метод для хеширования пароля
  String _hashPassword(String password) {
    var bytes = utf8.encode(password); // Преобразуем пароль в байты
    var digest = sha256.convert(bytes); // Хешируем с помощью SHA-256
    return digest.toString(); // Преобразуем хеш в строку
  }

  // Метод для проверки формата email
  bool _isEmailValid(String email) {
    String pattern = r'^[^@]+@[^@]+\.[^@]+';
    RegExp regex = RegExp(pattern);
    return regex.hasMatch(email);
  }

  Future<void> _submitLogin() async {
    String email = _loginController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar('Пожалуйста, введите email и пароль.');
      return;
    }

    if (!_isEmailValid(email)) {
      _showErrorSnackBar('Некорректный email.');
      return;
    }

    if (password.length < 6) {
      _showErrorSnackBar('Пароль должен содержать не менее 6 символов.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLoginMode) {
        // Выход из текущего аккаунта перед новой попыткой входа
        await FirebaseAuth.instance.signOut();
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Получаем роль пользователя
        await _checkUserRole();

      } else {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        String uid = userCredential.user?.uid ?? '';
        await _addUserToFirestore(email, _hashPassword(password), uid);

        Navigator.pushNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showErrorSnackBar('Пользователь не найден.');
      } else if (e.code == 'wrong-password') {
        _showErrorSnackBar('Неверный пароль.');
      } else if (e.code == 'email-already-in-use') {
        _showErrorSnackBar('Этот email уже используется.');
      } else {
        _showErrorSnackBar('Ошибка: ${e.message}');
      }
    } catch (e) {
      _showErrorSnackBar('Неизвестная ошибка: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Метод для добавления пользователя в Firestore
  Future<void> _addUserToFirestore(String email, String hashedPassword, String uid) async {
    CollectionReference customers = FirebaseFirestore.instance.collection('customers');

    try {
      // Добавляем нового пользователя с UID и ролью user
      await customers.doc(uid).set({
        'email': email,
        'hashedPassword': hashedPassword,
        'createdAt': FieldValue.serverTimestamp(), // Добавляем метку времени
        'role': 'user', // Изначально назначаем роль user
      });
    } catch (e) {
      _showErrorSnackBar('Ошибка при сохранении данных: ${e.toString()}');
    }
  }

  // Метод для проверки роли пользователя
  Future<void> _checkUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('customers').doc(user.uid).get();
      if (doc.exists) {
        String role = doc['role'];
        if (role == 'admin') {
          // Если админ - перенаправляем на админскую страницу
          Navigator.pushNamed(context, '/admin');
        } else {
          // Если не админ - на обычную страницу
          Navigator.pushNamed(context, '/home');
        }
      }
    }
  }

  // Показываем сообщение об ошибке
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Переключение между режимами входа и регистрации
  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            color: Colors.black, // Задний фон просто черный
          ),
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Discount',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w800,
                        fontSize: 43,
                        color: Color(0xFFB9F240),
                        shadows: [
                          Shadow(
                            offset: Offset(2, 2),
                            blurRadius: 10,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                    TextSpan(
                      text: 'Keeper',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w800,
                        fontSize: 43,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(2, 2),
                            blurRadius: 10,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    if (!isKeyboardVisible) ...[
                      Text(
                        _isLoginMode ? 'Введите логин и пароль' : 'Регистрация',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLoginMode ? 'чтобы войти' : 'чтобы создать аккаунт',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 32),
                    _buildTextField(_loginController, 'Логин (Email)'),
                    const SizedBox(height: 16),
                    _buildTextField(_passwordController, 'Пароль', obscureText: true),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        FocusScope.of(context).unfocus(); // Скрыть клавиатуру
                        _submitLogin();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: width * 0.85,
                        height: 53,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB9F240), Color(0xFFA9E020)], // Градиент для кнопки
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: const Offset(0, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.black)
                              : Text(
                            _isLoginMode ? 'Войти' : 'Регистрация',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _toggleMode,
                      child: Text(
                        _isLoginMode ? 'Создать аккаунт' : 'Уже есть аккаунт? Войти',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Метод для создания полей ввода
  Widget _buildTextField(TextEditingController controller, String hintText, {bool obscureText = false}) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: 53,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(172, 172, 172, 0.29),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Color.fromRGBO(172, 172, 172, 0.65),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}