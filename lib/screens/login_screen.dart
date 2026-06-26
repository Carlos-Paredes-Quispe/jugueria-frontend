import 'package:flutter/material.dart';
import 'package:flutter_jugueria/main.dart';
import 'package:flutter_jugueria/screens/dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../tema_global.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _recordarUsuario = false;
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatosGuardados();
    mostrarSoporteGlobal.value = false;
  }

  @override
  void dispose() {
    mostrarSoporteGlobal.value = true;
    super.dispose(); 
  }

  Future<void> _cargarDatosGuardados() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _recordarUsuario = prefs.getBool('recordarCheckbox') ?? false;
      if (_recordarUsuario) {
        _userController.text = prefs.getString('usuarioGuardado') ?? '';
      }
    });
  }

  Future<void> _conectarAPI() async {
    final String usuario = _userController.text;
    final String password = _passwordController.text;

    if (usuario.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingrese usuario y contraseña'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conectando con el servidor...'), backgroundColor: AppColores.naranjaLogo, duration: Duration(seconds: 1)),
    );

    final url = Uri.parse('http://192.168.18.194:3000/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({'usuario': usuario, 'contrasena': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ignore: unused_local_variable
        final data = jsonDecode(response.body);
        
        SharedPreferences prefs = await SharedPreferences.getInstance();
        if (_recordarUsuario) {
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('rolUsuario', 'ADMINISTRADOR'); 
          await prefs.setString('usuarioGuardado', usuario); 
          await prefs.setBool('recordarCheckbox', true); 
        } else {
          await prefs.remove('usuarioGuardado');
          await prefs.setBool('recordarCheckbox', false);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Conexión exitosa! ✅'), backgroundColor: AppColores.verdeLogo),
          );
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen(rolUsuario: 'ADMINISTRADOR')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario o contraseña incorrectos'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de red: No se pudo contactar al servidor'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {

        final Color bgColor = isDark ? AppColores.fondoOscuro : AppColores.fondoClaro;
        final Color cardColor = isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara;
        final Color textColor = isDark ? AppColores.textoOscuro : AppColores.textoClaro;
        final Color subtitleColor = isDark ? AppColores.textoOscuroSecundario : AppColores.textoClaroSecundario;

        return Scaffold(
          backgroundColor: bgColor, // <-- Aquí se aplica el nuevo fondo verde suave
          body: Stack(
            children: [
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    child: Container(
                      width: 450, 
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(30), 
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.05), // Sombra más suave
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          
                          Image.asset(
                            'assets/images/logoJugueria.png', 
                            height: 90,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => 
                                  Icon(Icons.local_drink, size: 75, color: AppColores.naranjaLogo),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'JUGUERÍA VERASALUD',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26, 
                              fontWeight: FontWeight.w900, 
                              color: textColor,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Sistema de Gestión de Juguería",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subtitleColor, fontSize: 16),
                          ),
                          const SizedBox(height: 40),

                          _buildTextField(
                            controller: _userController,
                            label: "Ingresar Usuario",
                            icon: Icons.person_outline,
                            obscureText: false,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _passwordController,
                            label: "Contraseña",
                            icon: Icons.lock_outline,
                            obscureText: true,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Checkbox(
                                value: _recordarUsuario,
                                activeColor: AppColores.naranjaLogo, 
                                side: BorderSide(color: textColor.withValues(alpha: 0.5)),
                                onChanged: (bool? value) {
                                  setState(() { _recordarUsuario = value ?? false; });
                                },
                              ),
                              Text('Recordar mis datos', style: TextStyle(color: textColor)),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // BOTÓN SÓLIDO (Sin degradado, idéntico a tu diseño)
                          SizedBox(
                            height: 55,
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColores.naranjaLogo,
                                elevation: 3,
                                shadowColor: AppColores.naranjaLogo.withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15), // Bordes menos redondos para igualar el botón
                                ),
                              ),
                              onPressed: _conectarAPI, 
                              child: const Text(
                                "INGRESAR",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 50),

                          Column(
                            children: [
                              Text('Powered by', style: TextStyle(color: subtitleColor, fontSize: 13)),
                              const SizedBox(height: 8),
                              Image.asset(
                                'assets/images/logoDragon.png', 
                                height: 50,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => 
                                  const Icon(Icons.local_fire_department, color: AppColores.naranjaLogo, size: 30),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'DragonPOS',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 20,
                right: 20,
                child: SafeArea(
                  child: IconButton(
                    iconSize: 28,
                    icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: AppColores.naranjaLogo),
                    onPressed: () { isDarkModeGlobal.value = !isDarkModeGlobal.value; },
                    tooltip: 'Cambiar tema',
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscureText,
    required bool isDark,
  }) {
    final Color inputTextColor = isDark ? AppColores.textoOscuro : AppColores.textoClaro;
    final Color hintColor = isDark ? AppColores.textoOscuroSecundario : AppColores.textoClaroSecundario;
    final Color fillColor = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white; // Fondo blanco en inputs

    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: inputTextColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hintColor),
        prefixIcon: Icon(icon, color: AppColores.naranjaLogo), 
        filled: true,
        fillColor: fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: AppColores.textoClaroSecundario.withValues(alpha: 0.2)), // Borde sutil gris/verde
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColores.naranjaLogo, width: 2), 
        ),
      ),
    );
  }
}