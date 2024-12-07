import 'dart:convert'; // Для конвертации строки в байты
import 'package:crypto/crypto.dart'; // Для хеширования пароля
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController(); // Контроллер для подтверждения пароля
  bool _isLoading = false;
  bool _isLoginMode = true;
  bool _obscurePassword = true; // Переменная для отслеживания режима (вход/регистрация)
  bool _obscureConfirmPassword = true; // Переменная для скрытия/показа подтверждения пароля
  bool _isAgreementAccepted = false; // Переменная для отслеживания согласия с пользовательским соглашением

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // Очистка контроллера подтверждения пароля
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

  // Проверка совпадения паролей
  bool _arePasswordsMatching() {
    return _passwordController.text == _confirmPasswordController.text;
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

    // Проверка на совпадение паролей
    if (!_isLoginMode && !_arePasswordsMatching()) {
      _showErrorSnackBar('Пароли не совпадают.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLoginMode) {
        await FirebaseAuth.instance.signOut();
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        await _checkUserRole();
      } else {
        if (!_isAgreementAccepted) {
          _showErrorSnackBar('Пожалуйста, примите пользовательское соглашение.');
          return;
        }

        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
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
  Future<void> _addUserToFirestore(String email, String hashedPassword,
      String uid) async {
    CollectionReference customers = FirebaseFirestore.instance.collection(
        'customers');

    try {
      await customers.doc(uid).set({
        'email': email,
        'hashedPassword': hashedPassword,
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'user',
      });
    } catch (e) {
      _showErrorSnackBar('Ошибка при сохранении данных: ${e.toString()}');
    }
  }

  // Метод для проверки роли пользователя
  Future<void> _checkUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection(
          'customers').doc(user.uid).get();
      if (doc.exists) {
        String role = doc['role'];
        if (role == 'admin') {
          Navigator.pushNamed(context, '/admin');
        } else {
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

  // Метод для вызова диалога восстановления пароля
  Future<void> _showPasswordResetDialog() async {
    TextEditingController emailController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black, // Черный фон
          title: const Text(
            'Восстановление пароля',
            style: TextStyle(
              color: Colors.white, // Белый цвет текста заголовка
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(
              hintText: 'Введите ваш email',
              hintStyle: TextStyle(color: Colors
                  .white54), // Полупрозрачный белый цвет для подсказки
            ),
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white), // Белый текст
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB9F240), // Цвет текста кнопки
              ),
              child: const Text('Отмена'),
              onPressed: () {
                Navigator.of(context).pop(); // Закрываем диалоговое окно
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB9F240), // Цвет текста кнопки
              ),
              child: const Text('Отправить'),
              onPressed: () async {
                String email = emailController.text.trim();
                if (email.isEmpty || !_isEmailValid(email)) {
                  _showErrorSnackBar('Введите корректный email.');
                  return;
                }

                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                      email: email);
                  Navigator.of(context).pop(); // Закрываем диалоговое окно
                  _showErrorSnackBar(
                      'Инструкции по восстановлению пароля отправлены на $email.');
                } catch (e) {
                  Navigator.of(context).pop(); // Закрываем диалоговое окно
                  _showErrorSnackBar(
                      'Ошибка при отправке письма: ${e.toString()}');
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // Отключаем сдвиг содержимого при появлении клавиатуры
      body: Stack(
        children: [
          Container(
            color: Colors.black,
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
          Positioned(
            top: 200,
            left: 20,
            right: 20,
            child: SingleChildScrollView(
              reverse: true,
              child: Column(
                children: [
                  // Заголовок страницы
                  Text(
                    _isLoginMode ? 'Авторизация' : 'Регистрация',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Color(0xFFB9F240),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Поле ввода email
                  TextField(
                    controller: _loginController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),

                  // Поле ввода пароля
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      labelStyle: const TextStyle(color: Colors.white),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),

                  // Поле ввода подтверждения пароля (только для регистрации)
                  if (!_isLoginMode) ...[
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Подтверждение пароля',
                        labelStyle: const TextStyle(color: Colors.white),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),

                    // Чекбокс согласия с пользовательским соглашением
                    Row(
                      children: [
                        Checkbox(
                          value: _isAgreementAccepted,
                          onChanged: (bool? value) {
                            setState(() {
                              _isAgreementAccepted = value ?? false;
                            });
                          },
                          activeColor: const Color(0xFFB9F240),
                        ),
                        // Внутри вашего Expanded
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Я согласен с ',
                                  style: TextStyle(color: Colors.white),
                                ),
                                TextSpan(
                                  text: 'пользовательским соглашением',
                                  style: const TextStyle(color: Colors.blue), // Цвет текста ссылки
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () async {
                                      // Открываем ссылку на пользовательское соглашение
                                      const url = 'https://vk.com/nyankrultepes'; // Укажите здесь свою ссылку
                                      final Uri uri = Uri.parse(url); // Преобразуем строку в Uri

                                      try {
                                        // Проверяем, можно ли открыть URL
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri); // Открываем ссылку
                                        } else {
                                          print('Не удалось открыть ссылку');
                                          _showErrorSnackBar('Не удалось открыть ссылку.');
                                        }
                                      } catch (e) {
                                        print('Ошибка при попытке открыть ссылку: $e');
                                        _showErrorSnackBar('Ошибка при открытии ссылки: $e');
                                      }
                                    },
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Кнопка отправки формы
                  _isLoading
                      ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFB9F240)),
                  )
                      : ElevatedButton(
                    onPressed: _submitLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB9F240),
                    ),
                    child: Text(_isLoginMode ? 'Войти' : 'Зарегистрироваться'),
                  ),
                  const SizedBox(height: 20),

                  // Ссылки на переключение между режимами
                  TextButton(
                    onPressed: _toggleMode,
                    child: Text(
                      _isLoginMode
                          ? 'Не зарегистрированы? Регистрация'
                          : 'Уже есть аккаунт? Вход',
                      style: const TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  if (_isLoginMode) ...[
                    TextButton(
                      onPressed: _showPasswordResetDialog,
                      child: const Text(
                        'Забыли пароль?',
                        style: TextStyle(
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
