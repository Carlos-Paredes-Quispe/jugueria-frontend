import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/impresora_service.dart';
import '../tema_global.dart';

class ConfigImpresorasScreen extends StatefulWidget {
  const ConfigImpresorasScreen({super.key});

  @override
  State<ConfigImpresorasScreen> createState() => _ConfigImpresorasScreenState();
}

class _ConfigImpresorasScreenState extends State<ConfigImpresorasScreen> {
  final TextEditingController _ipCajaController = TextEditingController();
  final TextEditingController _ipCocinaController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  // 1. CARGAR IPs GUARDADAS
  Future<void> _cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Si es la primera vez, ponemos unas IPs de ejemplo
      _ipCajaController.text = prefs.getString('ip_ticketera_caja') ?? '192.168.18.236';
      _ipCocinaController.text = prefs.getString('ip_ticketera_cocina') ?? '192.168.18.237';
      _isLoading = false;
    });
  }

  // 2. GUARDAR NUEVAS IPs
  Future<void> _guardarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ip_ticketera_caja', _ipCajaController.text.trim());
    await prefs.setString('ip_ticketera_cocina', _ipCocinaController.text.trim());
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Configuración guardada exitosamente! ✅'), 
          backgroundColor: AppColores.verdeLogo,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 3. ENVIAR TICKET DE PRUEBA
  Future<void> _probarImpresora(String ip, String tipoImpresora) async {
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, ingresa una IP válida'), backgroundColor: Colors.redAccent));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enviando prueba a $ip...'), backgroundColor: AppColores.naranjaLogo));

    try {
      // Usamos el servicio de cocina simulando un producto para ver si imprime
      final bytes = await ImpresoraService.generarTicketCocina(
        'PRUEBA DE CONEXIÓN - $tipoImpresora', 
        [{'cantidad': 1, 'nombre': 'Conexión Exitosa', 'notas': 'La tablet se comunicó con la impresora'}]
      );
      
      await ImpresoraService.enviarAImpresoraIP(ip, bytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Prueba enviada! Debería estar imprimiendo...'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de red: No se encontró la impresora en $ip'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        final Color cardColor = isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara;
        final Color textColor = isDark ? AppColores.textoOscuro : AppColores.textoClaro;
        final Color textLightColor = isDark ? AppColores.textoOscuroSecundario : AppColores.textoClaroSecundario;

        if (_isLoading) {
          return Center(child: CircularProgressIndicator(color: AppColores.naranjaLogo));
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.print, color: AppColores.naranjaLogo, size: 32),
                      const SizedBox(width: 15),
                      Text('Configuración de Impresoras', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ingresa la dirección IP de cada impresora térmica (formato: 192.168.x.x). Asegúrate de que la tablet y las impresoras estén conectadas al mismo WiFi.',
                    style: TextStyle(color: textLightColor, fontSize: 14),
                  ),
                  const SizedBox(height: 30),

                  // ==========================================
                  // CONFIGURACIÓN: CAJA
                  // ==========================================
                  _buildImpresoraCard(
                    titulo: 'Impresora de CAJA (Boletas)',
                    icono: Icons.receipt_long,
                    controlador: _ipCajaController,
                    colorTema: AppColores.verdeLogo,
                    textColor: textColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),

                  // ==========================================
                  // CONFIGURACIÓN: COCINA
                  // ==========================================
                  _buildImpresoraCard(
                    titulo: 'Impresora de COCINA (Comandas)',
                    icono: Icons.restaurant_menu,
                    controlador: _ipCocinaController,
                    colorTema: AppColores.naranjaLogo,
                    textColor: textColor,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 40),

                  // BOTÓN GUARDAR
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColores.naranjaLogo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: _guardarConfiguracion,
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text('GUARDAR CONFIGURACIÓN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  // Tarjeta reutilizable para cada impresora
  Widget _buildImpresoraCard({
    required String titulo,
    required IconData icono,
    required TextEditingController controlador,
    required Color colorTema,
    required Color textColor,
    required bool isDark,
  }) {
    final Color fillColor = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF9F9F9);
    final Color borderColor = isDark ? Colors.white12 : Colors.black12;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: colorTema),
              const SizedBox(width: 10),
              Text(titulo, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controlador,
                  style: TextStyle(color: textColor, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Dirección IP',
                    prefixIcon: const Icon(Icons.wifi),
                    filled: true,
                    fillColor: fillColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  side: BorderSide(color: colorTema),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                onPressed: () => _probarImpresora(controlador.text.trim(), titulo),
                icon: Icon(Icons.print, color: colorTema),
                label: Text('PROBAR', style: TextStyle(color: colorTema, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}