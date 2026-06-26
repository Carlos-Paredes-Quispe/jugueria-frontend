import 'package:flutter/material.dart';

// Escuchador global para el modo oscuro
final ValueNotifier<bool> isDarkModeGlobal = ValueNotifier<bool>(false);

// ==========================================
// 🎨 PALETA DE COLORES CORPORATIVA (ACTUALIZADA)
// ==========================================
class AppColores {
  // Colores base de la marca
  static const Color naranjaLogo = Color(0xFFF36C21);
  static const Color verdeLogo = Color(0xFF8DC63F);
  
  // Paleta para Modo Claro (IDÉNTICA A TU IMAGEN)
  static const Color fondoClaro = Color(0xFFE4EFE5); // <-- Verde pastel suave del fondo
  static const Color tarjetaClara = Colors.white;
  static const Color textoClaro = Color(0xFF2B3A2C); // <-- Verde muy oscuro, casi negro
  static const Color textoClaroSecundario = Color(0xFF6A786B);

  // Paleta para Modo Oscuro
  static const Color fondoOscuro = Color(0xFF1E1610);
  static const Color tarjetaOscura = Color(0xFF2A2019);
  static const Color textoOscuro = Color(0xFFF7F4F2);
  static const Color textoOscuroSecundario = Color(0xFFBCB4AF);
}