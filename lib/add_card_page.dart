import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';

class AddCardPage extends StatefulWidget {
  const AddCardPage({super.key});

  @override
  _AddCardPageState createState() => _AddCardPageState();
}

class _AddCardPageState extends State<AddCardPage> {
  final Logger _logger = Logger('AddCardPage');
  final ImagePicker _picker = ImagePicker();
  XFile? _frontImage;
  XFile? _backImage;
  final TextEditingController _cardNameController = TextEditingController();
  String? _selectedCategory;
  String nickname = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('customers').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          nickname = data['cusname'] ?? '';
        });
      }
    }
  }

  Future<void> _pickImage(bool isFront) async {
    final XFile? pickedImage = await _picker.pickImage(source: ImageSource.camera);
    if (pickedImage != null) {
      setState(() {
        if (isFront) {
          _frontImage = pickedImage;
        } else {
          _backImage = pickedImage;
        }
      });
    }
  }

  Future<void> _saveCard() async {
    if (_cardNameController.text.isEmpty || _selectedCategory == null || _frontImage == null || _backImage == null) {
      _showSnackBar('Пожалуйста, заполните все поля.');
      return;
    }

    try {
      String frontImageUrl = await _uploadImage(_frontImage!, 'front');
      String backImageUrl = await _uploadImage(_backImage!, 'back');

      // Получаем текущего пользователя
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null || user.email == null) {
        throw Exception('Пользователь не авторизован или email недоступен');
      }

      // Добавляем данные карты в Firestore, включая адрес электронной почты
      await FirebaseFirestore.instance.collection('cards').add({
        'cardName': _cardNameController.text,
        'category': _selectedCategory,
        'frontImageUrl': frontImageUrl,
        'backImageUrl': backImageUrl,
        'userEmail': user.email, // Добавляем адрес электронной почты
      });

      _showSnackBar('Карта успешно добавлена!');
      _clearFields();
    } catch (e) {
      _logger.severe('Ошибка при добавлении карты: $e');
      _showSnackBar('Ошибка при добавлении карты: $e');
    }
  }

  Future<String> _uploadImage(XFile image, String type) async {
    try {
      // Получаем текущего пользователя
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null || user.email == null) {
        throw Exception('Пользователь не авторизован или email недоступен');
      }

      // Используем email пользователя для формирования имени файла
      String email = user.email!.replaceAll('@', '_').replaceAll('.', '_');
      String fileName = '${email}_${type}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = FirebaseStorage.instance.ref().child('customercards').child(fileName);
      await ref.putFile(File(image.path));
      return await ref.getDownloadURL();
    } catch (e) {
      _logger.severe('Ошибка загрузки изображения: $e');
      throw Exception('Ошибка загрузки изображения');
    }
  }

  void _clearFields() {
    _cardNameController.clear();
    setState(() {
      _frontImage = null;
      _backImage = null;
      _selectedCategory = null;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Добавить карту',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFB9F240)),
      ),
      body: Container(
        // Solid black background
        width: double.infinity,
        height: double.infinity,
        color: Colors.black, // Changed to a solid black color
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildTextSection('Сканируйте лицевую сторону карты'),
                GestureDetector(
                  onTap: () => _pickImage(true),
                  child: _buildImageContainer(_frontImage),
                ),
                const SizedBox(height: 20),
                _buildTextSection('Сканируйте обратную сторону карты'),
                GestureDetector(
                  onTap: () => _pickImage(false),
                  child: _buildImageContainer(_backImage),
                ),
                const SizedBox(height: 20),
                _buildTextField('Название карты', _cardNameController),
                const SizedBox(height: 20),
                _buildDropdownField(),
                const SizedBox(height: 20),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
      resizeToAvoidBottomInset: false, // Move this parameter here
    );
  }

  Widget _buildTextSection(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildImageContainer(XFile? image) {
    return Container(
      width: 300,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        image: image != null ? DecorationImage(
          image: FileImage(File(image.path)),
          fit: BoxFit.cover,
        ) : null,
        border: Border.all(color: Colors.grey),
      ),
      child: image == null
          ? const Center(child: Icon(Icons.camera_alt, color: Colors.grey))
          : null,
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        border: const OutlineInputBorder(),
        fillColor: const Color(0xFF2C2C2C),
        filled: true,
      ),
    );
  }

  Widget _buildDropdownField() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Категория',
        border: OutlineInputBorder(),
        fillColor: Color(0xFF2C2C2C),
        filled: true,
      ),
      value: _selectedCategory,
      items: <String>['Продукты питания', 'Одежда и обувь', 'Косметика и парфюмерия', 'Электроника', 'Автозапчасти и услуги', 'Спорт и активный отдых', 'Кафе и рестораны', 'Медицинские услуги', 'Развлечения и досуг', 'Туризм и путешествия'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, style: const TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedCategory = newValue;
        });
      },
      dropdownColor: const Color(0xFF1A1A1A),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero, // Убрали все внутренние отступы
      margin: EdgeInsets.zero,  // Убрали внешние отступы
      child: ElevatedButton(
        onPressed: _saveCard,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB9F240),
          padding: const EdgeInsets.symmetric(vertical: 12), // Контролируем padding
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Center(
          child: Text('Сохранить карту', style: TextStyle(color: Colors.black)),
        ),
      ),
    );
  }
}