import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jugueria/config/api_config.dart';
import 'package:flutter_jugueria/main.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/impresora_service.dart';
import '../tema_global.dart';

class TomarPedidoScreen extends StatefulWidget {
  final Map<String, dynamic> silla;

  const TomarPedidoScreen({
    super.key,
    required this.silla,
  });

  @override
  State<TomarPedidoScreen> createState() => _TomarPedidoScreenState();
}

class _TomarPedidoScreenState extends State<TomarPedidoScreen> {
  final Color copperPrimary = const Color(0xFFC07C46);

  List<dynamic> _categoriasMenu = [];
  final List<Map<String, dynamic>> _carrito = [];
  List<dynamic> _productosYaPedidos = [];

  bool _isLoadingMenu = true;
  bool _isLoadingPrecuenta = false;
  bool _enviandoPedido = false;

  int _categoriaSeleccionadaIndex = 0;

  @override
  void initState() {
    super.initState();

    mostrarSoporteGlobal.value = false;

    _cargarMenu();

    if (widget.silla['ocupada'] == true) {
      _cargarPrecuentaMesa();
    }
  }

  @override
  void dispose() {
    mostrarSoporteGlobal.value = true;
    super.dispose();
  }

  String get _tituloMesa {
    return widget.silla['grupo'] != null
        ? 'Grupo ${widget.silla['grupo']}'
        : 'Silla ${widget.silla['id']}';
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
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

  Future<void> _cargarMenu() async {
    if (!mounted) return;

    setState(() {
      _isLoadingMenu = true;
    });

    try {
      final response = await http
          .get(
            ApiConfig.uri('/productos/menu'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _categoriasMenu = data is List ? data : [];
          _categoriaSeleccionadaIndex = 0;
          _isLoadingMenu = false;
        });
      } else {
        setState(() {
          _isLoadingMenu = false;
        });

        _mostrarMensaje(
          'No se pudo cargar menú: ${_mensajeBackend(response.body)}',
          Colors.redAccent,
        );
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _isLoadingMenu = false;
      });

      _mostrarMensaje(
        'Tiempo agotado al cargar menú.',
        Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMenu = false;
      });

