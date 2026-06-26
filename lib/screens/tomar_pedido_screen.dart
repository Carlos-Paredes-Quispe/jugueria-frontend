import 'package:flutter/material.dart';
import 'package:flutter_jugueria/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/impresora_service.dart'; 
import '../tema_global.dart'; 

class TomarPedidoScreen extends StatefulWidget {
  final Map<String, dynamic> silla; 

  const TomarPedidoScreen({super.key, required this.silla});

  @override
  State<TomarPedidoScreen> createState() => _TomarPedidoScreenState();
}

class _TomarPedidoScreenState extends State<TomarPedidoScreen> {
  final Color copperPrimary = const Color(0xFFC07C46);

  List<dynamic> _categoriasMenu = [];
  final List<Map<String, dynamic>> _carrito = []; // <-- Solo los NUEVOS pedidos
  List<dynamic> _productosYaPedidos = [];         // <-- Historial de la mesa
  
  bool _isLoadingMenu = true;
  bool _isLoadingPrecuenta = false;
  int _categoriaSeleccionadaIndex = 0;

  @override
  void initState() {
    super.initState();
    _cargarMenu();
    // Si la silla ya está ocupada, cargamos su historial para sumar el total
    if (widget.silla['ocupada'] == true) {
      _cargarPrecuentaMesa();
    }
    mostrarSoporteGlobal.value = false;
  }

  @override
  void dispose() {
    mostrarSoporteGlobal.value = true;
    super.dispose();
  }

  // --- CARGA DE DATOS ---
  Future<void> _cargarMenu() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.18.194:3000/productos/menu'));
      if (response.statusCode == 200) {
        setState(() {
          _categoriasMenu = jsonDecode(response.body);
          _isLoadingMenu = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingMenu = false);
    }
  }

  Future<void> _cargarPrecuentaMesa() async {
    setState(() => _isLoadingPrecuenta = true);
    try {
      final bool esGrupo = widget.silla['grupo'] != null;
      final String endpoint = esGrupo ? 'grupo/${widget.silla['grupo']}' : 'silla/${widget.silla['id']}';
      final response = await http.get(Uri.parse('http://192.168.18.194:3000/pedidos/precuenta/$endpoint'));
      
      if (response.statusCode == 200) {
        setState(() {
          _productosYaPedidos = jsonDecode(response.body)['detalles'] ?? [];
          _isLoadingPrecuenta = false;
        });
      } else {
        setState(() => _isLoadingPrecuenta = false);
      }
    } catch (e) {
      setState(() => _isLoadingPrecuenta = false);
    }
  }

  // --- LÓGICA DEL CARRITO NUEVO ---
  void _agregarAlCarrito(dynamic producto) {
    setState(() {
      int index = _carrito.indexWhere((item) => item['productoId'] == producto['id'] && item['notas'] == '');
      if (index != -1) {
        _carrito[index]['cantidad']++;
      } else {
        _carrito.add({
          'productoId': producto['id'],
          'nombre': producto['nombre'],
          'precio': double.parse(producto['precio'].toString()),
          'cantidad': 1,
          'notas': '' 
        });
      }
    });
  }

  void _modificarCantidad(int index, int delta) {
    setState(() {
      _carrito[index]['cantidad'] += delta;
      if (_carrito[index]['cantidad'] <= 0) _carrito.removeAt(index); 
    });
  }

