import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../tema_global.dart';

class PuntoVentaScreen extends StatefulWidget {
  const PuntoVentaScreen({Key? key}) : super(key: key);

  @override
  State<PuntoVentaScreen> createState() => _PuntoVentaScreenState();
}

class _PuntoVentaScreenState extends State<PuntoVentaScreen> {
  final Color copperPrimary = const Color(0xFFC07C46);

  List<dynamic> _cuentasActivas = [];
  bool _isLoadingCuentas = true;
  
  Map<String, dynamic>? _cuentaSeleccionada;
  Map<String, dynamic>? _detallePrecuenta;
  bool _isLoadingPrecuenta = false;

  String _metodoPagoSeleccionado = 'EFECTIVO'; // Por defecto

  @override
  void initState() {
    super.initState();
    _cargarCuentasActivas();
  }

  // ==========================================
  // 1. CARGAR SOLO SILLAS/GRUPOS OCUPADOS
  // ==========================================
  Future<void> _cargarCuentasActivas() async {
    setState(() => _isLoadingCuentas = true);
    try {
      final url = Uri.parse('http://192.168.18.194:3000/sillas');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> todasLasSillas = jsonDecode(response.body);
        // Filtramos solo las que están ocupadas
        setState(() {
          _cuentasActivas = todasLasSillas.where((s) => s['ocupada'] == true).toList();
          _isLoadingCuentas = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al cargar cuentas activas')));
      setState(() => _isLoadingCuentas = false);
    }
  }

  // ==========================================
  // 2. OBTENER EL RESUMEN DE LA CUENTA
  // ==========================================
  Future<void> _cargarPrecuenta(Map<String, dynamic> silla) async {
    setState(() {
      _cuentaSeleccionada = silla;
      _isLoadingPrecuenta = true;
      _detallePrecuenta = null;
    });

    try {
      // Si tiene grupo, pedimos la precuenta del grupo, si no, la de la silla individual
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró un pedido activo para esta mesa')));
      }
    } catch (e) {
      setState(() => _isLoadingPrecuenta = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de red al consultar precuenta')));
    }
  }

  // ==========================================
  // 3. PROCESAR EL COBRO
  // ==========================================
  Future<void> _procesarCobro() async {
    if (_detallePrecuenta == null) return;

    final int pedidoId = _detallePrecuenta!['id']; // ID del pedido a cobrar

    try {
      final url = Uri.parse('http://192.168.18.194:3000/pedidos/$pedidoId/pagar');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'metodoPago': _metodoPagoSeleccionado}),
      );

      if (response.statusCode == 200) {
        // ========================================================
        // 🔥 AQUÍ CONECTAREMOS LA TICKETERA DE CAJA MÁS ADELANTE
        // ImpresoraTermica.imprimirBoleta(
        //   precuenta: _detallePrecuenta, 
        //   metodo: _metodoPagoSeleccionado
        // );
        // ========================================================

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('¡Cobro exitoso! Imprimiendo boleta... 🧾', style: TextStyle(color: Colors.white)), 
          backgroundColor: Colors.green
        ));