      _mostrarMensaje(
        'Error al conectar con productos.',
        Colors.redAccent,
      );
    }
  }

  Future<void> _cargarPrecuentaMesa() async {
    if (!mounted) return;

    setState(() {
      _isLoadingPrecuenta = true;
    });

    try {
      final bool esGrupo = widget.silla['grupo'] != null;

      final String endpoint = esGrupo
          ? 'grupo/${widget.silla['grupo']}'
          : 'silla/${widget.silla['id']}';

      final response = await http
          .get(
            ApiConfig.uri('/pedidos/precuenta/$endpoint'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _productosYaPedidos = data['detalles'] ?? [];
          _isLoadingPrecuenta = false;
        });
      } else {
        setState(() {
          _productosYaPedidos = [];
          _isLoadingPrecuenta = false;
        });
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _isLoadingPrecuenta = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingPrecuenta = false;
      });
    }
  }

  String _categoriaActualNombre() {
    if (_categoriasMenu.isEmpty) return 'GENERAL';

    if (_categoriaSeleccionadaIndex < 0 ||
        _categoriaSeleccionadaIndex >= _categoriasMenu.length) {
      return 'GENERAL';
    }

    return (_categoriasMenu[_categoriaSeleccionadaIndex]['nombre'] ?? 'GENERAL')
        .toString();
  }

  void _agregarAlCarrito(dynamic producto) {
    final String categoriaNombre = _categoriaActualNombre();

    setState(() {
      final int index = _carrito.indexWhere(
        (item) =>
            item['productoId'] == producto['id'] &&
            item['notas'] == '' &&
            item['categoria'] == categoriaNombre,
      );

      if (index != -1) {
        _carrito[index]['cantidad'] = _toInt(_carrito[index]['cantidad']) + 1;
      } else {
        _carrito.add({
          'productoId': producto['id'],
          'nombre': producto['nombre'],
          'precio': _toDouble(producto['precio']),
          'cantidad': 1,
          'notas': '',
          'categoria': categoriaNombre,
        });
      }
    });
  }

  void _modificarCantidad(int index, int delta) {
    setState(() {
      _carrito[index]['cantidad'] = _toInt(_carrito[index]['cantidad']) + delta;

      if (_toInt(_carrito[index]['cantidad']) <= 0) {
        _carrito.removeAt(index);
      }
    });
  }

  void _agregarNotaEspecial(int index) {
    final TextEditingController notaCtrl = TextEditingController(
      text: _carrito[index]['notas']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        final double tecladoAltura =
            MediaQuery.of(dialogContext).viewInsets.bottom;

        return AlertDialog(
          insetPadding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: tecladoAltura + 24,
          ),
          title: const Text('Nota para Cocina'),
          content: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: TextField(
              controller: notaCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ej: Sin azúcar, sin hielo, poco dulce...',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                notaCtrl.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: copperPrimary,
              ),
              onPressed: () {
                setState(() {
                  _carrito[index]['notas'] = notaCtrl.text.trim();
                });

                notaCtrl.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  double _calcularTotalNuevos() {
    return _carrito.fold(0.0, (suma, item) {
      return suma + (_toDouble(item['precio']) * _toInt(item['cantidad']));
    });
  }

  double _calcularTotalYaPedidos() {
    return _productosYaPedidos.fold(0.0, (suma, item) {
      return suma + _toDouble(item['subtotal']);
    });
  }

  double _calcularTotalGeneral() {
    return _calcularTotalNuevos() + _calcularTotalYaPedidos();
  }

  int _totalItemsNuevos() {
    return _carrito.fold<int>(0, (suma, item) {
      return suma + _toInt(item['cantidad']);
    });
  }

  void _mostrarPreviewCocina() {
    if (_carrito.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final double anchoPantalla = MediaQuery.of(dialogContext).size.width;
        final bool esCelular = anchoPantalla < 650;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: esCelular ? 14 : 24,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            child: Container(
              width: esCelular ? double.infinity : 360,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      'VERASALUD',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      '--- COMANDA COCINA ---',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      'UBICACIÓN: $_tituloMesa',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const Text(
                    '--------------------------------',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._carrito.map((item) {
                    final bool tieneNota =
                        item['notas'].toString().trim().isNotEmpty;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['cantidad']}x '.padRight(4),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '[${item['categoria'] ?? 'GENERAL'}] ${item['nombre']}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (tieneNota)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 28.0,
                                top: 2.0,
                                bottom: 2.0,
                              ),
                              child: Text(
                                '  => * OBS: ${item['notas'].toString().toUpperCase()} *',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  const Text(
                    '--------------------------------',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.black26),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text(
                            'CORREGIR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _enviandoPedido
                              ? null
                              : () {
                                  Navigator.pop(dialogContext);
                                  _enviarPedido();
                                },
                          child: const Text(
                            'CONFIRMAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _enviarPedido() async {
    if (_carrito.isEmpty || _enviandoPedido) return;

    setState(() {
      _enviandoPedido = true;
    });

    try {
      final body = {
        if (widget.silla['grupo'] == null)
          'sillaId': widget.silla['id']
        else
          'grupoId': widget.silla['grupo'],
        'items': _carrito.map((item) {
          return {
            'productoId': item['productoId'],
            'cantidad': item['cantidad'],
            'precio': item['precio'],
            'notas': item['notas'],
          };
        }).toList(),
      };

      final response = await http
          .post(
            ApiConfig.uri('/pedidos'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        bool impresionOk = false;

        try {
          final prefs = await SharedPreferences.getInstance();
          final ipCocina = prefs.getString('ip_ticketera_cocina') ?? '';

          if (ipCocina.isNotEmpty) {
            final bytes = await ImpresoraService.generarTicketCocina(
              _tituloMesa,
              _carrito,
            );

            impresionOk = await ImpresoraService.enviarAImpresoraIP(
              ipCocina,
              bytes,
            );
          }
        } catch (e) {
          debugPrint('Error impresión cocina: $e');
        }

        if (!mounted) return;

        _mostrarMensaje(
          impresionOk
              ? '¡Pedido enviado a cocina e impreso!'
              : '¡Pedido enviado a cocina! No se pudo imprimir.',
          impresionOk ? Colors.green : Colors.orange,
        );

        Navigator.pop(context);
      } else {
        _mostrarMensaje(
          'No se pudo enviar pedido: ${_mensajeBackend(response.body)}',
          Colors.redAccent,
        );
      }
    } on TimeoutException {
      if (!mounted) return;

      _mostrarMensaje(
        'Tiempo agotado al enviar pedido.',
        Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error al enviar pedido.',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _enviandoPedido = false;
        });
      }
    }
  }

  void _mostrarCarritoMobile(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final Color panelBg =
            isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara;
        final Color textColor =
            isDark ? AppColores.textoOscuro : AppColores.textoClaro;

        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Comanda Actual',
                            style: TextStyle(
                              color: copperPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Icon(Icons.close, color: textColor),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildCarritoLista(
                      isDark: isDark,
                      controller: scrollController,
                    ),
                  ),
                  _buildCarritoFooter(
                    isDark: isDark,
                    esCelular: true,
                    onEnviar: _carrito.isEmpty
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            Future.delayed(
                              const Duration(milliseconds: 120),
                              _mostrarPreviewCocina,
                            );
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        final Color backgroundColor =
            isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5);

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool esCelular = constraints.maxWidth < 760;

            return Scaffold(
              resizeToAvoidBottomInset: true,
              backgroundColor: backgroundColor,
              appBar: AppBar(
                backgroundColor: isDark
                    ? AppColores.tarjetaOscura
                    : AppColores.tarjetaClara,
                foregroundColor:
                    isDark ? AppColores.textoOscuro : AppColores.textoClaro,
                elevation: 0,
                title: Text(
                  esCelular ? _tituloMesa : 'Pedido: $_tituloMesa',
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  if (esCelular)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _mostrarCarritoMobile(isDark),
                          icon: const Icon(Icons.shopping_cart_outlined),
                        ),
                        if (_totalItemsNuevos() > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _totalItemsNuevos().toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              body: esCelular
                  ? _buildMobileLayout(isDark)
                  : Row(
                      children: [
                        Expanded(
                          flex: 65,
                          child: _buildMenu(
                            isDark: isDark,
                            esCelular: false,
                          ),
                        ),
                        Container(
                          width: 2,
                          color: Colors.grey.withOpacity(0.3),
                        ),
                        Expanded(
                          flex: 35,
                          child: _buildCarritoPanelTablet(isDark),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: _buildMenu(
            isDark: isDark,
            esCelular: true,
          ),
        ),
        _buildResumenMobile(isDark),
      ],
    );
  }

  Widget _buildResumenMobile(bool isDark) {
    final Color panelColor =
        isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara;
    final Color textColor =
        isDark ? AppColores.textoOscuro : AppColores.textoClaro;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: panelColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(18),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total: S/ ${_calcularTotalGeneral().toStringAsFixed(2)}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_totalItemsNuevos()} nuevo(s)',
                  style: TextStyle(
                    color: copperPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _mostrarCarritoMobile(isDark),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Ver comanda'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _carrito.isEmpty ? Colors.grey : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: _carrito.isEmpty ? null : _mostrarPreviewCocina,
                    icon: _enviandoPedido
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    label: const Text(
                      'Enviar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu({
    required bool isDark,
    required bool esCelular,
  }) {
    final Color textColor =
        isDark ? AppColores.textoOscuro : AppColores.textoClaro;

    if (_isLoadingMenu) {
      return Center(
        child: CircularProgressIndicator(color: copperPrimary),
      );
    }

    if (_categoriasMenu.isEmpty) {
      return Center(
        child: Text(
          'No hay productos disponibles',
          style: TextStyle(color: textColor),
        ),
      );
    }

    if (_categoriaSeleccionadaIndex >= _categoriasMenu.length) {
      _categoriaSeleccionadaIndex = 0;
    }

    final productos =
        _categoriasMenu[_categoriaSeleccionadaIndex]['productos'] ?? [];

    return Column(
      children: [
        SizedBox(
          height: esCelular ? 58 : 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: _categoriasMenu.length,
            itemBuilder: (context, index) {
              final bool seleccionada = _categoriaSeleccionadaIndex == index;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: seleccionada
                        ? copperPrimary
                        : (isDark ? Colors.grey[850] : Colors.white),
                    foregroundColor: seleccionada
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black),
                    elevation: seleccionada ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _categoriaSeleccionadaIndex = index;
                    });
                  },
                  child: Text(
                    _categoriasMenu[index]['nombre']?.toString() ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: productos.isEmpty
              ? Center(
                  child: Text(
                    'No hay productos en esta categoría.',
                    style: TextStyle(color: textColor.withOpacity(0.65)),
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.all(esCelular ? 10 : 16),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: esCelular ? 2 : 4,
                    crossAxisSpacing: esCelular ? 8 : 10,
                    mainAxisSpacing: esCelular ? 8 : 10,
                    childAspectRatio: esCelular ? 1.28 : 2.5,
                  ),
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    final producto = productos[index];

                    return _buildProductoCard(
                      producto: producto,
                      isDark: isDark,
                      esCelular: esCelular,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductoCard({
    required dynamic producto,
    required bool isDark,
    required bool esCelular,
  }) {
    final String nombre = producto['nombre']?.toString() ?? '-';
    final double precio = _toDouble(producto['precio']);

    return InkWell(
      onTap: () => _agregarAlCarrito(producto),
      borderRadius: BorderRadius.circular(14),
      child: Card(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: EdgeInsets.all(esCelular ? 10 : 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment:
                esCelular ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.local_drink,
                color: copperPrimary,
                size: esCelular ? 28 : 22,
              ),
              SizedBox(height: esCelular ? 8 : 4),
              Text(
                nombre,
                maxLines: esCelular ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                textAlign: esCelular ? TextAlign.center : TextAlign.left,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: esCelular ? 13 : 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'S/ ${precio.toStringAsFixed(2)}',
                style: TextStyle(
                  color: copperPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: esCelular ? 15 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarritoPanelTablet(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: isDark ? Colors.black26 : const Color(0xFFE0E0E0),
          width: double.infinity,
          child: Text(
            'Comanda Actual',
            style: TextStyle(
              color: copperPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: _buildCarritoLista(isDark: isDark),
        ),
        _buildCarritoFooter(
          isDark: isDark,
          esCelular: false,
          onEnviar: _carrito.isEmpty ? null : _mostrarPreviewCocina,
        ),
      ],
    );
  }

  Widget _buildCarritoLista({
    required bool isDark,
    ScrollController? controller,
  }) {
    final Color textColor =
        isDark ? AppColores.textoOscuro : AppColores.textoClaro;

    if (_isLoadingPrecuenta) {
      return Center(
        child: CircularProgressIndicator(color: copperPrimary),
      );
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_productosYaPedidos.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Text(
                  'YA PEDIDOS',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ..._productosYaPedidos.map((item) {
            return Card(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              elevation: 0,
              child: ListTile(
                dense: true,
                leading: Text(
                  '${item['cantidad']}x',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                title: Text(
                  item['nombre']?.toString() ?? '-',
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: Text(
                  'S/ ${_toDouble(item['subtotal']).toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            );
          }),
          const Divider(height: 24),
        ],
        if (_carrito.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  Icons.fiber_new,
                  color: AppColores.verdeLogo,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'NUEVOS',
                  style: TextStyle(
                    color: AppColores.verdeLogo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        if (_carrito.isEmpty && _productosYaPedidos.isEmpty)
          Padding(
            padding: const EdgeInsets.all(30),
            child: Center(
              child: Text(
                'Sin productos',
                style: TextStyle(color: textColor.withOpacity(0.65)),
              ),
            ),
          ),
        ..._carrito.asMap().entries.map((entry) {
          final int index = entry.key;
          final item = entry.value;

          final int cantidad = _toInt(item['cantidad']);
          final double precio = _toDouble(item['precio']);
          final double subtotal = cantidad * precio;
          final bool tieneNota = item['notas'].toString().trim().isNotEmpty;

          return Card(
            color: isDark ? const Color(0xFF252525) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['categoria']?.toString() ?? 'GENERAL',
                    style: TextStyle(
                      color: copperPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['nombre']?.toString() ?? '-',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'S/ ${subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: copperPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (tieneNota)
                    Padding(
                      padding: const EdgeInsets.only(top: 5.0),
                      child: Text(
                        'Nota: ${item['notas']}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_note,
                          color: Colors.grey,
                        ),
                        onPressed: () => _agregarNotaEspecial(index),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _modificarCantidad(index, -1),
                          ),
                          Text(
                            cantidad.toString(),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.green,
                            ),
                            onPressed: () => _modificarCantidad(index, 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCarritoFooter({
    required bool isDark,
    required bool esCelular,
    required VoidCallback? onEnviar,
  }) {
    final Color textColor =
        isDark ? AppColores.textoOscuro : AppColores.textoClaro;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.all(esCelular ? 16 : 20),
        color: isDark ? Colors.black45 : const Color(0xFFF5F5F5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TOTAL GENERAL',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'S/ ${_calcularTotalGeneral().toStringAsFixed(2)}',
                  style: TextStyle(
                    color: copperPrimary,
                    fontSize: esCelular ? 22 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (_productosYaPedidos.isNotEmpty || _carrito.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ya pedidos: S/ ${_calcularTotalYaPedidos().toStringAsFixed(2)}',
                      style: TextStyle(
                        color: textColor.withOpacity(0.62),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'Nuevos: S/ ${_calcularTotalNuevos().toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppColores.verdeLogo,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _carrito.isEmpty ? Colors.grey : Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _carrito.isEmpty || _enviandoPedido ? null : onEnviar,
                icon: _enviandoPedido
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.restaurant_menu, color: Colors.white),
                label: Text(
                  _enviandoPedido ? 'ENVIANDO...' : 'ENVIAR A COCINA',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}