import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Para el refresco automático
import '../tema_global.dart';
import 'package:flutter_jugueria/main.dart';

class CocinaScreen extends StatefulWidget {
  const CocinaScreen({super.key});

  @override
  State<CocinaScreen> createState() => _CocinaScreenState();
}

class _CocinaScreenState extends State<CocinaScreen> {
  final Color copperPrimary = const Color(0xFFC07C46);
  
  List<dynamic> _comandas = [];
  bool _isLoading = true;
  Timer? _timerRefresco;

  @override
  void initState() {
    super.initState();
    _cargarComandasCocina();
    mostrarSoporteGlobal.value = false;
    // REFRESCO AUTOMÁTICO: Cada 8 segundos consulta al backend por nuevos pedidos
    _timerRefresco = Timer.periodic(const Duration(seconds: 8), (timer) {
      _cargarComandasCocina(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timerRefresco?.cancel(); // Cancelamos el timer al salir de la pantalla para no gastar memoria
    mostrarSoporteGlobal.value = true;
    super.dispose();
  }

  // ==========================================
  // 1. OBTENER COMANDAS PENDIENTES DE COCINA
  // ==========================================
  Future<void> _cargarComandasCocina({bool silencioso = false}) async {
    if (!silencioso) setState(() => _isLoading = true);
    try {
      final url = Uri.parse('http://192.168.18.194:3000/pedidos/cocina');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _comandas = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error en cocina: $e');
      if (!silencioso) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // 2. MARCAR PEDIDO COMO LISTO / ENTREGADO
  // ==========================================
  Future<void> _marcarComoListo(int pedidoId) async {
    try {
      final url = Uri.parse('http://192.168.18.194:3000/pedidos/$pedidoId/listo');
      final response = await http.patch(url);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Pedido despachado! 🍹🏁'), backgroundColor: Colors.green, duration: Duration(seconds: 1))
        );
        _cargarComandasCocina(); // Recargamos la lista
      }
    } catch (e) {
      debugPrint('Error al despachar: $e');
    }
  }

  // ==========================================
  // DISEÑO DE LA PANTALLA DE COCINA
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        
        final Color textColor = isDark ? Colors.white : const Color(0xFF222222);
        final Color cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
        final Color borderColor = isDark ? Colors.white12 : Colors.black12;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monitor de Cocina', style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Órdenes pendientes en tiempo real', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14)),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: copperPrimary, size: 30),
                  onPressed: () => _cargarComandasCocina(),
                  tooltip: 'Actualizar ahora',
                )
              ],
            ),
            const SizedBox(height: 25),

            // Contenedor principal de pedidos
            Expanded(
              child: _isLoading
                ? Center(child: CircularProgressIndicator(color: copperPrimary))
                : _comandas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 80, color: Colors.green.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text('¡Cocina limpia! No hay pedidos pendientes', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 18)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, // 3 columnas de comandas en horizontal
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.85, // Proporción vertical para que quepan listas largas
                      ),
                      itemCount: _comandas.length,
                      itemBuilder: (context, index) {
                        final pedido = _comandas[index];
                        final detalles = pedido['detalles'] ?? [];
                        final DateTime fechaPedido = DateTime.parse(pedido['fecha']);
                        final String horaFormateada = "${fechaPedido.hour.toString().padLeft(2, '0')}:${fechaPedido.minute.toString().padLeft(2, '0')}";

                        // Determinar el origen físico
                        final String ubicacion = pedido['grupoId'] != null 
                            ? "GRUPO ${pedido['grupoId']}" 
                            : "SILLA ${pedido['sillaId']}";

                        return Card(
                          color: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: borderColor, width: 1.5),
                          ),
                          elevation: isDark ? 0 : 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cabecera del ticket de cocina
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: pedido['estado'] == 'PREPARANDO' ? Colors.orange.withValues(alpha: 0.2) : copperPrimary.withValues(alpha: 0.15),
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(ubicacion, style: TextStyle(color: copperPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(horaFormateada, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),

                              // Cuerpo: Lista de productos a preparar
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: detalles.length,
                                  itemBuilder: (context, dIdx) {
                                    final detalle = detalles[dIdx];
                                    final String productoNombre = detalle['producto']['nombre'] ?? '';
                                    final int cantidad = detalle['cantidad'] ?? 1;
                                    final String notas = detalle['notes'] ?? detalle['notas'] ?? '';

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Cantidad destacada en un círculo/recuadro
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(color: copperPrimary, borderRadius: BorderRadius.circular(6)),
                                                child: Text('$cantidad', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                              ),
                                              const SizedBox(width: 10),
                                              // Nombre del jugo / comida
                                              Expanded(
                                                child: Text(
                                                  productoNombre, 
                                                  style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Notas especiales (Ej: Sin azúcar)
                                          if (notas.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 32.0, top: 2.0),
                                              child: Text(
                                                '⚠️ $notas', 
                                                style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Botón inferior para despachar el pedido completo
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _marcarComoListo(pedido['id']),
                                    child: const Text('ORDEN LISTA ✓', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      }
    );
  }
}