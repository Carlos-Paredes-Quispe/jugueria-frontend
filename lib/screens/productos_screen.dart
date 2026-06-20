import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../tema_global.dart'; // <-- 1. IMPORTAMOS LA VARIABLE GLOBAL

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
  String _errorMensaje = '';

  @override
  void initState() {
    super.initState();
    _cargarMenu();
  }

  // ==========================================
  // 1. OBTENER PRODUCTOS (GET)
  // ==========================================
  Future<void> _cargarMenu() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('http://192.168.18.194:3000/productos/menu');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _categoriasOriginales = jsonDecode(response.body);
          _categoriasFiltradas = _categoriasOriginales;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMensaje = 'Error al cargar los datos del servidor.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMensaje = 'No se pudo conectar con la base de datos.';
        _isLoading = false;
      });
    }
  }

  // ==========================================
  // 2. BUSCADOR EN TIEMPO REAL
  // ==========================================
  void _filtrarProductos(String textoBuscado) {
    if (textoBuscado.isEmpty) {
      setState(() => _categoriasFiltradas = _categoriasOriginales);
      return;
    }

    String busqueda = textoBuscado.toLowerCase();
    List<dynamic> resultadoFiltro = [];

    for (var categoria in _categoriasOriginales) {
      List<dynamic> productos = categoria['productos'] ?? [];
      
      List<dynamic> productosCoincidentes = productos.where((prod) {
        return prod['nombre'].toString().toLowerCase().contains(busqueda);
      }).toList();

      if (productosCoincidentes.isNotEmpty) {
        resultadoFiltro.add({
          'nombre': categoria['nombre'],
          'id': categoria['id'],
          'productos': productosCoincidentes
        });
      }
    }
    setState(() => _categoriasFiltradas = resultadoFiltro);
  }

  // ==========================================
  // 3. CREAR PRODUCTO (POST)
  // ==========================================
  void _mostrarDialogoCrear() {
    TextEditingController nombreCtrl = TextEditingController();
    TextEditingController precioCtrl = TextEditingController();
    
    int? categoriaSeleccionadaId = _categoriasOriginales.isNotEmpty 
        ? _categoriasOriginales[0]['id'] 
        : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // ENVOLVEMOS EL DIÁLOGO PARA QUE RESPETE EL TEMA
            return ValueListenableBuilder<bool>(
              valueListenable: isDarkModeGlobal,
              builder: (context, isDark, child) {
                final Color dialogBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
                final Color dialogText = isDark ? Colors.white : const Color(0xFF222222);
                final Color dialogSubtext = isDark ? Colors.white70 : Colors.black54;

                return AlertDialog(
                  backgroundColor: dialogBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  title: Text('Nuevo Producto', style: TextStyle(color: dialogText, fontWeight: FontWeight.bold)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nombreCtrl,
                        style: TextStyle(color: dialogText),
                        decoration: InputDecoration(
                          labelText: 'Nombre del producto',
                          labelStyle: TextStyle(color: dialogSubtext),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogSubtext)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: copperPrimary)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: precioCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: dialogText),
                        decoration: InputDecoration(
                          labelText: 'Precio (S/)',
                          labelStyle: TextStyle(color: dialogSubtext),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogSubtext)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: copperPrimary)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<int>(
                        dropdownColor: dialogBg,
                        initialValue: categoriaSeleccionadaId,
                        style: TextStyle(color: dialogText),
                        decoration: InputDecoration(
                          labelText: 'Categoría',
                          labelStyle: TextStyle(color: dialogSubtext),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogSubtext)),
                        ),
                        items: _categoriasOriginales.map<DropdownMenuItem<int>>((cat) {
                          return DropdownMenuItem<int>(
                            value: cat['id'],
                            child: Text(cat['nombre'] ?? ''),
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
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.redAccent)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: copperPrimary),
                      onPressed: () {
                        if (nombreCtrl.text.isEmpty || precioCtrl.text.isEmpty || categoriaSeleccionadaId == null) return;
                        Navigator.pop(context);
                        _crearProductoAPI(nombreCtrl.text, double.tryParse(precioCtrl.text) ?? 0.0, categoriaSeleccionadaId!);
                      },
                      child: const Text('Agregar', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                );
              }
            );
          },
        );
      },
    );
  }

  Future<void> _crearProductoAPI(String nombre, double precio, int categoriaId) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardando nuevo producto...'), duration: Duration(seconds: 1)));
    try {
      final url = Uri.parse('http://192.168.18.194:3000/productos'); 
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'nombre': nombre, 'precio': precio, 'categoriaId': categoriaId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Producto agregado con éxito! 🍹'), backgroundColor: Colors.green));
        _cargarMenu(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar en el servidor'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de red al crear producto'), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // 4. EDITAR PRODUCTO (PATCH)
  // ==========================================
  void _mostrarDialogoEditar(Map<String, dynamic> producto) {
    TextEditingController nombreCtrl = TextEditingController(text: producto['nombre']);
    TextEditingController precioCtrl = TextEditingController(text: producto['precio'].toString());

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
              title: Text('Editar Producto', style: TextStyle(color: dialogText, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    style: TextStyle(color: dialogText),
                    decoration: InputDecoration(
                      labelText: 'Nombre del producto',
                      labelStyle: TextStyle(color: dialogSubtext),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogSubtext)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: copperPrimary)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: precioCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: dialogText),
                    decoration: InputDecoration(
                      labelText: 'Precio (S/)',
                      labelStyle: TextStyle(color: dialogSubtext),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogSubtext)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: copperPrimary)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: copperPrimary),
                  onPressed: () {
                    Navigator.pop(context);
                    _actualizarProductoAPI(producto['id'], nombreCtrl.text, double.tryParse(precioCtrl.text) ?? 0.0);
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _actualizarProductoAPI(int idProducto, String nuevoNombre, double nuevoPrecio) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actualizando producto...'), duration: Duration(seconds: 1)));
    try {
      final url = Uri.parse('http://192.168.18.194:3000/productos/$idProducto'); 
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'nombre': nuevoNombre, 'precio': nuevoPrecio}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Actualizado correctamente! ✅'), backgroundColor: Colors.green));
        _cargarMenu(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al actualizar en la base de datos'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de red al actualizar'), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // 5. ELIMINAR PRODUCTO (DELETE)
  // ==========================================
  void _mostrarDialogoEliminar(Map<String, dynamic> producto) {
    showDialog(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: isDarkModeGlobal,
          builder: (context, isDark, child) {
            final Color dialogBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
            final Color dialogText = isDark ? Colors.white : const Color(0xFF222222);

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text('Eliminar Producto', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              content: Text(
                '¿Estás seguro que deseas eliminar "${producto['nombre']}" de forma permanente?',
                style: TextStyle(color: dialogText),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () {
                    Navigator.pop(context); // Cierra la ventana
                    _eliminarProductoAPI(producto['id']); // Llama a la API
                  },
                  child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _eliminarProductoAPI(int idProducto) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eliminando producto...'), duration: Duration(seconds: 1)));
    try {
      final url = Uri.parse('http://192.168.18.194:3000/productos/$idProducto'); 
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto eliminado permanentemente 🗑️'), backgroundColor: Colors.orange));
        _cargarMenu(); // Recarga la lista para que desaparezca el producto
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar en la base de datos'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de red al intentar eliminar'), backgroundColor: Colors.red));
    }
  }

  // ==========================================
  // CONSTRUCCIÓN DE LA PANTALLA
  // ==========================================
  @override
  Widget build(BuildContext context) {
    // 2. ENVOLVEMOS LA PANTALLA EN EL ESCUCHADOR GLOBAL
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {
        
        // 3. PALETA DINÁMICA DE COLORES
        final Color panelColor = isDark ? const Color(0xFF1A1A1A) : Colors.white; 
        final Color textColor = isDark ? Colors.white : const Color(0xFF222222);
        final Color textLightColor = isDark ? Colors.white70 : Colors.black54;
        final Color searchBgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F2F5);
        final Color borderColor = isDark ? Colors.white12 : Colors.black12;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Catálogo de Productos', style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _mostrarDialogoCrear,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Nuevo Producto', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: copperPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: _isLoading 
                ? Center(child: CircularProgressIndicator(color: copperPrimary))
                : _errorMensaje.isNotEmpty
                  ? Center(child: Text(_errorMensaje, style: const TextStyle(color: Colors.redAccent)))
                  : _categoriasFiltradas.isEmpty
                    ? Center(child: Text('No se encontraron productos.', style: TextStyle(color: textLightColor)))
                    : ListView.builder(
                        itemCount: _categoriasFiltradas.length,
                        itemBuilder: (context, index) {
                          final categoria = _categoriasFiltradas[index];
                          final productos = categoria['productos'] ?? [];

                          return Card(
                            color: panelColor,
                            elevation: isDark ? 0 : 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: borderColor)
                            ),
                            child: ExpansionTile(
                              iconColor: copperPrimary,
                              collapsedIconColor: textLightColor,
                              initiallyExpanded: _searchController.text.isNotEmpty,
                              title: Text(categoria['nombre'] ?? '', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                              children: productos.map<Widget>((producto) {
                                return Container(
                                  decoration: BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                    title: Text(producto['nombre'], style: TextStyle(color: textColor)),
                                    subtitle: Text('S/ ${producto['precio'].toString()}', style: TextStyle(color: copperPrimary, fontWeight: FontWeight.bold)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent), 
                                          onPressed: () => _mostrarDialogoEditar(producto),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                                          onPressed: () => _mostrarDialogoEliminar(producto),
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
      }
    );
  }
}