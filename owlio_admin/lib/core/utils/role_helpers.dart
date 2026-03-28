import 'package:flutter/material.dart';

/// Color for role badge display.
Color getRoleColor(String role) {
  return switch (role.toLowerCase()) {
    'admin' => Colors.red,
    'head' => Colors.purple,
    'teacher' => Colors.blue,
    'student' => Colors.green,
    _ => Colors.grey,
  };
}

/// Turkish display label for role.
String getRoleLabel(String role) {
  return switch (role.toLowerCase()) {
    'admin' => 'Admin',
    'head' => 'Baş Öğretmen',
    'teacher' => 'Öğretmen',
    'student' => 'Öğrenci',
    _ => role,
  };
}