  void _agregarNotaEspecial(int index) {
    TextEditingController notaCtrl = TextEditingController(text: _carrito[index]['notas']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nota para Cocina'),
        content: TextField(controller: notaCtrl, decoration: const InputDecoration(hintText: 'Ej: Sin azúcar...')),
        actions: [
          ElevatedButton(onPressed: () {
            setState(() { _carrito[index]['notas'] = notaCtrl.text; });
            Navigator.pop(context);
          }, child: const Text('Guardar')),
        ],
      )
    );
  }

  // --- CÁLCULO DE TOTALES ---
  double _calcularTotalNuevos() {
    return _carrito.fold(0, (suma, item) => suma + (item['precio'] * item['cantidad']));
  }

  double _calcularTotalYaPedidos() {
    return _productosYaPedidos.fold(0, (suma, item) {
      return suma + (double.tryParse(item['subtotal'].toString()) ?? 0.0);
    });
  }

  double _calcularTotalGeneral() {
    return _calcularTotalNuevos() + _calcularTotalYaPedidos();
  }

  // --- PREVIEW Y ENVÍO A COCINA ---
  void _mostrarPreviewCocina() {
    if (_carrito.isEmpty) return;
    final String tituloMesa = widget.silla['grupo'] != null ? 'Grupo ${widget.silla['grupo']}' : 'Silla ${widget.silla['id']}';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 320, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(alignment: Alignment.center, child: Text('VERASALUD', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black))),
              const Align(alignment: Alignment.center, child: Text('--- COMANDA COCINA ---', style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black))),
              Align(alignment: Alignment.center, child: Text('UBICACIÓN: $tituloMesa', style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black))),
              const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', color: Colors.black)),
              const SizedBox(height: 8),
              
              ..._carrito.map((item) {
                final bool tieneNota = item['notas'].toString().trim().isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item['cantidad']}x '.padRight(4), style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                          Expanded(child: Text(item['nombre'], style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500))),
                        ],
                      ),
                      if (tieneNota)
                        Padding(
                          padding: const EdgeInsets.only(left: 28.0, top: 2.0, bottom: 2.0),
                          child: Text('  => * OBS: ${item['notas'].toString().toUpperCase()} *', style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black)),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', color: Colors.black)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.black26), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () => Navigator.pop(context), child: const Text('CORREGIR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () { Navigator.pop(context); _enviarPedido(); }, child: const Text('CONFIRMAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enviarPedido() async {
    if (_carrito.isEmpty) return;
    try {
      final body = {
        if (widget.silla['grupo'] == null) 'sillaId': widget.silla['id'] else 'grupoId': widget.silla['grupo'],
        'items': _carrito.map((item) => {
          'productoId': item['productoId'], 'cantidad': item['cantidad'], 'precio': item['precio'], 'notas': item['notas']
        }).toList()
      };

      final response = await http.post(Uri.parse('http://192.168.18.194:3000/pedidos'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final ipCocina = prefs.getString('ip_ticketera_cocina') ?? '';
          if (ipCocina.isNotEmpty) {
            final String tituloMesa = widget.silla['grupo'] != null ? 'Grupo ${widget.silla['grupo']}' : 'Silla ${widget.silla['id']}';
            final bytes = await ImpresoraService.generarTicketCocina(tituloMesa, _carrito);
            await ImpresoraService.enviarAImpresoraIP(ipCocina, bytes);
          }
        } catch (e) { print("Error impresion: $e"); }

        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Pedido enviado a cocina!'), backgroundColor: Colors.green));
          Navigator.pop(context); 
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al enviar pedido'), backgroundColor: Colors.red));
    }
  }

  // --- INTERFAZ ---
  @override
  Widget build(BuildContext context) {
    final String tituloMesa = widget.silla['grupo'] != null ? 'Grupo ${widget.silla['grupo']}' : 'Silla ${widget.silla['id']}';
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5),
          appBar: AppBar(title: Text('Pedido: $tituloMesa')),
          body: Row(
            children: [
              Expanded(flex: 65, child: _buildMenu(isDark)),
              Container(width: 2, color: Colors.grey.withValues(alpha: 0.3)),
              Expanded(flex: 35, child: _buildCarritoUI(isDark)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildMenu(bool isDark) {
    if (_isLoadingMenu) return Center(child: CircularProgressIndicator(color: copperPrimary));
    if (_categoriasMenu.isEmpty) return const Center(child: Text('No hay productos disponibles'));

    return Column(
      children: [
        SizedBox(
          height: 60, 
          child: ListView.builder(
            scrollDirection: Axis.horizontal, 
            itemCount: _categoriasMenu.length, 
            itemBuilder: (c, i) => Padding(
              padding: const EdgeInsets.all(8), 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _categoriaSeleccionadaIndex == i ? copperPrimary : (isDark ? Colors.grey[800] : Colors.white), foregroundColor: _categoriaSeleccionadaIndex == i ? Colors.white : (isDark ? Colors.white : Colors.black)),
                onPressed: () => setState(() => _categoriaSeleccionadaIndex = i), 
                child: Text(_categoriasMenu[i]['nombre'], style: const TextStyle(fontWeight: FontWeight.bold))
              )
            )
          )
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.5),
            itemCount: (_categoriasMenu[_categoriaSeleccionadaIndex]['productos'] ?? []).length,
            itemBuilder: (context, idx) {
              final p = _categoriasMenu[_categoriaSeleccionadaIndex]['productos'][idx];
              return InkWell(
                onTap: () => _agregarAlCarrito(p), 
                child: Card(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['nombre'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('S/ ${p['precio']}', style: TextStyle(color: copperPrimary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                )
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCarritoUI(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: isDark ? Colors.black26 : const Color(0xFFE0E0E0),
          width: double.infinity,
          child: Text('Comanda Actual', style: TextStyle(color: copperPrimary, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ),
        Expanded(
          child: _isLoadingPrecuenta 
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  // ===== HISTORIAL (YA PEDIDOS) =====
                  if (_productosYaPedidos.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.all(8), child: Row(children: [Icon(Icons.history, color: Colors.grey, size: 18), SizedBox(width: 8), Text('YA PEDIDOS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))])),
                    ..._productosYaPedidos.map((item) => Card(
                      color: isDark ? Colors.white10 : Colors.grey.shade200, elevation: 0,
                      child: ListTile(
                        dense: true,
                        leading: Text('${item['cantidad']}x', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        title: Text(item['nombre'], style: const TextStyle(color: Colors.grey)),
                        trailing: Text('S/ ${double.parse(item['subtotal'].toString()).toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                      ),
                    )),
                    const Divider(height: 24),
                  ],

                  // ===== NUEVOS PEDIDOS =====
                  if (_carrito.isNotEmpty)
                    Padding(padding: const EdgeInsets.all(8), child: Row(children: [Icon(Icons.fiber_new, color: AppColores.verdeLogo, size: 18), const SizedBox(width: 8), Text('NUEVOS', style: TextStyle(color: AppColores.verdeLogo, fontWeight: FontWeight.bold))])),
                  
                  if (_carrito.isEmpty && _productosYaPedidos.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Sin productos'))),

                  ..._carrito.asMap().entries.map((entry) {
                    int i = entry.key; var item = entry.value;
                    return Card(
                      color: isDark ? const Color(0xFF252525) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold))),
                                Text('S/ ${(item['precio'] * item['cantidad']).toStringAsFixed(2)}', style: TextStyle(color: copperPrimary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (item['notas'].toString().isNotEmpty)
                              Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('Nota: ${item['notas']}', style: const TextStyle(color: Colors.orange, fontSize: 12, fontStyle: FontStyle.italic))),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(icon: const Icon(Icons.edit_note, color: Colors.grey), onPressed: () => _agregarNotaEspecial(i)),
                                Row(
                                  children: [
                                    IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => _modificarCantidad(i, -1)),
                                    Text('${item['cantidad']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _modificarCantidad(i, 1)),
                                  ],
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
        ),
        // ===== TOTAL Y ENVIAR =====
        Container(
          padding: const EdgeInsets.all(20),
          color: isDark ? Colors.black45 : const Color(0xFFF5F5F5),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL GENERAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('S/ ${_calcularTotalGeneral().toStringAsFixed(2)}', style: TextStyle(color: copperPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _carrito.isEmpty ? Colors.grey : Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _carrito.isEmpty ? null : _mostrarPreviewCocina,
                  child: const Text('ENVIAR A COCINA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}