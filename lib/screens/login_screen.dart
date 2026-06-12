import 'package:flutter/material.dart';
import 'package:flutter_jugueria/screens/dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _recordarUsuario = false;
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Colores de la paleta DragonRES
  final Color darkBackground = const Color(0xFF0A0A0A);
  final Color copperPrimary = const Color(0xFFC58E58);
  final Color copperDark = const Color(0xFF8E5D31);
  final Color textLight = const Color(0xFFE0E0E0);

  // ========================================================
  // 1. ESTO SE EJECUTA SOLAMENTE AL ABRIR LA PANTALLA
  // ========================================================
  @override
  void initState() {
    super.initState();
    _cargarDatosGuardados();
  }

  Future<void> _cargarDatosGuardados() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _recordarUsuario = prefs.getBool('recordarCheckbox') ?? false;
      if (_recordarUsuario) {
        // Leemos el nombre de usuario de la memoria
        _userController.text = prefs.getString('usuarioGuardado') ?? '';
      }
    });
  }
  // ========================================================

  // FUNCIÓN PARA CONECTAR AL BACKEND
  Future<void> _conectarAPI() async {
    final String usuario = _userController.text;
    final String password = _passwordController.text;

    if (usuario.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingrese usuario y contraseña'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Conectando con el servidor...'),
        backgroundColor: copperDark,
        duration: const Duration(seconds: 1),
      ),
    );

    // ¡IMPORTANTE! REEMPLAZA LAS XX POR LA IP DE TU COMPUTADORA
    final url = Uri.parse('http://192.168.18.194:3000/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'usuario': usuario,
          'contrasena': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print("Token recibido: ${data['access_token']}");

        // ========================================================
        // 2. AQUÍ GUARDAMOS LOS DATOS SI MARCÓ LA CASILLA
        // ========================================================
        SharedPreferences prefs = await SharedPreferences.getInstance();
        
        if (_recordarUsuario) {
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('rolUsuario', 'ADMINISTRADOR'); 
          await prefs.setString('usuarioGuardado', usuario); // Guardamos su nombre de usuario
          await prefs.setBool('recordarCheckbox', true); // Recordamos que dejó el check marcado
        } else {
          // Si desmarcó la casilla, olvidamos su usuario para la próxima vez
          await prefs.remove('usuarioGuardado');
          await prefs.setBool('recordarCheckbox', false);
        }
        // ========================================================

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Conexión exitosa! ✅'), 
              backgroundColor: Colors.green
            ),
          );

          // Viajamos al Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DashboardScreen(rolUsuario: 'ADMINISTRADOR'),
            ),
          );
        }

      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuario o contraseña incorrectos'), 
              backgroundColor: Colors.red
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de red: No se pudo contactar al servidor'), 
            backgroundColor: Colors.red
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/logoDragon.png', 
                      height: 120,
                      width: 120,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "DragonRES",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: copperPrimary,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontFamily: 'Serif',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Sistema de Gestión de Restaurante",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textLight.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 48),

                    _buildTextField(
                      controller: _userController,
                      label: "Ingresar Usuario",
                      icon: Icons.person_outline,
                      obscureText: false,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _passwordController,
                      label: "Contraseña",
                      icon: Icons.lock_outline,
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),

                    // CHECKBOX DE RECORDAR USUARIO
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _recordarUsuario,
                          activeColor: copperPrimary, 
                          onChanged: (bool? value) {
                            setState(() {
                              _recordarUsuario = value ?? false;
                            });
                          },
                        ),
                        const Text(
                          'Recordar mis datos',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    Container(
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [copperPrimary, copperDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: copperPrimary.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _conectarAPI, 
                        child: const Text(
                          "INICIAR SESIÓN",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscureText,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: textLight),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textLight.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: copperPrimary),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: copperPrimary.withOpacity(0.3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: copperPrimary, width: 2),
        ),
      ),
    );
  }
}