import 'package:flutter/material.dart';

class VistaSillas extends StatefulWidget {
  const VistaSillas({Key? key}) : super(key: key);

  @override
  State<VistaSillas> createState() => _VistaSillasState();
}

class _VistaSillasState extends State<VistaSillas> {
  final Color darkBackground = const Color(0xFF0A0A0A);
  final Color cardBackground = const Color(0xFF1A1A1A);
  final Color copperPrimary = const Color(0xFFC07C46);
  
  // Simulamos una lista de 12 sillas en la barra/local. 
  // 'true' significa disponible, 'false' significa ocupada.
  final List<Map<String, dynamic>> _sillas = List.generate(
    12, 
    (index) => {"id": index + 1, "disponible": index % 3 != 0} // Solo para simular algunas ocupadas
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título superior
        const Text(
          'Estado del Local',
          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Selecciona una silla libre para tomar un nuevo pedido, o una ocupada para ver su cuenta.',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
        const SizedBox(height: 24),

        // Leyenda de colores
        Row(
          children: [
            _crearLeyenda(Colors.white, 'Disponible'),
            const SizedBox(width: 20),
            _crearLeyenda(copperPrimary, 'Ocupada / Con Pedido'),
          ],
        ),
        const SizedBox(height: 24),

        // Cuadrícula de Sillas
        Expanded(
          child: GridView.builder(
            itemCount: _sillas.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // 4 sillas por fila (ideal para tablet)
              childAspectRatio: 1.2, // Proporción del rectángulo
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              final silla = _sillas[index];
              final bool disponible = silla['disponible'];

              return GestureDetector(
                onTap: () {
                  // AQUÍ LUEGO ABRIREMOS EL MENÚ DE GASEOSAS
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Abriendo menú para la Silla ${silla["id"]}...')),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: disponible ? cardBackground : copperPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: disponible ? Colors.white12 : copperPrimary,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chair_alt, 
                        size: 48, 
                        color: disponible ? Colors.white54 : copperPrimary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Silla ${silla["id"]}',
                        style: TextStyle(
                          color: disponible ? Colors.white : copperPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        disponible ? 'Libre' : 'Ver pedido',
                        style: TextStyle(
                          color: disponible ? Colors.white38 : copperPrimary.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Pequeño widget para dibujar los círculos de la leyenda
  Widget _crearLeyenda(Color color, String texto) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 8),
        Text(texto, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ],
    );
  }
}