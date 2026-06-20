import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/impresora_service.dart'; // Ajusta la ruta de tu servicio
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../tema_global.dart';

class ConfigImpresorasScreen extends StatefulWidget {
  const ConfigImpresorasScreen({super.key});

  @override
  State<ConfigImpresorasScreen> createState() => _ConfigImpresorasScreenState();
}

class _ConfigImpresorasScreenState extends State<ConfigImpresorasScreen> {
  final Color copperPrimary = const Color(0xFFC07C46);
  
  final TextEditingController _ipCajaCtrl = TextEditingController();
  final TextEditingController _ipCocinaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarIPsGuardadas();
  }

  // Carga las IPs almacenadas en la tablet
  Future<void> _cargarIPsGuardadas() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ipCajaCtrl.text = prefs.getString('ip_ticketera_caja') ?? '192.168.1.90';
      _ipCocinaCtrl.text = prefs.getString('ip_ticketera_cocina') ?? '192.168.1.236';
    });
  }

  // Guarda las IPs permanentemente
  Future<void> _guardarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ip_ticketera_caja', _ipCajaCtrl.text.trim());
    await prefs.setString('ip_ticketera_cocina', _ipCocinaCtrl.text.trim());

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('¡Configuración de impresoras guardada! 💾'),
      backgroundColor: Colors.green,
    ));
  }

  // Envía un ticket de prueba básico para verificar que la IP responde
  Future<void> _probarImpresora(String ip, String nombreSeccion) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Probando conexión con $nombreSeccion...')));
    
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += generator.text('TEST CONEXION - DRAGONPOS', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Impresora: $nombreSeccion', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('IP: $ip', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();

    bool exito = await ImpresoraService.enviarAImpresoraIP(ip, bytes);

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('¡Conexión exitosa con $nombreSeccion! 🧾✔️'),
        backgroundColor: Colors.green,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: No se pudo conectar a la IP $ip. Verifica que la ticketera esté encendida.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        final Color textColor = isDark ? Colors.white : const Color(0xFF222222);
        final Color panelColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configuración de Hardware', style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.bold)),
                Text('Enlace de Ticketeras Térmicas por Red Local (TCP/IP)', style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 14)),
                const SizedBox(height: 30),

                // CARD CONFIGURACIÓN CAJA
                _buildFormImpresora("Ticketera de Caja (Boletas / Precuentas)", _ipCajaCtrl, () => _probarImpresora(_ipCajaCtrl.text, "CAJA"), panelColor, textColor),
                const SizedBox(height: 20),

                // CARD CONFIGURACIÓN COCINA
                _buildFormImpresora("Ticketera de Cocina (Comandas)", _ipCocinaCtrl, () => _probarImpresora(_ipCocinaCtrl.text, "COCINA"), panelColor, textColor),
                
                const Spacer(),

                // BOTÓN GUARDAR CONFIGURACIÓN GENERAL
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: copperPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('GUARDAR AJUSTES DE IMPRESIÓN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: _guardarConfiguracion,
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormImpresora(String titulo, TextEditingController controller, VoidCallback onTest, Color panelColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(color: textColor),
                  keyboardType: TextInputType.values[3], // Teclado numérico/puntos
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.router, color: copperPrimary),
                    hintText: 'Ej: 192.168.1.100',
                    hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text('PROBAR', style: TextStyle(color: Colors.white)),
                onPressed: onTest,
              )
            ],
          )
        ],
      ),
    );
  }
}