import 'package:flutter/material.dart';
import 'package:flutter_jugueria/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/impresora_service.dart'; 
import '../tema_global.dart'; // <-- Paleta de colores corporativa
import 'tomar_pedido_screen.dart'; // <-- Importamos la pantalla de pedidos

class PuntoVentaScreen extends StatefulWidget {
  const PuntoVentaScreen({super.key});

  @override
  State<PuntoVentaScreen> createState() => _PuntoVentaScreenState();
}

class _PuntoVentaScreenState extends State<PuntoVentaScreen> {
  // ==========================================
  // VARIABLES: GESTIÓN DE SILLAS
  // ==========================================
  List<dynamic> _sillas = [];
  bool _isLoadingSillas = true;
  bool _modoJuntar = false;
  final List<int> _sillasSeleccionadasParaJuntar = [];

  // ==========================================
  // VARIABLES: FACTURACIÓN Y TICKET
  // ==========================================
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
    _cargarSillas();
    // Ocultamos el botón de soporte para que no estorbe al cobrar
    mostrarSoporteGlobal.value = false;
  }

  @override
  void dispose() {
    mostrarSoporteGlobal.value = true;
    super.dispose();
  }

  // ==========================================
  // 1. API: SILLAS Y GRUPOS
  // ==========================================
  Future<void> _cargarSillas() async {
    setState(() => _isLoadingSillas = true);
    try {
      final url = Uri.parse('http://192.168.18.194:3000/sillas');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _sillas = jsonDecode(response.body);
          _isLoadingSillas = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar el mapa de mesas'), backgroundColor: Colors.redAccent)
      );
      setState(() => _isLoadingSillas = false);
    }
  }

  Future<void> _ocuparSillaAPI(int idSilla) async {
    try {
      final url = Uri.parse('http://192.168.18.194:3000/sillas/$idSilla/ocupar');
      await http.patch(url);
      _cargarSillas(); 
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _liberarSillaAPI(int idSilla) async {
    try {
      final url = Uri.parse('http://192.168.18.194:3000/sillas/$idSilla/liberar');
      await http.patch(url);
      _cargarSillas();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _agruparSillasAPI(List<int> ids) async {
    try {
      final url = Uri.parse('http://192.168.18.194:3000/sillas/agrupar');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sillasIds': ids}),
      );
      _cargarSillas();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _liberarGrupoAPI(int grupoId) async {
    try {
      final url = Uri.parse('http://192.168.18.194:3000/sillas/grupo/$grupoId/liberar');
      await http.patch(url);
      _cargarSillas();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // ==========================================
  // 2. INTERACCIÓN CON SILLAS (EL PUENTE AL TICKET)
  // ==========================================
  void _alTocarSilla(int index) {
    final silla = _sillas[index];
    
    if (_modoJuntar) {
      if (!silla['ocupada']) {
        setState(() {
          if (_sillasSeleccionadasParaJuntar.contains(silla['id'])) {
            _sillasSeleccionadasParaJuntar.remove(silla['id']);
          } else {
            _sillasSeleccionadasParaJuntar.add(silla['id']);
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silla ya ocupada, no se puede juntar')));
      }
    } else {
      if (silla['ocupada']) {
        _mostrarDialogoOpcionesSilla(silla);
      } else {
        _ocuparSillaAPI(silla['id']);
      }
    }
  }

  void _confirmarGrupo() {
    if (_sillasSeleccionadasParaJuntar.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona al menos 2 sillas')));
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
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkModeGlobal.value ? AppColores.tarjetaOscura : AppColores.tarjetaClara,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            esGrupo ? 'Mesa / Grupo ${silla['grupo']}' : 'Mesa / Silla ${silla['id']}', 
            style: TextStyle(color: isDarkModeGlobal.value ? AppColores.textoOscuro : AppColores.textoClaro, fontWeight: FontWeight.bold)
          ),
          content: Text(
            '¿Qué acción deseas realizar con esta cuenta?',
            style: TextStyle(color: isDarkModeGlobal.value ? AppColores.textoOscuroSecundario : AppColores.textoClaroSecundario),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            // 1. TOMAR PEDIDO
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColores.verdeLogo),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => TomarPedidoScreen(silla: silla)));
              },
              icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
              label: const Text('Pedido', style: TextStyle(color: Colors.white)),
            ),
            // 2. ENVIAR A COBRAR (Carga el ticket a la derecha)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColores.naranjaLogo),
              onPressed: () {
                Navigator.pop(context);
                _cargarPrecuenta(silla);
              },
              icon: const Icon(Icons.receipt_long, color: Colors.white, size: 18),
              label: const Text('Cobrar', style: TextStyle(color: Colors.white)),
            ),
            // 3. LIBERAR/CANCELAR
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(context);
                if (esGrupo) {
                  _liberarGrupoAPI(silla['grupo']);
                } else {
                  _liberarSillaAPI(silla['id']);
                }
                if (_cuentaSeleccionada?['id'] == silla['id']) {
                  setState(() => _cuentaSeleccionada = null);
                }
              },
              icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
              label: const Text('Liberar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );
  }

  // ==========================================
  // 3. API: PRECUENTA Y PAGO
  // ==========================================
  Future<void> _cargarPrecuenta(Map<String, dynamic> silla) async {
    setState(() {
      _cuentaSeleccionada = silla;
      _isLoadingPrecuenta = true;
      _detallePrecuenta = null;
      _limpiarCliente(); 
    });

    try {
      final bool esGrupo = silla['grupo'] != null;
      final String endpoint = esGrupo ? 'grupo/${silla['grupo']}' : 'silla/${silla['id']}';
      final url = Uri.parse('http://192.168.18.194:3000/pedidos/precuenta/$endpoint');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _detallePrecuenta = jsonDecode(response.body);
          _isLoadingPrecuenta = false;
        });
      } else {
        setState(() => _isLoadingPrecuenta = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta mesa aún no tiene pedidos')));
      }
    } catch (e) {
      setState(() => _isLoadingPrecuenta = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al consultar cuenta')));
    }
  }

  // Lógica de clientes
  Future<void> _buscarCliente() async {
    final documento = _documentoController.text.trim();
    if (documento.isEmpty) return;
    setState(() => _buscandoCliente = true);

    try {
      final urlLocal = Uri.parse('http://192.168.18.194:3000/clientes/local/$documento');
      final responseLocal = await http.get(urlLocal);

      if (responseLocal.statusCode == 200) {
        setState(() {
          _clienteSeleccionado = jsonDecode(responseLocal.body)['cliente'];
          _buscandoCliente = false;
        });
      } else {
        setState(() => _buscandoCliente = false);
        _mostrarDialogoConfirmacionSunat(documento);
      }
    } catch (e) {
      setState(() => _buscandoCliente = false);
    }
  }

  void _mostrarDialogoConfirmacionSunat(String documento) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cliente Nuevo'),
        content: Text('¿Buscar a $documento en SUNAT/RENIEC?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColores.naranjaLogo),
            onPressed: () {
              Navigator.pop(context);
              _buscarClienteEnSunat(documento); 
            },
            child: const Text('Sí, Consultar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _buscarClienteEnSunat(String documento) async {
    setState(() => _buscandoCliente = true);
    try {
      final urlExterno = Uri.parse('http://192.168.18.194:3000/clientes/externo/$documento');
      final response = await http.get(urlExterno);
      if (response.statusCode == 200) {
        setState(() {
          _clienteSeleccionado = jsonDecode(response.body)['cliente'];
          _buscandoCliente = false;
        });
      } else {
        setState(() => _buscandoCliente = false);
      }
    } catch (e) {
      setState(() => _buscandoCliente = false);
    }
  }

  void _limpiarCliente() {
    setState(() {
      _clienteSeleccionado = null;
      _documentoController.clear();
    });
  }

  Future<void> _procesarCobro() async {
    if (_detallePrecuenta == null) return;
    final int pedidoId = _detallePrecuenta!['id'];

    try {
      final url = Uri.parse('http://192.168.18.194:3000/pedidos/$pedidoId/pagar');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'metodoPago': _metodoPagoSeleccionado,
          'clienteId': _clienteSeleccionado != null ? _clienteSeleccionado!['id'] : null
        }),
      );

      if (response.statusCode == 200) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final ipCaja = prefs.getString('ip_ticketera_caja') ?? '192.168.18.238';
          if (ipCaja.isNotEmpty) {
            final tituloMesa = _cuentaSeleccionada!['grupo'] != null ? 'Grupo ${_cuentaSeleccionada!['grupo']}' : 'Silla ${_cuentaSeleccionada!['id']}';
            final total = double.tryParse(_detallePrecuenta!['total'].toString()) ?? 0.0;
            final items = _detallePrecuenta!['detalles'] ?? [];
            final bytes = await ImpresoraService.generarBoletaCaja(tituloMesa, items, total, _metodoPagoSeleccionado, _clienteSeleccionado);
            await ImpresoraService.enviarAImpresoraIP(ipCaja, bytes);
          }
        } catch (e) {
          debugPrint("Error impresión: $e");
        }

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Cobro exitoso!'), backgroundColor: Colors.green));
        
        setState(() {
          _cuentaSeleccionada = null;
          _detallePrecuenta = null;
          _metodoPagoSeleccionado = 'EFECTIVO';
          _limpiarCliente();
        });
        _cargarSillas(); // Recargamos las sillas para que se libere el color
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al cobrar')));
    }
  }

  Future<void> _imprimirPrecuentaFisica() async {
    if (_detallePrecuenta == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ipCaja = prefs.getString('ip_ticketera_caja') ?? '';
      
      if (ipCaja.isNotEmpty) {
        final tituloMesa = _cuentaSeleccionada!['grupo'] != null ? 'Grupo ${_cuentaSeleccionada!['grupo']}' : 'Silla ${_cuentaSeleccionada!['id']}';
        final total = double.tryParse(_detallePrecuenta!['total'].toString()) ?? 0.0;
        final items = _detallePrecuenta!['detalles'] ?? [];
        
        // Enviamos el ticket a Caja, usando "PRECUENTA" como método de pago para que salga en el título
        final bytes = await ImpresoraService.generarBoletaCaja(tituloMesa, items, total, 'PRECUENTA', null);
        await ImpresoraService.enviarAImpresoraIP(ipCaja, bytes);
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imprimiendo Precuenta en Caja...'), backgroundColor: Colors.blueAccent));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configura la IP de Caja primero'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión con impresora'), backgroundColor: Colors.red));
    }
  }

  // --- LÓGICA DE PREVIEW ---
  void _mostrarPreview(bool esComanda) {
    if (_detallePrecuenta == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(esComanda ? '--- COMANDA COCINA ---' : '--- BOLETA TICKET ---', 
                   style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
              const Divider(),
              ...(_detallePrecuenta!['detalles'] ?? []).map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item['cantidad']}x ${item['nombre']}', style: const TextStyle(fontFamily: 'Courier', color: Colors.black)),
                    Text('S/${double.parse(item['subtotal'].toString()).toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Courier', color: Colors.black)),
                  ],
                ),
              )),
              if (!esComanda) ...[
                const Divider(),
                Text('TOTAL: S/${_detallePrecuenta!['total']}', 
                     style: const TextStyle(fontFamily: 'Courier', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColores.naranjaLogo),
                onPressed: () => Navigator.pop(context), 
                child: const Text('Cerrar', style: TextStyle(color: Colors.white))
              )
            ],
          ),
        ),
      )
    );
  }

  // ==========================================
  // CONSTRUCCIÓN VISUAL UNIFICADA
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {

        final Color panelBgColor = isDark ? AppColores.tarjetaOscura : AppColores.tarjetaClara;
        final Color cardColor = isDark ? const Color(0xFF332A22) : const Color(0xFFF9F5F0);
        final Color textColor = isDark ? AppColores.textoOscuro : AppColores.textoClaro;
        final Color textLightColor = isDark ? AppColores.textoOscuroSecundario : AppColores.textoClaroSecundario;
        final Color borderColor = isDark ? Colors.white12 : Colors.black12;

        return Row(
          children: [
            // ==========================================
            // PANEL IZQUIERDO: MAPA DE MESAS Y SILLAS
            // ==========================================
            Expanded(
              flex: 55,
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: panelBgColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Mapa de Mesas', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                        if (_modoJuntar) ...[
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => setState(() { _modoJuntar = false; _sillasSeleccionadasParaJuntar.clear(); }),
                                child: const Text('Cancelar', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _confirmarGrupo,
                                icon: const Icon(Icons.check, color: Colors.white, size: 18),
                                label: const Text('Unir', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColores.verdeLogo),
                              ),
                            ],
                          )
                        ] else ...[
                          Row(
                            children: [
                              IconButton(icon: Icon(Icons.refresh, color: AppColores.naranjaLogo), onPressed: _cargarSillas),
                              ElevatedButton.icon(
                                onPressed: () => setState(() => _modoJuntar = true),
                                icon: const Icon(Icons.link, color: Colors.white, size: 18),
                                label: const Text('Juntar', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColores.naranjaLogo),
                              ),
                            ],
                          )
                        ]
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _isLoadingSillas 
                        ? Center(child: CircularProgressIndicator(color: AppColores.naranjaLogo))
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4, // 4 columnas para que quepan bien
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.1,
                            ),
                            itemCount: _sillas.length,
                            itemBuilder: (context, index) {
                              final silla = _sillas[index];
                              final bool estaOcupada = silla['ocupada'];
                              final bool tieneGrupo = silla['grupo'] != null;
                              final bool estaSeleccionadaGrupo = _sillasSeleccionadasParaJuntar.contains(silla['id']);
                              final bool estaSeleccionadaCobro = _cuentaSeleccionada != null && _cuentaSeleccionada!['id'] == silla['id'];

                              // Colores Corporativos para el estado de la silla
                              Color colorFondo = cardColor;
                              Color colorBorde = cardColor;
                              Color colorTextoSilla = textColor;

                              if (_modoJuntar && estaSeleccionadaGrupo) {
                                colorFondo = AppColores.naranjaLogo.withValues(alpha: 0.2);
                                colorBorde = AppColores.naranjaLogo;
                              } else if (estaSeleccionadaCobro) {
                                colorFondo = AppColores.naranjaLogo; // Silla activa en caja
                                colorBorde = AppColores.naranjaLogo;
                                colorTextoSilla = Colors.white;
                              } else if (estaOcupada) {
                                colorFondo = AppColores.naranjaLogo.withValues(alpha: 0.8);
                                colorBorde = AppColores.naranjaLogo;
                                colorTextoSilla = Colors.white;
                              } else {
                                // Silla Disponible (Verde corporativo sutil)
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
                                          Icon(Icons.chair_alt, size: 30, color: estaOcupada ? Colors.white : AppColores.verdeLogo),
                                          const SizedBox(height: 4),
                                          Text('Silla ${silla['id']}', style: TextStyle(color: colorTextoSilla, fontSize: 14, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      if (tieneGrupo)
                                        Positioned(
                                          top: 6, right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                                            child: Text('G${silla['grupo']}', style: TextStyle(color: AppColores.naranjaLogo, fontWeight: FontWeight.bold, fontSize: 10)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 20), // Separador central

            // ==========================================
            // PANEL DERECHO: TICKET / CAJA
            // ==========================================
            Expanded(
              flex: 45,
              child: Container(
                decoration: BoxDecoration(
                  color: panelBgColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
                ),
                child: _cuentaSeleccionada == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 80, color: borderColor),
                          const SizedBox(height: 16),
                          Text('Selecciona una mesa ocupada\ny presiona "Cobrar"', textAlign: TextAlign.center, style: TextStyle(color: textLightColor, fontSize: 18)),
                        ],
                      ),
                    )
                  : _isLoadingPrecuenta
                    ? Center(child: CircularProgressIndicator(color: AppColores.naranjaLogo))
                    : _detallePrecuenta == null
                      ? const Center(child: Text('Error al cargar detalle', style: TextStyle(color: Colors.redAccent)))
                      : Column(
                          children: [
                            // Cabecera del ticket
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColores.naranjaLogo.withValues(alpha: 0.1),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
                              ),
                              width: double.infinity,
                              child: Text(
                                'Cobrar - ${_cuentaSeleccionada!['grupo'] != null ? 'Grupo ${_cuentaSeleccionada!['grupo']}' : 'Silla ${_cuentaSeleccionada!['id']}'}', 
                                style: TextStyle(color: AppColores.naranjaLogo, fontSize: 20, fontWeight: FontWeight.bold), 
                                textAlign: TextAlign.center
                              ),
                            ),
                            
                            // Lista de productos
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: (_detallePrecuenta!['detalles'] ?? []).length,
                                itemBuilder: (context, index) {
                                  final item = _detallePrecuenta!['detalles'][index];
                                  final String nombre = item['nombre'] ?? 'Producto';
                                  final int cantidad = item['cantidad'] ?? 1;
                                  final double precio = double.tryParse(item['precio']?.toString() ?? '0.0') ?? 0.0;
                                  final double subtotal = double.tryParse(item['subtotal']?.toString() ?? '0.0') ?? (cantidad * precio);

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text('${cantidad}x $nombre', style: TextStyle(color: textColor, fontSize: 15))),
                                        Text('S/ ${subtotal.toStringAsFixed(2)}', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Buscador de Clientes
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
                              child: _clienteSeleccionado == null 
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _documentoController,
                                        style: TextStyle(color: textColor),
                                        decoration: InputDecoration(
                                          hintText: 'DNI / RUC del cliente',
                                          hintStyle: TextStyle(color: textLightColor, fontSize: 13),
                                          filled: true,
                                          fillColor: cardColor,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColores.verdeLogo, padding: const EdgeInsets.all(14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                      onPressed: _buscandoCliente ? null : _buscarCliente,
                                      child: _buscandoCliente 
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Icon(Icons.search, color: Colors.white),
                                    )
                                  ],
                                )
                              : Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: AppColores.verdeLogo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColores.verdeLogo)),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person, color: AppColores.verdeLogo),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_clienteSeleccionado!['nombreRazonSocial'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                                            Text('${_clienteSeleccionado!['tipoDocumento']}: ${_clienteSeleccionado!['documento']}', style: TextStyle(color: textLightColor, fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      IconButton(icon: const Icon(Icons.close, color: Colors.redAccent, size: 20), onPressed: _limpiarCliente)
                                    ],
                                  ),
                                ),
                            ),

                            // Total y Metodos de Pago
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: isDark ? Colors.black45 : const Color(0xFFF9F9F9), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('TOTAL A PAGAR', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                      Text(
                                        'S/ ${double.tryParse(_detallePrecuenta!['total'].toString())?.toStringAsFixed(2) ?? "0.00"}', 
                                        style: TextStyle(color: AppColores.naranjaLogo, fontSize: 28, fontWeight: FontWeight.bold)
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  Row(
                                    children: [
                                      _botonMetodoPago('EFECTIVO', Icons.payments_outlined, cardColor, textColor, borderColor),
                                      const SizedBox(width: 8),
                                      _botonMetodoPago('TARJETA', Icons.credit_card, cardColor, textColor, borderColor),
                                      const SizedBox(width: 8),
                                      _botonMetodoPago('YAPE / PLIN', Icons.qr_code_scanner, cardColor, textColor, borderColor),
                                    ],
                                  ),
                                  const SizedBox(height: 15),

                                  // ==========================================
                                  // AQUÍ ESTÁN LOS BOTONES ACTUALIZADOS
                                  // ==========================================
                                  /*Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.restaurant_menu, size: 18),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.blueGrey,
                                            side: const BorderSide(color: Colors.blueGrey),
                                          ),
                                          onPressed: () => _mostrarPreview(true), 
                                          label: const Text('Ver Comanda'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.receipt_long, size: 18),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.teal,
                                            side: const BorderSide(color: Colors.teal),
                                          ),
                                          onPressed: () => _mostrarPreview(false), 
                                          label: const Text('Ver Ticket'),
                                        ),
                                      ),
                                    ],
                                  ),*/
                                  const SizedBox(height: 10),
                                  
                                  // BOTÓN DE IMPRIMIR PRECUENTA (AZUL GRISÁCEO)
                                  SizedBox(
                                    height: 50, width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      icon: const Icon(Icons.receipt, color: Colors.white),
                                      label: const Text('IMPRIMIR PRECUENTA', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                      onPressed: _imprimirPrecuentaFisica,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  
                                  // BOTÓN FINAL DE COBRO (NARANJA)
                                  SizedBox(
                                    height: 55, width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColores.naranjaLogo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      icon: const Icon(Icons.print, color: Colors.white),
                                      label: const Text('COBRAR E IMPRIMIR BOLETA', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                      onPressed: _procesarCobro,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _botonMetodoPago(String metodo, IconData icono, Color cardColor, Color textColor, Color borderColor) {
    final bool seleccionado = _metodoPagoSeleccionado == metodo;
    final Color textLightColor = isDarkModeGlobal.value ? AppColores.textoOscuroSecundario : AppColores.textoClaroSecundario;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _metodoPagoSeleccionado = metodo),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: seleccionado ? AppColores.naranjaLogo.withValues(alpha: 0.15) : cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: seleccionado ? AppColores.naranjaLogo : borderColor),
          ),
          child: Column(
            children: [
              Icon(icono, color: seleccionado ? AppColores.naranjaLogo : textLightColor, size: 24),
              const SizedBox(height: 4),
              Text(
                metodo, 
                style: TextStyle(color: seleccionado ? AppColores.naranjaLogo : textColor, fontSize: 10, fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}