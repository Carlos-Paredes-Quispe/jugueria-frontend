import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jugueria/config/api_config.dart';
import 'package:flutter_jugueria/main.dart';
import 'package:http/http.dart' as http;

import '../tema_global.dart';

class CocinaScreen extends StatefulWidget {
  const CocinaScreen({super.key});

  @override
  State<CocinaScreen> createState() => _CocinaScreenState();
}

class _CocinaScreenState extends State<CocinaScreen> {
  final Color copperPrimary = const Color(0xFFC07C46);

  List<dynamic> _comandas = [];

  bool _isLoading = true;
  bool _procesando = false;

  Timer? _timerRefresco;
  DateTime? _ultimaActualizacion;

  @override
  void initState() {
    super.initState();

    mostrarSoporteGlobal.value = false;

    _cargarComandasCocina();

    _timerRefresco = Timer.periodic(const Duration(seconds: 8), (_) {
      _cargarComandasCocina(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timerRefresco?.cancel();
    mostrarSoporteGlobal.value = true;
    super.dispose();
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

  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _horaFormateada(dynamic fechaRaw) {
    if (fechaRaw == null) return '--:--';

    try {
      final fecha = DateTime.parse(fechaRaw.toString()).toLocal();
      final hora = fecha.hour.toString().padLeft(2, '0');
      final minuto = fecha.minute.toString().padLeft(2, '0');
      return '$hora:$minuto';
    } catch (_) {
      return '--:--';
    }
  }

  String _ubicacionPedido(Map<String, dynamic> pedido) {
    if (pedido['grupoId'] != null) {
      return 'GRUPO ${pedido['grupoId']}';
    }

    if (pedido['grupo'] != null) {
      return 'GRUPO ${pedido['grupo']}';
    }

    if (pedido['sillaId'] != null) {
      return 'SILLA ${pedido['sillaId']}';
    }

    return 'SIN MESA';
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<void> _cargarComandasCocina({bool silencioso = false}) async {
    if (!mounted) return;

    if (!silencioso) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final response = await http
          .get(
            ApiConfig.uri('/pedidos/cocina'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _comandas = data is List ? data : [];
          _ultimaActualizacion = DateTime.now();
          _isLoading = false;
        });
      } else {
        if (!silencioso) {
          setState(() {
            _isLoading = false;
          });

          _mostrarMensaje(
            'No se pudo cargar cocina: ${_mensajeBackend(response.body)}',
            Colors.redAccent,
          );
        }
      }
    } on TimeoutException {
      if (!mounted) return;

      if (!silencioso) {
        setState(() {
          _isLoading = false;
        });

        _mostrarMensaje(
          'Tiempo agotado al cargar cocina.',
          Colors.redAccent,
        );
      }
    } catch (e) {
      if (!mounted) return;

      if (!silencioso) {
        setState(() {
          _isLoading = false;
        });

        _mostrarMensaje(
          'Error al conectar con cocina.',
          Colors.redAccent,
        );
      }
    }
  }

  Future<void> _marcarComoListo(int pedidoId) async {
    if (_procesando) return;

    if (pedidoId <= 0) {
      _mostrarMensaje(
        'Pedido inválido.',
        Colors.redAccent,
      );
      return;
    }

    setState(() {
      _procesando = true;
    });

    try {
      final response = await http
          .patch(
            ApiConfig.uri('/pedidos/$pedidoId/listo'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        _mostrarMensaje(
          '¡Pedido despachado! 🍹🏁',
          Colors.green,
        );

        await _cargarComandasCocina();
      } else {
        _mostrarMensaje(
          'No se pudo despachar: ${_mensajeBackend(response.body)}',
          Colors.redAccent,
        );
      }
    } on TimeoutException {
      if (!mounted) return;

      _mostrarMensaje(
        'Tiempo agotado al despachar pedido.',
        Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error al despachar pedido.',
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

  Future<void> _confirmarPedidoListo(Map<String, dynamic> pedido) async {
    final int pedidoId = _toInt(pedido['id']);
    final String ubicacion = _ubicacionPedido(pedido);

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar despacho'),
          content: Text(
            '¿Confirmas que el pedido #$pedidoId de $ubicacion ya está listo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Sí, está listo',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      _marcarComoListo(pedidoId);
    }
  }

  String _textoUltimaActualizacion() {
    final fecha = _ultimaActualizacion;

    if (fecha == null) {
      return 'Actualizando...';
    }

    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    final segundo = fecha.second.toString().padLeft(2, '0');

    return 'Última actualización: $hora:$minuto:$segundo';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        final Color bgColor =
            isDark ? AppColores.fondoOscuro : AppColores.fondoClaro;
        final Color textColor =
            isDark ? AppColores.textoOscuro : AppColores.textoClaro;
        final Color textLightColor = isDark
            ? AppColores.textoOscuroSecundario
            : AppColores.textoClaroSecundario;
        final Color cardBg =
            isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara;
        final Color borderColor = isDark ? Colors.white12 : Colors.black12;

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool esCelular = constraints.maxWidth < 760;
            final bool esTabletMedia =
                constraints.maxWidth >= 760 && constraints.maxWidth < 1120;

            final int columnas = esCelular
                ? 1
                : esTabletMedia
                    ? 2
                    : 3;

            final double cardHeight = esCelular ? 360 : 390;

            return Container(
              color: bgColor,
              width: double.infinity,
              height: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(
                    textColor: textColor,
                    textLightColor: textLightColor,
                    esCelular: esCelular,
                  ),

                  SizedBox(height: esCelular ? 14 : 22),

                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: copperPrimary,
                            ),
                          )
                        : _comandas.isEmpty
                            ? _buildCocinaLimpia(
                                textColor: textColor,
                                textLightColor: textLightColor,
                              )
                            : RefreshIndicator(
                                onRefresh: () => _cargarComandasCocina(),
                                child: GridView.builder(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.only(
                                    left: esCelular ? 2 : 0,
                                    right: esCelular ? 2 : 0,
                                    bottom: 24,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columnas,
                                    crossAxisSpacing: esCelular ? 10 : 14,
                                    mainAxisSpacing: esCelular ? 10 : 14,
                                    mainAxisExtent: cardHeight,
                                  ),
                                  itemCount: _comandas.length,
                                  itemBuilder: (context, index) {
                                    final raw = _comandas[index];

                                    final pedido = raw is Map
                                        ? Map<String, dynamic>.from(raw)
                                        : <String, dynamic>{};

                                    return _buildComandaCard(
                                      pedido: pedido,
                                      cardBg: cardBg,
                                      textColor: textColor,
                                      textLightColor: textLightColor,
                                      borderColor: borderColor,
                                      esCelular: esCelular,
                                      isDark: isDark,
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader({
    required Color textColor,
    required Color textLightColor,
    required bool esCelular,
  }) {
    if (esCelular) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Monitor de Cocina',
            style: TextStyle(
              color: textColor,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Órdenes pendientes en tiempo real',
            style: TextStyle(
              color: textLightColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _textoUltimaActualizacion(),
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _procesando
                    ? null
                    : () => _cargarComandasCocina(),
                icon: Icon(
                  Icons.refresh,
                  color: copperPrimary,
                  size: 18,
                ),
                label: Text(
                  'Actualizar',
                  style: TextStyle(color: copperPrimary),
                ),
              ),
            ],
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
                'Monitor de Cocina',
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Órdenes pendientes en tiempo real',
                style: TextStyle(
                  color: textLightColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _textoUltimaActualizacion(),
                style: TextStyle(
                  color: textLightColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: copperPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: copperPrimary.withOpacity(0.35)),
              ),
              child: Text(
                '${_comandas.length} pendiente(s)',
                style: TextStyle(
                  color: copperPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: copperPrimary,
                size: 30,
              ),
              onPressed: _procesando
                  ? null
                  : () => _cargarComandasCocina(),
              tooltip: 'Actualizar ahora',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCocinaLimpia({
    required Color textColor,
    required Color textLightColor,
  }) {
    return RefreshIndicator(
      onRefresh: () => _cargarComandasCocina(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 84,
                    color: Colors.green.withOpacity(0.55),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¡Cocina limpia!',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No hay pedidos pendientes',
                    style: TextStyle(
                      color: textLightColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => _cargarComandasCocina(),
                    icon: Icon(Icons.refresh, color: copperPrimary),
                    label: Text(
                      'Actualizar',
                      style: TextStyle(color: copperPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComandaCard({
    required Map<String, dynamic> pedido,
    required Color cardBg,
    required Color textColor,
    required Color textLightColor,
    required Color borderColor,
    required bool esCelular,
    required bool isDark,
  }) {
    final dynamic detallesRaw = pedido['detalles'];
    final List<dynamic> detalles = detallesRaw is List ? detallesRaw : [];

    final String ubicacion = _ubicacionPedido(pedido);
    final String horaFormateada = _horaFormateada(pedido['fecha']);
    final int pedidoId = _toInt(pedido['id']);

    return Card(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor,
          width: 1.4,
        ),
      ),
      elevation: isDark ? 0 : 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCabeceraComanda(
            pedidoId: pedidoId,
            ubicacion: ubicacion,
            hora: horaFormateada,
            textColor: textColor,
            esCelular: esCelular,
          ),

          Expanded(
            child: detalles.isEmpty
                ? Center(
                    child: Text(
                      'Sin detalles del pedido',
                      style: TextStyle(
                        color: textLightColor,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: detalles.length,
                    itemBuilder: (context, index) {
                      final raw = detalles[index];

                      final detalle = raw is Map
                          ? Map<String, dynamic>.from(raw)
                          : <String, dynamic>{};

                      return _buildItemDetalle(
                        detalle: detalle,
                        textColor: textColor,
                        textLightColor: textLightColor,
                      );
                    },
                  ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _procesando
                    ? null
                    : () => _confirmarPedidoListo(pedido),
                icon: _procesando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                      ),
                label: Text(
                  _procesando ? 'PROCESANDO...' : 'ORDEN LISTA',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCabeceraComanda({
    required int pedidoId,
    required String ubicacion,
    required String hora,
    required Color textColor,
    required bool esCelular,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: esCelular ? 12 : 14,
        vertical: esCelular ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: copperPrimary.withOpacity(0.15),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: copperPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$pedidoId',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ubicacion,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: copperPrimary,
                fontWeight: FontWeight.w900,
                fontSize: esCelular ? 17 : 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: textColor.withOpacity(0.75),
                size: 17,
              ),
              const SizedBox(width: 4),
              Text(
                hora,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetalle({
    required Map<String, dynamic> detalle,
    required Color textColor,
    required Color textLightColor,
  }) {
    final dynamic productoRaw = detalle['producto'];
    final Map<String, dynamic> producto = productoRaw is Map
        ? Map<String, dynamic>.from(productoRaw)
        : <String, dynamic>{};

    final dynamic categoriaRaw =
        detalle['categoria'] ?? detalle['categoriaNombre'] ?? producto['categoria'];

    String categoria = '';

    if (categoriaRaw is String) {
      categoria = categoriaRaw;
    } else if (categoriaRaw is Map && categoriaRaw['nombre'] != null) {
      categoria = categoriaRaw['nombre'].toString();
    }

    final String productoNombre =
        detalle['nombre']?.toString() ??
        producto['nombre']?.toString() ??
        'Producto sin nombre';

    final int cantidad = _toInt(detalle['cantidad']);
    final String notas =
        detalle['notes']?.toString() ?? detalle['notas']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: textLightColor.withOpacity(0.16),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categoria.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 3),
              child: Text(
                categoria.toUpperCase(),
                style: TextStyle(
                  color: copperPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 34),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: copperPrimary,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${cantidad <= 0 ? 1 : cantidad}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  productoNombre,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          if (notas.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 5),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.35),
                  ),
                ),
                child: Text(
                  '⚠️ $notas',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}