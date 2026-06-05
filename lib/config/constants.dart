import 'package:flutter/material.dart';

class AppConstants {
  static const appName = 'SplitEx';

  static const List<String> expenseCategories = [
    'Rent',
    'Groceries',
    'Electricity',
    'Maid',
    'Wi-Fi',
    'Food',
    'Transport',
    'Other',
  ];

  static const Map<String, IconData> categoryIcons = {
    'Rent': Icons.home,
    'Groceries': Icons.shopping_cart,
    'Electricity': Icons.bolt,
    'Maid': Icons.cleaning_services,
    'Wi-Fi': Icons.wifi,
    'Food': Icons.restaurant,
    'Transport': Icons.directions_car,
    'Other': Icons.receipt_long,
  };

  static const int maxRoomMembers = 10;
  static const int recentExpensesCount = 5;
  static const int expensesPageSize = 20;
}