        // Limpiamos la pantalla derecha y recargamos la izquierda
        setState(() {
          _cuentaSeleccionada = null;
          _detallePrecuenta = null;
        });
        _cargarCuentasActivas(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al procesar el cobro'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de red al cobrar')));
    }
  }

  // ==========================================
  // DISEÑO VISUAL
  // ==========================================
  @override
  Widget build(BuildContext context) {
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
          body: Row(
            children: [
              // ==========================================
              // LADO IZQUIERDO: CUENTAS ACTIVAS (55%)
              // ==========================================
              Expanded(
                flex: 55,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Cuentas por Cobrar', style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: Icon(Icons.refresh, color: copperPrimary),
                            onPressed: _cargarCuentasActivas,
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      Expanded(
                        child: _isLoadingCuentas
                          ? Center(child: CircularProgressIndicator(color: copperPrimary))
                          : _cuentasActivas.isEmpty
                            ? Center(child: Text('No hay cuentas abiertas', style: TextStyle(color: textLightColor, fontSize: 18)))
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1.2,
                                ),
                                itemCount: _cuentasActivas.length,
                                itemBuilder: (context, index) {
                                  final silla = _cuentasActivas[index];
                                  final bool esGrupo = silla['grupo'] != null;
                                  final String nombreCuenta = esGrupo ? 'Grupo ${silla['grupo']}' : 'Silla ${silla['id']}';
                                  
                                  final bool estaSeleccionada = _cuentaSeleccionada != null && _cuentaSeleccionada!['id'] == silla['id'];

                                  return InkWell(
                                    onTap: () => _cargarPrecuenta(silla),
                                    borderRadius: BorderRadius.circular(15),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: estaSeleccionada ? copperPrimary : panelColor,
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(color: estaSeleccionada ? copperPrimary : borderColor, width: 2),
                                        boxShadow: [
                                          if (!isDark && !estaSeleccionada) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                                        ]
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.receipt_long, size: 40, color: estaSeleccionada ? Colors.white : textLightColor),
                                          const SizedBox(height: 8),
                                          Text(
                                            nombreCuenta, 
                                            style: TextStyle(color: estaSeleccionada ? Colors.white : textColor, fontSize: 18, fontWeight: FontWeight.bold)
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

              // SEPARADOR VERTICAL
              Container(width: 2, color: borderColor),

              // ==========================================
              // LADO DERECHO: TICKET Y COBRO (45%)
              // ==========================================
              Expanded(
                flex: 45,
                child: Container(
                  color: panelColor,
                  child: _cuentaSeleccionada == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.point_of_sale, size: 80, color: borderColor),
                            const SizedBox(height: 16),
                            Text('Seleccione una cuenta para cobrar', style: TextStyle(color: textLightColor, fontSize: 18)),
                          ],
                        ),
                      )
                    : _isLoadingPrecuenta
                      ? Center(child: CircularProgressIndicator(color: copperPrimary))
                      : _detallePrecuenta == null
                        ? Center(child: Text('Error al cargar el detalle', style: TextStyle(color: Colors.redAccent)))
                        : Column(
                            children: [
                              // CABECERA DEL TICKET
                              Container(
                                padding: const EdgeInsets.all(20),
                                color: isDark ? Colors.black26 : const Color(0xFFE0E0E0),
                                width: double.infinity,
                                child: Text(
                                  'Precuenta - ${_cuentaSeleccionada!['grupo'] != null ? 'Grupo ${_cuentaSeleccionada!['grupo']}' : 'Silla ${_cuentaSeleccionada!['id']}'}', 
                                  style: TextStyle(color: copperPrimary, fontSize: 22, fontWeight: FontWeight.bold), 
                                  textAlign: TextAlign.center
                                ),
                              ),
                              
                              // LISTA DE PRODUCTOS CONSUMIDOS
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: (_detallePrecuenta!['detalles'] ?? []).length,
                                  itemBuilder: (context, index) {
                                    final item = _detallePrecuenta!['detalles'][index];
                                    
                                    // LA SOLUCIÓN ESTÁ AQUÍ: Ahora leemos el nombre y precio directamente
                                    final String nombre = item['nombre'] ?? 'Producto';
                                    final int cantidad = item['cantidad'] ?? 1;
                                    final double precio = double.tryParse(item['precio']?.toString() ?? '0.0') ?? 0.0;
                                    
                                    // Usamos el subtotal que ya nos envía calculado el backend
                                    final double subtotal = double.tryParse(item['subtotal']?.toString() ?? '0.0') ?? (cantidad * precio);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text('${cantidad}x $nombre', style: TextStyle(color: textColor, fontSize: 16)),
                                          ),
                                          Text('S/ ${subtotal.toStringAsFixed(2)}', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // SECCIÓN DE PAGOS Y TOTAL
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black45 : const Color(0xFFF5F5F5),
                                  border: Border(top: BorderSide(color: borderColor)),
                                ),
                                child: Column(
                                  children: [
                                    // Total a pagar
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('TOTAL A PAGAR', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                                        Text(
                                          'S/ ${double.tryParse(_detallePrecuenta!['total'].toString())?.toStringAsFixed(2) ?? "0.00"}', 
                                          style: TextStyle(color: copperPrimary, fontSize: 32, fontWeight: FontWeight.bold)
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    
                                    // Métodos de pago
                                    Text('MÉTODO DE PAGO', style: TextStyle(color: textLightColor, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _botonMetodoPago('EFECTIVO', Icons.payments_outlined, cardColor, textColor, borderColor),
                                        const SizedBox(width: 10),
                                        _botonMetodoPago('TARJETA', Icons.credit_card, cardColor, textColor, borderColor),
                                        const SizedBox(width: 10),
                                        _botonMetodoPago('YAPE / PLIN', Icons.qr_code_scanner, cardColor, textColor, borderColor),
                                      ],
                                    ),
                                    const SizedBox(height: 24),

                                    // Botón de Cobrar
                                    SizedBox(
                                      width: double.infinity,
                                      height: 60,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        icon: const Icon(Icons.print, color: Colors.white),
                                        label: const Text('COBRAR E IMPRIMIR BOLETA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
          ),
        );
      }
    );
  }

  // Widget para generar los botones de métodos de pago
  Widget _botonMetodoPago(String metodo, IconData icono, Color cardColor, Color textColor, Color borderColor) {
    final bool seleccionado = _metodoPagoSeleccionado == metodo;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _metodoPagoSeleccionado = metodo),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: seleccionado ? copperPrimary.withOpacity(0.2) : cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: seleccionado ? copperPrimary : borderColor),
          ),
          child: Column(
            children: [
              Icon(icono, color: seleccionado ? copperPrimary : textColor, size: 28),
              const SizedBox(height: 8),
              Text(
                metodo, 
                style: TextStyle(
                  color: seleccionado ? copperPrimary : textColor, 
                  fontSize: 12, 
                  fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}