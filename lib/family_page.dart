import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Страница для отображения полного изображения карты
class FullImagePage extends StatelessWidget {
  final String imageUrl;

  FullImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Чёрный фон для всего Scaffold
      appBar: AppBar(
        title: const Text('Полное изображение', style: TextStyle(color: Colors.white)), // Белый цвет текста
        backgroundColor: Colors.black, // Чёрный фон для AppBar
      ),
      body: Center(
        child: Image.network(imageUrl), // Отображаем полное изображение
      ),
    );
  }
}

class FamilyPage extends StatefulWidget {
  @override
  _FamilyPageState createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  final TextEditingController emailController = TextEditingController();
  final String? currentUserEmail = FirebaseAuth.instance.currentUser?.email;

  // Список выбранных карт
  List<String> selectedCards = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Черный фон для всего Scaffold
      appBar: AppBar(
        backgroundColor: Colors.black, // Черный фон для AppBar
        automaticallyImplyLeading: false, // Убираем стрелочку назад
        title: const Text(
          'Семейный доступ',
          style: TextStyle(color: Colors.white), // Белый цвет для текста
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Отправка запроса на доступ
            const Text(
              'Предоставить доступ к картам:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email друга',
                labelStyle: TextStyle(color: Colors.white),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Выберите карты, которыми хотите поделиться:',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 8),
            FutureBuilder(
              future: fetchUserCards(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('У вас нет карт', style: TextStyle(color: Colors.white));
                }

                var cards = snapshot.data as List<DocumentSnapshot>;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    var card = cards[index];

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.black,
                      child: ListTile(
                        leading: Image.network(card['frontImageUrl']),
                        title: Text(card['cardName'], style: const TextStyle(color: Colors.white)),
                        subtitle: Text(card['category'], style: const TextStyle(color: Colors.white)),
                        trailing: Checkbox(
                          value: selectedCards.contains(card.id),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                selectedCards.add(card.id); // Добавляем карту в список выбранных
                              } else {
                                selectedCards.remove(card.id); // Убираем карту из списка
                              }
                            });
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(const Color(0xFFB9F240)),
                ),
                onPressed: selectedCards.isEmpty
                    ? null  // Кнопка неактивна, если нет выбранных карт
                    : () async {
                  String friendEmail = emailController.text.trim();

                  if (friendEmail.isEmpty || friendEmail == currentUserEmail) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Введите корректный email')),
                    );
                    return;
                  }

                  // Отправляем запросы на доступ для каждой выбранной карты
                  for (String cardId in selectedCards) {
                    await FirebaseFirestore.instance.collection('accessRequests').add({
                      'ownerEmail': currentUserEmail,
                      'friendEmail': friendEmail,
                      'status': 'pending',
                      'cardId': cardId,
                    });
                  }

                  emailController.clear();
                  selectedCards.clear(); // Очищаем список выбранных карт

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Запросы отправлены')),
                  );
                },
                child: const Text(
                  'Поделиться картами',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
            const Divider(height: 32, thickness: 2, color: Colors.white60), // 60% прозрачность

            // Просмотр входящих запросов
            const Text(
              'Входящие запросы:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('accessRequests')
                  .where('friendEmail', isEqualTo: currentUserEmail)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var requests = snapshot.data!.docs;

                if (requests.isEmpty) {
                  return const Text('Нет запросов на доступ', style: TextStyle(color: Colors.white));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    var request = requests[index];

                    return ListTile(
                      title: Text('Запрос от: ${request['ownerEmail']}', style: const TextStyle(color: Colors.white)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () {
                              FirebaseFirestore.instance
                                  .collection('accessRequests')
                                  .doc(request.id)
                                  .update({'status': 'approved'});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              FirebaseFirestore.instance
                                  .collection('accessRequests')
                                  .doc(request.id)
                                  .update({'status': 'rejected'});
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const Divider(height: 32, thickness: 2, color: Colors.white60), // 60% прозрачность

            Center(
              child: Text(
                'Карты с доступом:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder(
              future: fetchSharedCards(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('Нет доступных карт', style: TextStyle(color: Colors.white));
                }

                var cards = snapshot.data as List<DocumentSnapshot>;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    var card = cards[index];

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.black,
                      child: ListTile(
                        leading: Image.network(card['frontImageUrl']),
                        title: Text(card['cardName'], style: const TextStyle(color: Colors.white)),
                        subtitle: Text(card['category'], style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          // Переходим на экран с полным изображением
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullImagePage(imageUrl: card['frontImageUrl']),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      // Нижняя панель навигации
      bottomNavigationBar: Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          height: 98,
          decoration: const BoxDecoration(
            color: Colors.black,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.home,
                  color: Colors.grey,
                ),
                iconSize: 28,
                onPressed: () {
                  Navigator.pushNamed(context, '/home');
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.group_add,
                  color: Color(0xFFB9F240),
                ),
                iconSize: 28,
                onPressed: () {
                  Navigator.pushNamed(context, '/family');
                },
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
    );
  }

  // Функция получения карт пользователя
  Future<List<DocumentSnapshot>> fetchUserCards() async {
    var userCards = await FirebaseFirestore.instance
        .collection('cards')
        .where('userEmail', isEqualTo: currentUserEmail)
        .get();

    return userCards.docs;
  }

  // Функция получения карт с доступом
  Future<List<DocumentSnapshot>> fetchSharedCards() async {
    var approvedRequests = await FirebaseFirestore.instance
        .collection('accessRequests')
        .where('friendEmail', isEqualTo: currentUserEmail)
        .where('status', isEqualTo: 'approved')
        .get();

    List<String> ownerEmails =
    approvedRequests.docs.map((doc) => doc['ownerEmail'] as String).toList();

    if (ownerEmails.isEmpty) return [];

    var cards = await FirebaseFirestore.instance
        .collection('cards')
        .where('userEmail', whereIn: ownerEmails)
        .get();

    return cards.docs;
  }
}