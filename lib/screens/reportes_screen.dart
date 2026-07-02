import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jugueria/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../tema_global.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  bool _isLoading = true;

  DateTime _desde = DateTime.now();
  DateTime _hasta = DateTime.now();

  Map<String, dynamic> _resumen = {};
  List<dynamic> _topProductos = [];
  List<dynamic> _pedidos = [];

  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarReporte();
  }

  String _fechaApi(DateTime fecha) {
    final y = fecha.year.toString().padLeft(4, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    final d = fecha.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _fechaVista(DateTime fecha) {
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    final y = fecha.year.toString();
    return '$d/$m/$y';
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _mensajeBackend(String body) {
    try {
      final data = jsonDecode(body);

      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }

      if (data is Map && data['mensaje'] != null) {
        return data['mensaje'].toString();
      }

      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }

      return body;
    } catch (_) {
      return body;
    }
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';

    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _cargarReporte() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = ApiConfig.uri(
        '/reports/resumen?desde=${_fechaApi(_desde)}&hasta=${_fechaApi(_hasta)}',
      );

      final response = await http
          .get(
            uri,
            headers: await _headers(),
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is! Map) {
          setState(() {
            _isLoading = false;
            _error = 'El backend respondió un formato inválido para reportes.';
          });
          return;
        }

        final Map<String, dynamic> data = Map<String, dynamic>.from(decoded);

        final dynamic resumenRaw = data['resumen'];
        final dynamic topProductosRaw = data['topProductos'];
        final dynamic pedidosRaw = data['pedidos'];

        setState(() {
          _resumen = resumenRaw is Map
              ? Map<String, dynamic>.from(resumenRaw)
              : {
                  'totalVentas': 0,
                  'totalPedidos': 0,
                  'ventasEfectivo': 0,
                  'ventasTarjeta': 0,
                  'ventasDigital': 0,
                  'totalIngresosCaja': 0,
                  'totalEgresosCaja': 0,
                  'turnosCaja': 0,
                };

          _topProductos = topProductosRaw is List ? topProductosRaw : [];
          _pedidos = pedidosRaw is List ? pedidosRaw : [];

          _isLoading = false;
          _error = null;
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        setState(() {
          _isLoading = false;
          _error =
              'No tienes permisos para ver reportes. Ingresa como ADMINISTRADOR.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _error =
              'No se pudo cargar reportes. Código ${response.statusCode}: ${_mensajeBackend(response.body)}';
        });
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error =
            'Tiempo agotado al cargar reportes. Revisa si el backend está encendido.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'Error al cargar reportes: $e';
      });
    }
  }

  Future<void> _seleccionarFecha(bool esDesde) async {
    final fechaActual = esDesde ? _desde : _hasta;

    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: fechaActual,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (seleccion == null) return;

    setState(() {
      if (esDesde) {
        _desde = seleccion;

        if (_desde.isAfter(_hasta)) {
          _hasta = _desde;
        }
      } else {
        _hasta = seleccion;

        if (_hasta.isBefore(_desde)) {
          _desde = _hasta;
        }
      }
    });

    _cargarReporte();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        final Color textColor =
            isDark ? AppColores.textoOscuro : AppColores.textoClaro;
        final Color cardColor =
            isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara;
        final Color bgColor =
            isDark ? AppColores.fondoOscuro : AppColores.fondoClaro;

        if (_isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColores.naranjaLogo,
            ),
          );
        }

        if (_error != null) {
          return _buildError(bgColor, cardColor, textColor);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool esCelular = constraints.maxWidth < 760;

            return Container(
              color: bgColor,
              width: double.infinity,
              height: double.infinity,
              child: RefreshIndicator(
                onRefresh: _cargarReporte,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: esCelular ? 4 : 0,
                    right: esCelular ? 4 : 0,
                    bottom: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(
                        textColor: textColor,
                        esCelular: esCelular,
                      ),

                      const SizedBox(height: 18),

                      _buildCardsResumen(
                        resumen: _resumen,
                        cardColor: cardColor,
                        textColor: textColor,
                        esCelular: esCelular,
                      ),

                      const SizedBox(height: 18),

                      if (esCelular)
                        Column(
                          children: [
                            SizedBox(
                              height: 420,
                              child: _buildTopProductos(
                                _topProductos,
                                cardColor,
                                textColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 430,
                              child: _buildUltimosPedidos(
                                _pedidos,
                                cardColor,
                                textColor,
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          height: 430,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: _buildTopProductos(
                                  _topProductos,
                                  cardColor,
                                  textColor,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 5,
                                child: _buildUltimosPedidos(
                                  _pedidos,
                                  cardColor,
                                  textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildError(Color bgColor, Color cardColor, Color textColor) {
    return Container(
      color: bgColor,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 54,
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudo mostrar el reporte',
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor.withOpacity(0.75),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColores.naranjaLogo,
                ),
                onPressed: _cargarReporte,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Reintentar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required Color textColor,
    required bool esCelular,
  }) {
    if (esCelular) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reportes',
            style: TextStyle(
              color: textColor,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ventas, caja y productos vendidos.',
            style: TextStyle(
              color: textColor.withOpacity(0.65),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          _buildFechaButton('Desde', _fechaVista(_desde), () {
            _seleccionarFecha(true);
          }),
          const SizedBox(height: 8),
          _buildFechaButton('Hasta', _fechaVista(_hasta), () {
            _seleccionarFecha(false);
          }),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.naranjaLogo,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onPressed: _cargarReporte,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              'Actualizar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reportes Administrativos',
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Resumen de ventas, caja, métodos de pago y productos vendidos.',
                style: TextStyle(
                  color: textColor.withOpacity(0.65),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildFechaButton('Desde', _fechaVista(_desde), () {
              _seleccionarFecha(true);
            }),
            const SizedBox(width: 8),
            _buildFechaButton('Hasta', _fechaVista(_hasta), () {
              _seleccionarFecha(false);
            }),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.naranjaLogo,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onPressed: _cargarReporte,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Actualizar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFechaButton(String label, String value, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_month),
      label: Text('$label: $value'),
    );
  }

  Widget _buildCardsResumen({
    required Map<String, dynamic> resumen,
    required Color cardColor,
    required Color textColor,
    required bool esCelular,
  }) {
    final cards = [
      _buildCard(
        'Ventas Totales',
        'S/ ${_toDouble(resumen['totalVentas']).toStringAsFixed(2)}',
        Icons.payments,
        AppColores.verdeLogo,
        cardColor,
        textColor,
      ),
      _buildCard(
        'Pedidos Pagados',
        '${resumen['totalPedidos'] ?? 0}',
        Icons.receipt_long,
        AppColores.naranjaLogo,
        cardColor,
        textColor,
      ),
      _buildCard(
        'Efectivo',
        'S/ ${_toDouble(resumen['ventasEfectivo']).toStringAsFixed(2)}',
        Icons.money,
        Colors.green,
        cardColor,
        textColor,
      ),
      _buildCard(
        'Tarjeta',
        'S/ ${_toDouble(resumen['ventasTarjeta']).toStringAsFixed(2)}',
        Icons.credit_card,
        Colors.orange,
        cardColor,
        textColor,
      ),
      _buildCard(
        'Yape / Plin',
        'S/ ${_toDouble(resumen['ventasDigital']).toStringAsFixed(2)}',
        Icons.qr_code_2,
        Colors.purple,
        cardColor,
        textColor,
      ),
      _buildCard(
        'Ingresos Caja',
        'S/ ${_toDouble(resumen['totalIngresosCaja']).toStringAsFixed(2)}',
        Icons.arrow_downward,
        Colors.teal,
        cardColor,
        textColor,
      ),
      _buildCard(
        'Egresos Caja',
        'S/ ${_toDouble(resumen['totalEgresosCaja']).toStringAsFixed(2)}',
        Icons.arrow_upward,
        Colors.redAccent,
        cardColor,
        textColor,
      ),
      _buildCard(
        'Turnos Caja',
        '${resumen['turnosCaja'] ?? 0}',
        Icons.lock_clock,
        Colors.blueGrey,
        cardColor,
        textColor,
      ),
    ];

    if (esCelular) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: card,
              ),
            )
            .toList(),
      );
    }

    return Column(
      children: [
        Row(children: cards.sublist(0, 4)),
        const SizedBox(height: 10),
        Row(children: cards.sublist(4, 8)),
      ],
    );
  }

  Widget _buildCard(
    String titulo,
    String valor,
    IconData icono,
    Color color,
    Color cardColor,
    Color textColor,
  ) {
    return Expanded(
      child: Card(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, color: color, size: 26),
                const SizedBox(height: 10),
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor.withOpacity(0.65),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopProductos(
    List<dynamic> productos,
    Color cardColor,
    Color textColor,
  ) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top productos vendidos',
              style: TextStyle(
                color: textColor,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: productos.isEmpty
                  ? Center(
                      child: Text(
                        'No hay productos vendidos en este rango.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textColor.withOpacity(0.65)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: productos.length,
                      separatorBuilder: (_, __) => const Divider(height: 18),
                      itemBuilder: (context, index) {
                        final raw = productos[index];
                        final item = raw is Map
                            ? Map<String, dynamic>.from(raw)
                            : <String, dynamic>{};

                        return Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  AppColores.naranjaLogo.withOpacity(0.12),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: AppColores.naranjaLogo,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item['nombre']?.toString() ?? '-',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${item['cantidad'] ?? 0} und.',
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'S/ ${_toDouble(item['total']).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.55),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUltimosPedidos(
    List<dynamic> pedidos,
    Color cardColor,
    Color textColor,
  ) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pedidos pagados',
              style: TextStyle(
                color: textColor,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: pedidos.isEmpty
                  ? Center(
                      child: Text(
                        'No hay pedidos pagados en este rango.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textColor.withOpacity(0.65)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: pedidos.length,
                      separatorBuilder: (_, __) => const Divider(height: 18),
                      itemBuilder: (context, index) {
                        final raw = pedidos[index];
                        final item = raw is Map
                            ? Map<String, dynamic>.from(raw)
                            : <String, dynamic>{};

                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Pedido #${item['id'] ?? '-'}',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              item['metodoPago']?.toString() ?? '-',
                              style: TextStyle(
                                color: textColor.withOpacity(0.65),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Text(
                              'S/ ${_toDouble(item['total']).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColores.verdeLogo,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}