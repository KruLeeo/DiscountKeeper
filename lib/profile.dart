import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Logger _logger = Logger('ProfilePage');
  final TextEditingController _nicknameController = TextEditingController();
  String email = '';
  String creationDate = '';
  String nickname = '';
  String profileImageUrl = '';
  int userBonus = 0; // Новое поле для отображения бонусов
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  int selectedIndex = 2;

  double profileFieldSpacing = 25.0;
  double actionButtonSpacing = 20.0;
  double topPadding = 40.0;
  double profileFieldHeight = 37.0; // Высота полей профиля

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        email = user.email ?? '';
        creationDate = user.metadata.creationTime?.toLocal().toString().split(' ')[0] ?? 'Неизвестно';
      });

      // Загружаем данные из Firebase каждый раз при входе
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('customers').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          nickname = data['cusname'] ?? '';
          profileImageUrl = data['profileimg'] ?? '';
          userBonus = data['bonus'] ?? 0; // Загружаем бонусы
          _nicknameController.text = nickname;
        });
        // Сохраняем данные локально
        await _saveLocalData(nickname, profileImageUrl, userBonus);
      } else {
        // Если данные не существуют, очищаем локальные данные
        setState(() {
          nickname = '';
          profileImageUrl = '';
          userBonus = 0;
          _nicknameController.clear();
        });
      }
    }
  }

  Future<void> _saveLocalData(String nickname, String profileImageUrl, int bonus) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', nickname);
    await prefs.setString('profileImageUrl', profileImageUrl);
    await prefs.setInt('userBonus', bonus);
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nickname = prefs.getString('nickname') ?? '';
      profileImageUrl = prefs.getString('profileImageUrl') ?? '';
      userBonus = prefs.getInt('userBonus') ?? 0;
    });
  }

  Future<void> _saveProfile() async {
    String nickname = _nicknameController.text;

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        String? imageUrl;
        if (_selectedImage != null) {
          imageUrl = await _uploadImage(_selectedImage!);
        }

        await FirebaseFirestore.instance.collection('customers').doc(user.uid).set({
          'cusname': nickname,
          'profileimg': imageUrl ?? profileImageUrl,
          'bonus': userBonus, // Сохраняем бонусы
        }, SetOptions(merge: true));

        // Сохраняем локально
        await _saveLocalData(nickname, imageUrl ?? profileImageUrl, userBonus);

        _logger.info('Профиль успешно сохранен');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль сохранен')),
        );
      } catch (e) {
        _logger.severe('Ошибка при сохранении профиля: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  // Метод для увеличения бонусов
  Future<void> _increaseBonus(int value) async {
    setState(() {
      userBonus += value; // Увеличиваем локально
    });

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Обновляем в Firestore
        await FirebaseFirestore.instance.collection('customers').doc(user.uid).update({
          'bonus': userBonus,
        });

        // Сохраняем локально
        await _saveLocalData(nickname, profileImageUrl, userBonus);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Бонусы обновлены')),
        );
      } catch (e) {
        _logger.severe('Ошибка при обновлении бонусов: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final ref = FirebaseStorage.instance.ref().child('profile_images').child('${user.uid}.jpg');
        await ref.putFile(image);
        return await ref.getDownloadURL();
      }
    } catch (e) {
      _logger.severe('Ошибка при загрузке изображения: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при загрузке изображения: $e')),
      );
    }
    return null;
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Черный фон для всего экрана
      body: SingleChildScrollView( // Добавлено для прокрутки
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // Отступ слева для выравнивания
                  // Кнопка выхода
                  IconButton(
                    icon: const Icon(Icons.logout, color: Color(0xFFB9F240)),
                    onPressed: _signOut,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20), // Дополнительный отступ
            // Надпись DiscountKeeper
            RichText(
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
            const SizedBox(height: 20), // Дополнительный отступ
            SizedBox(
              height: 120,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Профиль, ',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            TextSpan(
                              text: nickname, // Никнейм пользователя
                              style: const TextStyle(
                                color: Color(0xFFB9F240), // Цвет никнейма
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Здесь вы можете управлять своим аккаунтом.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProfileImage(),
                  SizedBox(height: profileFieldSpacing),
                  _buildProfileField('Ваша почта', email),
                  SizedBox(height: profileFieldSpacing),
                  _buildProfileField('Дата создания аккаунта', creationDate),
                  SizedBox(height: profileFieldSpacing),
                  _buildNicknameField(),
                ],
              ),
            ),
            const SizedBox(height: 30), // Отступ для визуального разделения
            // Поле отображения бонусов
            Text(
              'Ваши бонусы: $userBonus',
              style: const TextStyle(
                color: Color(0xFFB9F240),
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 20), // Дополнительный отступ
            // Добавляем кнопки для изменения бонусов

            SizedBox(height: actionButtonSpacing),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _pickImage,
      child: CircleAvatar(
        radius: 75,
        backgroundImage: _selectedImage != null
            ? FileImage(_selectedImage!)
            : (profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null) as ImageProvider<Object>?,
        child: _selectedImage == null && profileImageUrl.isEmpty
            ? const Icon(Icons.camera_alt, size: 40, color: Colors.white70)
            : null,
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(
          height: profileFieldHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w500,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNicknameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ваш никнейм',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(
          height: profileFieldHeight,
          child: TextField(
            controller: _nicknameController,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w500,
              fontSize: 18,
            ),
            decoration: const InputDecoration(
              hintText: 'Введите ваш никнейм',
              hintStyle: TextStyle(
                color: Colors.white54,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFB9F240)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFB9F240)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveProfile,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        backgroundColor: const Color(0xFFB9F240),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: const Text(
        'Сохранить изменения',
        style: TextStyle(
          color: Colors.black,
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}