import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  AdminPageState createState() => AdminPageState();
}

class AdminPageState extends State<AdminPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<DocumentSnapshot> _users = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _fetchAllUsers(); // Загрузка всех пользователей при инициализации
    _getCurrentUserId(); // Получение текущего идентификатора пользователя
  }

  Future<void> _getCurrentUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid; // Сохранение идентификатора текущего пользователя
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllUsers() async {
    setState(() {
      _isLoading = true;
    });

    CollectionReference users = FirebaseFirestore.instance.collection('customers');
    QuerySnapshot querySnapshot = await users.get();

    // Фильтруем пользователей, оставляя только тех, у кого есть email
    setState(() {
      _users = querySnapshot.docs.where((doc) => doc['email'] != null && doc['email'].isNotEmpty).toList();
      _isLoading = false;
    });
  }

  Future<void> _searchUsers() async {
    setState(() {
      _isLoading = true;
    });

    String searchText = _searchController.text.trim();
    CollectionReference users = FirebaseFirestore.instance.collection('customers');

    QuerySnapshot querySnapshot;

    if (searchText.isEmpty) {
      // Если запрос пустой, загрузить всех пользователей
      querySnapshot = await users.get();
    } else {
      // Поиск по cusname или email
      querySnapshot = await users.where('cusname', isEqualTo: searchText).get();

      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await users.where('email', isEqualTo: searchText).get();
      }
    }

    // Фильтруем пользователей, оставляя только тех, у кого есть email
    setState(() {
      _users = querySnapshot.docs.where((doc) => doc['email'] != null && doc['email'].isNotEmpty).toList();
      _isLoading = false;
    });
  }

  Future<void> _updateUserBonus(String userId, int bonus) async {
    CollectionReference users = FirebaseFirestore.instance.collection('customers');

    await users.doc(userId).update({
      'bonus': bonus,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Бонусы обновлены')));
  }

  Future<void> _updateUserNickname(String userId, String newNickname) async {
    CollectionReference users = FirebaseFirestore.instance.collection('customers');

    await users.doc(userId).update({
      'cusname': newNickname,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Никнейм обновлен')));
  }

  Future<void> _deleteUser(String userId) async {
    if (userId == _currentUserId) {
      // Предотвращение удаления своего аккаунта
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Вы не можете удалить свой аккаунт!')));
      return;
    }

    try {
      CollectionReference users = FirebaseFirestore.instance.collection('customers');
      await users.doc(userId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пользователь удален')));
      _fetchAllUsers(); // Обновляем список пользователей после удаления
    } catch (e) {
      print('Error deleting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка при удалении пользователя')));
    }
  }

  void _showEditBonusDialog(String userId, int currentBonus) {
    TextEditingController bonusController = TextEditingController(text: currentBonus.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black, // Устанавливаем черный фон
          title: const Text('Редактировать бонусы', style: TextStyle(color: Colors.white)), // Изменение цвета текста
          content: TextField(
            controller: bonusController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Введите новое количество бонусов',
              labelStyle: TextStyle(color: Colors.white), // Изменение цвета текста
            ),
            style: const TextStyle(color: Colors.white), // Цвет текста ввода
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Отмена', style: TextStyle(color: Colors.white)), // Изменение цвета текста
            ),
            TextButton(
              onPressed: () {
                int newBonus = int.parse(bonusController.text);
                _updateUserBonus(userId, newBonus);
                Navigator.of(context).pop();
              },
              child: const Text('Сохранить', style: TextStyle(color: Color(0xFFB9F240))), // Изменение цвета текста
            ),
          ],
        );
      },
    );
  }

  void _showEditNicknameDialog(String userId, String currentNickname) {
    TextEditingController nicknameController = TextEditingController(text: currentNickname);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black, // Устанавливаем черный фон
          title: const Text('Редактировать никнейм', style: TextStyle(color: Colors.white)), // Изменение цвета текста
          content: TextField(
            controller: nicknameController,
            decoration: const InputDecoration(
              labelText: 'Введите новый никнейм',
              labelStyle: TextStyle(color: Colors.white), // Изменение цвета текста
            ),
            style: const TextStyle(color: Colors.white), // Цвет текста ввода
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Отмена', style: TextStyle(color: Colors.white)), // Изменение цвета текста
            ),
            TextButton(
              onPressed: () {
                String newNickname = nicknameController.text;
                _updateUserNickname(userId, newNickname);
                Navigator.of(context).pop();
              },
              child: const Text('Сохранить', style: TextStyle(color: Color(0xFFB9F240))), // Изменение цвета текста
            ),
          ],
        );
      },
    );
  }

  void _goToHomePage() {
    Navigator.pushNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Страница Админа', style: TextStyle(color: Colors.white)), // Изменение цвета текста
        backgroundColor: Colors.black, // Установка черного цвета для AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Color(0xFFB9F240)), // Изменение цвета иконки
            onPressed: _goToHomePage,
          ),
        ],
      ),
      body: Container(
        color: Colors.black, // Установка черного фона
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Поиск по никнейму или email',
                labelStyle: const TextStyle(color: Colors.white), // Изменение цвета текста
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFFB9F240)), // Изменение цвета иконки
                  onPressed: _searchUsers,
                ),
              ),
              style: const TextStyle(color: Colors.white), // Изменение цвета текста ввода
              cursorColor: Colors.white, // Цвет курсора
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : _users.isEmpty
                ? const Text('Нет результатов', style: TextStyle(color: Colors.white)) // Изменение цвета текста
                : Expanded(
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  var user = _users[index].data() as Map<String, dynamic>;
                  String userId = _users[index].id;
                  String cusname = user['cusname'] ?? 'Нет ника';
                  String email = user['email'] ?? 'Нет email';
                  int bonus = (user['bonus'] is int) ? user['bonus'] : 0; // Преобразование к int

                  return ListTile(
                    title: Text(
                        '$cusname (${email.isNotEmpty ? email : 'Нет email'})',
                        style: const TextStyle(color: Colors.white) // Изменение цвета текста
                    ),
                    subtitle: Text('Бонусы: $bonus', style: const TextStyle(color: Colors.white)), // Изменение цвета текста
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.cached, color: Color(0xFFB9F240)), // Изменение цвета иконки
                          onPressed: () => _showEditBonusDialog(userId, bonus),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFFB9F240)), // Изменение цвета иконки
                          onPressed: () => _showEditNicknameDialog(userId, cusname),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDeleteUser(userId),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteUser(String userId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black, // Устанавливаем черный фон
          title: const Text('Подтверждение удаления', style: TextStyle(color: Colors.white)), // Изменение цвета текста
          content: const Text('Вы уверены, что хотите удалить этого пользователя?', style: TextStyle(color: Colors.white)), // Изменение цвета текста
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрыть диалог
              },
              child: const Text('Отмена', style: TextStyle(color: Colors.white)), // Изменение цвета текста
            ),
            TextButton(
              onPressed: () {
                _deleteUser(userId); // Удалить пользователя
                Navigator.of(context).pop(); // Закрыть диалог
              },
              child: const Text('Удалить', style: TextStyle(color: Colors.red)), // Изменение цвета текста
            ),
          ],
        );
      },
    );
  }
}