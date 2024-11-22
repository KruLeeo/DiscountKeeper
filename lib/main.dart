import 'package:flutter/material.dart';
import 'dart:async';
import 'login_page.dart';
import 'profile.dart';
import 'admin_page.dart';
import 'add_card_page.dart';
import 'family_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'firebase_options.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Discount Keeper',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),

      home: const AuthCheck(),
      routes: {
        '/home': (context) => const HomePage(),
        '/admin': (context) => const AdminPage(),
        '/profile': (context) => const ProfilePage(),
        '/addCard': (context) => const AddCardPage(),
        '/family': (context) => FamilyPage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() {
    return HomePageState();
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  _AuthCheckState createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  String? userRole;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 1), () {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      await _checkUserRole(currentUser);
    } else {
      FirebaseAuth.instance.authStateChanges().listen((User? user) async {
        if (user == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        } else {
          await _checkUserRole(user);
        }
      });
    }
  }

  Future<void> _checkUserRole(User user) async {
    final roleSnapshot = await FirebaseFirestore.instance
        .collection('customers')
        .doc(user.uid)
        .get();

    if (roleSnapshot.exists) {
      userRole = roleSnapshot.data()?['role'];

      if (userRole == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black, // Черный фон
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Discount',
                  style: TextStyle(
                    fontSize: 48, // Размер шрифта для "Discount"
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Keeper',
                  style: TextStyle(
                    fontSize: 48, // Размер шрифта для "Keeper"
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB9F240), // Цвет для "Keeper"
                  ),
                ),
              ],
            ),
            SizedBox(height: 20), // Отступ между заголовком и подзаголовком
            Text(
              'Простой кошелек для управления',
              style: TextStyle(
                fontSize: 18, // Размер шрифта для первой строки подзаголовка
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'вашими картами',
              style: TextStyle(
                fontSize: 18, // Размер шрифта для второй строки подзаголовка
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


class HomePageState extends State<HomePage> {
  int currentIndex = 0;
  List<String> _frontImageUrls = [];
  bool isLoading = true;

  // Search parameters
  String searchCardName = '';
  String selectedCategory = 'Все категории'; // Add a default category
  final List<String> categories = [
    'Все категории',
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
  Future<void> deleteCard(String imageUrl) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Найдем документ с нужным `frontImageUrl` и `userEmail`
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('cards')
            .where('userEmail', isEqualTo: user.email)
            .where('frontImageUrl', isEqualTo: imageUrl)
            .get();

        if (snapshot.docs.isNotEmpty) {
          await snapshot.docs.first.reference.delete();
          // Удаляем карту из списка локально
          setState(() {
            _frontImageUrls.remove(imageUrl);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Карта удалена')),
          );
        }
      } catch (e) {
        print('Ошибка при удалении карты: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при удалении карты')),
        );
      }
    }
  }

  Future<void> editCardDetails(BuildContext context, String imageUrl, String newName) async {
    try {
      // Получаем текущего пользователя
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Находим документ карты по imageUrl и email
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('cards')
            .where('userEmail', isEqualTo: user.email)
            .where('frontImageUrl', isEqualTo: imageUrl)
            .get();

        if (snapshot.docs.isNotEmpty) {
          // Обновляем данные в Firestore
          await snapshot.docs.first.reference.update({
            'cardName': newName,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Карта успешно обновлена')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Карта не найдена')),
          );
        }
      }
    } catch (e) {
      print('Ошибка при редактировании карты: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при обновлении карты')),
      );
    }
  }


  @override
  void initState() {
    super.initState();
    // Subscribe to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        clearImages(); // Clear images if user logged out
      } else {
        _searchCards(); // Load images if user logged in
      }
    });
  }

  void showCardActionsMenu(BuildContext context, String imageUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.edit,
                color: Color(0xFFB9F240),
              ),
              title: const Text(
                'Редактировать карту',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context); // Закрываем меню
                showEditCardDialog(context, imageUrl); // Открываем диалог редактирования
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete,
                color: Color(0xFFB9F240),
              ),
              title: const Text(
                'Удалить карту',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                deleteCard(imageUrl); // Вызов удаления карты
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void showEditCardDialog(BuildContext context, String imageUrl) async {
    // Инициализация контроллера для названия карты
    final _cardNameController = TextEditingController();

    // Загружаем текущие данные карты
    await FirebaseFirestore.instance
        .collection('cards')
        .where('frontImageUrl', isEqualTo: imageUrl)
        .get()
        .then((QuerySnapshot snapshot) {
      if (snapshot.docs.isNotEmpty) {
        var cardData = snapshot.docs.first.data() as Map<String, dynamic>;
        _cardNameController.text = cardData['cardName'] ?? '';
      }
    });

    // Показываем диалог редактирования
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text(
            'Редактировать карту',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _cardNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Название карты',
                  labelStyle: TextStyle(color: Color(0xFFB9F240)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFB9F240)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFB9F240)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Закрываем диалог
              },
              child: const Text(
                'Отмена',
                style: TextStyle(color: Color(0xFFB9F240)),
              ),
            ),
            TextButton(
              onPressed: () async {
                // Логика сохранения изменений
                await editCardDetails(context, imageUrl, _cardNameController.text);
                Navigator.pop(context); // Закрываем диалог
              },
              child: const Text(
                'Сохранить',
                style: TextStyle(color: Color(0xFFB9F240)),
              ),
            ),
          ],
        );
      },
    );
  }

  // Clear images and reset loading state
  void clearImages() {
    setState(() {
      _frontImageUrls.clear();
      isLoading = true; // Indicate loading state
    });
  }

  Future<void> _searchCards() async {
    setState(() {
      isLoading = true; // Устанавливаем состояние загрузки
    });

    try {
      // Получаем текущего авторизованного пользователя
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Если пользователь не авторизован, очищаем изображения и выходим
        clearImages();
        return;
      }

      Query query = FirebaseFirestore.instance.collection('cards');

      // Логирование значений
      print('Searching cards for user: ${user.email} with name: $searchCardName, category: $selectedCategory');

      // Фильтр по адресу электронной почты пользователя
      query = query.where('userEmail', isEqualTo: user.email);

      // Добавляем фильтр по названию карты
      if (searchCardName.isNotEmpty) {
        query = query.where('cardName', isEqualTo: searchCardName);
      }

      // Добавляем фильтр по категории
      if (selectedCategory != 'Все категории') {
        query = query.where('category', isEqualTo: selectedCategory);
      }

      // Получаем документы
      QuerySnapshot querySnapshot = await query.get();
      List<String> frontImages = [];

      for (var doc in querySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        // Получаем frontImageUrl для каждой карты
        if (data.containsKey('frontImageUrl')) {
          String imageUrl = data['frontImageUrl'];
          frontImages.add(imageUrl);
        }
      }

      setState(() {
        _frontImageUrls = frontImages; // Обновляем изображения карт
        isLoading = false; // Завершаем загрузку
      });
    } catch (e) {
      print('Error searching cards: $e');
      setState(() {
        isLoading = false; // Завершаем загрузку даже при ошибке
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient background
          Positioned(
            top: height - 98,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Search bar
          Positioned(
            top: 112,
            left: (width - 340) / 2,
            child: Container(
              width: 340,
              height: 45,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(172, 172, 172, 0.29),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          searchCardName = value;
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Поиск по названию карты',
                          hintStyle: TextStyle(
                            color: Color.fromRGBO(172, 172, 172, 0.65),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Color(0xFFB9F240)),
                      onPressed: _searchCards,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Category dropdown
          Positioned(
            top: 160,
            left: (width - 200) / 2,
            child: DropdownButton<String>(
              value: selectedCategory,
              items: categories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedCategory = newValue!;
                });
                _searchCards();
              },
              dropdownColor: Colors.black,
              iconEnabledColor: const Color(0xFFB9F240),
            ),
          ),
          // Card images from Firebase
          Positioned(
            top: 200,
            bottom: 98,
            left: 0,
            right: 0,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _frontImageUrls.isNotEmpty
                ? PageView.builder(
              itemCount: _frontImageUrls.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return Center(
                  child: buildCardFromUrl(_frontImageUrls[index]),
                );
              },
            )
                : const Center(
              child: Text(
                'Карты не найдены.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Discount',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: 25,
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
                  fontSize: 25,
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
        centerTitle: true,
        backgroundColor: Colors.black,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.pushNamed(context, '/addCard');
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: const Color(0xFFB9F240),
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Главная'),
          BottomNavigationBarItem(icon: Icon(Icons.group_add), label: 'Поделиться'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Профиль'),
        ],
        onTap: (index) {
          if (index == 0) Navigator.pushNamed(context, '/home');
          if (index == 1) Navigator.pushNamed(context, '/family');
          if (index == 2) Navigator.pushNamed(context, '/profile');
        },
      ),
    );
  }

  Widget buildCardFromUrl(String imageUrl) {
    return GestureDetector(
      onTap: () {
        // Открытие страницы с деталями карты
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CardDetailsPage(imageUrl: imageUrl),
          ),
        );
      },
      onLongPress: () {
        // Открытие всплывающего меню при долгом нажатии
        showCardActionsMenu(context, imageUrl);
      },
      child: Container(
        width: 250,
        height: 450,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          image: DecorationImage(
            image: CachedNetworkImageProvider(imageUrl),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

// New page for card details
class CardDetailsPage extends StatelessWidget {
  final String imageUrl;

  const CardDetailsPage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали карты'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 300,
              height: 450,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Additional information
            const Text(
              'Детали о карте',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.black,
    );
  }
}