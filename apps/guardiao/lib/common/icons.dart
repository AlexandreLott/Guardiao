import 'package:flutter/material.dart';

/// Ícones das missões (a chave vai para a nuvem).
const missionIcons = <String, IconData>{
  'broom': Icons.cleaning_services_outlined,
  'dish': Icons.soup_kitchen_outlined,
  'book': Icons.menu_book_outlined,
  'pet': Icons.pets_outlined,
  'trash': Icons.delete_outline,
  'bed': Icons.bed_outlined,
  'star': Icons.star_outline,
};

/// Ícones das rotinas.
const routineIcons = <String, IconData>{
  'sun': Icons.wb_sunny_outlined,
  'fork': Icons.restaurant,
  'book': Icons.menu_book_outlined,
  'gamepad': Icons.sports_esports_outlined,
  'moon': Icons.bedtime_outlined,
  'bus': Icons.directions_bus_outlined,
};

IconData missionIcon(String key) => missionIcons[key] ?? Icons.star_outline;
IconData routineIcon(String key) =>
    routineIcons[key] ?? Icons.schedule_outlined;
