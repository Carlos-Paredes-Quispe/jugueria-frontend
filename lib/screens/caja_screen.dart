import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jugueria/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/impresora_service.dart';
import '../tema_global.dart';

class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
  bool _isLoading = true;
  bool _procesando = false;

  Map<String, dynamic>? _turnoActivo;
  Map<String, dynamic>? _resumenCierre;

  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarTurnoActual();
  }

  @override
  void dispose() {
    _montoController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  double? _leerMonto(String texto) {
    return double.tryParse(texto.trim().replaceAll(',', '.'));
  }

  String _mensajeBackend(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['message'] != null) return data['message'].toString();
      if (data is Map && data['mensaje'] != null) return data['mensaje'].toString();
      return body;
    } catch (_) {
      return body;
    }
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

  Future<void> _cargarTurnoActual() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .get(
            ApiConfig.uri('/caja/actual'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          if (response.body.isEmpty || response.body == 'null') {
            _turnoActivo = null;
          } else {
            _turnoActivo = jsonDecode(response.body);
          }

          _isLoading = false;
        });
      } else {
        setState(() {
          _turnoActivo = null;
          _isLoading = false;
        });

        _mostrarMensaje(
          'No se pudo consultar caja: ${_mensajeBackend(response.body)}',
          Colors.orange,
        );
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _mostrarMensaje(
        'Tiempo agotado consultando caja.',
        Colors.orange,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _mostrarMensaje(
        'No se pudo conectar con caja: $e',
        Colors.orange,
      );
    }
  }

  Future<void> _cargarResumenCierre() async {
    try {
      final response = await http
          .get(
            ApiConfig.uri('/caja/resumen-actual'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200 && response.body != 'null') {
        setState(() {
          _resumenCierre = jsonDecode(response.body);
        });
      } else {
        _mostrarMensaje(
          'No se pudo cargar el resumen de caja.',
          Colors.orange,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error cargando resumen de cierre: $e',
        Colors.redAccent,
      );
    }
  }

  Future<void> _abrirCaja() async {
    if (_procesando) return;

    final double? montoInicial = _leerMonto(_montoController.text);

    if (montoInicial == null || montoInicial < 0) {
      _mostrarMensaje(
        'Ingresa un monto válido para abrir caja.',
        Colors.redAccent,
      );
      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final usuario =
          prefs.getString('usuarioLogueado') ??
          prefs.getString('usuarioGuardado') ??
          'Cajero Principal';

      final response = await http
          .post(
            ApiConfig.uri('/caja/abrir'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'montoInicial': montoInicial,
              'usuarioApertura': usuario,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _montoController.clear();

        _mostrarMensaje(
          'Caja abierta exitosamente ✅',
          Colors.green,
        );

        await _cargarTurnoActual();
      } else {
        _mostrarMensaje(
          'No se pudo abrir caja: ${_mensajeBackend(response.body)}',
          Colors.redAccent,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error al abrir caja: $e',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Future<void> _registrarMovimiento(String tipo) async {
    if (_procesando) return;

    if (_turnoActivo == null) {
      _mostrarMensaje(
        'No hay caja abierta.',
        Colors.redAccent,
      );
      return;
    }

    final double? monto = _leerMonto(_montoController.text);
    final descripcion = _descripcionController.text.trim();

    if (monto == null || monto <= 0) {
      _mostrarMensaje(
        'Ingresa un monto válido mayor a 0.',
        Colors.redAccent,
      );
      return;
    }

    if (descripcion.isEmpty) {
      _mostrarMensaje(
        'Ingresa una descripción.',
        Colors.redAccent,
      );
      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      final response = await http
          .post(
            ApiConfig.uri('/caja/movimiento'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'cajaTurnoId': _turnoActivo!['id'],
              'tipo': tipo,
              'monto': monto,
              'descripcion': descripcion,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.of(context).pop();

        _montoController.clear();
        _descripcionController.clear();

        _mostrarMensaje(
          tipo == 'INGRESO'
              ? 'Ingreso registrado correctamente ✅'
              : 'Egreso registrado correctamente ✅',
          Colors.green,
        );

        await _cargarTurnoActual();
      } else {
        _mostrarMensaje(
          'No se pudo registrar: ${_mensajeBackend(response.body)}',
          Colors.redAccent,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error al registrar movimiento: $e',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Future<void> _cerrarCajaDesdeModal() async {
    if (_procesando) return;

    if (_turnoActivo == null) {
      _mostrarMensaje(
        'No hay caja abierta para cerrar.',
        Colors.redAccent,
      );
      return;
    }

    final resumen = _resumenCierre ?? {};
    final efectivoEsperado = _toDouble(resumen['efectivoEsperado']);

    setState(() {
      _procesando = true;
    });

    try {
      final response = await http
          .patch(
            ApiConfig.uri('/caja/cerrar/${_turnoActivo!['id']}'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'montoEfectivoReal': efectivoEsperado,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> cierre = jsonDecode(response.body);

        bool impresionOk = false;

        try {
          final prefs = await SharedPreferences.getInstance();
          final ipCaja = prefs.getString('ip_ticketera_caja') ?? '192.168.18.236';

          final bytes = await ImpresoraService.generarCierreCaja(cierre);

          impresionOk = await ImpresoraService.enviarAImpresoraIP(
            ipCaja,
            bytes,
          );
        } catch (e) {
          debugPrint('Error imprimiendo cierre de caja: $e');
        }

        if (!mounted) return;

        Navigator.of(context).pop();

        setState(() {
          _turnoActivo = null;
          _resumenCierre = null;
        });

        _mostrarMensaje(
          impresionOk
              ? 'Caja cerrada e impresión enviada ✅'
              : 'Caja cerrada, pero no se pudo imprimir el cierre.',
          impresionOk ? Colors.green : Colors.orange,
        );

        await _cargarTurnoActual();
      } else {
        _mostrarMensaje(
          'No se pudo cerrar caja: ${_mensajeBackend(response.body)}',
          Colors.redAccent,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error al cerrar caja: $e',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  void _mostrarModalMovimiento(String tipo) {
    _montoController.clear();
    _descripcionController.clear();

    showDialog(
      context: context,
      barrierDismissible: !_procesando,
      builder: (dialogContext) {
        final tecladoAltura = MediaQuery.of(dialogContext).viewInsets.bottom;

        return AlertDialog(
          insetPadding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: tecladoAltura + 24,
          ),
          title: Text(tipo == 'INGRESO' ? 'Registrar ingreso' : 'Registrar egreso'),
          content: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _montoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monto (S/)',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descripcionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descripción / Motivo',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _procesando ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: tipo == 'INGRESO' ? Colors.green : Colors.red,
              ),
              onPressed: _procesando ? null : () => _registrarMovimiento(tipo),
              child: Text(
                _procesando ? 'Guardando...' : 'Guardar',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _mostrarModalCierre() async {
    await _cargarResumenCierre();

    if (!mounted || _resumenCierre == null) return;

    final resumen = _resumenCierre!;
    final montoInicial = _toDouble(resumen['montoInicial']);
    final cantidadVentas = resumen['cantidadVentas'] ?? 0;
    final totalVendido = _toDouble(resumen['totalVendido']);
    final pendientesSync = resumen['pendientesSync'] ?? 0;

    showDialog(
      context: context,
      barrierDismissible: !_procesando,
      builder: (dialogContext) {
        final double tecladoAltura = MediaQuery.of(dialogContext).viewInsets.bottom;
        final double anchoPantalla = MediaQuery.of(dialogContext).size.width;
        final bool esCelular = anchoPantalla < 650;

        return Dialog(
          insetPadding: EdgeInsets.only(
            left: esCelular ? 14 : 24,
            right: esCelular ? 14 : 24,
            top: 24,
            bottom: tecladoAltura + 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Container(
              width: esCelular ? double.infinity : 520,
              padding: EdgeInsets.all(esCelular ? 24 : 34),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F8F1),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Cerrar caja',
                      style: TextStyle(
                        color: const Color(0xFF0B2D2E),
                        fontSize: esCelular ? 30 : 36,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '¿Confirmas el cierre del turno actual?',
                      style: TextStyle(
                        color: const Color(0xFF0B2D2E),
                        fontSize: esCelular ? 19 : 22,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _filaModalCierre(
                    'Monto inicial',
                    'S/ ${montoInicial.toStringAsFixed(2)}',
                    esCelular: esCelular,
                  ),
                  const SizedBox(height: 12),
                  _filaModalCierre(
                    'Ventas del turno',
                    cantidadVentas.toString(),
                    esCelular: esCelular,
                  ),
                  const SizedBox(height: 12),
                  _filaModalCierre(
                    'Total vendido',
                    'S/ ${totalVendido.toStringAsFixed(2)}',
                    esCelular: esCelular,
                  ),
                  const SizedBox(height: 12),
                  _filaModalCierre(
                    'Pendientes sync',
                    pendientesSync.toString(),
                    esCelular: esCelular,
                  ),
                  const SizedBox(height: 32),
                  if (esCelular)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE94045),
                            padding: const EdgeInsets.symmetric(vertical: 17),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: _procesando ? null : _cerrarCajaDesdeModal,
                          child: Text(
                            _procesando ? 'Cerrando...' : 'Cerrar caja',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _procesando ? null : () => Navigator.pop(dialogContext),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              color: Color(0xFF0E785F),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _procesando ? null : () => Navigator.pop(dialogContext),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              color: Color(0xFF0E785F),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE94045),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 34,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: _procesando ? null : _cerrarCajaDesdeModal,
                          child: Text(
                            _procesando ? 'Cerrando...' : 'Cerrar caja',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filaModalCierre(
    String titulo,
    String valor, {
    required bool esCelular,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: esCelular ? 16 : 22,
        vertical: esCelular ? 15 : 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                color: const Color(0xFF6A7E7A),
                fontSize: esCelular ? 16 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              color: const Color(0xFF0B2D2E),
              fontSize: esCelular ? 17 : 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        final bgColor = isDark ? AppColores.fondoOscuro : AppColores.fondoClaro;
        final cardColor = isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara;
        final textColor = isDark ? AppColores.textoOscuro : AppColores.textoClaro;

        if (_isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColores.naranjaLogo,
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool esCelular = constraints.maxWidth < 760;
            final double tecladoAltura = MediaQuery.of(context).viewInsets.bottom;

            return Container(
              color: bgColor,
              width: double.infinity,
              height: double.infinity,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  left: esCelular ? 8 : 16,
                  right: esCelular ? 8 : 16,
                  top: esCelular ? 8 : 16,
                  bottom: tecladoAltura + 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: _turnoActivo == null
                        ? _buildCajaCerrada(
                            cardColor: cardColor,
                            textColor: textColor,
                            esCelular: esCelular,
                          )
                        : _buildCajaAbierta(
                            cardColor: cardColor,
                            textColor: textColor,
                            esCelular: esCelular,
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

  Widget _buildCajaCerrada({
    required Color cardColor,
    required Color textColor,
    required bool esCelular,
  }) {
    return Card(
      color: cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(esCelular ? 26 : 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: esCelular ? 64 : 80,
              color: AppColores.naranjaLogo,
            ),
            const SizedBox(height: 18),
            Text(
              'CAJA CERRADA',
              style: TextStyle(
                fontSize: esCelular ? 22 : 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Para empezar a cobrar pedidos, necesitas abrir el turno.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor.withOpacity(0.7)),
            ),
            const SizedBox(height: 26),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: TextField(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: textColor, fontSize: 19),
                decoration: InputDecoration(
                  labelText: 'Monto de apertura S/',
                  hintText: 'Ejemplo: 50.00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.attach_money),
                ),
              ),
            ),
            const SizedBox(height: 26),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.verdeLogo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _procesando ? null : _abrirCaja,
                  child: Text(
                    _procesando ? 'ABRIENDO...' : 'ABRIR CAJA',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCajaAbierta({
    required Color cardColor,
    required Color textColor,
    required bool esCelular,
  }) {
    final inicial = _toDouble(_turnoActivo!['montoInicial']);
    final ventasEf = _toDouble(_turnoActivo!['ventasEfectivo']);
    final ventasTarjeta = _toDouble(_turnoActivo!['ventasTarjeta']);
    final ventasDigital = _toDouble(_turnoActivo!['ventasDigital']);
    final ingresos = _toDouble(_turnoActivo!['ingresos']);
    final egresos = _toDouble(_turnoActivo!['egresos']);
    final saldoEsperado = inicial + ventasEf + ingresos - egresos;

    final widgetsMetricas = [
      _buildMetricaCard(
        'Monto Inicial',
        inicial,
        Icons.play_circle_filled,
        Colors.blueGrey,
        cardColor,
        textColor,
      ),
      _buildMetricaCard(
        'Ventas Efectivo',
        ventasEf,
        Icons.payments,
        Colors.green,
        cardColor,
        textColor,
      ),
      _buildMetricaCard(
        'Tarjeta / Digital',
        ventasTarjeta + ventasDigital,
        Icons.credit_card,
        Colors.orange,
        cardColor,
        textColor,
      ),
      _buildMetricaCard(
        'Ingresos Manuales',
        ingresos,
        Icons.arrow_downward,
        Colors.teal,
        cardColor,
        textColor,
      ),
      _buildMetricaCard(
        'Egresos / Gastos',
        egresos,
        Icons.arrow_upward,
        Colors.red,
        cardColor,
        textColor,
      ),
      _buildMetricaCard(
        'EFECTIVO ESPERADO',
        saldoEsperado,
        Icons.account_balance_wallet,
        AppColores.verdeLogo,
        cardColor,
        textColor,
        isDestacado: true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (esCelular)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen de Turno Actual',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              _badgeCajaAbierta(),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resumen de Turno Actual',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              _badgeCajaAbierta(),
            ],
          ),
        const SizedBox(height: 24),

        if (esCelular)
          Column(
            children: widgetsMetricas
                .map(
                  (widget) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: widget,
                  ),
                )
                .toList(),
          )
        else ...[
          Row(children: widgetsMetricas.sublist(0, 3)),
          const SizedBox(height: 12),
          Row(children: widgetsMetricas.sublist(3, 6)),
        ],

        const SizedBox(height: 28),

        if (esCelular)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _botonMovimiento(
                titulo: 'Ingreso Extra',
                icono: Icons.add,
                color: Colors.teal,
                onPressed: () => _mostrarModalMovimiento('INGRESO'),
              ),
              const SizedBox(height: 12),
              _botonMovimiento(
                titulo: 'Registrar Gasto',
                icono: Icons.remove,
                color: Colors.red,
                onPressed: () => _mostrarModalMovimiento('EGRESO'),
              ),
              const SizedBox(height: 12),
              _botonCerrarCaja(),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _botonMovimiento(
                  titulo: 'Ingreso Extra',
                  icono: Icons.add,
                  color: Colors.teal,
                  onPressed: () => _mostrarModalMovimiento('INGRESO'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _botonMovimiento(
                  titulo: 'Registrar Gasto',
                  icono: Icons.remove,
                  color: Colors.red,
                  onPressed: () => _mostrarModalMovimiento('EGRESO'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(child: _botonCerrarCaja()),
            ],
          ),
      ],
    );
  }

  Widget _badgeCajaAbierta() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green),
      ),
      child: const Text(
        'CAJA ABIERTA',
        style: TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _botonMovimiento({
    required String titulo,
    required IconData icono,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(18),
        foregroundColor: color,
        side: BorderSide(color: color),
      ),
      onPressed: _procesando ? null : onPressed,
      icon: Icon(icono),
      label: Text(titulo),
    );
  }

  Widget _botonCerrarCaja() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(18),
        backgroundColor: Colors.blueGrey,
      ),
      onPressed: _procesando ? null : _mostrarModalCierre,
      icon: const Icon(Icons.lock, color: Colors.white),
      label: const Text(
        'CERRAR CAJA Y ARQUEAR',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetricaCard(
    String titulo,
    double valor,
    IconData icono,
    Color color,
    Color cardColor,
    Color textColor, {
    bool isDestacado = false,
  }) {
    return Expanded(
      child: Card(
        color: isDestacado ? color.withOpacity(0.10) : cardColor,
        elevation: isDestacado ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDestacado ? color : Colors.transparent,
            width: 2,
          ),
        ),
        margin: const EdgeInsets.all(6),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'S/ ${valor.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isDestacado ? color : textColor,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}