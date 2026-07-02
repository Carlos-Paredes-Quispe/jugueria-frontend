import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_jugueria/config/api_config.dart';
import 'package:http/http.dart' as http;

import '../tema_global.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  final Color copperPrimary = const Color(0xFFC07C46);

  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _categoriasOriginales = [];
  List<dynamic> _categoriasFiltradas = [];

  bool _isLoading = true;
  bool _procesando = false;
  String _errorMensaje = '';

  @override
  void initState() {
    super.initState();
    _cargarMenu();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double? _leerPrecio(String texto) {
    return double.tryParse(texto.trim().replaceAll(',', '.'));
  }

  String _mensajeBackend(String body) {
    try {
      final data = jsonDecode(body);

      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }

      if (data is Map && data['mensaje'] != null) {
        return data['mensaje'].toString();
      }

      return body;
    } catch (_) {
      return body;
    }
  }

  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _cargarMenu() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMensaje = '';
    });

    try {
      final response = await http
          .get(
            ApiConfig.uri('/productos/menu'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _categoriasOriginales = data is List ? data : [];
          _categoriasFiltradas = _categoriasOriginales;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMensaje =
              'Error al cargar productos: ${_mensajeBackend(response.body)}';
          _isLoading = false;
        });
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _errorMensaje = 'Tiempo agotado al cargar productos.';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMensaje = 'No se pudo conectar con la base de datos.';
        _isLoading = false;
      });
    }
  }

  void _filtrarProductos(String textoBuscado) {
    if (textoBuscado.trim().isEmpty) {
      setState(() {
        _categoriasFiltradas = _categoriasOriginales;
      });
      return;
    }

    final String busqueda = textoBuscado.toLowerCase();
    final List<dynamic> resultadoFiltro = [];

    for (final categoria in _categoriasOriginales) {
      final List<dynamic> productos = categoria['productos'] ?? [];

      final List<dynamic> productosCoincidentes = productos.where((prod) {
        final nombre = prod['nombre']?.toString().toLowerCase() ?? '';
        final categoriaNombre = categoria['nombre']?.toString().toLowerCase() ?? '';

        return nombre.contains(busqueda) || categoriaNombre.contains(busqueda);
      }).toList();

      if (productosCoincidentes.isNotEmpty) {
        resultadoFiltro.add({
          'nombre': categoria['nombre'],
          'id': categoria['id'],
          'productos': productosCoincidentes,
        });
      }
    }

    setState(() {
      _categoriasFiltradas = resultadoFiltro;
    });
  }

  Future<void> _mostrarDialogoCrear() async {
    if (_categoriasOriginales.isEmpty) {
      _mostrarMensaje(
        'No hay categorías disponibles para crear productos.',
        Colors.redAccent,
      );
      return;
    }

    final TextEditingController nombreCtrl = TextEditingController();
    final TextEditingController precioCtrl = TextEditingController();

    int? categoriaSeleccionadaId = int.tryParse(
      _categoriasOriginales.first['id'].toString(),
    );

    await showDialog(
      context: context,
      barrierDismissible: !_procesando,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ValueListenableBuilder<bool>(
              valueListenable: isDarkModeGlobal,
              builder: (context, isDark, child) {
                final Color dialogBg =
                    isDark ? const Color(0xFF1A1A1A) : Colors.white;
                final Color dialogText =
                    isDark ? Colors.white : const Color(0xFF222222);
                final Color dialogSubtext =
                    isDark ? Colors.white70 : Colors.black54;
                final double tecladoAltura =
                    MediaQuery.of(context).viewInsets.bottom;

                return AlertDialog(
                  insetPadding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 24,
                    bottom: tecladoAltura + 24,
                  ),
                  backgroundColor: dialogBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  title: Text(
                    'Nuevo Producto',
                    style: TextStyle(
                      color: dialogText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nombreCtrl,
                            style: TextStyle(color: dialogText),
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Nombre del producto',
                              labelStyle: TextStyle(color: dialogSubtext),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: dialogSubtext),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: copperPrimary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: precioCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: TextStyle(color: dialogText),
                            decoration: InputDecoration(
                              labelText: 'Precio (S/)',
                              hintText: 'Ejemplo: 8.50',
                              labelStyle: TextStyle(color: dialogSubtext),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: dialogSubtext),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: copperPrimary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          DropdownButtonFormField<int>(
                            value: categoriaSeleccionadaId,
                            dropdownColor: dialogBg,
                            style: TextStyle(color: dialogText),
                            decoration: InputDecoration(
                              labelText: 'Categoría',
                              labelStyle: TextStyle(color: dialogSubtext),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: dialogSubtext),
                              ),
                            ),
                            items: _categoriasOriginales
                                .map<DropdownMenuItem<int>>((cat) {
                              return DropdownMenuItem<int>(
                                value: int.tryParse(cat['id'].toString()),
                                child: Text(
                                  cat['nombre']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (int? nuevoId) {
                              setDialogState(() {
                                categoriaSeleccionadaId = nuevoId;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: _procesando
                          ? null
                          : () => Navigator.pop(dialogContext),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: copperPrimary,
                      ),
                      onPressed: _procesando
                          ? null
                          : () {
                              final String nombre = nombreCtrl.text.trim();
                              final double? precio =
                                  _leerPrecio(precioCtrl.text);

                              if (nombre.isEmpty) {
                                _mostrarMensaje(
                                  'Ingresa el nombre del producto.',
                                  Colors.redAccent,
                                );
                                return;
                              }

                              if (precio == null || precio <= 0) {
                                _mostrarMensaje(
                                  'Ingresa un precio válido mayor a 0.',
                                  Colors.redAccent,
                                );
                                return;
                              }

                              if (categoriaSeleccionadaId == null) {
                                _mostrarMensaje(
                                  'Selecciona una categoría.',
                                  Colors.redAccent,
                                );
                                return;
                              }

                              Navigator.pop(dialogContext);
                              _crearProductoAPI(
                                nombre,
                                precio,
                                categoriaSeleccionadaId!,
                              );
                            },
                      child: const Text(
                        'Agregar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    nombreCtrl.dispose();
    precioCtrl.dispose();
  }

  Future<void> _crearProductoAPI(
    String nombre,
    double precio,
    int categoriaId,
  ) async {
    if (_procesando) return;

    setState(() {
      _procesando = true;
    });

    _mostrarMensaje(
      'Guardando nuevo producto...',
      copperPrimary,
    );

    try {
      final response = await http
          .post(
            ApiConfig.uri('/productos'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'nombre': nombre,
              'precio': precio,
              'categoriaId': categoriaId,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _mostrarMensaje(
          '¡Producto agregado con éxito! 🍹',
          Colors.green,
        );
        await _cargarMenu();
      } else {
        _mostrarMensaje(
          'Error al guardar: ${_mensajeBackend(response.body)}',
          Colors.redAccent,
        );
      }
    } on TimeoutException {
      if (!mounted) return;

      _mostrarMensaje(
        'Tiempo agotado al crear producto.',
        Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error de red al crear producto.',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Future<void> _mostrarDialogoEditar(Map<String, dynamic> producto) async {
    final TextEditingController nombreCtrl = TextEditingController(
      text: producto['nombre']?.toString() ?? '',
    );
    final TextEditingController precioCtrl = TextEditingController(
      text: producto['precio']?.toString() ?? '',
    );

    await showDialog(
      context: context,
      barrierDismissible: !_procesando,
      builder: (dialogContext) {
        return ValueListenableBuilder<bool>(
          valueListenable: isDarkModeGlobal,
          builder: (context, isDark, child) {
            final Color dialogBg =
                isDark ? const Color(0xFF1A1A1A) : Colors.white;
            final Color dialogText =
                isDark ? Colors.white : const Color(0xFF222222);
            final Color dialogSubtext =
                isDark ? Colors.white70 : Colors.black54;
            final double tecladoAltura =
                MediaQuery.of(context).viewInsets.bottom;

            return AlertDialog(
              insetPadding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 24,
                bottom: tecladoAltura + 24,
              ),
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                'Editar Producto',
                style: TextStyle(
                  color: dialogText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nombreCtrl,
                        style: TextStyle(color: dialogText),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Nombre del producto',
                          labelStyle: TextStyle(color: dialogSubtext),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: dialogSubtext),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: copperPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: precioCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: dialogText),
                        decoration: InputDecoration(
                          labelText: 'Precio (S/)',
                          labelStyle: TextStyle(color: dialogSubtext),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: dialogSubtext),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: copperPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      _procesando ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: copperPrimary,
                  ),
                  onPressed: _procesando
                      ? null
                      : () {
                          final String nombre = nombreCtrl.text.trim();
                          final double? precio = _leerPrecio(precioCtrl.text);

                          if (nombre.isEmpty) {
                            _mostrarMensaje(
                              'Ingresa el nombre del producto.',
                              Colors.redAccent,
                            );
                            return;
                          }

                          if (precio == null || precio <= 0) {
                            _mostrarMensaje(
                              'Ingresa un precio válido mayor a 0.',
                              Colors.redAccent,
                            );
                            return;
                          }

                          Navigator.pop(dialogContext);

                          _actualizarProductoAPI(
                            int.tryParse(producto['id'].toString()) ?? 0,
                            nombre,
                            precio,
                          );
                        },
                  child: const Text(
                    'Guardar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nombreCtrl.dispose();
    precioCtrl.dispose();
  }

  Future<void> _actualizarProductoAPI(
    int idProducto,
    String nuevoNombre,
    double nuevoPrecio,
  ) async {
    if (_procesando) return;

    if (idProducto <= 0) {
      _mostrarMensaje(
        'ID de producto inválido.',
        Colors.redAccent,
      );
      return;
    }

    setState(() {
      _procesando = true;
    });

    _mostrarMensaje(
      'Actualizando producto...',
      copperPrimary,
    );

    try {
      final response = await http
          .patch(
            ApiConfig.uri('/productos/$idProducto'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'nombre': nuevoNombre,
              'precio': nuevoPrecio,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        _mostrarMensaje(
          '¡Actualizado correctamente! ✅',
          Colors.green,
        );
        await _cargarMenu();
      } else {
        _mostrarMensaje(
          'Error al actualizar: ${_mensajeBackend(response.body)}',
          Colors.redAccent,
        );
      }
    } on TimeoutException {
      if (!mounted) return;

      _mostrarMensaje(
        'Tiempo agotado al actualizar producto.',
        Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error de red al actualizar producto.',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  Future<void> _mostrarDialogoEliminar(Map<String, dynamic> producto) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return ValueListenableBuilder<bool>(
          valueListenable: isDarkModeGlobal,
          builder: (context, isDark, child) {
            final Color dialogBg =
                isDark ? const Color(0xFF1A1A1A) : Colors.white;
            final Color dialogText =
                isDark ? Colors.white : const Color(0xFF222222);

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: const Text(
                'Eliminar Producto',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                '¿Estás seguro que deseas eliminar "${producto['nombre']}"?',
                style: TextStyle(color: dialogText),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _eliminarProductoAPI(
                      int.tryParse(producto['id'].toString()) ?? 0,
                    );
                  },
                  child: const Text(
                    'Eliminar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _eliminarProductoAPI(int idProducto) async {
    if (_procesando) return;

    if (idProducto <= 0) {
      _mostrarMensaje(
        'ID de producto inválido.',
        Colors.redAccent,
      );
      return;
    }

    setState(() {
      _procesando = true;
    });

    _mostrarMensaje(
      'Eliminando producto...',
      copperPrimary,
    );

    try {
      final response = await http
          .delete(
            ApiConfig.uri('/productos/$idProducto'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(ApiConfig.timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        _mostrarMensaje(
          'Producto eliminado 🗑️',
          Colors.orange,
        );
        await _cargarMenu();
      } else {
        _mostrarMensaje(
          'Error al eliminar: ${_mensajeBackend(response.body)}',
          Colors.redAccent,
        );
      }
    } on TimeoutException {
      if (!mounted) return;

      _mostrarMensaje(
        'Tiempo agotado al eliminar producto.',
        Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje(
        'Error de red al intentar eliminar.',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        final Color panelColor =
            isDark ? const Color(0xFF1A1A1A) : Colors.white;
        final Color textColor =
            isDark ? Colors.white : const Color(0xFF222222);
        final Color textLightColor = isDark ? Colors.white70 : Colors.black54;
        final Color searchBgColor =
            isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F2F5);
        final Color borderColor = isDark ? Colors.white12 : Colors.black12;

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool esCelular = constraints.maxWidth < 760;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (esCelular)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Catálogo de Productos',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _procesando ? null : _mostrarDialogoCrear,
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'Nuevo Producto',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: copperPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Catálogo de Productos',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _procesando ? null : _mostrarDialogoCrear,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          'Nuevo Producto',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: copperPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 18),

                TextField(
                  controller: _searchController,
                  onChanged: _filtrarProductos,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Buscar jugo, sándwich, etc...',
                    hintStyle: TextStyle(color: textLightColor),
                    prefixIcon: Icon(Icons.search, color: copperPrimary),
                    filled: true,
                    fillColor: searchBgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: copperPrimary,
                          ),
                        )
                      : _errorMensaje.isNotEmpty
                          ? Center(
                              child: Text(
                                _errorMensaje,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                ),
                              ),
                            )
                          : _categoriasFiltradas.isEmpty
                              ? Center(
                                  child: Text(
                                    'No se encontraron productos.',
                                    style: TextStyle(color: textLightColor),
                                  ),
                                )
                              : ListView.builder(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  itemCount: _categoriasFiltradas.length,
                                  itemBuilder: (context, index) {
                                    final categoria =
                                        _categoriasFiltradas[index];
                                    final productos =
                                        categoria['productos'] ?? [];

                                    return Card(
                                      color: panelColor,
                                      elevation: isDark ? 0 : 2,
                                      margin: const EdgeInsets.only(bottom: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: borderColor),
                                      ),
                                      child: ExpansionTile(
                                        iconColor: copperPrimary,
                                        collapsedIconColor: textLightColor,
                                        initiallyExpanded:
                                            _searchController.text.isNotEmpty,
                                        title: Text(
                                          categoria['nombre']?.toString() ?? '',
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        children: productos.map<Widget>((producto) {
                                          final precio = producto['precio']
                                                  ?.toString() ??
                                              '0.00';

                                          return Container(
                                            decoration: BoxDecoration(
                                              border: Border(
                                                top: BorderSide(
                                                  color: borderColor,
                                                ),
                                              ),
                                            ),
                                            child: ListTile(
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                horizontal:
                                                    esCelular ? 14 : 24,
                                                vertical: 4,
                                              ),
                                              title: Text(
                                                producto['nombre']?.toString() ??
                                                    '',
                                                style:
                                                    TextStyle(color: textColor),
                                              ),
                                              subtitle: Text(
                                                'S/ $precio',
                                                style: TextStyle(
                                                  color: copperPrimary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              trailing: Wrap(
                                                spacing: 2,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit_outlined,
                                                      color: Colors.blueAccent,
                                                    ),
                                                    onPressed: _procesando
                                                        ? null
                                                        : () =>
                                                            _mostrarDialogoEditar(
                                                              Map<String,
                                                                      dynamic>.from(
                                                                  producto),
                                                            ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      color: Colors.redAccent,
                                                    ),
                                                    onPressed: _procesando
                                                        ? null
                                                        : () =>
                                                            _mostrarDialogoEliminar(
                                                              Map<String,
                                                                      dynamic>.from(
                                                                  producto),
                                                            ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}