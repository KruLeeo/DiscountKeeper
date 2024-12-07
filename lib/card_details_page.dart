import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CardDetailsPage extends StatefulWidget {
  final String cardId; // Передаём cardId документа из Firestore

  const CardDetailsPage({super.key, required this.cardId});

  @override
  _CardDetailsPageState createState() => _CardDetailsPageState();
}

class _CardDetailsPageState extends State<CardDetailsPage> {
  String cardName = '';
  String selectedCategory = 'Продукты питания'; // Default category
  String frontImageUrl = '';
  String backImageUrl = '';
  final List<String> categories = [
    'Продукты питания',
    'Одежда и обувь',
    'Косметика и парфюмерия',
    'Электроника',
    'Автозапчасти и услуги',
    'Спорт и активный отдых',
    'Кафе и рестораны',
    'Медицинские услуги',
    'Развлечения и досуг',
    'Туризм и путешествия'
  ];

  TextEditingController _cardNameController = TextEditingController();

  Future<DocumentSnapshot> _getCardData() async {
    if (widget.cardId.isEmpty) {
      throw Exception('Ошибка: cardId пустой! Передайте корректный идентификатор карты.');
    }
    return await FirebaseFirestore.instance.collection('cards').doc(widget.cardId).get();
  }

  Future<void> _updateCardData() async {
    try {
      // Обновляем данные в Firestore
      await FirebaseFirestore.instance.collection('cards').doc(widget.cardId).update({
        'cardName': cardName,
        'category': selectedCategory,
        'frontImageUrl': frontImageUrl,
        'backImageUrl': backImageUrl,
      });

      // После успешного обновления данных перезагружаем данные карты
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные карты успешно обновлены')),
      );
    } catch (e) {
      print('Ошибка при обновлении данных карты: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при обновлении данных карты')),
      );
    }
  }

  Future<String> _uploadImage(File image, String side, String email) async {
    try {
      // Формируем имя файла в нужном формате
      String fileName = '${email}_${side}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Загружаем файл в Firebase Storage с уникальным именем
      Reference storageReference = FirebaseStorage.instance.ref().child('card_images/$fileName');
      UploadTask uploadTask = storageReference.putFile(image);

      // Получаем URL загруженного изображения
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Удаляем старое изображение, если оно существует
      await _deleteOldImage(side);

      return downloadUrl;
    } catch (e) {
      print('Ошибка загрузки изображения: $e');
      throw Exception('Ошибка загрузки изображения в Firebase Storage');
    }
  }

  Future<void> _deleteOldImage(String side) async {
    try {
      // Если уже есть изображение, удаляем его из Firebase Storage
      String oldImageUrl = side == 'front' ? frontImageUrl : backImageUrl;
      if (oldImageUrl.isNotEmpty) {
        Reference storageReference = FirebaseStorage.instance.refFromURL(oldImageUrl);
        await storageReference.delete();
      }
    } catch (e) {
      print('Ошибка при удалении старого изображения: $e');
    }
  }

  // Функция для выбора источника изображения
  Future<void> _pickImage(String side, String email) async {
    final picker = ImagePicker();
    // Показываем диалог для выбора источника (камера или галерея)
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black, // Черный фон для диалога
          title: const Text(
            'Выберите источник изображения',
            style: TextStyle(color: Colors.white), // Белый текст заголовка
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, ImageSource.camera); // Камера
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB9F240), // Цвет кнопки
              ),
              child: const Text('Камера'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, ImageSource.gallery); // Галерея
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB9F240), // Цвет кнопки
              ),
              child: const Text('Галерея'),
            ),
          ],
        );
      },
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);

        String downloadUrl = await _uploadImage(imageFile, side, email);

        setState(() {
          if (side == 'front') {
            frontImageUrl = downloadUrl;
          } else {
            backImageUrl = downloadUrl;
          }
        });

        _updateCardData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали карты'),
        backgroundColor: Colors.black,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _getCardData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Карта не найдена',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // Данные карты
          var cardData = snapshot.data!.data() as Map<String, dynamic>;
          cardName = cardData['cardName'] ?? 'Без названия';
          frontImageUrl = cardData['frontImageUrl'] ?? '';
          backImageUrl = cardData['backImageUrl'] ?? '';
          selectedCategory = cardData['category'] ?? 'Категория не указана';

          // Устанавливаем значение в контроллер при загрузке данных
          _cardNameController.text = cardName;

          return SingleChildScrollView(
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Отображение лицевой стороны карты
                  GestureDetector(
                    onTap: () {
                      _pickImage('front', 'user@example.com');  // Передайте правильный email
                    },
                    child: Container(
                      width: 300,
                      height: 200,
                      margin: const EdgeInsets.only(top: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: frontImageUrl.isNotEmpty
                              ? NetworkImage(frontImageUrl)
                              : const AssetImage('assets/images/placeholder.png') as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Отображение задней стороны карты
                  GestureDetector(
                    onTap: () {
                      _pickImage('back', 'user@example.com');  // Передайте правильный email
                    },
                    child: Container(
                      width: 300,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: backImageUrl.isNotEmpty
                              ? NetworkImage(backImageUrl)
                              : const AssetImage('assets/images/placeholder.png') as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Поле для редактирования названия карты
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _cardNameController,
                      decoration: const InputDecoration(
                        labelText: 'Название карты',
                        labelStyle: TextStyle(color: Colors.white),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) {
                        cardName = value; // Обновляем только в переменной
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Выпадающий список для выбора категории
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      icon: const Icon(Icons.arrow_downward, color: Colors.white),
                      dropdownColor: Colors.black,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedCategory = newValue!;
                        });
                      },
                      items: categories.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Кнопка для сохранения изменений
                  ElevatedButton(
                    onPressed: _updateCardData,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), // Добавляем отступы
                      backgroundColor: const Color(0xFFB9F240), // Цвет фона
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25), // Закругление углов
                      ),
                    ),
                    child: const Text(
                      'Сохранить изменения',
                      style: TextStyle(
                        color: Colors.black, // Цвет текста
                        fontFamily: 'Montserrat', // Шрифт
                        fontWeight: FontWeight.bold, // Жирный шрифт
                        fontSize: 16, // Размер шрифта
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
      backgroundColor: Colors.black,
    );
  }
}
