import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jugueria/screens/dashboard_screen.dart';
import 'package:flutter_jugueria/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ========================================================
// 🔥 NUEVA VARIABLE GLOBAL PARA CONTROLAR LA VISIBILIDAD
// ========================================================
final ValueNotifier<bool> mostrarSoporteGlobal = ValueNotifier<bool>(true);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String rolUsuario = prefs.getString('rolUsuario') ?? 'ADMINISTRADOR';

  runApp(MyApp(isLoggedIn: isLoggedIn, rolUsuario: rolUsuario));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String rolUsuario;

  const MyApp({super.key, required this.isLoggedIn, required this.rolUsuario});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DragonRES',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      
      builder: (context, child) {
        return Stack(
          children: [
            ?child,
            
            // Posicionamos el contenedor del botón
            Positioned(
              right: 20, 
              bottom: 20,
              // Escucha si debe mostrarse u ocultarse
              child: ValueListenableBuilder<bool>(
                valueListenable: mostrarSoporteGlobal,
                builder: (context, mostrar, _) {
                  // Si es falso, devuelve un espacio vacío invisible e incleable
                  if (!mostrar) return const SizedBox.shrink();
                  return const BotonSoporteGlobal();
                },
              ),
            ),
          ],
        );
      },

      home: isLoggedIn 
          ? DashboardScreen(rolUsuario: rolUsuario) 
          : const LoginScreen(), 
    );
  }
}

// ==========================================
// WIDGET GLOBAL DE SOPORTE TÉCNICO
// ==========================================
class BotonSoporteGlobal extends StatelessWidget {
  const BotonSoporteGlobal({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.5, 
        child: FloatingActionButton.extended(
          heroTag: 'btnSoporteGlobal',
          backgroundColor: const Color(0xFFC58E58), 
          elevation: 0, 
          onPressed: () {
            if (navigatorKey.currentContext != null) {
              _mostrarModalSoporte(navigatorKey.currentContext!);
            }
          },
          icon: const Icon(Icons.support_agent, color: Colors.white),
          label: const Text(
            'S', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)
          ),
        ),
      ),
    );
  }

  void _mostrarModalSoporte(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.headset_mic, color: Color(0xFFC58E58), size: 30),
            SizedBox(width: 10),
            Text('Soporte DragonPOS', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Necesitas ayuda con el sistema de la juguería? Comunícate con nuestro equipo técnico:', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.phone_android, color: Colors.green),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('WhatsApp: +51 997 978 179', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('WhatsApp: +51 999 888 777', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            const Row(
              children: [
                Icon(Icons.email_outlined, color: Colors.blueAccent),
                SizedBox(width: 10),
                Text('soporte@dragonpos.com', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CERRAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}