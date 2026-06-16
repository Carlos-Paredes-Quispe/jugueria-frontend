import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../tema_global.dart'; 

class TomarPedidoScreen extends StatefulWidget {
  final Map<String, dynamic> silla; 

  const TomarPedidoScreen({Key? key, required this.silla}) : super(key: key);

  @override
  State<TomarPedidoScreen> createState() => _TomarPedidoScreenState();
}

class _TomarPedidoScreenState extends State<TomarPedidoScreen> {
  final Color copperPrimary = const Color(0xFFC07C46);

  List<dynamic> _categoriasMenu = [];
  List<Map<String, dynamic>> _carrito = [];
  bool _isLoading = true;
  int _categoriaSeleccionadaIndex = 0;

  @override
  void initState() {
    super.initState();
    _cargarMenu();
  }

  // ==========================================
  // 1. CARGAR MENÚ DESDE NESTJS
  // ==========================================
  Future<void> _cargarMenu() async {
    try {
      final url = Uri.parse('http://192.168.18.194:3000/productos/menu');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _categoriasMenu = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al cargar el menú')));
    }
  }

  // ==========================================
  // 2. LÓGICA DEL CARRITO (COMANDA)
  // ==========================================
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
      if (_carrito[index]['cantidad'] <= 0) {
        _carrito.removeAt(index); 
      }
    });
  }

  void _agregarNotaEspecial(int index) {
    TextEditingController notaCtrl = TextEditingController(text: _carrito[index]['notas']);
    
    showDialog(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: isDarkModeGlobal,
          builder: (context, isDark, child) {
            final Color dialogBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
            final Color dialogText = isDark ? Colors.white : const Color(0xFF222222);
            final Color dialogSubtext = isDark ? Colors.white70 : Colors.black54;

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text('Nota para Cocina', style: TextStyle(color: dialogText, fontWeight: FontWeight.bold)),
              content: TextField(
                controller: notaCtrl,
                style: TextStyle(color: dialogText),
                decoration: InputDecoration(
                  hintText: 'Ej: Sin azúcar, poco hielo...',
                  hintStyle: TextStyle(color: dialogSubtext),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogSubtext)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: copperPrimary)),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: Text('Cancelar', style: TextStyle(color: dialogSubtext))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: copperPrimary),
                  onPressed: () {
                    setState(() { _carrito[index]['notas'] = notaCtrl.text; });
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar Nota', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          }
        );
      }
    );
  }

  double _calcularTotal() {
    return _carrito.fold(0, (suma, item) => suma + (item['precio'] * item['cantidad']));
  }

  // ==========================================
  // 3. ENVIAR PEDIDO A NESTJS Y COCINA
  // ==========================================
  Future<void> _enviarPedido() async {
    if (_carrito.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviando comanda a cocina...')));

    try {
      final url = Uri.parse('http://192.168.18.194:3000/pedidos');
      
      final body = {
        if (widget.silla['grupo'] == null) 'sillaId': widget.silla['id'] else 'grupoId': widget.silla['grupo'],
        'items': _carrito.map((item) => {
          'productoId': item['productoId'],
          'cantidad': item['cantidad'],
          'precio': item['precio'],
          'notas': item['notas']
        }).toList()
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Pedido enviado con éxito! 🍹', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
        Navigator.pop(context); 
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al enviar pedido'), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // CONSTRUCCIÓN VISUAL
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final bool esGrupo = widget.silla['grupo'] != null;
    final String tituloMesa = esGrupo ? 'Grupo ${widget.silla['grupo']}' : 'Silla ${widget.silla['id']}';

    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {

        final Color mainBgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5);
        final Color panelColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
        final Color cardColor = isDark ? const Color(0xFF252525) : const Color(0xFFFAFAFA);
        final Color textColor = isDark ? Colors.white : const Color(0xFF222222);
        final Color textLightColor = isDark ? Colors.white70 : Colors.black54;
        final Color borderColor = isDark ? Colors.white12 : Colors.black12;

        return Scaffold(
          backgroundColor: mainBgColor,
          appBar: AppBar(
            backgroundColor: panelColor,
            title: Text('Tomando pedido: $tituloMesa', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            iconTheme: IconThemeData(color: textColor),
            actions: [
              IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: copperPrimary),
                onPressed: () {
                  isDarkModeGlobal.value = !isDarkModeGlobal.value;
                },
                tooltip: 'Cambiar tema',
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Row(
            children: [
              // ==========================================
              // LADO IZQUIERDO: EL MENÚ (65% del ancho)
              // ==========================================
              Expanded(
                flex: 65,
                child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: copperPrimary))
                  : Column(
                      children: [
                        // Filtro de categorías horizontal
                        Container(
                          height: 60,
                          color: isDark ? const Color(0xFF1A1A1A).withOpacity(0.5) : Colors.white,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categoriasMenu.length,
                            itemBuilder: (context, index) {
                              final categoria = _categoriasMenu[index];
                              final bool estaSeleccionada = _categoriaSeleccionadaIndex == index;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: estaSeleccionada ? copperPrimary : cardColor,
                                    foregroundColor: estaSeleccionada ? Colors.white : textColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(color: estaSeleccionada ? Colors.transparent : borderColor)
                                    ),
                                    elevation: estaSeleccionada ? 2 : 0,
                                  ),
                                  onPressed: () => setState(() => _categoriaSeleccionadaIndex = index),
                                  child: Text(categoria['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // ==========================================
                        // NUEVA GRILLA MINIMALISTA DE PRODUCTOS
                        // ==========================================
                        Expanded(
                          child: _categoriasMenu.isEmpty 
                            ? Center(child: Text('No hay productos', style: TextStyle(color: textColor)))
                            : GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4, // 4 columnas para aprovechar mejor la tablet
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 2.8, // Aspecto rectangular tipo "botón plano"
                                ),
                                itemCount: (_categoriasMenu[_categoriaSeleccionadaIndex]['productos'] ?? []).length,
                                itemBuilder: (context, idx) {
                                  final producto = _categoriasMenu[_categoriaSeleccionadaIndex]['productos'][idx];
                                  return InkWell(
                                    onTap: () => _agregarAlCarrito(producto),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: borderColor, width: 1),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start, // Alineación a la izquierda
                                        children: [
                                          Text(
                                            producto['nombre'], 
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13, height: 1.1)
                                          ),
                                          const SizedBox(height: 4),
                                          Text('S/ ${producto['precio']}', style: TextStyle(color: copperPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
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

              // LÍNEA SEPARADORA VERTICAL
              Container(width: 2, color: borderColor),

              // ==========================================
              // LADO DERECHO: LA COMANDA / CARRITO (35% del ancho)
              // ==========================================
              Expanded(
                flex: 35,
                child: Container(
                  color: panelColor,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: isDark ? Colors.black26 : const Color(0xFFE0E0E0),
                        width: double.infinity,
                        child: Text('Comanda Actual', style: TextStyle(color: copperPrimary, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ),
                      
                      // Lista de items elegidos
                      Expanded(
                        child: _carrito.isEmpty
                            ? Center(child: Text('Sin productos', style: TextStyle(color: textLightColor)))
                            : ListView.builder(
                                itemCount: _carrito.length,
                                itemBuilder: (context, index) {
                                  final item = _carrito[index];
                                  return Card(
                                    color: cardColor,
                                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    elevation: isDark ? 0 : 1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: borderColor)
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(child: Text(item['nombre'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                                              Text('S/ ${(item['precio'] * item['cantidad']).toStringAsFixed(2)}', style: TextStyle(color: copperPrimary, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          if (item['notas'].toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text('Nota: ${item['notas']}', style: const TextStyle(color: Colors.orange, fontSize: 12, fontStyle: FontStyle.italic)),
                                            ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              IconButton(
                                                icon: Icon(Icons.edit_note, color: textLightColor),
                                                onPressed: () => _agregarNotaEspecial(index),
                                                tooltip: 'Agregar nota',
                                              ),
                                              Row(
                                                children: [
                                                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => _modificarCantidad(index, -1)),
                                                  Text('${item['cantidad']}', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                                                  IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _modificarCantidad(index, 1)),
                                                ],
                                              )
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      // ZONA INFERIOR: TOTAL Y BOTÓN CONFIRMAR
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black45 : const Color(0xFFF5F5F5),
                          border: Border(top: BorderSide(color: borderColor)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('TOTAL', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                                Text('S/ ${_calcularTotal().toStringAsFixed(2)}', style: TextStyle(color: copperPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _carrito.isEmpty ? Colors.grey : Colors.green,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _carrito.isEmpty ? null : _enviarPedido,
                                child: const Text('ENVIAR A COCINA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
          ),
        );
      }
    );
  }
}