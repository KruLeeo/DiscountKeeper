import 'package:flutter/material.dart';

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
            // Отображение изображения карты
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
            // Здесь можно добавить дополнительную информацию о карте
            const Text(
              'Дополнительная информация о карте',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            // Примерное место для дополнительных данных (например, имя карты или скидки)
            const Text(
              'Название карты: Пример карты',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Описание карты: Здесь может быть информация о карте, о скидках, или другая полезная информация.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      backgroundColor: Colors.black,
    );
  }
}