// ignore_for_file: unused_element

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jugueria/config/api_config.dart';
import 'package:flutter_jugueria/main.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/impresora_service.dart';
import '../tema_global.dart';
import 'tomar_pedido_screen.dart';

class PuntoVentaScreen extends StatefulWidget {
  const PuntoVentaScreen({super.key});

  @override
  State<PuntoVentaScreen> createState() => _PuntoVentaScreenState();
}

class _PuntoVentaScreenState extends State<PuntoVentaScreen> {
  List<dynamic> _sillas = [];
  bool _isLoadingSillas = true;
  bool _modoJuntar = false;
  bool _procesandoCobro = false;

  final List<int> _sillasSeleccionadasParaJuntar = [];

  Map<String, dynamic>? _cuentaSeleccionada;
  Map<String, dynamic>? _detallePrecuenta;

  bool _isLoadingPrecuenta = false;
  String _metodoPagoSeleccionado = 'EFECTIVO';

  final TextEditingController _documentoController = TextEditingController();

  Map<String, dynamic>? _clienteSeleccionado;
  bool _buscandoCliente = false;

  @override
  void initState() {
    super.initState();
    mostrarSoporteGlobal.value = false;
    _cargarSillas();
  }

  @override
  void dispose() {
    mostrarSoporteGlobal.value = true;
    _documentoController.dispose();
    super.dispose();
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

  Future<void> _cargarSillas() async {
    if (!mounted) return;

    setState(() {
      _isLoadingSillas = true;
    });

    try {
      final response = await http
          .get(
            ApiConfig.uri('/sillas'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _sillas = jsonDecode(response.body);
          _isLoadingSillas = false;
        });
      } else {
        setState(() {
          _isLoadingSillas = false;
        });

        _mostrarMensaje(
          'No se pudo cargar mesas: ${_mensajeBackend(response.body)}',
          Colors.redAccent,
        );
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _isLoadingSillas = false;
      });

      _mostrarMensaje(
        'Tiempo agotado al cargar mesas.',
        Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingSillas = false;
      });

