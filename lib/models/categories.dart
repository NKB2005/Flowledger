import 'package:flutter/material.dart';

class AppCategory {
  final String name;
  final IconData icon;
  final Color color;

  const AppCategory(this.name, this.icon, this.color);
}

const expenseCategories = [
  AppCategory('Food', Icons.restaurant, Color(0xFFFB923C)),
  AppCategory('Transport', Icons.directions_bus, Color(0xFF60A5FA)),
  AppCategory('Shopping', Icons.shopping_bag, Color(0xFFF472B6)),
  AppCategory('Bills', Icons.receipt_long, Color(0xFFFBBF24)),
  AppCategory('Entertainment', Icons.movie, Color(0xFFA78BFA)),
  AppCategory('Health', Icons.favorite, Color(0xFFFB7185)),
  AppCategory('Other', Icons.category, Color(0xFF9CA3AF)),
];

const incomeCategories = [
  AppCategory('Salary', Icons.account_balance_wallet, Color(0xFF34D399)),
  AppCategory('Freelance', Icons.work, Color(0xFF35D9C6)),
  AppCategory('Gift', Icons.card_giftcard, Color(0xFFF472B6)),
  AppCategory('Other', Icons.category, Color(0xFF9CA3AF)),
];

AppCategory categoryFor(String name) => [
  ...expenseCategories,
  ...incomeCategories,
].firstWhere((c) => c.name == name, orElse: () => expenseCategories.last);
