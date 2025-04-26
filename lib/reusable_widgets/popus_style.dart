import 'package:flutter/material.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';

class PopupsStyle {
  static InputDecoration textFieldDecoration(String labelText, {String? errorText}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: hexStringToColor("5E61F4")),
      errorText: errorText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: hexStringToColor("5E61F4")),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: hexStringToColor("CB2B93"), width: 2),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
    );
  }

  static TextStyle dialogTitleStyle() {
    return TextStyle(
      color: hexStringToColor("5E61F4"),
      fontSize: 22,
      fontWeight: FontWeight.bold,
    );
  }

  static TextStyle dialogContentStyle() {
    return TextStyle(
      color: Colors.grey[800],
      fontSize: 16,
    );
  }

  static ButtonStyle dialogButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.purple[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
    ));
  }

  static ButtonStyle dialogSecondaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.grey[300],
      foregroundColor: Colors.grey[800],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }

  static Widget dialogHeaderIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hexStringToColor("5E61F4").withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 30, color: hexStringToColor("5E61F4")),
    );
  }

  static AlertDialog styledDialog({
    required BuildContext context,
    required String title,
    required Widget content,
    required List<Widget> actions,
    IconData? icon,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 10,
      backgroundColor: Colors.white,
      title: Column(
        children: [
          if (icon != null) dialogHeaderIcon(icon),
          const SizedBox(height: 10),
          Text(title, style: dialogTitleStyle(), textAlign: TextAlign.center),
        ],
      ),
      content: SingleChildScrollView(
        child: content,
      ),
      actions: actions,
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.only(bottom: 20),
    );
  }
}