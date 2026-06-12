import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Asegúrate de que estas rutas coincidan con la ubicación de tus archivos
import 'login_screen.dart'; 
import 'vista_sillas.dart';
import 'productos_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  final String rolUsuario;

  const DashboardScreen({Key? key, this.rolUsuario = 'ADMINISTRADOR'}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Colores de tu marca
  final Color darkBackground = const Color(0xFF0A0A0A);
  final Color sidebarBackground = const Color(0xFF1A1A1A);
  final Color copperPrimary = const Color(0xFFC07C46); 
  final Color textLight = Colors.white70;

  int _indiceSeleccionado = 0; 
  bool _menuExpandido = true; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      body: Row(
        children: [
          // ==========================================
          // 1. MENÚ LATERAL ANIMADO (SIDEBAR)
          // ==========================================
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _menuExpandido ? 250 : 80, 
            color: sidebarBackground,
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Botón de hamburguesa para expandir/contraer
                Align(
                  alignment: _menuExpandido ? Alignment.centerRight : Alignment.center,
                  child: IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _menuExpandido = !_menuExpandido;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Logo dinámico
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _menuExpandido ? 80 : 40,
                  // Asegúrate de que esta ruta sea correcta para tu logo
                  child: Image.asset('assets/images/logoJugueriafondo.png', fit: BoxFit.contain), 
                ),
                
                // Título (solo visible si está expandido)
                if (_menuExpandido) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'DragonRES',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 40),

                // Botones del menú
                _crearBotonMenu(0, Icons.chair_alt, 'Sillas'),
                _crearBotonMenu(1, Icons.blender, 'Pedidos'), 
                _crearBotonMenu(2, Icons.point_of_sale, 'Punto de Venta'),
                
                // Opciones exclusivas del Administrador
                if (widget.rolUsuario == 'ADMINISTRADOR') ...[
                  Divider(color: Colors.white24, height: 40, indent: _menuExpandido ? 20 : 10, endIndent: _menuExpandido ? 20 : 10),
                  _crearBotonMenu(3, Icons.inventory_2_outlined, 'Productos'), // <-- Tu nueva pantalla
                  _crearBotonMenu(4, Icons.bar_chart, 'Reportes'), 
                ],

                const Spacer(),
                
                // ==========================================
                // BOTÓN DE CERRAR SESIÓN (ACTUALIZADO)
                // ==========================================
                InkWell(
                  onTap: () async {
                    // 1. Abrimos la memoria local
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    
                    // 2. Apagamos la sesión pero SIN borrar el 'usuarioGuardado'
                    await prefs.setBool('isLoggedIn', false); 
                    await prefs.remove('rolUsuario');
                    
                    // 3. Regresamos al Login destruyendo el historial de pantallas
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
                          const Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent)),
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
              child: _mostrarPantallaCentral(),
            ),
          ),
        ],
      ),
    );
  }

  // Función para crear los botones del menú lateral
  Widget _crearBotonMenu(int indice, IconData icono, String titulo) {
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
          color: estaSeleccionado ? copperPrimary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: estaSeleccionado ? copperPrimary : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: _menuExpandido ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(icono, color: estaSeleccionado ? copperPrimary : textLight),
            if (_menuExpandido) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    color: estaSeleccionado ? copperPrimary : textLight,
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
  Widget _mostrarPantallaCentral() {
    switch (_indiceSeleccionado) {
      case 0:
        return const VistaSillas();
      case 1:
        return const Center(child: Text('🍹 Pantalla de Pedidos', style: TextStyle(color: Colors.white, fontSize: 24)));
      case 2:
        return const Center(child: Text('💰 Punto de Venta', style: TextStyle(color: Colors.white, fontSize: 24)));
      case 3:
        return const ProductosScreen(); // <-- AQUÍ CARGA TU INVENTARIO
      case 4:
        return const Center(child: Text('📊 Reportes Administrativos', style: TextStyle(color: Colors.white, fontSize: 24)));
      default:
        return const Center(child: Text('Seleccione una opción', style: TextStyle(color: Colors.white, fontSize: 24)));
    }
  }
}