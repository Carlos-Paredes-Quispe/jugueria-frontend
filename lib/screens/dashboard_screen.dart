import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tema_global.dart'; // <-- IMPORTAMOS LA VARIABLE GLOBAL

import 'login_screen.dart'; 
import 'vista_sillas.dart';
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
  // Color principal de marca que no cambia
  final Color copperPrimary = const Color(0xFFC07C46); 

  int _indiceSeleccionado = 0; 
  bool _menuExpandido = true; 

  @override
  Widget build(BuildContext context) {
    // ENVOLVEMOS EL DASHBOARD EN EL ESCUCHADOR GLOBAL
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {

        // ==========================================
        // PALETA DINÁMICA DE COLORES
        // ==========================================
        final Color mainBgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFE8EAED);
        final Color sidebarBgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
        final Color textColor = isDark ? Colors.white : const Color(0xFF222222);
        final Color textLightColor = isDark ? Colors.white70 : Colors.black54;
        final Color dividerColor = isDark ? Colors.white24 : Colors.black12;

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
                color: sidebarBgColor, // <--- Color dinámico
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Fila superior: Modo Claro/Oscuro y Botón Hamburguesa
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: _menuExpandido ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                        children: [
                          // Botón del Tema (Solo visible si está expandido o podrías dejarlo siempre)
                          if (_menuExpandido)
                            IconButton(
                              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: copperPrimary),
                              onPressed: () {
                                isDarkModeGlobal.value = !isDarkModeGlobal.value;
                              },
                              tooltip: 'Cambiar tema',
                            ),
                            
                          // Botón Hamburguesa
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

                    // Logo dinámico
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _menuExpandido ? 80 : 40,
                      child: Image.asset('assets/images/logoJugueriafondo.png', fit: BoxFit.contain), 
                    ),
                    
                    // Título (solo visible si está expandido)
                    if (_menuExpandido) ...[
                      const SizedBox(height: 10),
                      Text(
                        'DragonRES',
                        style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 40),

                    // Botones del menú
                    _crearBotonMenu(0, Icons.chair_alt, 'Sillas', textColor, textLightColor),
                    _crearBotonMenu(1, Icons.blender, 'Pedidos', textColor, textLightColor), 
                    _crearBotonMenu(2, Icons.point_of_sale, 'Punto de Venta', textColor, textLightColor),
                    
                    // Opciones exclusivas del Administrador
                    if (widget.rolUsuario == 'ADMINISTRADOR') ...[
                      Divider(color: dividerColor, height: 40, indent: _menuExpandido ? 20 : 10, endIndent: _menuExpandido ? 20 : 10),
                      _crearBotonMenu(3, Icons.inventory_2_outlined, 'Productos', textColor, textLightColor),
                      _crearBotonMenu(4, Icons.bar_chart, 'Reportes', textColor, textLightColor), 
                      _crearBotonMenu(5, Icons.print, 'Configurar Impresora', textColor, textLightColor), 
                    ],

                    const Spacer(),
                    
                    // ==========================================
                    // BOTÓN DE CERRAR SESIÓN
                    // ==========================================
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
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  child: _mostrarPantallaCentral(textColor),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  // Función actualizada para recibir los colores del tema
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
          color: estaSeleccionado ? copperPrimary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: estaSeleccionado ? copperPrimary : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: _menuExpandido ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(icono, color: estaSeleccionado ? copperPrimary : textLightColor),
            if (_menuExpandido) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    color: estaSeleccionado ? copperPrimary : textColor,
                    fontWeight: estaSeleccionado ? FontWeight.bold : FontWeight.normal,
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

  // Controlador de las pantallas
  Widget _mostrarPantallaCentral(Color textColor) {
    switch (_indiceSeleccionado) {
      case 0:
        return const VistaSillas();
      case 1:
        return const CocinaScreen();
      case 2:
        return const PuntoVentaScreen();
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