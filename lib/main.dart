import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- 1. IMPORTANTE PARA PANTALLA COMPLETA
import 'package:flutter_jugueria/screens/dashboard_screen.dart';
import 'package:flutter_jugueria/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main() async {
  // Asegura que Flutter esté listo antes de ejecutar configuraciones
  WidgetsFlutterBinding.ensureInitialized();

  // 2. ¡MAGIA DE PANTALLA COMPLETA! Oculta la barra de navegación y la barra de estado
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 3. Leemos la memoria local antes de arrancar
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String rolUsuario = prefs.getString('rolUsuario') ?? 'ADMINISTRADOR';

  runApp(MyApp(isLoggedIn: isLoggedIn, rolUsuario: rolUsuario));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String rolUsuario;

  const MyApp({Key? key, required this.isLoggedIn, required this.rolUsuario}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DragonRES',
      debugShowCheckedModeBanner: false,
      // Si el usuario marcó "Recordar", va al Dashboard. Si no, al Login.
      home: isLoggedIn 
          ? DashboardScreen(rolUsuario: rolUsuario) 
          : LoginScreen(), // Cambia 'LoginScreen' por el nombre de tu clase
    );
  }
}