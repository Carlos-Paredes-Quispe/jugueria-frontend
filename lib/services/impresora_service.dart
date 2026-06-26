import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class ImpresoraService {
  
  // ==========================================
  // FILTRO ANTI-ERRORES DE TICKETERA
  // ==========================================
  static String _limpiarTexto(String texto) {
    const conTilde = 'ÁÉÍÓÚÑáéíóúñ';
    const sinTilde = 'AEIOUNaeioun';
    String resultado = texto;
    for (int i = 0; i < conTilde.length; i++) {
      resultado = resultado.replaceAll(conTilde[i], sinTilde[i]);
    }
    return resultado;
  }

  // ==========================================
  // 1. FORMATO: TICKET DE COCINA
  // ==========================================
  static Future<List<int>> generarTicketCocina(String mesa, List<dynamic> carrito) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile); // Ajustado a 80mm
    List<int> bytes = [];

    // Cabecera grande para que el cocinero la vea rápido
    bytes += generator.text('NUEVA ORDEN',
        styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2, bold: true));
    bytes += generator.text('UBICACION: $mesa',
        styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2));
    
    bytes += generator.hr(); // Línea separadora
    bytes += generator.emptyLines(1);

    // Lista de productos
    for (var item in carrito) {
      final cantidad = item['cantidad'];
      final nombreOriginal = item['nombre'] ?? item['producto']['nombre']; // Soporta ambas pantallas
      final notaOriginal = item['notas']?.toString() ?? '';

      // Limpiamos de tildes para evitar errores de impresión
      final nombre = _limpiarTexto(nombreOriginal.toString().toUpperCase());
      final nota = _limpiarTexto(notaOriginal.toUpperCase());

      // Imprime: "2x JUGO DE FRESA"
      bytes += generator.text('${cantidad}x $nombre', styles: const PosStyles(bold: true, height: PosTextSize.size1));
      
      // Si hay nota, la imprime debajo resaltada
      if (nota.isNotEmpty) {
        bytes += generator.text('   => * OBS: $nota *', styles: const PosStyles(align: PosAlign.left, bold: true));
      }
    }

    bytes += generator.emptyLines(2);
    bytes += generator.text('------------------------------------------------', styles: const PosStyles(align: PosAlign.center));
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

    // --- ENCABEZADO ---
    bytes += generator.text('VERASALUD',
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    
    // Si es precuenta, que el título lo diga, sino, es una boleta final
    String tipoDocumento = metodoPago == 'PRECUENTA' ? 'PRECUENTA' : 'BOLETA DE VENTA';
    bytes += generator.text(tipoDocumento, styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('------------------------------------------------', styles: const PosStyles(align: PosAlign.center));

    // --- DATOS GENERALES ---
    bytes += generator.text('FECHA: ${DateTime.now().toString().substring(0, 16)}');
    bytes += generator.text('UBICACION: ${_limpiarTexto(mesa.toUpperCase())}');

    if (cliente != null) {
      bytes += generator.text('------------------------------------------------', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('CLIENTE: ${_limpiarTexto(cliente['nombreRazonSocial'].toString().toUpperCase())}');
      bytes += generator.text('${cliente['tipoDocumento']}: ${cliente['documento']}');
    }
    
    bytes += generator.text('------------------------------------------------', styles: const PosStyles(align: PosAlign.center));

    // --- FILA DE TÍTULOS DE COLUMNA (Ancho total = 12) ---
    bytes += generator.row([
      PosColumn(text: 'CANT', width: 2, styles: const PosStyles(bold: true)),
      PosColumn(text: 'DESCRIPCION', width: 7, styles: const PosStyles(bold: true)),
      PosColumn(text: 'TOTAL', width: 3, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.text('------------------------------------------------', styles: const PosStyles(align: PosAlign.center));

    // --- DETALLE DE PRODUCTOS ---
    for (var item in items) {
      final cantidad = item['cantidad'];
      final nombre = _limpiarTexto(item['nombre'].toString().toUpperCase());
      final subtotal = double.tryParse(item['subtotal']?.toString() ?? '0') ?? (cantidad * item['precio']);

      bytes += generator.row([
        PosColumn(text: '${cantidad}x', width: 2),
        PosColumn(text: nombre, width: 7),
        PosColumn(text: 'S/ ${subtotal.toStringAsFixed(2)}', width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.text('------------------------------------------------', styles: const PosStyles(align: PosAlign.center));
    
    // --- TOTALES Y CÁLCULO DE IGV ---
    final double opGravadas = total / 1.18;
    final double igv = total - opGravadas;

    if (metodoPago != 'PRECUENTA') {
      bytes += generator.text('METODO DE PAGO: $metodoPago');
      bytes += generator.emptyLines(1);

      bytes += generator.row([
        PosColumn(text: 'OP. GRAVADAS:', width: 7),
        PosColumn(text: 'S/', width: 2, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: opGravadas.toStringAsFixed(2), width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
      
      bytes += generator.row([
        PosColumn(text: 'I.G.V. (18%):', width: 7),
        PosColumn(text: 'S/', width: 2, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: igv.toStringAsFixed(2), width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
      
      bytes += generator.emptyLines(1);
    } else {
      bytes += generator.emptyLines(1);
    }
    
    // Total gigante alineado a la derecha
    bytes += generator.row([
      PosColumn(text: 'TOTAL A PAGAR:', width: 7, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(text: 'S/ ${total.toStringAsFixed(2)}', width: 5, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
    ]);

    bytes += generator.emptyLines(1);
    bytes += generator.text('================================================', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('!GRACIAS POR SU PREFERENCIA!', styles: const PosStyles(align: PosAlign.center, bold: true));
    
    if (metodoPago != 'PRECUENTA') {
      bytes += generator.text('Representacion impresa de comprobante', styles: const PosStyles(align: PosAlign.center));
    }
    
    bytes += generator.emptyLines(2);
    
    bytes += generator.cut();

    return bytes;
  }

  // ==========================================
  // 3. ENVIAR FÍSICAMENTE LOS BYTES POR IP
  // ==========================================
  static Future<bool> enviarAImpresoraIP(String ip, List<int> bytes) async {
    try {
      final socket = await Socket.connect(ip, 9100, timeout: const Duration(seconds: 3));
      socket.add(bytes);
      await socket.flush();
      socket.destroy();
      return true; 
    } catch (e) {
      print("Error físico de impresión en IP $ip: $e");
      return false; 
    }
  }
}