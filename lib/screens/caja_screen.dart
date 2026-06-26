import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../tema_global.dart';

class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _turnoActivo; // Si es null, la caja está cerrada
  
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarTurnoActual();
  }

  // ==========================================
  // API: OBTENER TURNO ACTUAL
  // ==========================================
  Future<void> _cargarTurnoActual() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(Uri.parse('http://192.168.18.194:3000/caja/actual'));
      
      if (response.statusCode == 200) {
        // Si el backend responde 200 pero el cuerpo es vacío o la palabra "null"
        if (response.body.isEmpty || response.body == 'null') {
          setState(() {
            _turnoActivo = null; // Mapea como Caja Cerrada limpiamente
            _isLoading = false;
          });
        } else {
          setState(() {
            _turnoActivo = jsonDecode(response.body); // Mapea Caja Abierta con sus datos
            _isLoading = false;
          });
        }
      } else {
        // Cualquier otro código de error (404, 500)
        setState(() {
          _turnoActivo = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Caja en modo local o sin conexión activa'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // ==========================================
  // API: ABRIR CAJA
  // ==========================================
  Future<void> _abrirCaja() async {
    print("1. BOTÓN PRESIONADO"); // <-- Para ver si el botón reacciona

    if (_montoController.text.isEmpty) {
      print("❌ ERROR: El campo de texto está vacío. Cancelando.");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, ingresa un monto primero')));
      return;
    }

    print("2. MONTO INGRESADO: ${_montoController.text}");

    try {
      print("3. ENVIANDO PETICIÓN AL BACKEND...");
      final response = await http.post(
        Uri.parse('http://192.168.18.194:3000/caja/abrir'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'montoInicial': double.parse(_montoController.text),
          'usuarioApertura': 'Cajero Principal',
        }),
      );

      print("4. RESPUESTA DEL BACKEND RECIBIDA: Status ${response.statusCode}");
      print("5. CUERPO DE RESPUESTA: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        _montoController.clear();
        _cargarTurnoActual(); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caja abierta exitosamente', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error del servidor: ${response.body}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      print("❌ 6. ERROR FATAL DE FLUTTER: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión: $e'), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // API: MOVIMIENTOS (INGRESO / EGRESO)
  // ==========================================
  Future<void> _registrarMovimiento(String tipo) async {
    if (_montoController.text.isEmpty || _descripcionController.text.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('http://192.168.18.194:3000/caja/movimiento'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cajaTurnoId': _turnoActivo!['id'],
          'tipo': tipo, // 'INGRESO' o 'EGRESO'
          'monto': double.parse(_montoController.text),
          'descripcion': _descripcionController.text,
        }),
      );

      if (response.statusCode == 201) {
        Navigator.pop(context); // Cierra el modal
        _montoController.clear();
        _descripcionController.clear();
        _cargarTurnoActual();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$tipo registrado'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al registrar movimiento')));
    }
  }

  // ==========================================
  // API: CERRAR CAJA
  // ==========================================
  Future<void> _cerrarCaja() async {
    if (_montoController.text.isEmpty) return;

    try {
      final response = await http.patch(
        Uri.parse('http://192.168.18.194:3000/caja/cerrar/${_turnoActivo!['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'montoEfectivoReal': double.parse(_montoController.text),
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context); // Cierra el modal de arqueo
        _montoController.clear();
        
        // Forzamos manualmente el estado a null antes de volver a consultar
        setState(() {
          _turnoActivo = null; 
        });
        
        _cargarTurnoActual(); // Recarga la vista reflejando la "Caja Cerrada"
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Caja Cerrada y Turno Archivado!'), backgroundColor: Colors.blue)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al procesar cierre')));
    }
  }

  // ==========================================
  // MODALES
  // ==========================================
  void _mostrarModalMovimiento(String tipo) {
    _montoController.clear();
    _descripcionController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Registrar $tipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _montoController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monto (S/)', prefixIcon: Icon(Icons.attach_money))),
            const SizedBox(height: 10),
            TextField(controller: _descripcionController, decoration: const InputDecoration(labelText: 'Descripción / Motivo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: tipo == 'INGRESO' ? Colors.green : Colors.red),
            onPressed: () => _registrarMovimiento(tipo),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  void _mostrarModalCierre() {
    _montoController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cierre de Caja (Arqueo)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cuenta el dinero físico en la gaveta y digita el monto exacto.'),
            const SizedBox(height: 15),
            TextField(
              controller: _montoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Efectivo en gaveta (S/)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.monetization_on, color: Colors.green)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            onPressed: _cerrarCaja,
            child: const Text('CONFIRMAR CIERRE', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  // ==========================================
  // INTERFAZ VISUAL
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5);
        final cardColor = isDark ? AppColores.tarjetaOscura : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        if (_isLoading) return Center(child: CircularProgressIndicator(color: AppColores.naranjaLogo));

        return Scaffold(
          backgroundColor: bgColor,
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.all(24),
              child: _turnoActivo == null ? _buildCajaCerrada(cardColor, textColor) : _buildCajaAbierta(cardColor, textColor),
            ),
          ),
        );
      }
    );
  }

  // VISTA 1: CAJA CERRADA (Apertura)
  Widget _buildCajaCerrada(Color cardColor, Color textColor) {
    return Card(
      color: cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 80, color: AppColores.naranjaLogo),
            const SizedBox(height: 20),
            Text('CAJA CERRADA', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 10),
            Text('Para empezar a cobrar pedidos, necesitas abrir el turno.', style: TextStyle(color: textColor.withValues(alpha: 0.7))),
            const SizedBox(height: 30),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _montoController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor, fontSize: 20),
                decoration: InputDecoration(
                  labelText: 'Monto de Apertura (Sencillo) S/',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.attach_money),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 300, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColores.verdeLogo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _abrirCaja,
                child: const Text('ABRIR CAJA', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // VISTA 2: CAJA ABIERTA (Resumen)
  Widget _buildCajaAbierta(Color cardColor, Color textColor) {
    // Calculo de Saldo Esperado en Efectivo
    final double inicial = double.tryParse(_turnoActivo!['montoInicial'].toString()) ?? 0.0;
    final double ventasEf = double.tryParse(_turnoActivo!['ventasEfectivo'].toString()) ?? 0.0;
    final double ingresos = double.tryParse(_turnoActivo!['ingresos'].toString()) ?? 0.0;
    final double egresos = double.tryParse(_turnoActivo!['egresos'].toString()) ?? 0.0;
    
    final double saldoEsperado = inicial + ventasEf + ingresos - egresos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Resumen de Turno Actual', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green)),
              child: const Text('CAJA ABIERTA', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            )
          ],
        ),
        const SizedBox(height: 30),
        
        // Tarjetas de Métricas
        Row(
          children: [
            _buildMetricaCard('Monto Inicial', inicial, Icons.play_circle_filled, Colors.blueGrey, cardColor, textColor),
            _buildMetricaCard('Ventas Efectivo', ventasEf, Icons.payments, Colors.green, cardColor, textColor),
            _buildMetricaCard('Ventas Tarjeta/Yape', (double.tryParse(_turnoActivo!['ventasTarjeta'].toString()) ?? 0.0) + (double.tryParse(_turnoActivo!['ventasDigital'].toString()) ?? 0.0), Icons.credit_card, Colors.orange, cardColor, textColor),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            _buildMetricaCard('Ingresos Manuales', ingresos, Icons.arrow_downward, Colors.teal, cardColor, textColor),
            _buildMetricaCard('Egresos / Gastos', egresos, Icons.arrow_upward, Colors.red, cardColor, textColor),
            _buildMetricaCard('EFECTIVO ESPERADO', saldoEsperado, Icons.account_balance_wallet, AppColores.verdeLogo, cardColor, textColor, isDestacado: true),
          ],
        ),
        
        const Spacer(),
        
        // Botonera de Acción
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(20), foregroundColor: Colors.teal, side: const BorderSide(color: Colors.teal)), onPressed: () => _mostrarModalMovimiento('INGRESO'), icon: const Icon(Icons.add), label: const Text('Ingreso Extra'))),
            const SizedBox(width: 15),
            Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(20), foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), onPressed: () => _mostrarModalMovimiento('EGRESO'), icon: const Icon(Icons.remove), label: const Text('Registrar Gasto'))),
            const SizedBox(width: 15),
            Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20), backgroundColor: Colors.blueGrey), onPressed: _mostrarModalCierre, icon: const Icon(Icons.lock, color: Colors.white), label: const Text('CERRAR CAJA Y ARQUEAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ],
        )
      ],
    );
  }

  Widget _buildMetricaCard(String titulo, double valor, IconData icono, Color color, Color cardColor, Color textColor, {bool isDestacado = false}) {
    return Expanded(
      child: Card(
        color: isDestacado ? color.withValues(alpha: 0.1) : cardColor,
        elevation: isDestacado ? 0 : 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDestacado ? color : Colors.transparent, width: 2)),
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(titulo, style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              Text('S/ ${valor.toStringAsFixed(2)}', style: TextStyle(color: isDestacado ? color : textColor, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}