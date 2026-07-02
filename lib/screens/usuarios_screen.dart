import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jugueria/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../tema_global.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  bool _isLoading = true;
  bool _creando = false;

  List<dynamic> _usuarios = [];
  List<dynamic> _roles = [];

  int? _rolSeleccionado;

  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';

    return {
      if (json) 'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  String _mensajeBackend(String body) {
    try {
      final data = jsonDecode(body);

      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }

      if (data is Map && data['mensaje'] != null) {
        return data['mensaje'].toString();
      }

      return body;
    } catch (_) {
      return body;
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

  int? _idRol(dynamic rol) {
    return int.tryParse(rol['id'].toString());
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final headers = await _headers();

      final rolesResponse = await http
          .get(
            ApiConfig.uri('/auth/roles'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      final usuariosResponse = await http
          .get(
            ApiConfig.uri('/auth/usuarios'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (rolesResponse.statusCode == 200 &&
          usuariosResponse.statusCode == 200) {
        final roles = jsonDecode(rolesResponse.body);
        final usuarios = jsonDecode(usuariosResponse.body);

        setState(() {
          _roles = roles is List ? roles : [];
          _usuarios = usuarios is List ? usuarios : [];

          if (_roles.isNotEmpty && _rolSeleccionado == null) {
            _rolSeleccionado = _idRol(_roles.first);
          }

          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });

        _mostrarMensaje(
          'No se pudo cargar usuarios: ${_mensajeBackend(usuariosResponse.body)}',
          Colors.redAccent,
        );
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _mostrarMensaje(
        'Tiempo agotado al cargar usuarios.',
        Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _mostrarMensaje(
        'Error al cargar usuarios: $e',
        Colors.redAccent,
      );
    }
  }

  Future<void> _crearUsuario() async {
    if (_creando) return;

    final String usuario = _usuarioController.text.trim();
    final String contrasena = _contrasenaController.text.trim();

    if (usuario.length < 3) {
      _mostrarMensaje(
        'El usuario debe tener al menos 3 caracteres.',
        Colors.redAccent,
      );
      return;
    }

    if (contrasena.length < 6) {
      _mostrarMensaje(
        'La contraseña debe tener al menos 6 caracteres.',
        Colors.redAccent,
      );
      return;
    }

    if (_rolSeleccionado == null) {
      _mostrarMensaje(
        'Selecciona un rol.',
        Colors.redAccent,
      );
      return;
    }

    setState(() {
      _creando = true;
    });

    try {
      final response = await http
          .post(
            ApiConfig.uri('/auth/usuarios'),
            headers: await _headers(json: true),
            body: jsonEncode({
              'usuario': usuario,
              'contrasena': contrasena,
              'rolId': _rolSeleccionado,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _usuarioController.clear();
        _contrasenaController.clear();

        _mostrarMensaje(
          'Usuario creado correctamente ✅',
          Colors.green,
        );

        await _cargarDatos();
      } else {
        _mostrarMensaje(
          'No se pudo crear usuario: ${_mensajeBackend(response.body)}',
          Colors.redAccent,
        );
      }
    } on TimeoutException {
      if (!mounted) return;

      _mostrarMensaje(
        'Tiempo agotado al crear usuario.',
        Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error al crear usuario: $e',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _creando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        final Color textColor =
            isDark ? AppColores.textoOscuro : AppColores.textoClaro;
        final Color cardColor =
            isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara;
        final Color bgColor =
            isDark ? AppColores.fondoOscuro : AppColores.fondoClaro;

        if (_isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColores.naranjaLogo,
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool esCelular = constraints.maxWidth < 760;
            final double tecladoAltura = MediaQuery.of(context).viewInsets.bottom;

            if (esCelular) {
              return Container(
                color: bgColor,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(
                    left: 4,
                    right: 4,
                    top: 4,
                    bottom: tecladoAltura + 24,
                  ),
                  child: Column(
                    children: [
                      _buildFormulario(
                        cardColor: cardColor,
                        textColor: textColor,
                        esCelular: true,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 540,
                        child: _buildListado(
                          cardColor: cardColor,
                          textColor: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              color: bgColor,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildFormulario(
                      cardColor: cardColor,
                      textColor: textColor,
                      esCelular: false,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 6,
                    child: _buildListado(
                      cardColor: cardColor,
                      textColor: textColor,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormulario({
    required Color cardColor,
    required Color textColor,
    required bool esCelular,
  }) {
    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: EdgeInsets.all(esCelular ? 20 : 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: esCelular ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Text(
              'Crear Usuario',
              style: TextStyle(
                color: textColor,
                fontSize: esCelular ? 22 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Solo el administrador puede crear nuevos usuarios para caja, cocina o atención.',
              style: TextStyle(
                color: textColor.withOpacity(0.65),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: _usuarioController,
              style: TextStyle(color: textColor),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Usuario',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _contrasenaController,
              obscureText: true,
              style: TextStyle(color: textColor),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _crearUsuario(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<int>(
              value: _rolSeleccionado,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Rol',
                prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _roles.map((rol) {
                return DropdownMenuItem<int>(
                  value: _idRol(rol),
                  child: Text(rol['nombre']?.toString() ?? '-'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _rolSeleccionado = value;
                });
              },
            ),

            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.naranjaLogo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _creando ? null : _crearUsuario,
                icon: _creando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_add, color: Colors.white),
                label: Text(
                  _creando ? 'CREANDO...' : 'CREAR USUARIO',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListado({
    required Color cardColor,
    required Color textColor,
  }) {
    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usuarios Registrados',
              style: TextStyle(
                color: textColor,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Listado de usuarios que pueden ingresar al sistema.',
              style: TextStyle(
                color: textColor.withOpacity(0.65),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 18),

            Expanded(
              child: _usuarios.isEmpty
                  ? Center(
                      child: Text(
                        'No hay usuarios registrados.',
                        style: TextStyle(color: textColor.withOpacity(0.65)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargarDatos,
                      child: ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: _usuarios.length,
                        separatorBuilder: (_, __) => const Divider(height: 18),
                        itemBuilder: (context, index) {
                          final usuario = _usuarios[index] is Map
                              ? Map<String, dynamic>.from(_usuarios[index])
                              : <String, dynamic>{};

                          final rol = usuario['rol'] is Map
                              ? Map<String, dynamic>.from(usuario['rol'])
                              : <String, dynamic>{};

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColores.naranjaLogo.withOpacity(0.12),
                              child: const Icon(
                                Icons.person,
                                color: AppColores.naranjaLogo,
                              ),
                            ),
                            title: Text(
                              usuario['usuario']?.toString() ?? '-',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              rol['nombre']?.toString() ?? '-',
                              style: TextStyle(
                                color: textColor.withOpacity(0.65),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'ACTIVO',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}