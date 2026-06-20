import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/impresora_service.dart'; // Asegúrate de que la ruta coincida con tu proyecto
import '../tema_global.dart';

class PuntoVentaScreen extends StatefulWidget {
  const PuntoVentaScreen({super.key});

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

  String _metodoPagoSeleccionado = 'EFECTIVO';

  // ==========================================
  // NUEVAS VARIABLES PARA GESTIÓN DE CLIENTES
  // ==========================================
  final TextEditingController _documentoController = TextEditingController();
  Map<String, dynamic>? _clienteSeleccionado;
  bool _buscandoCliente = false;

  @override
  void initState() {
    super.initState();
    _cargarCuentasActivas();
  }

  // ==========================================
  // 1. CARGAR SILLAS/GRUPOS (SIN REPETIR GRUPOS)
  // ==========================================
  Future<void> _cargarCuentasActivas() async {
    setState(() => _isLoadingCuentas = true);
    try {
      final url = Uri.parse('http://192.168.18.194:3000/sillas');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> todasLasSillas = jsonDecode(response.body);
        List<dynamic> ocupadas = todasLasSillas.where((s) => s['ocupada'] == true).toList();
        
        List<dynamic> consolidadas = [];
        Set<dynamic> gruposAgregados = {};

        for (var silla in ocupadas) {
          if (silla['grupo'] != null) {
            final grupoId = silla['grupo'];
            if (!gruposAgregados.contains(grupoId)) {
              gruposAgregados.add(grupoId);
              consolidadas.add(silla);
            }
          } else {
            consolidadas.add(silla);
          }
        }

        setState(() {
          _cuentasActivas = consolidadas;
          _isLoadingCuentas = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al cargar cuentas activas')));
      setState(() => _isLoadingCuentas = false);
    }
  }

  // ==========================================
  // 2. OBTENER RESUMEN DE PRECUENTA
  // ==========================================
  Future<void> _cargarPrecuenta(Map<String, dynamic> silla) async {
    if (_cuentaSeleccionada != null && _cuentaSeleccionada!['id'] == silla['id']) return;

    setState(() {
      _cuentaSeleccionada = silla;
      _isLoadingPrecuenta = true;
      _detallePrecuenta = null;
      _limpiarCliente(); // Reseteamos buscador al cambiar de mesa
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró un pedido activo')));
      }
    } catch (e) {
      setState(() => _isLoadingPrecuenta = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de red al consultar precuenta')));
    }
  }

 // ==========================================
  // 3. BÚSQUEDA DE CLIENTE (LOCAL PRIMERO)
  // ==========================================
  Future<void> _buscarCliente() async {
    final documento = _documentoController.text.trim();
    if (documento.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese un DNI o RUC')));
      return;
    }

    setState(() => _buscandoCliente = true);

    try {
      // 1. INTENTAMOS BUSCARLO GRATIS EN NUESTRA BASE DE DATOS
      final urlLocal = Uri.parse('http://192.168.18.194:3000/clientes/local/$documento');
      final responseLocal = await http.get(urlLocal);

      if (responseLocal.statusCode == 200) {
        // ¡Lo encontramos localmente! Costo = 0.
        final data = jsonDecode(responseLocal.body);
        setState(() {
          _clienteSeleccionado = data['cliente'];
          _buscandoCliente = false;
        });
      } else {
        // 2. NO EXISTE LOCALMENTE. Le preguntamos al cajero si desea usar la API.
        setState(() => _buscandoCliente = false);
        _mostrarDialogoConfirmacionSunat(documento);
      }
    } catch (e) {
      setState(() => _buscandoCliente = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al conectar con el servidor local')));
    }
  }

  // Modal para confirmar si queremos gastar una consulta de la API
  void _mostrarDialogoConfirmacionSunat(String documento) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud, color: Colors.blueAccent),
            SizedBox(width: 10),
            Text('Cliente Nuevo')
          ],
        ),
        content: Text('El documento $documento no está en la base de datos local.\n\n¿Deseas consumir una consulta para buscarlo en la SUNAT/RENIEC?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              Navigator.pop(context);
              _buscarClienteEnSunat(documento); // Dispara la consulta externa
            },
            child: const Text('SÍ, CONSULTAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BÚSQUEDA EXTERNA (CONSUME API FACTILIZA)
  // ==========================================
  Future<void> _buscarClienteEnSunat(String documento) async {
    setState(() => _buscandoCliente = true);

    try {
      final urlExterno = Uri.parse('http://192.168.18.194:3000/clientes/externo/$documento');
      final response = await http.get(urlExterno);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _clienteSeleccionado = data['cliente'];
          _buscandoCliente = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente encontrado y guardado con éxito'), backgroundColor: Colors.green)
        );
      } else {
        setState(() => _buscandoCliente = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El documento no existe en los registros de SUNAT/RENIEC'), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      setState(() => _buscandoCliente = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al conectar con la API externa')));
    }
  }

  void _limpiarCliente() {
    setState(() {
      _clienteSeleccionado = null;
      _documentoController.clear();
    });
  }

  // ==========================================
  // 4. NUEVO: MODAL PREVIEW DE TICKETERA (80mm)
  // ==========================================
  void _mostrarPreview() {
    if (_detallePrecuenta == null) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 380, // Equivalente en pantalla a los 80mm físicos
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFDFD), // Color papel
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 5))],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Text(
                      _generarTextoTicket(),
                      style: const TextStyle(
                        fontFamily: 'Courier', // Forzamos letra de ticketera
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: copperPrimary),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text('CERRAR PREVIEW', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  String _generarTextoTicket() {
    StringBuffer ticket = StringBuffer();
    final String lineaPunteada = "-" * 48; // Bloque de 48 columnas estándar

    ticket.writeln("                JUGUERIA EL OASIS               ");
    ticket.writeln("          Av. Principal 123, Tu Ciudad          ");
    ticket.writeln("                 RUC: 10123456789               ");
    ticket.writeln(lineaPunteada);
    ticket.writeln("Fecha: ${DateTime.now().toString().substring(0, 16)}");
    
    if (_clienteSeleccionado != null) {
      final tipo = _clienteSeleccionado!['tipoDocumento'] ?? 'DOC';
      ticket.writeln("Cliente: ${_clienteSeleccionado!['nombreRazonSocial']}");
      ticket.writeln("$tipo: ${_clienteSeleccionado!['documento']}");
      if (_clienteSeleccionado!['direccion'] != null && _clienteSeleccionado!['direccion'].toString().isNotEmpty) {
        ticket.writeln("Dir: ${_clienteSeleccionado!['direccion']}");
      }
    } else {
      ticket.writeln("Cliente: PUBLICO GENERAL");
      ticket.writeln("DNI: 00000000");
    }
    
    ticket.writeln(lineaPunteada);
    ticket.writeln("CANT  PRODUCTO                        SUBTOTAL  ");
    ticket.writeln(lineaPunteada);

    for (var item in _detallePrecuenta!['detalles']) {
      String cant = item['cantidad'].toString().padRight(4);
      String nombre = (item['nombre'].toString().length > 30) 
          ? item['nombre'].toString().substring(0, 30) 
          : item['nombre'].toString().padRight(30);
      String sub = double.parse(item['subtotal'].toString()).toStringAsFixed(2).padLeft(8);
      
      ticket.writeln("$cant $nombre $sub");
    }

    ticket.writeln(lineaPunteada);
    String total = double.parse(_detallePrecuenta!['total'].toString()).toStringAsFixed(2);
    ticket.writeln("TOTAL A PAGAR:                  S/ ${total.padLeft(8)}");
    ticket.writeln(lineaPunteada);
    ticket.writeln("        ¡Gracias por su preferencia!        ");
    
    return ticket.toString();
  }

  // ==========================================
  // 5. PROCESAR EL PAGO Y ENVIAR AL HARDWARE
  // ==========================================
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
        // Enviar impresión a la red local IP
        try {
          final prefs = await SharedPreferences.getInstance();
          final ipCaja = prefs.getString('ip_ticketera_caja') ?? '192.168.18.236';
          
          if (ipCaja.isNotEmpty) {
            final String tituloMesa = _cuentaSeleccionada!['grupo'] != null 
                ? 'Grupo ${_cuentaSeleccionada!['grupo']}' 
                : 'Silla ${_cuentaSeleccionada!['id']}';
            final double total = double.tryParse(_detallePrecuenta!['total'].toString()) ?? 0.0;
            final List<dynamic> items = _detallePrecuenta!['detalles'] ?? [];

            final bytes = await ImpresoraService.generarBoletaCaja(tituloMesa, items, total, _metodoPagoSeleccionado, _clienteSeleccionado);
            await ImpresoraService.enviarAImpresoraIP(ipCaja, bytes);
          }
        } catch (e) {
          print("Error hardware de impresión: $e");
        }

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('¡Cobro exitoso! Generando boleta física... 🧾', style: TextStyle(color: Colors.white)), 
          backgroundColor: Colors.green
        ));

        setState(() {
          _cuentaSeleccionada = null;
          _detallePrecuenta = null;
          _metodoPagoSeleccionado = 'EFECTIVO';
          _limpiarCliente();
        });
        _cargarCuentasActivas(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al procesar el cobro'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de red al cobrar')));
    }
  }

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
              // PANEL IZQUIERDO: SELECCIÓN DE CUENTA
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
                                          if (!isDark && !estaSeleccionada) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
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

              Container(width: 2, color: borderColor),

              // PANEL DERECHO: TICKET INTERACTIVO
              Expanded(
                flex: 44,
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
                        ? const Center(child: Text('Error al cargar el detalle', style: TextStyle(color: Colors.redAccent)))
                        : Column(
                            children: [
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
                                    final String notas = item['notas'] ?? '';

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('${cantidad}x $nombre', style: TextStyle(color: textColor, fontSize: 16)),
                                                if (notas.isNotEmpty)
                                                  Text('   * $notas', style: TextStyle(color: copperPrimary, fontSize: 13, fontStyle: FontStyle.italic)),
                                              ],
                                            ),
                                          ),
                                          Text('S/ ${subtotal.toStringAsFixed(2)}', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // ==========================================
                              // NUEVA INTERFAZ REACTIVA: BUSCADOR DE CLIENTES
                              // ==========================================
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF222222) : const Color(0xFFEEEEEE),
                                  border: Border(top: BorderSide(color: borderColor, width: 1)),
                                ),
                                child: _clienteSeleccionado == null 
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _documentoController,
                                          style: TextStyle(color: textColor),
                                          decoration: InputDecoration(
                                            hintText: 'Buscar por DNI o RUC',
                                            hintStyle: TextStyle(color: textLightColor),
                                            filled: true,
                                            fillColor: cardColor,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: copperPrimary,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: _buscandoCliente ? null : _buscarCliente,
                                        child: _buscandoCliente 
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Icon(Icons.search, color: Colors.white),
                                      )
                                    ],
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: copperPrimary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: copperPrimary.withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.person, color: copperPrimary),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(_clienteSeleccionado!['nombreRazonSocial'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              Text('${_clienteSeleccionado!['tipoDocumento']}: ${_clienteSeleccionado!['documento']}', style: TextStyle(color: textLightColor, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.redAccent),
                                          onPressed: _limpiarCliente,
                                        )
                                      ],
                                    ),
                                  ),
                              ),

                              // SECCIÓN TOTAL, METODO Y ACCIONES
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
                                        Text('TOTAL A PAGAR', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                                        Text(
                                          'S/ ${double.tryParse(_detallePrecuenta!['total'].toString())?.toStringAsFixed(2) ?? "0.00"}', 
                                          style: TextStyle(color: copperPrimary, fontSize: 32, fontWeight: FontWeight.bold)
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
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
                                    const SizedBox(height: 20),

                                    // FILA DE ACCIONES CON PREVIEW INCORPORADO
                                    Row(
                                      children: [
                                        Container(
                                          height: 60,
                                          margin: const EdgeInsets.only(right: 12),
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blueGrey,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: _mostrarPreview,
                                            child: const Icon(Icons.remove_red_eye, color: Colors.white, size: 28),
                                          ),
                                        ),
                                        Expanded(
                                          child: SizedBox(
                                            height: 60,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              icon: const Icon(Icons.print, color: Colors.white),
                                              label: const Text('COBRAR', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                              onPressed: _procesarCobro,
                                            ),
                                          ),
                                        ),
                                      ],
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