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
  bool _probandoCaja = false;
  bool _probandoCocina = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _ipCajaController.dispose();
    _ipCocinaController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _ipCajaController.text =
          prefs.getString('ip_ticketera_caja') ?? '192.168.18.236';
      _ipCocinaController.text =
          prefs.getString('ip_ticketera_cocina') ?? '192.168.18.237';
      _isLoading = false;
    });
  }

  bool _ipValida(String ip) {
    final RegExp regex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.){3}'
      r'(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)$',
    );

    return regex.hasMatch(ip);
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

  Future<void> _guardarConfiguracion() async {
    final String ipCaja = _ipCajaController.text.trim();
    final String ipCocina = _ipCocinaController.text.trim();

    if (!_ipValida(ipCaja)) {
      _mostrarMensaje(
        'La IP de caja no es válida. Ejemplo: 192.168.18.236',
        Colors.redAccent,
      );
      return;
    }

    if (!_ipValida(ipCocina)) {
      _mostrarMensaje(
        'La IP de cocina no es válida. Ejemplo: 192.168.18.237',
        Colors.redAccent,
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('ip_ticketera_caja', ipCaja);
    await prefs.setString('ip_ticketera_cocina', ipCocina);

    if (!mounted) return;

    _mostrarMensaje(
      '¡Configuración guardada exitosamente! ✅',
      AppColores.verdeLogo,
    );
  }

  Future<void> _probarImpresora(String ip, String tipoImpresora) async {
    final String ipLimpia = ip.trim();

    if (ipLimpia.isEmpty) {
      _mostrarMensaje(
        'Por favor, ingresa una IP válida.',
        Colors.redAccent,
      );
      return;
    }

    if (!_ipValida(ipLimpia)) {
      _mostrarMensaje(
        'La IP ingresada no tiene un formato válido.',
        Colors.redAccent,
      );
      return;
    }

    final bool esCaja = tipoImpresora.toUpperCase().contains('CAJA');

    setState(() {
      if (esCaja) {
        _probandoCaja = true;
      } else {
        _probandoCocina = true;
      }
    });

    _mostrarMensaje(
      'Enviando prueba a $ipLimpia...',
      AppColores.naranjaLogo,
    );

    try {
      final bytes = await ImpresoraService.generarTicketCocina(
        'PRUEBA DE CONEXION - $tipoImpresora',
        [
          {
            'cantidad': 1,
            'nombre': 'Conexion Exitosa',
            'categoria': 'PRUEBA',
            'notas': 'La tablet se comunico con la impresora',
          }
        ],
      );

      final bool enviado = await ImpresoraService.enviarAImpresoraIP(
        ipLimpia,
        bytes,
      );

      if (!mounted) return;

      if (enviado) {
        _mostrarMensaje(
          '¡Prueba enviada! La impresora debería estar imprimiendo.',
          Colors.green,
        );
      } else {
        _mostrarMensaje(
          'No se pudo conectar con la impresora en $ipLimpia.',
          Colors.redAccent,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error de red: no se encontró la impresora en $ipLimpia.',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          if (esCaja) {
            _probandoCaja = false;
          } else {
            _probandoCocina = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        final Color cardColor =
            isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara;
        final Color textColor =
            isDark ? AppColores.textoOscuro : AppColores.textoClaro;
        final Color textLightColor = isDark
            ? AppColores.textoOscuroSecundario
            : AppColores.textoClaroSecundario;

        if (_isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColores.naranjaLogo,
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool esCelular = constraints.maxWidth < 650;
            final double tecladoAltura = MediaQuery.of(context).viewInsets.bottom;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                left: esCelular ? 12 : 0,
                right: esCelular ? 12 : 0,
                top: 12,
                bottom: tecladoAltura + 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Container(
                    padding: EdgeInsets.all(esCelular ? 20 : 32),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.print,
                              color: AppColores.naranjaLogo,
                              size: esCelular ? 28 : 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Configuración de Impresoras',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: esCelular ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'Ingresa la dirección IP de cada impresora térmica. La tablet y las impresoras deben estar conectadas al mismo WiFi.',
                          style: TextStyle(
                            color: textLightColor,
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 28),

                        _buildImpresoraCard(
                          titulo: 'Impresora de CAJA (Boletas)',
                          icono: Icons.receipt_long,
                          controlador: _ipCajaController,
                          colorTema: AppColores.verdeLogo,
                          textColor: textColor,
                          isDark: isDark,
                          probando: _probandoCaja,
                          esCelular: esCelular,
                        ),

                        const SizedBox(height: 18),

                        _buildImpresoraCard(
                          titulo: 'Impresora de COCINA (Comandas)',
                          icono: Icons.restaurant_menu,
                          controlador: _ipCocinaController,
                          colorTema: AppColores.naranjaLogo,
                          textColor: textColor,
                          isDark: isDark,
                          probando: _probandoCocina,
                          esCelular: esCelular,
                        ),

                        const SizedBox(height: 34),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColores.naranjaLogo,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _guardarConfiguracion,
                            icon: const Icon(Icons.save, color: Colors.white),
                            label: const Text(
                              'GUARDAR CONFIGURACIÓN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImpresoraCard({
    required String titulo,
    required IconData icono,
    required TextEditingController controlador,
    required Color colorTema,
    required Color textColor,
    required bool isDark,
    required bool probando,
    required bool esCelular,
  }) {
    final Color fillColor =
        isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF9F9F9);
    final Color borderColor = isDark ? Colors.white12 : Colors.black12;

    final campoIp = TextField(
      controller: controlador,
      style: TextStyle(
        color: textColor,
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Dirección IP',
        hintText: 'Ejemplo: 192.168.18.236',
        prefixIcon: const Icon(Icons.wifi),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );

    final botonProbar = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 15,
        ),
        side: BorderSide(color: colorTema),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: probando
          ? null
          : () => _probarImpresora(
                controlador.text.trim(),
                titulo,
              ),
      icon: probando
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorTema,
              ),
            )
          : Icon(Icons.print, color: colorTema),
      label: Text(
        probando ? 'PROBANDO...' : 'PROBAR',
        style: TextStyle(
          color: colorTema,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.all(esCelular ? 16 : 20),
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
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          if (esCelular)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                campoIp,
                const SizedBox(height: 12),
                botonProbar,
              ],
            )
          else
            Row(
              children: [
                Expanded(child: campoIp),
                const SizedBox(width: 15),
                botonProbar,
              ],
            ),
        ],
      ),
    );
  }
}