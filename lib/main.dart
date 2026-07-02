import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jugueria/screens/dashboard_screen.dart';
import 'package:flutter_jugueria/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Control global para mostrar/ocultar el botón flotante de soporte.
final ValueNotifier<bool> mostrarSoporteGlobal = ValueNotifier<bool>(true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Modo pantalla completa para tablet.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final String rolUsuario = prefs.getString('rolUsuario') ?? 'ADMINISTRADOR';

  runApp(MyApp(isLoggedIn: isLoggedIn, rolUsuario: rolUsuario));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String rolUsuario;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.rolUsuario,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DragonRES',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),

            Positioned(
              right: 20,
              bottom: 20,
              child: ValueListenableBuilder<bool>(
                valueListenable: mostrarSoporteGlobal,
                builder: (context, mostrar, _) {
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
            final contextActual = navigatorKey.currentContext;
            if (contextActual != null) {
              _mostrarModalSoporte(contextActual);
            }
          },
          icon: const Icon(Icons.support_agent, color: Colors.white),
          label: const Text(
            'S',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
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
            Text(
              'Soporte DragonPOS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Necesitas ayuda con el sistema de la juguería? Comunícate con nuestro equipo técnico:',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.phone_android, color: Colors.green),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp: +51 997 978 179',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'WhatsApp: +51 999 888 777',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 15),
            Row(
              children: [
                Icon(Icons.email_outlined, color: Colors.blueAccent),
                SizedBox(width: 10),
                Text(
                  'soporte@dragonpos.com',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CERRAR',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}