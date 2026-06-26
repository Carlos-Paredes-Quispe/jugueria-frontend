import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tema_global.dart'; // <-- PALETA DE COLORES GLOBAL

import 'caja_screen.dart';
import 'login_screen.dart'; 
import 'productos_screen.dart'; 
import 'cocina_screen.dart';
import 'punto_venta_screen.dart';
import 'config_impresoras_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String rolUsuario;

  const DashboardScreen({super.key, this.rolUsuario = 'ADMINISTRADOR'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Inicializamos en el índice 0, que ahora corresponderá directamente a Punto de Venta
  int _indiceSeleccionado = 0; 
  bool _menuExpandido = true; 
  String _nombreUsuarioLogueado = "Cargando..."; 

  @override
  void initState() {
    super.initState();
    _obtenerUsuarioLogueado();
  }

  Future<void> _obtenerUsuarioLogueado() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _nombreUsuarioLogueado = prefs.getString('usuarioGuardado') ?? widget.rolUsuario;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {

        final Color mainBgColor = isDark ? AppColores.fondoOscuro : AppColores.fondoClaro; 
        final Color sidebarBgColor = isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara; 
        final Color textColor = isDark ? AppColores.textoOscuro : AppColores.textoClaro; 
        final Color textLightColor = isDark ? AppColores.textoOscuroSecundario : AppColores.textoClaroSecundario;
        final Color dividerColor = isDark ? Colors.white24 : AppColores.textoClaroSecundario.withValues(alpha: 0.2);

        return Scaffold(
          backgroundColor: mainBgColor,
          body: Row(
            children: [
              // ==========================================
              // 1. MENÚ LATERAL ANIMADO (SIDEBAR)
              // ==========================================
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: _menuExpandido ? 250 : 80, 
                decoration: BoxDecoration(
                  color: sidebarBgColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.04), 
                      blurRadius: 15,
                      offset: const Offset(3, 0),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: _menuExpandido ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                        children: [
                          if (_menuExpandido)
                            IconButton(
                              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: AppColores.naranjaLogo),
                              onPressed: () {
                                isDarkModeGlobal.value = !isDarkModeGlobal.value;
                              },
                              tooltip: 'Cambiar tema',
                            ),
                          IconButton(
                            icon: Icon(Icons.menu, color: textColor),
                            onPressed: () {
                              setState(() {
                                _menuExpandido = !_menuExpandido;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _menuExpandido ? 80 : 40,
                      child: Image.asset(
                        'assets/images/logoJugueriafondo.png', 
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => 
                            const Icon(Icons.local_drink, size: 40, color: AppColores.naranjaLogo),
                      ), 
                    ),
                    
                    if (_menuExpandido) ...[
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
                    ],
                    const SizedBox(height: 40),

                    // 🔥 MENÚ REORGANIZADO: Quitamos "Sillas" y "Punto de Venta" pasa al índice 0
                    _crearBotonMenu(0, Icons.money, 'Caja', textColor, textLightColor),
                    _crearBotonMenu(1, Icons.point_of_sale, 'Punto de Venta', textColor, textLightColor),
                    _crearBotonMenu(2, Icons.blender, 'Pedidos / Cocina', textColor, textLightColor), 
                    
                    if (widget.rolUsuario == 'ADMINISTRADOR') ...[
                      Divider(color: dividerColor, height: 40, indent: _menuExpandido ? 20 : 10, endIndent: _menuExpandido ? 20 : 10),
                      _crearBotonMenu(3, Icons.inventory_2_outlined, 'Productos', textColor, textLightColor),
                      _crearBotonMenu(4, Icons.bar_chart, 'Reportes', textColor, textLightColor), 
                      _crearBotonMenu(5, Icons.print, 'Configurar Impresora', textColor, textLightColor), 
                    ],

                    const Spacer(),
                    
                    InkWell(
                      onTap: () async {
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('isLoggedIn', false); 
                        await prefs.remove('rolUsuario');
                        
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()), 
                            (route) => false, 
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: _menuExpandido ? MainAxisAlignment.start : MainAxisAlignment.center,
                          children: [
                            if (_menuExpandido) const SizedBox(width: 16),
                            const Icon(Icons.logout, color: Colors.redAccent),
                            if (_menuExpandido) ...[
                              const SizedBox(width: 16),
                              const Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ==========================================
              // 2. ÁREA CENTRAL 
              // ==========================================
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      color: Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.account_circle, color: AppColores.naranjaLogo, size: 28),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _nombreUsuarioLogueado,
                                style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                widget.rolUsuario,
                                style: TextStyle(color: textLightColor, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
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
    );
  }

  Widget _crearBotonMenu(int indice, IconData icono, String titulo, Color textColor, Color textLightColor) {
    final bool estaSeleccionado = _indiceSeleccionado == indice;

    return InkWell(
      onTap: () {
        setState(() {
          _indiceSeleccionado = indice;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: _menuExpandido ? 16 : 0),
        decoration: BoxDecoration(
          color: estaSeleccionado ? AppColores.naranjaLogo.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: estaSeleccionado ? AppColores.naranjaLogo : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: _menuExpandido ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(icono, color: estaSeleccionado ? AppColores.naranjaLogo : textLightColor),
            if (_menuExpandido) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    color: estaSeleccionado ? AppColores.naranjaLogo : textColor,
                    fontWeight: estaSeleccionado ? FontWeight.w900 : FontWeight.w500,
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

  // 🔥 CONTROLADOR DE PANTALLAS CON RUTA CENTRALIZADA
  Widget _mostrarPantallaCentral(Color textColor) {
    switch (_indiceSeleccionado) {
      case 0:
        // Ahora "Punto de Venta" es el encargado de arrancar mostrando las sillas internamente
        return const CajaScreen();
      case 1:
        return const PuntoVentaScreen();
      case 2:
        return const CocinaScreen();
      case 3:
        return const ProductosScreen();
      case 4:
        return Center(child: Text('📊 Reportes Administrativos', style: TextStyle(color: textColor, fontSize: 24))); 
      case 5:
        return const ConfigImpresorasScreen();
      default:
        return Center(child: Text('Seleccione una opción', style: TextStyle(color: textColor, fontSize: 24)));
    }
  }
}