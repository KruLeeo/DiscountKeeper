import 'package:flutter/material.dart';
import 'dart:async';
import 'login_page.dart';
import 'profile.dart';
import 'admin_page.dart';
import 'add_card_page.dart';
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
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Редактировать карту'),
              onTap: () {
                // Логика редактирования карты
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Удалить карту'),
              onTap: () {
                // Логика удаления карты
                Navigator.pop(context);
              },
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
    final width = MediaQuery
        .of(context)
        .size
        .width;
    final height = MediaQuery
        .of(context)
        .size
        .height;

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
              // Увеличиваем высоту для более гармоничного размещения текста
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
                          searchCardName = value; // Update search name
                        },
                        style: const TextStyle(
                          color: Colors.white, // Белый цвет текста
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Поиск по названию карты',
                          hintStyle: TextStyle(
                            color: Color.fromRGBO(172, 172, 172, 0.65),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 10), // Регулируем отступы сверху и снизу
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Color(0xFFB9F240)),
                      onPressed: _searchCards, // Trigger search
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
                  child: Text(
                      category, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedCategory = newValue!;
                });
                _searchCards(); // Обновляем поиск при изменении категории
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
          // Bottom navigation bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 98,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black,
                    Colors.transparent
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.home,
                      color: Color(0xFFB9F240),
                    ),
                    iconSize: 28,
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.group_add,
                      color: Colors.grey,
                    ),
                    iconSize: 28,
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.account_circle,
                      color: Colors.grey,
                    ),
                    iconSize: 28,
                    onPressed: () {
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                ],
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