      _mostrarMensaje(
        'Error al cargar mapa de mesas.',
        Colors.redAccent,
      );
    }
  }

  Future<void> _ocuparSillaAPI(int idSilla) async {
    try {
      await http
          .patch(
            ApiConfig.uri('/sillas/$idSilla/ocupar'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      await _cargarSillas();
    } catch (e) {
      _mostrarMensaje('No se pudo ocupar la silla.', Colors.redAccent);
    }
  }

  Future<void> _liberarSillaAPI(int idSilla) async {
    try {
      await http
          .patch(
            ApiConfig.uri('/sillas/$idSilla/liberar'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      await _cargarSillas();
    } catch (e) {
      _mostrarMensaje('No se pudo liberar la silla.', Colors.redAccent);
    }
  }

  Future<void> _agruparSillasAPI(List<int> ids) async {
    try {
      await http
          .post(
            ApiConfig.uri('/sillas/agrupar'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({'sillasIds': ids}),
          )
          .timeout(ApiConfig.timeout);

      await _cargarSillas();
    } catch (e) {
      _mostrarMensaje('No se pudo juntar las sillas.', Colors.redAccent);
    }
  }

  Future<void> _liberarGrupoAPI(int grupoId) async {
    try {
      await http
          .patch(
            ApiConfig.uri('/sillas/grupo/$grupoId/liberar'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      await _cargarSillas();
    } catch (e) {
      _mostrarMensaje('No se pudo liberar el grupo.', Colors.redAccent);
    }
  }

  void _alTocarSilla(int index) {
    final silla = _sillas[index];

    if (_modoJuntar) {
      if (silla['ocupada'] == true) {
        _mostrarMensaje(
          'Silla ya ocupada, no se puede juntar.',
          Colors.orange,
        );
        return;
      }

      setState(() {
        if (_sillasSeleccionadasParaJuntar.contains(silla['id'])) {
          _sillasSeleccionadasParaJuntar.remove(silla['id']);
        } else {
          _sillasSeleccionadasParaJuntar.add(silla['id']);
        }
      });

      return;
    }

    if (silla['ocupada'] == true) {
      _mostrarDialogoOpcionesSilla(Map<String, dynamic>.from(silla));
    } else {
      _ocuparSillaAPI(silla['id']);
    }
  }

  void _confirmarGrupo() {
    if (_sillasSeleccionadasParaJuntar.length < 2) {
      _mostrarMensaje(
        'Selecciona al menos 2 sillas.',
        Colors.orange,
      );
      return;
    }

    _agruparSillasAPI(_sillasSeleccionadasParaJuntar);

    setState(() {
      _modoJuntar = false;
      _sillasSeleccionadasParaJuntar.clear();
    });
  }

  void _mostrarDialogoOpcionesSilla(Map<String, dynamic> silla) {
    final bool esGrupo = silla['grupo'] != null;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final bool isDark = isDarkModeGlobal.value;
        final Color textColor =
            isDark ? AppColores.textoOscuro : AppColores.textoClaro;
        final Color subTextColor = isDark
            ? AppColores.textoOscuroSecundario
            : AppColores.textoClaroSecundario;

        return AlertDialog(
          backgroundColor:
              isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            esGrupo ? 'Mesa / Grupo ${silla['grupo']}' : 'Mesa / Silla ${silla['id']}',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '¿Qué acción deseas realizar con esta cuenta?',
            style: TextStyle(color: subTextColor),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TomarPedidoScreen(silla: silla),
                  ),
                );
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Pedido'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _cargarPrecuenta(silla);
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('Cobrar'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);

                if (esGrupo) {
                  _liberarGrupoAPI(silla['grupo']);
                } else {
                  _liberarSillaAPI(silla['id']);
                }

                if (_cuentaSeleccionada?['id'] == silla['id']) {
                  setState(() {
                    _cuentaSeleccionada = null;
                    _detallePrecuenta = null;
                  });
                }
              },
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              label: const Text(
                'Liberar',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cargarPrecuenta(Map<String, dynamic> silla) async {
    setState(() {
      _cuentaSeleccionada = silla;
      _isLoadingPrecuenta = true;
      _detallePrecuenta = null;
      _clienteSeleccionado = null;
      _documentoController.clear();
    });

    try {
      final bool esGrupo = silla['grupo'] != null;
      final String endpoint =
          esGrupo ? 'grupo/${silla['grupo']}' : 'silla/${silla['id']}';

      final response = await http
          .get(
            ApiConfig.uri('/pedidos/precuenta/$endpoint'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _detallePrecuenta = jsonDecode(response.body);
          _isLoadingPrecuenta = false;
        });
      } else {
        setState(() {
          _isLoadingPrecuenta = false;
        });

        _mostrarMensaje(
          'Esta mesa aún no tiene pedidos.',
          Colors.orange,
        );
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _isLoadingPrecuenta = false;
      });

      _mostrarMensaje(
        'Tiempo agotado consultando cuenta.',
        Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingPrecuenta = false;
      });

      _mostrarMensaje(
        'Error al consultar cuenta.',
        Colors.redAccent,
      );
    }
  }

  Future<void> _buscarCliente() async {
    final documento = _documentoController.text.trim();

    if (documento.isEmpty) return;

    setState(() {
      _buscandoCliente = true;
    });

    try {
      final responseLocal = await http
          .get(
            ApiConfig.uri('/clientes/local/$documento'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (responseLocal.statusCode == 200) {
        setState(() {
          _clienteSeleccionado = jsonDecode(responseLocal.body)['cliente'];
          _buscandoCliente = false;
        });
      } else {
        setState(() {
          _buscandoCliente = false;
        });

        _mostrarDialogoConfirmacionSunat(documento);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _buscandoCliente = false;
      });

      _mostrarDialogoConfirmacionSunat(documento);
    }
  }

  void _mostrarDialogoConfirmacionSunat(String documento) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cliente Nuevo'),
        content: Text('¿Buscar a $documento en SUNAT/RENIEC?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.naranjaLogo,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _buscarClienteEnSunat(documento);
            },
            child: const Text(
              'Sí, Consultar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buscarClienteEnSunat(String documento) async {
    setState(() {
      _buscandoCliente = true;
    });

    try {
      final response = await http
          .get(
            ApiConfig.uri('/clientes/externo/$documento'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _clienteSeleccionado = jsonDecode(response.body)['cliente'];
          _buscandoCliente = false;
        });
      } else {
        setState(() {
          _buscandoCliente = false;
        });

        _mostrarMensaje(
          'No se encontró el cliente.',
          Colors.orange,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _buscandoCliente = false;
      });

      _mostrarMensaje(
        'No se pudo consultar cliente externo.',
        Colors.redAccent,
      );
    }
  }

  void _limpiarCliente() {
    setState(() {
      _clienteSeleccionado = null;
      _documentoController.clear();
    });
  }

  Future<void> _procesarCobro() async {
    if (_detallePrecuenta == null || _procesandoCobro) return;

    final int pedidoId = int.tryParse(_detallePrecuenta!['id'].toString()) ?? 0;

    if (pedidoId <= 0) {
      _mostrarMensaje('Pedido inválido.', Colors.redAccent);
      return;
    }

    setState(() {
      _procesandoCobro = true;
    });

    try {
      final response = await http
          .patch(
            ApiConfig.uri('/pedidos/$pedidoId/pagar'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'metodoPago': _metodoPagoSeleccionado,
              'clienteId': _clienteSeleccionado != null
                  ? _clienteSeleccionado!['id']
                  : null,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        bool impresionCorrecta = false;

        try {
          final prefs = await SharedPreferences.getInstance();
          final ipCaja =
              prefs.getString('ip_ticketera_caja') ?? '192.168.18.236';

          if (ipCaja.isNotEmpty) {
            final tituloMesa = _cuentaSeleccionada!['grupo'] != null
                ? 'Grupo ${_cuentaSeleccionada!['grupo']}'
                : 'Silla ${_cuentaSeleccionada!['id']}';

            final total = _toDouble(_detallePrecuenta!['total']);
            final items = _detallePrecuenta!['detalles'] ?? [];

            final bytes = await ImpresoraService.generarBoletaCaja(
              tituloMesa,
              items,
              total,
              _metodoPagoSeleccionado,
              _clienteSeleccionado,
            );

            impresionCorrecta = await ImpresoraService.enviarAImpresoraIP(
              ipCaja,
              bytes,
            );
          }
        } catch (e) {
          debugPrint('Error impresión: $e');
        }

        if (!mounted) return;

        setState(() {
          _cuentaSeleccionada = null;
          _detallePrecuenta = null;
          _metodoPagoSeleccionado = 'EFECTIVO';
          _clienteSeleccionado = null;
          _documentoController.clear();
        });

        _mostrarMensaje(
          impresionCorrecta
              ? '¡Cobro exitoso e impresión enviada!'
              : '¡Cobro exitoso! Pero no se pudo imprimir.',
          impresionCorrecta ? Colors.green : Colors.orange,
        );

        await _cargarSillas();
      } else {
        _mostrarMensaje(
          'No se pudo cobrar: ${_mensajeBackend(response.body)}',
          Colors.redAccent,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error al cobrar.',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _procesandoCobro = false;
        });
      }
    }
  }

  Future<void> _imprimirPrecuentaFisica() async {
    if (_detallePrecuenta == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final ipCaja = prefs.getString('ip_ticketera_caja') ?? '';

      if (ipCaja.isEmpty) {
        _mostrarMensaje(
          'Configura la IP de Caja primero.',
          Colors.orange,
        );
        return;
      }

      final tituloMesa = _cuentaSeleccionada!['grupo'] != null
          ? 'Grupo ${_cuentaSeleccionada!['grupo']}'
          : 'Silla ${_cuentaSeleccionada!['id']}';

      final total = _toDouble(_detallePrecuenta!['total']);
      final items = _detallePrecuenta!['detalles'] ?? [];

      final bytes = await ImpresoraService.generarBoletaCaja(
        tituloMesa,
        items,
        total,
        'PRECUENTA',
        null,
      );

      final ok = await ImpresoraService.enviarAImpresoraIP(ipCaja, bytes);

      if (!mounted) return;

      _mostrarMensaje(
        ok
            ? 'Imprimiendo precuenta en caja...'
            : 'No se pudo imprimir la precuenta.',
        ok ? Colors.blueAccent : Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error de conexión con impresora.',
        Colors.redAccent,
      );
    }
  }

  void _mostrarPreview(bool esComanda) {
    if (_detallePrecuenta == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SingleChildScrollView(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  esComanda ? '--- COMANDA COCINA ---' : '--- BOLETA TICKET ---',
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const Divider(),
                ...(_detallePrecuenta!['detalles'] ?? []).map((item) {
                  final subtotal = _toDouble(item['subtotal']);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item['cantidad']}x ${item['nombre']}',
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Text(
                          'S/${subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (!esComanda) ...[
                  const Divider(),
                  Text(
                    'TOTAL: S/${_detallePrecuenta!['total']}',
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.naranjaLogo,
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        final Color panelBgColor =
            isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara;
        final Color cardColor =
            isDark ? const Color(0xFF332A22) : const Color(0xFFF9F5F0);
        final Color textColor =
            isDark ? AppColores.textoOscuro : AppColores.textoClaro;
        final Color textLightColor = isDark
            ? AppColores.textoOscuroSecundario
            : AppColores.textoClaroSecundario;
        final Color borderColor = isDark ? Colors.white12 : Colors.black12;

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool esCelular = constraints.maxWidth < 760;

            if (esCelular) {
              return _buildMobile(
                panelBgColor: panelBgColor,
                cardColor: cardColor,
                textColor: textColor,
                textLightColor: textLightColor,
                borderColor: borderColor,
                isDark: isDark,
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 55,
                  child: _buildPanelMesas(
                    panelBgColor: panelBgColor,
                    cardColor: cardColor,
                    textColor: textColor,
                    textLightColor: textLightColor,
                    borderColor: borderColor,
                    esCelular: false,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 45,
                  child: _buildPanelCobro(
                    panelBgColor: panelBgColor,
                    cardColor: cardColor,
                    textColor: textColor,
                    textLightColor: textLightColor,
                    borderColor: borderColor,
                    esCelular: false,
                    isDark: isDark,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMobile({
    required Color panelBgColor,
    required Color cardColor,
    required Color textColor,
    required Color textLightColor,
    required Color borderColor,
    required bool isDark,
  }) {
    final bool viendoCobro = _cuentaSeleccionada != null;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          children: [
            if (viendoCobro)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _cuentaSeleccionada = null;
                        _detallePrecuenta = null;
                        _clienteSeleccionado = null;
                        _documentoController.clear();
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver al mapa de mesas'),
                  ),
                ),
              ),
            viendoCobro
                ? _buildPanelCobro(
                    panelBgColor: panelBgColor,
                    cardColor: cardColor,
                    textColor: textColor,
                    textLightColor: textLightColor,
                    borderColor: borderColor,
                    esCelular: true,
                    isDark: isDark,
                  )
                : _buildPanelMesas(
                    panelBgColor: panelBgColor,
                    cardColor: cardColor,
                    textColor: textColor,
                    textLightColor: textLightColor,
                    borderColor: borderColor,
                    esCelular: true,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelMesas({
    required Color panelBgColor,
    required Color cardColor,
    required Color textColor,
    required Color textLightColor,
    required Color borderColor,
    required bool esCelular,
  }) {
    final grid = GridView.builder(
      shrinkWrap: esCelular,
      physics: esCelular
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: esCelular ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: esCelular ? 1.15 : 1.1,
      ),
      itemCount: _sillas.length,
      itemBuilder: (context, index) {
        return _buildSillaCard(
          silla: _sillas[index],
          index: index,
          panelBgColor: panelBgColor,
          cardColor: cardColor,
          textColor: textColor,
        );
      },
    );

    return Container(
      padding: EdgeInsets.all(esCelular ? 14 : 20),
      decoration: BoxDecoration(
        color: panelBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        mainAxisSize: esCelular ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (esCelular)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Mapa de Mesas',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildAccionesMesas(esCelular: true),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mapa de Mesas',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildAccionesMesas(esCelular: false),
              ],
            ),
          const SizedBox(height: 20),
          if (_isLoadingSillas)
            SizedBox(
              height: esCelular ? 260 : null,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColores.naranjaLogo,
                ),
              ),
            )
          else if (esCelular)
            grid
          else
            Expanded(child: grid),
        ],
      ),
    );
  }

  Widget _buildAccionesMesas({required bool esCelular}) {
    if (_modoJuntar) {
      if (esCelular) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _modoJuntar = false;
                  _sillasSeleccionadasParaJuntar.clear();
                });
              },
              child: const Text(
                'Cancelar unión',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _confirmarGrupo,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'Unir seleccionadas',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.verdeLogo,
              ),
            ),
          ],
        );
      }

      return Row(
        children: [
          TextButton(
            onPressed: () {
              setState(() {
                _modoJuntar = false;
                _sillasSeleccionadasParaJuntar.clear();
              });
            },
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _confirmarGrupo,
            icon: const Icon(Icons.check, color: Colors.white, size: 18),
            label: const Text('Unir', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.verdeLogo,
            ),
          ),
        ],
      );
    }

    if (esCelular) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
              onPressed: _cargarSillas,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _modoJuntar = true;
                });
              },
              icon: const Icon(Icons.link, color: Colors.white),
              label: const Text(
                'Juntar',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.naranjaLogo,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.refresh, color: AppColores.naranjaLogo),
          onPressed: _cargarSillas,
        ),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _modoJuntar = true;
            });
          },
          icon: const Icon(Icons.link, color: Colors.white, size: 18),
          label: const Text(
            'Juntar',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColores.naranjaLogo,
          ),
        ),
      ],
    );
  }

  Widget _buildSillaCard({
    required dynamic silla,
    required int index,
    required Color panelBgColor,
    required Color cardColor,
    required Color textColor,
  }) {
    final bool estaOcupada = silla['ocupada'] == true;
    final bool tieneGrupo = silla['grupo'] != null;
    final bool estaSeleccionadaGrupo =
        _sillasSeleccionadasParaJuntar.contains(silla['id']);
    final bool estaSeleccionadaCobro =
        _cuentaSeleccionada != null && _cuentaSeleccionada!['id'] == silla['id'];

    Color colorFondo = cardColor;
    Color colorBorde = cardColor;
    Color colorTextoSilla = textColor;

    if (_modoJuntar && estaSeleccionadaGrupo) {
      colorFondo = AppColores.naranjaLogo.withOpacity(0.2);
      colorBorde = AppColores.naranjaLogo;
    } else if (estaSeleccionadaCobro) {
      colorFondo = AppColores.naranjaLogo;
      colorBorde = AppColores.naranjaLogo;
      colorTextoSilla = Colors.white;
    } else if (estaOcupada) {
      colorFondo = AppColores.naranjaLogo.withOpacity(0.82);
      colorBorde = AppColores.naranjaLogo;
      colorTextoSilla = Colors.white;
    } else {
      colorFondo = panelBgColor;
      colorBorde = AppColores.verdeLogo;
    }

    return InkWell(
      onTap: () => _alTocarSilla(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorBorde, width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chair_alt,
                  size: 30,
                  color: estaOcupada ? Colors.white : AppColores.verdeLogo,
                ),
                const SizedBox(height: 4),
                Text(
                  'Silla ${silla['id']}',
                  style: TextStyle(
                    color: colorTextoSilla,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (estaOcupada)
                  Text(
                    'Ocupada',
                    style: TextStyle(
                      color: colorTextoSilla.withOpacity(0.85),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            if (tieneGrupo)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'G${silla['grupo']}',
                    style: TextStyle(
                      color: AppColores.naranjaLogo,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelCobro({
    required Color panelBgColor,
    required Color cardColor,
    required Color textColor,
    required Color textLightColor,
    required Color borderColor,
    required bool esCelular,
    required bool isDark,
  }) {
    if (_cuentaSeleccionada == null) {
      return Container(
        padding: EdgeInsets.all(esCelular ? 24 : 20),
        decoration: BoxDecoration(
          color: panelBgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            )
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 76, color: borderColor),
              const SizedBox(height: 16),
              Text(
                'Selecciona una mesa ocupada\ny presiona "Cobrar"',
                textAlign: TextAlign.center,
                style: TextStyle(color: textLightColor, fontSize: 17),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingPrecuenta) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: panelBgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColores.naranjaLogo,
          ),
        ),
      );
    }

    if (_detallePrecuenta == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: panelBgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            'Error al cargar detalle',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    final detalles = _detallePrecuenta!['detalles'] ?? [];

    final listaProductos = ListView.builder(
      shrinkWrap: esCelular,
      physics: esCelular
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: detalles.length,
      itemBuilder: (context, index) {
        final item = detalles[index];
        final String nombre = item['nombre'] ?? 'Producto';
        final int cantidad = int.tryParse(item['cantidad'].toString()) ?? 1;
        final double precio = _toDouble(item['precio']);
        final double subtotal =
            _toDouble(item['subtotal']) == 0 ? cantidad * precio : _toDouble(item['subtotal']);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${cantidad}x $nombre',
                  style: TextStyle(color: textColor, fontSize: 15),
                ),
              ),
              Text(
                'S/ ${subtotal.toStringAsFixed(2)}',
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );

    return Container(
      decoration: BoxDecoration(
        color: panelBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        mainAxisSize: esCelular ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColores.naranjaLogo.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            width: double.infinity,
            child: Text(
              'Cobrar - ${_cuentaSeleccionada!['grupo'] != null ? 'Grupo ${_cuentaSeleccionada!['grupo']}' : 'Silla ${_cuentaSeleccionada!['id']}'}',
              style: TextStyle(
                color: AppColores.naranjaLogo,
                fontSize: esCelular ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          if (esCelular) listaProductos else Expanded(child: listaProductos),

          _buildClienteBox(
            cardColor: cardColor,
            textColor: textColor,
            textLightColor: textLightColor,
            borderColor: borderColor,
            esCelular: esCelular,
          ),

          _buildTotalPagoBox(
            cardColor: cardColor,
            textColor: textColor,
            borderColor: borderColor,
            isDark: isDark,
            esCelular: esCelular,
          ),
        ],
      ),
    );
  }

  Widget _buildClienteBox({
    required Color cardColor,
    required Color textColor,
    required Color textLightColor,
    required Color borderColor,
    required bool esCelular,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: _clienteSeleccionado == null
          ? esCelular
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _campoDocumentoCliente(
                      cardColor: cardColor,
                      textColor: textColor,
                      textLightColor: textLightColor,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColores.verdeLogo,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _buscandoCliente ? null : _buscarCliente,
                      icon: _buscandoCliente
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.search, color: Colors.white),
                      label: const Text(
                        'Buscar cliente',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _campoDocumentoCliente(
                        cardColor: cardColor,
                        textColor: textColor,
                        textLightColor: textLightColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColores.verdeLogo,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _buscandoCliente ? null : _buscarCliente,
                      child: _buscandoCliente
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.search, color: Colors.white),
                    )
                  ],
                )
          : Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColores.verdeLogo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColores.verdeLogo),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: AppColores.verdeLogo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _clienteSeleccionado!['nombreRazonSocial'] ?? '-',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_clienteSeleccionado!['tipoDocumento']}: ${_clienteSeleccionado!['documento']}',
                          style: TextStyle(
                            color: textLightColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: _limpiarCliente,
                  )
                ],
              ),
            ),
    );
  }

  Widget _campoDocumentoCliente({
    required Color cardColor,
    required Color textColor,
    required Color textLightColor,
  }) {
    return TextField(
      controller: _documentoController,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: 'DNI / RUC del cliente',
        hintStyle: TextStyle(color: textLightColor, fontSize: 13),
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _buscarCliente(),
    );
  }

  Widget _buildTotalPagoBox({
    required Color cardColor,
    required Color textColor,
    required Color borderColor,
    required bool isDark,
    required bool esCelular,
  }) {
    final double total = _toDouble(_detallePrecuenta!['total']);

    return Container(
      padding: EdgeInsets.all(esCelular ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.black45 : const Color(0xFFF9F9F9),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          if (esCelular)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'TOTAL A PAGAR',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'S/ ${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColores.naranjaLogo,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL A PAGAR',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'S/ ${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColores.naranjaLogo,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 15),

          _buildMetodoPagoButtons(
            cardColor: cardColor,
            textColor: textColor,
            borderColor: borderColor,
            esCelular: esCelular,
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.receipt, color: Colors.white),
              label: const Text(
                'IMPRIMIR PRECUENTA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _imprimirPrecuentaFisica,
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 55,
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColores.naranjaLogo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _procesandoCobro
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.print, color: Colors.white),
              label: Text(
                _procesandoCobro
                    ? 'COBRANDO...'
                    : 'COBRAR E IMPRIMIR BOLETA',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              onPressed: _procesandoCobro ? null : _procesarCobro,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetodoPagoButtons({
    required Color cardColor,
    required Color textColor,
    required Color borderColor,
    required bool esCelular,
  }) {
    final botones = [
      _botonMetodoPago(
        'EFECTIVO',
        Icons.payments_outlined,
        cardColor,
        textColor,
        borderColor,
      ),
      _botonMetodoPago(
        'TARJETA',
        Icons.credit_card,
        cardColor,
        textColor,
        borderColor,
      ),
      _botonMetodoPago(
        'YAPE / PLIN',
        Icons.qr_code_scanner,
        cardColor,
        textColor,
        borderColor,
      ),
    ];

    if (esCelular) {
      return Column(
        children: botones
            .map(
              (boton) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: boton,
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: [
        Expanded(child: botones[0]),
        const SizedBox(width: 8),
        Expanded(child: botones[1]),
        const SizedBox(width: 8),
        Expanded(child: botones[2]),
      ],
    );
  }

  Widget _botonMetodoPago(
    String metodo,
    IconData icono,
    Color cardColor,
    Color textColor,
    Color borderColor,
  ) {
    final bool seleccionado = _metodoPagoSeleccionado == metodo;
    final Color textLightColor = isDarkModeGlobal.value
        ? AppColores.textoOscuroSecundario
        : AppColores.textoClaroSecundario;

    return InkWell(
      onTap: () {
        setState(() {
          _metodoPagoSeleccionado = metodo;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColores.naranjaLogo.withOpacity(0.15)
              : cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seleccionado ? AppColores.naranjaLogo : borderColor,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icono,
              color: seleccionado ? AppColores.naranjaLogo : textLightColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              metodo,
              style: TextStyle(
                color: seleccionado ? AppColores.naranjaLogo : textColor,
                fontSize: 10,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}