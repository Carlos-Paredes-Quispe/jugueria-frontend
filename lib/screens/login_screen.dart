import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jugueria/config/api_config.dart';
import 'package:flutter_jugueria/main.dart';
import 'package:flutter_jugueria/screens/dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../tema_global.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _recordarUsuario = false;
  bool _isLoading = false;
  bool _ocultarPassword = true;

  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    mostrarSoporteGlobal.value = false;
    _cargarDatosGuardados();
  }

  @override
  void dispose() {
    mostrarSoporteGlobal.value = true;
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosGuardados() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _recordarUsuario = prefs.getBool('recordarCheckbox') ?? false;

      if (_recordarUsuario) {
        _userController.text = prefs.getString('usuarioGuardado') ?? '';
      }
    });
  }

  Future<void> _conectarAPI() async {
    final String usuario = _userController.text.trim();
    final String password = _passwordController.text.trim();

    if (usuario.isEmpty || password.isEmpty) {
      _mostrarMensaje(
        'Por favor, ingrese usuario y contraseña',
        Colors.redAccent,
      );
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .post(
            ApiConfig.uri('/auth/login'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'usuario': usuario,
              'contrasena': password,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        final String rol = data['rol']?.toString() ?? 'ADMINISTRADOR';
        final String token = data['access_token']?.toString() ?? '';
        final String usuarioBackend = data['usuario']?.toString() ?? usuario;

        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('rolUsuario', rol);
        await prefs.setString('usuarioLogueado', usuarioBackend);

        if (token.isNotEmpty) {
          await prefs.setString('accessToken', token);
        }

        if (_recordarUsuario) {
          await prefs.setString('usuarioGuardado', usuario);
          await prefs.setBool('recordarCheckbox', true);
        } else {
          await prefs.remove('usuarioGuardado');
          await prefs.setBool('recordarCheckbox', false);
        }

        if (!mounted) return;

        _mostrarMensaje(
          '¡Conexión exitosa! ✅',
          AppColores.verdeLogo,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(rolUsuario: rol),
          ),
        );
      } else {
        _mostrarMensaje(
          'Usuario o contraseña incorrectos',
          Colors.redAccent,
        );
      }
    } on TimeoutException {
      if (!mounted) return;

      _mostrarMensaje(
        'Tiempo agotado. Revisa si el backend está encendido.',
        Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error de red: No se pudo contactar al servidor',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        final Color bgColor =
            isDark ? AppColores.fondoOscuro : AppColores.fondoClaro;
        final Color cardColor =
            isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara;
        final Color textColor =
            isDark ? AppColores.textoOscuro : AppColores.textoClaro;
        final Color subtitleColor = isDark
            ? AppColores.textoOscuroSecundario
            : AppColores.textoClaroSecundario;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: bgColor,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bool esCelular = constraints.maxWidth < 650;
              final double cardWidth = esCelular
                  ? constraints.maxWidth - 28
                  : 460;

              final double paddingHorizontal = esCelular ? 24 : 40;
              final double paddingVertical = esCelular ? 28 : 48;
              final double logoHeight = esCelular ? 74 : 92;
              final double tituloSize = esCelular ? 21 : 26;
              final double subtituloSize = esCelular ? 14 : 16;

              return Stack(
                children: [
                  SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.symmetric(
                          horizontal: esCelular ? 14 : 20,
                          vertical: esCelular ? 16 : 24,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: cardWidth,
                          ),
                          child: Container(
                            width: cardWidth,
                            padding: EdgeInsets.symmetric(
                              horizontal: paddingHorizontal,
                              vertical: paddingVertical,
                            ),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(
                                esCelular ? 24 : 30,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    isDark ? 0.55 : 0.06,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/logoJugueria.png',
                                  height: logoHeight,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    Icons.local_drink,
                                    size: logoHeight - 16,
                                    color: AppColores.naranjaLogo,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  'JUGUERÍA VERASALUD',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: tituloSize,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                    letterSpacing: 1.2,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  'Sistema de Gestión de Juguería',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: subtituloSize,
                                  ),
                                ),

                                SizedBox(height: esCelular ? 28 : 38),

                                _buildTextField(
                                  controller: _userController,
                                  label: 'Usuario',
                                  icon: Icons.person_outline,
                                  obscureText: false,
                                  isDark: isDark,
                                  textInputAction: TextInputAction.next,
                                ),

                                const SizedBox(height: 18),

                                _buildTextField(
                                  controller: _passwordController,
                                  label: 'Contraseña',
                                  icon: Icons.lock_outline,
                                  obscureText: _ocultarPassword,
                                  isDark: isDark,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _conectarAPI(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _ocultarPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColores.naranjaLogo,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _ocultarPassword = !_ocultarPassword;
                                      });
                                    },
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Checkbox(
                                      value: _recordarUsuario,
                                      activeColor: AppColores.naranjaLogo,
                                      side: BorderSide(
                                        color: textColor.withOpacity(0.45),
                                      ),
                                      onChanged: _isLoading
                                          ? null
                                          : (bool? value) {
                                              setState(() {
                                                _recordarUsuario =
                                                    value ?? false;
                                              });
                                            },
                                    ),
                                    Flexible(
                                      child: Text(
                                        'Recordar mis datos',
                                        style: TextStyle(color: textColor),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: esCelular ? 24 : 30),

                                SizedBox(
                                  height: 54,
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColores.naranjaLogo,
                                      elevation: 3,
                                      shadowColor: AppColores.naranjaLogo
                                          .withOpacity(0.45),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    onPressed:
                                        _isLoading ? null : _conectarAPI,
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 23,
                                            width: 23,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'INGRESAR',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                  ),
                                ),

                                SizedBox(height: esCelular ? 34 : 48),

                                Column(
                                  children: [
                                    Text(
                                      'Powered by',
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Image.asset(
                                      'assets/images/logoDragon.png',
                                      height: esCelular ? 42 : 50,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                        Icons.local_fire_department,
                                        color: AppColores.naranjaLogo,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'DragonPOS',
                                      style: TextStyle(
                                        fontSize: esCelular ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
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
                  ),

                  Positioned(
                    top: 14,
                    right: 14,
                    child: SafeArea(
                      child: IconButton(
                        iconSize: 28,
                        icon: Icon(
                          isDark ? Icons.light_mode : Icons.dark_mode,
                          color: AppColores.naranjaLogo,
                        ),
                        onPressed: () {
                          isDarkModeGlobal.value = !isDarkModeGlobal.value;
                        },
                        tooltip: 'Cambiar tema',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscureText,
    required bool isDark,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
    Widget? suffixIcon,
  }) {
    final Color inputTextColor =
        isDark ? AppColores.textoOscuro : AppColores.textoClaro;
    final Color hintColor = isDark
        ? AppColores.textoOscuroSecundario
        : AppColores.textoClaroSecundario;
    final Color fillColor =
        isDark ? Colors.white.withOpacity(0.05) : Colors.white;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: inputTextColor),
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hintColor),
        prefixIcon: Icon(icon, color: AppColores.naranjaLogo),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: AppColores.textoClaroSecundario.withOpacity(0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: AppColores.naranjaLogo,
            width: 2,
          ),
        ),
      ),
    );
  }
}