import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({Key? key}) : super(key: key);

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  // Colores heredados de tu Dashboard
  final Color sidebarBackground = const Color(0xFF1A1A1A);
  final Color copperPrimary = const Color(0xFFC07C46);
  final Color textLight = Colors.white70;

  Future<List<dynamic>> fetchMenu() async {
    // Reemplaza esta IP con la IPv4 de tu computadora
    final url = Uri.parse('http://192.168.18.194:3000/productos/menu'); 
    
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar la base de datos');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos un Container transparente para no chocar con el padding del Dashboard
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera del Inventario
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Inventario de Productos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // Aquí irá el formulario para crear un nuevo jugo/producto
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nuevo Producto', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: copperPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Lista de Categorías y Productos
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: fetchMenu(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: copperPrimary));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error de conexión.\nVerifica que NestJS esté encendido y la IP sea correcta.\nDetalle: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final categorias = snapshot.data ?? [];

              if (categorias.isEmpty) {
                return const Center(
                  child: Text('No hay productos en el inventario.', style: TextStyle(color: Colors.white70)),
                );
              }

              return ListView.builder(
                itemCount: categorias.length,
                itemBuilder: (context, index) {
                  final categoria = categorias[index];
                  final productos = categoria['productos'] ?? [];

                  return Card(
                    color: sidebarBackground,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      iconColor: copperPrimary,
                      collapsedIconColor: textLight,
                      title: Text(
                        categoria['nombre'] ?? 'Sin categoría',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${productos.length} productos',
                        style: TextStyle(color: textLight, fontSize: 14),
                      ),
                      children: productos.map<Widget>((producto) {
                        return Container(
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                            title: Text(
                              producto['nombre'],
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              'S/ ${producto['precio'].toString()}',
                              style: TextStyle(color: copperPrimary, fontWeight: FontWeight.bold),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                                  onPressed: () { /* Lógica para editar */ },
                                  tooltip: 'Editar',
                                ),
                                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () { /* Lógica para eliminar */ },
                                  tooltip: 'Eliminar',
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}