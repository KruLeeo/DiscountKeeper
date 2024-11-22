import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CardDetailsPage extends StatelessWidget {
  final String cardId; // принимаем cardId

  const CardDetailsPage({super.key, required this.cardId});

  Future<DocumentSnapshot> _getCardData() async {
    // Получаем данные карты из Firestore
    return await FirebaseFirestore.instance.collection('cards').doc(cardId).get();
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
            return const Center(child: Text('Ошибка загрузки данных'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Карты не существует'));
          }

          var cardData = snapshot.data!;
          String cardName = cardData['cardName'];
          String frontImageUrl = cardData['frontImageUrl'];
          String backImageUrl = cardData['backImageUrl'];
          String aboutCard = cardData['aboutCard'] ?? 'Нет информации о карте';

          return Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Отображение лицевой стороны карты
                Container(
                  width: 300,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: NetworkImage(frontImageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Отображение задней стороны карты
                Container(
                  width: 300,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: NetworkImage(backImageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Название карты
                Text(
                  cardName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                // Информация о карте
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    aboutCard,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      backgroundColor: Colors.black,
    );
  }
}