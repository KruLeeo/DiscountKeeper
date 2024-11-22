import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Страница для отображения полного изображения карты
class FullImagePage extends StatelessWidget {
  final String imageUrl;

  const FullImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Полное изображение', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Image.network(imageUrl),
      ),
    );
  }
}

class FamilyPage extends StatefulWidget {
  const FamilyPage({super.key});

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
        title: const Text(
          'Семейный доступ',
          style: TextStyle(color: Colors.white),
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
                                selectedCards.add(card.id);
                              } else {
                                selectedCards.remove(card.id);
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
                  backgroundColor: WidgetStateProperty.all(const Color(0xFFB9F240)),
                ),
                onPressed: selectedCards.isEmpty
                    ? null
                    : () async {
                  String friendEmail = emailController.text.trim();

                  if (friendEmail.isEmpty || friendEmail == currentUserEmail) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Введите корректный email')),
                    );
                    return;
                  }

                  for (String cardId in selectedCards) {
                    await FirebaseFirestore.instance.collection('accessRequests').add({
                      'ownerEmail': currentUserEmail,
                      'friendEmail': friendEmail,
                      'status': 'pending',
                      'cardId': cardId,
                    });
                  }

                  emailController.clear();
                  selectedCards.clear();

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
            const Divider(height: 32, thickness: 2, color: Colors.white60),

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
                            onPressed: () async {
                              var cardId = request['cardId'];
                              var ownerEmail = request['ownerEmail'];

                              await FirebaseFirestore.instance.collection('accessRequests').doc(request.id).update({
                                'status': 'approved',
                              });

                              await FirebaseFirestore.instance.collection('cards').doc(cardId).update({
                                'sharedWith': FieldValue.arrayUnion([currentUserEmail]),
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              FirebaseFirestore.instance.collection('accessRequests').doc(request.id).update({
                                'status': 'rejected',
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const Divider(height: 32, thickness: 2, color: Colors.white60),

            // Карты с доступом
            const Text(
              'Карты с доступом:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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

                    // Проверка, является ли текущий пользователь владельцем карты
                    bool isOwner = card['userEmail'] == currentUserEmail;

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.black,
                      child: ListTile(
                        leading: Image.network(card['frontImageUrl']),
                        title: Text(card['cardName'], style: const TextStyle(color: Colors.white)),
                        subtitle: Text(card['category'], style: const TextStyle(color: Colors.white)),
                        trailing: isOwner
                            ? IconButton(
                          icon: const Icon(Icons.visibility_off, color: Colors.white),
                          onPressed: () async {
                            // Скрытие карты только для владельца
                            await FirebaseFirestore.instance.collection('cards').doc(card.id).update({
                              'hiddenFor': FieldValue.arrayUnion([currentUserEmail]),
                            });
                          },
                        )
                            : null,  // Если текущий пользователь не владелец, кнопка скрытия не отображается
                        onTap: () {
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
    bottomNavigationBar: BottomNavigationBar(
    backgroundColor: Colors.black,
    selectedItemColor: const Color(0xFFB9F240),
    unselectedItemColor: Colors.grey,
    currentIndex: 1, // Указываем текущую страницу ("Поделиться")
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

  // Функция для получения карт пользователя
  Future<List<DocumentSnapshot>> fetchUserCards() async {
    var userCardsQuery = await FirebaseFirestore.instance.collection('cards').where('userEmail', isEqualTo: currentUserEmail).get();
    return userCardsQuery.docs;
  }

  // Функция для получения карт, которыми поделились с пользователем
  Future<List<DocumentSnapshot>> fetchSharedCards() async {
    var sharedCardsQuery = await FirebaseFirestore.instance.collection('cards').where('sharedWith', arrayContains: currentUserEmail).get();
    return sharedCardsQuery.docs;
  }
}