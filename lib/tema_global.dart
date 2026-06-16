import 'package:flutter/material.dart';

// Esta variable global inicia en 'true' (Modo Oscuro activado por defecto).
// Al usar ValueNotifier, Flutter le avisa a todas las pantallas cuando este valor cambia.
final ValueNotifier<bool> isDarkModeGlobal = ValueNotifier<bool>(true);