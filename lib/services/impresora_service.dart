// ignore_for_file: unused_local_variable

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
 static Future<List<int>> generarTicketCocina(
  String mesa,
  List<dynamic> carrito,
) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm80, profile);
  List<int> bytes = [];

  bytes += generator.text(
    'NUEVA ORDEN',
    styles: const PosStyles(
      align: PosAlign.center,
      height: PosTextSize.size2,
      width: PosTextSize.size2,
      bold: true,
    ),
  );

  bytes += generator.text(
    'UBICACION: ${_limpiarTexto(mesa.toUpperCase())}',
    styles: const PosStyles(
      align: PosAlign.center,
      height: PosTextSize.size2,
      width: PosTextSize.size2,
    ),
  );

  bytes += generator.hr();
  bytes += generator.emptyLines(1);

  for (final item in carrito) {
    final cantidad = item['cantidad'] ?? 1;

    final nombreOriginal =
        item['nombre'] ??
        item['producto']?['nombre'] ??
        'PRODUCTO SIN NOMBRE';

    final dynamic categoriaObj =
        item['categoria'] ??
        item['categoriaNombre'] ??
        item['producto']?['categoria'];

    final String categoriaOriginal = categoriaObj is String
        ? categoriaObj
        : categoriaObj is Map && categoriaObj['nombre'] != null
            ? categoriaObj['nombre'].toString()
            : 'GENERAL';

    final notaOriginal = item['notas']?.toString() ?? '';

    final nombre = _limpiarTexto(nombreOriginal.toString().toUpperCase());
    final categoria = _limpiarTexto(categoriaOriginal.toUpperCase());
    final nota = _limpiarTexto(notaOriginal.toUpperCase());

    bytes += generator.text(
      '${cantidad}x [$categoria] $nombre',
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size1,
      ),
    );

    if (nota.trim().isNotEmpty) {
      bytes += generator.text(
        '   => * OBS: $nota *',
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
        ),
      );
    }

    bytes += generator.emptyLines(1);
  }

  bytes += generator.text(
    '------------------------------------------------',
    styles: const PosStyles(align: PosAlign.center),
  );

  bytes += generator.cut();

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

  static Future<List<int>> generarCierreCaja(Map<String, dynamic> cierre) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm80, profile);
  List<int> bytes = [];

  double toDouble(dynamic value) {
    if (value == null) return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String texto(dynamic value) {
    return _limpiarTexto(value?.toString() ?? '-');
  }

  String fechaCorta(dynamic value) {
    if (value == null) return '-';

    try {
      final fecha = DateTime.parse(value.toString()).toLocal();
      final dia = fecha.day.toString().padLeft(2, '0');
      final mes = fecha.month.toString().padLeft(2, '0');
      final anio = fecha.year.toString();
      final hora = fecha.hour.toString().padLeft(2, '0');
      final minuto = fecha.minute.toString().padLeft(2, '0');
      return '$dia/$mes/$anio $hora:$minuto';
    } catch (_) {
      return value.toString();
    }
  }

  final productos = cierre['productosVendidos'] is List
      ? cierre['productosVendidos'] as List
      : [];

  final montoInicial = toDouble(cierre['montoInicial']);
  final ventasEfectivo = toDouble(cierre['ventasEfectivo']);
  final ventasTarjeta = toDouble(cierre['ventasTarjeta']);
  final ventasDigital = toDouble(cierre['ventasDigital']);
  final ingresos = toDouble(cierre['ingresos']);
  final egresos = toDouble(cierre['egresos']);
  final totalVendido = toDouble(cierre['totalVendido']);
  final efectivoEsperado = toDouble(cierre['efectivoEsperado']);
  final montoEfectivoReal = toDouble(cierre['montoEfectivoReal']);
  final diferenciaCaja = toDouble(cierre['diferenciaCaja']);

  bytes += generator.text(
    'VERASALUD',
    styles: const PosStyles(
      align: PosAlign.center,
      bold: true,
      height: PosTextSize.size2,
      width: PosTextSize.size2,
    ),
  );

  bytes += generator.text(
    'CIERRE DE CAJA',
    styles: const PosStyles(
      align: PosAlign.center,
      bold: true,
    ),
  );

  bytes += generator.text('------------------------------------------------');

  bytes += generator.text('TURNO: #${texto(cierre['turnoId'])}');
  bytes += generator.text('USUARIO: ${texto(cierre['usuarioApertura'])}');
  bytes += generator.text('APERTURA: ${fechaCorta(cierre['fechaApertura'])}');
  bytes += generator.text('CIERRE: ${fechaCorta(cierre['fechaCierre'])}');

  bytes += generator.text('------------------------------------------------');

  bytes += generator.row([
    PosColumn(text: 'Monto inicial', width: 8),
    PosColumn(
      text: 'S/ ${montoInicial.toStringAsFixed(2)}',
      width: 4,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]);

  bytes += generator.row([
    PosColumn(text: 'Ventas efectivo', width: 8),
    PosColumn(
      text: 'S/ ${ventasEfectivo.toStringAsFixed(2)}',
      width: 4,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]);

  bytes += generator.row([
    PosColumn(text: 'Ventas tarjeta', width: 8),
    PosColumn(
      text: 'S/ ${ventasTarjeta.toStringAsFixed(2)}',
      width: 4,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]);

  bytes += generator.row([
    PosColumn(text: 'Yape / Plin', width: 8),
    PosColumn(
      text: 'S/ ${ventasDigital.toStringAsFixed(2)}',
      width: 4,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]);

  bytes += generator.row([
    PosColumn(text: 'Ingresos', width: 8),
    PosColumn(
      text: 'S/ ${ingresos.toStringAsFixed(2)}',
      width: 4,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]);

  bytes += generator.row([
    PosColumn(text: 'Egresos', width: 8),
    PosColumn(
      text: 'S/ ${egresos.toStringAsFixed(2)}',
      width: 4,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]);

  bytes += generator.text('------------------------------------------------');

  bytes += generator.row([
    PosColumn(
      text: 'TOTAL VENDIDO',
      width: 8,
      styles: const PosStyles(bold: true),
    ),
    PosColumn(
      text: 'S/ ${totalVendido.toStringAsFixed(2)}',
      width: 4,
      styles: const PosStyles(align: PosAlign.right, bold: true),
    ),
  ]);

  bytes += generator.row([
    PosColumn(text: 'Efectivo esperado', width: 8),
    PosColumn(
      text: 'S/ ${efectivoEsperado.toStringAsFixed(2)}',
      width: 4,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]);

  bytes += generator.row([
    PosColumn(text: 'Efectivo contado', width: 8),
    PosColumn(
      text: 'S/ ${montoEfectivoReal.toStringAsFixed(2)}',
      width: 4,
      styles: const PosStyles(align: PosAlign.right),
    ),
  ]);

  bytes += generator.row([
    PosColumn(
      text: 'Diferencia',
      width: 8,
      styles: const PosStyles(bold: true),
    ),
    PosColumn(
      text: 'S/ ${diferenciaCaja.toStringAsFixed(2)}',
      width: 4,
      styles: const PosStyles(align: PosAlign.right, bold: true),
    ),
  ]);

  bytes += generator.text('RESULTADO: ${texto(cierre['resultadoCaja'])}');

  bytes += generator.text('------------------------------------------------');

  /*bytes += generator.text(
    'PRODUCTOS VENDIDOS',
    styles: const PosStyles(align: PosAlign.center, bold: true),
  );

  if (productos.isEmpty) {
    bytes += generator.text('No hubo productos vendidos.');
  } else {
    for (final item in productos) {
      final map = item is Map ? item : {};
      final nombre = texto(map['nombre']).toUpperCase();
      final cantidad = map['cantidad'] ?? 0;
      final total = toDouble(map['total']);

      bytes += generator.row([
        PosColumn(text: '${cantidad}x', width: 2),
        PosColumn(text: nombre, width: 7),
        PosColumn(
          text: total.toStringAsFixed(2),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

  }*/

  bytes += generator.text('------------------------------------------------');

  bytes += generator.text(
    'CIERRE GENERADO POR DRAGONPOS',
    styles: const PosStyles(align: PosAlign.center),
  );

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