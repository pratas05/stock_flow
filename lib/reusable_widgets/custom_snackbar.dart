import 'package:flutter/material.dart';

class CustomSnackbar {
  static void show({
    required BuildContext context,
    required String message,
    Color backgroundColor = const Color(0xFF323232),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    Duration duration = const Duration(seconds: 3),
    IconData? icon, // Alterado de Icon para IconData para simplificar
    Color iconColor = Colors.white, // Cor padrão do ícone
  }) {
    final snackBar = SnackBar(
      behavior: behavior,
      duration: duration,
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      content: Row(
        children: [
          if (icon != null) // Mostra o ícone apenas se foi fornecido
          Padding(padding: const EdgeInsets.only(right: 8.0), child: Icon(icon, color: iconColor)),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}