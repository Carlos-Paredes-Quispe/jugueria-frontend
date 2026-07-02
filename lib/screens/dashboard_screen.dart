import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jugueria/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../tema_global.dart';

import 'caja_screen.dart';
import 'cocina_screen.dart';
import 'config_impresoras_screen.dart';
import 'login_screen.dart';
import 'productos_screen.dart';
import 'punto_venta_screen.dart';
import 'reportes_screen.dart';
import 'usuarios_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String rolUsuario;

  const DashboardScreen({
    super.key,
    this.rolUsuario = 'ADMINISTRADOR',
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _indiceSeleccionado = 0;
  bool _menuExpandido = true;
  String _nombreUsuarioLogueado = 'Cargando...';

  bool get _esAdmin => widget.rolUsuario.toUpperCase() == 'ADMINISTRADOR';

  @override
  void initState() {
    super.initState();
    _obtenerUsuarioLogueado();
  }

  Future<void> _obtenerUsuarioLogueado() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _nombreUsuarioLogueado =
          prefs.getString('usuarioLogueado') ??
          prefs.getString('usuarioGuardado') ??
          widget.rolUsuario;
    });
  }

  List<_MenuItemDashboard> _itemsMenu() {
    final List<_MenuItemDashboard> items = [
      _MenuItemDashboard(
        indice: 0,
        icono: Icons.money,
        titulo: 'Caja',
      ),
      _MenuItemDashboard(
        indice: 1,
        icono: Icons.point_of_sale,
        titulo: 'Punto de Venta',
      ),
      _MenuItemDashboard(
        indice: 2,
        icono: Icons.blender,
        titulo: 'Pedidos / Cocina',
      ),
    ];

    if (_esAdmin) {
      items.addAll([
        _MenuItemDashboard(
          indice: 3,
          icono: Icons.inventory_2_outlined,
          titulo: 'Productos',
        ),
        _MenuItemDashboard(
          indice: 4,
          icono: Icons.group,
          titulo: 'Usuarios',
        ),
        _MenuItemDashboard(
          indice: 5,
          icono: Icons.bar_chart,
          titulo: 'Reportes',
        ),
        _MenuItemDashboard(
          indice: 6,
          icono: Icons.print,
          titulo: 'Configurar Impresora',
        ),
      ]);
    }

    return items;
  }

  String _tituloActual() {
    final item = _itemsMenu().where((e) => e.indice == _indiceSeleccionado);
    if (item.isEmpty) return 'DragonRES';
    return item.first.titulo;
  }

  Future<bool> _hayCajaAbierta() async {
    try {
      final response = await http
          .get(
            ApiConfig.uri('/caja/actual'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body == 'null') {
          return false;
        }

        final data = jsonDecode(response.body);
        return data != null;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cerrarSesionConValidacion() async {
    final bool cajaAbierta = await _hayCajaAbierta();

    if (!mounted) return;

    if (cajaAbierta) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Caja abierta'),
          content: const Text(
            'No puedes cerrar sesión mientras la caja esté abierta. Primero debes cerrar caja y generar el cierre del turno.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.naranjaLogo,
              ),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _indiceSeleccionado = 0;
                });
              },
              child: const Text(
                'Ir a caja',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('rolUsuario');
    await prefs.remove('accessToken');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _seleccionarMenu(int indice, {bool cerrarDrawer = false}) {
    setState(() {
      _indiceSeleccionado = indice;
    });

    if (cerrarDrawer && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        final Color mainBgColor =
            isDark ? AppColores.fondoOscuro : AppColores.fondoClaro;
        final Color sidebarBgColor =
            isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara;
        final Color textColor =
            isDark ? AppColores.textoOscuro : AppColores.textoClaro;
        final Color textLightColor = isDark
            ? AppColores.textoOscuroSecundario
            : AppColores.textoClaroSecundario;

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool esCelular = constraints.maxWidth < 760;

            if (esCelular) {
              return _buildMobileLayout(
                mainBgColor: mainBgColor,
                sidebarBgColor: sidebarBgColor,
                textColor: textColor,
                textLightColor: textLightColor,
              );
            }

            return _buildTabletLayout(
              mainBgColor: mainBgColor,
              sidebarBgColor: sidebarBgColor,
              textColor: textColor,
              textLightColor: textLightColor,
              isDark: isDark,
            );
          },
        );
      },
    );
  }

  Widget _buildMobileLayout({
    required Color mainBgColor,
    required Color sidebarBgColor,
    required Color textColor,
    required Color textLightColor,
  }) {
    return Scaffold(
      backgroundColor: mainBgColor,
      appBar: AppBar(
        backgroundColor: sidebarBgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          _tituloActual(),
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDarkModeGlobal.value ? Icons.light_mode : Icons.dark_mode,
              color: AppColores.naranjaLogo,
            ),
            onPressed: () {
              isDarkModeGlobal.value = !isDarkModeGlobal.value;
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: sidebarBgColor,
        child: SafeArea(
          child: _buildMenuContenido(
            textColor: textColor,
            textLightColor: textLightColor,
            expandido: true,
            esDrawer: true,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _mostrarPantallaCentral(textColor),
        ),
      ),
    );
  }

  Widget _buildTabletLayout({
    required Color mainBgColor,
    required Color sidebarBgColor,
    required Color textColor,
    required Color textLightColor,
    required bool isDark,
  }) {
    return Scaffold(
      backgroundColor: mainBgColor,
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: _menuExpandido ? 250 : 82,
            decoration: BoxDecoration(
              color: sidebarBgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
                  blurRadius: 15,
                  offset: const Offset(3, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: _buildMenuContenido(
                textColor: textColor,
                textLightColor: textLightColor,
                expandido: _menuExpandido,
                esDrawer: false,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _buildHeaderSuperior(textColor, textLightColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 24,
                    ),
                    child: _mostrarPantallaCentral(textColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuContenido({
    required Color textColor,
    required Color textLightColor,
    required bool expandido,
    required bool esDrawer,
  }) {
    final Color dividerColor =
        isDarkModeGlobal.value ? Colors.white24 : textLightColor.withOpacity(0.22);

    return Column(
      children: [
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment:
                expandido ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
            children: [
              if (expandido)
                IconButton(
                  icon: Icon(
                    isDarkModeGlobal.value ? Icons.light_mode : Icons.dark_mode,
                    color: AppColores.naranjaLogo,
                  ),
                  onPressed: () {
                    isDarkModeGlobal.value = !isDarkModeGlobal.value;
                  },
                  tooltip: 'Cambiar tema',
                ),
              if (!esDrawer)
                IconButton(
                  icon: Icon(Icons.menu, color: textColor),
                  onPressed: () {
                    setState(() {
                      _menuExpandido = !_menuExpandido;
                    });
                  },
                ),
              if (esDrawer)
                IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: expandido ? 74 : 40,
          child: Image.asset(
            'assets/images/logoJugueria.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.local_drink,
              size: 40,
              color: AppColores.naranjaLogo,
            ),
          ),
        ),

        if (expandido) ...[
          const SizedBox(height: 10),
          Text(
            'VERASALUD',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.rolUsuario,
            style: TextStyle(
              color: textLightColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],

        const SizedBox(height: 28),

        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              for (final item in _itemsMenu()) ...[
                if (_esAdmin && item.indice == 3)
                  Divider(
                    color: dividerColor,
                    height: 34,
                    indent: expandido ? 20 : 10,
                    endIndent: expandido ? 20 : 10,
                  ),
                _crearBotonMenu(
                  item.indice,
                  item.icono,
                  item.titulo,
                  textColor,
                  textLightColor,
                  expandido: expandido,
                  cerrarDrawer: esDrawer,
                ),
              ],
            ],
          ),
        ),

        InkWell(
          onTap: _cerrarSesionConValidacion,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment:
                  expandido ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                if (expandido) const SizedBox(width: 16),
                const Icon(Icons.logout, color: Colors.redAccent),
                if (expandido) ...[
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Cerrar Sesión',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSuperior(Color textColor, Color textLightColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(
            Icons.account_circle,
            color: AppColores.naranjaLogo,
            size: 28,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _nombreUsuarioLogueado,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.rolUsuario,
                style: TextStyle(
                  color: textLightColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _crearBotonMenu(
    int indice,
    IconData icono,
    String titulo,
    Color textColor,
    Color textLightColor, {
    required bool expandido,
    required bool cerrarDrawer,
  }) {
    final bool estaSeleccionado = _indiceSeleccionado == indice;

    return InkWell(
      onTap: () => _seleccionarMenu(
        indice,
        cerrarDrawer: cerrarDrawer,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: EdgeInsets.symmetric(
          vertical: 12,
          horizontal: expandido ? 16 : 0,
        ),
        decoration: BoxDecoration(
          color: estaSeleccionado
              ? AppColores.naranjaLogo.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: estaSeleccionado
                ? AppColores.naranjaLogo
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment:
              expandido ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(
              icono,
              color: estaSeleccionado
                  ? AppColores.naranjaLogo
                  : textLightColor,
            ),
            if (expandido) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    color: estaSeleccionado
                        ? AppColores.naranjaLogo
                        : textColor,
                    fontWeight:
                        estaSeleccionado ? FontWeight.w900 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mostrarPantallaCentral(Color textColor) {
    if (!_esAdmin && _indiceSeleccionado > 2) {
      _indiceSeleccionado = 0;
    }

    switch (_indiceSeleccionado) {
      case 0:
        return const CajaScreen();
      case 1:
        return const PuntoVentaScreen();
      case 2:
        return const CocinaScreen();
      case 3:
        return const ProductosScreen();
      case 4:
        return const UsuariosScreen();
      case 5:
        return const ReportesScreen();
      case 6:
        return const ConfigImpresorasScreen();
      default:
        return Center(
          child: Text(
            'Seleccione una opción',
            style: TextStyle(
              color: textColor,
              fontSize: 22,
            ),
          ),
        );
    }
  }
}

class _MenuItemDashboard {
  final int indice;
  final IconData icono;
  final String titulo;

  _MenuItemDashboard({
    required this.indice,
    required this.icono,
    required this.titulo,
  });
}