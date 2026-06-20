import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class ImpresoraService {
  
  // ==========================================
  // 1. FORMATO: TICKET DE COCINA
  // ==========================================
  static Future<List<int>> generarTicketCocina(String mesa, List<dynamic> carrito) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile); // mm58 o mm80 según el ancho de tu papel
    List<int> bytes = [];

    // Cabecera grande para que el cocinero la vea rápido
    bytes += generator.text('NUEVA ORDEN',
        styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2, bold: true));
    bytes += generator.text('Mesa: $mesa',
        styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2));
    
    bytes += generator.hr(); // Línea separadora
    bytes += generator.emptyLines(1);

    // Lista de productos
    for (var item in carrito) {
      final cantidad = item['cantidad'];
      final nombre = item['nombre'] ?? item['producto']['nombre']; // Soporta ambas pantallas
      final nota = item['notas']?.toString() ?? '';

      // Imprime: "2x Jugo de Fresa"
      bytes += generator.text('${cantidad}x $nombre', styles: const PosStyles(bold: true, height: PosTextSize.size1));
      
      // Si hay nota, la imprime debajo resaltada
      if (nota.isNotEmpty) {
        bytes += generator.text('   -> NOTA: $nota', styles: const PosStyles(align: PosAlign.left));
      }
    }

    bytes += generator.emptyLines(2);
    bytes += generator.text('------------------------', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.cut(); // Corta el papel automáticamente
    
    return bytes;
  }

  // ==========================================
  // 2. FORMATO: PRECUENTA / BOLETA DE CAJA
  // ==========================================
  static Future<List<int>> generarBoletaCaja(
    String mesa, 
    List<dynamic> items, 
    double total, 
    String metodoPago,
    [Map<String, dynamic>? cliente]
    ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // Logo o Nombre del Local
    bytes += generator.text('JUGUERIA DRAGONPOS',
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += generator.text('Av. Siempre Viva 123', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.emptyLines(1);

    bytes += generator.text('Mesa: $mesa', styles: const PosStyles(align: PosAlign.left, bold: true));
    bytes += generator.text('Pago: $metodoPago', styles: const PosStyles(align: PosAlign.left));
    bytes += generator.hr();

    // Detalle de productos con precios alineados
    for (var item in items) {
      final cantidad = item['cantidad'];
      final nombre = item['nombre'];
      final subtotal = double.tryParse(item['subtotal']?.toString() ?? '0') ?? (cantidad * item['precio']);

      bytes += generator.row([
        PosColumn(text: '${cantidad}x', width: 2),
        PosColumn(text: nombre, width: 7),
        PosColumn(text: 'S/ ${subtotal.toStringAsFixed(2)}', width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr();
    
    // Total gigante
    bytes += generator.row([
      PosColumn(text: 'TOTAL:', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(text: 'S/ ${total.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
    ]);

    bytes += generator.emptyLines(1);
    bytes += generator.text('¡Gracias por su preferencia!', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.emptyLines(2);
    bytes += generator.cut();

    return bytes;
  }

  // ==========================================
  // 3. ENVIAR FÍSICAMENTE LOS BYTES POR IP
  // ==========================================
  static Future<bool> enviarAImpresoraIP(String ip, List<int> bytes) async {
    try {
      // Las ticketeras térmicas de red usan universalmente el puerto 9100
      final socket = await Socket.connect(ip, 9100, timeout: const Duration(seconds: 3));
      socket.add(bytes);
      await socket.flush();
      socket.destroy();
      return true; // Imprimió con éxito
    } catch (e) {
      print("Error físico de impresión en IP $ip: $e");
      return false; // Error de conexión (ticketera apagada o IP incorrecta)
    }
  }
}