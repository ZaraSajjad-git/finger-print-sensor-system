import 'package:finger_print_sensor/utils/app_colors.dart';
import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.white), // text color
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.white),
        suffixIcon: suffixIcon,
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.white),

        // Normal state
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.white, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),

        // Focused (when user taps inside)
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.accentGold, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),

        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.red, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),

        // Focused + error
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.red, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      obscureText: obscureText,
      cursorColor: AppColors.white,
    );
  }
}
