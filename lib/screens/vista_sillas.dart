import 'package:flutter/material.dart';

class VistaSillas extends StatefulWidget {
  const VistaSillas({Key? key}) : super(key: key);

  @override
  State<VistaSillas> createState() => _VistaSillasState();
}

class _VistaSillasState extends State<VistaSillas> {
  // Paleta de colores DragonRES
  final Color sidebarBackground = const Color(0xFF1A1A1A);
  final Color copperPrimary = const Color(0xFFC07C46);
  final Color textLight = Colors.white70;

  // Estado del Modo "Juntar Sillas"
  bool _modoJuntar = false;
  List<int> _sillasSeleccionadasParaJuntar = [];
  int _contadorGrupos = 1;

  // Base de datos local temporal de las 6 sillas
  // 'id': Número de silla
  // 'ocupada': Estado actual
  // 'grupo': ID del grupo si se juntaron varias sillas (nulo si es individual)
  final List<Map<String, dynamic>> _sillas = List.generate(
    6,
    (index) => {'id': index + 1, 'ocupada': false, 'grupo': null},
  );

  // ==========================================
  // LÓGICA DE INTERACCIÓN
  // ==========================================
  void _alTocarSilla(int index) {
    setState(() {
      if (_modoJuntar) {
        // MODO JUNTAR: Seleccionamos o deseleccionamos la silla
        // Solo podemos seleccionar sillas que estén libres
        if (!_sillas[index]['ocupada']) {
          if (_sillasSeleccionadasParaJuntar.contains(index)) {
            _sillasSeleccionadasParaJuntar.remove(index);
          } else {
            _sillasSeleccionadasParaJuntar.add(index);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No puedes juntar una silla que ya está ocupada')),
          );
        }
      } else {
        // MODO NORMAL: Ocupar o Liberar silla
        if (_sillas[index]['ocupada']) {
          _mostrarDialogoLiberar(index);
        } else {
          // Si está libre, la marcamos como ocupada (cliente individual)
          _sillas[index]['ocupada'] = true;
          _sillas[index]['grupo'] = null; // Sin grupo porque está solo
        }
      }
    });
  }

  // Confirmar la unión de varias sillas
  void _confirmarGrupo() {
    if (_sillasSeleccionadasParaJuntar.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar al menos 2 sillas para juntarlas')),
      );
      return;
    }

    setState(() {
      // Marcamos todas las seleccionadas como ocupadas y les asignamos el mismo número de grupo
      for (int i in _sillasSeleccionadasParaJuntar) {
        _sillas[i]['ocupada'] = true;
        _sillas[i]['grupo'] = _contadorGrupos;
      }
      
      _contadorGrupos++; // Aumentamos el contador para el próximo grupo
      _modoJuntar = false; // Salimos del modo juntar
      _sillasSeleccionadasParaJuntar.clear(); // Limpiamos la selección
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Sillas agrupadas y ocupadas con éxito! ✅'), backgroundColor: Colors.green),
    );
  }

  // Liberar silla (o el grupo entero)
  void _mostrarDialogoLiberar(int index) {
    final silla = _sillas[index];
    final bool esGrupo = silla['grupo'] != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: sidebarBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(esGrupo ? 'Liberar Grupo ${silla['grupo']}' : 'Liberar Silla ${silla['id']}', 
            style: const TextStyle(color: Colors.white)),
        content: Text(
          esGrupo 
            ? 'Esta silla pertenece a un grupo. ¿Deseas liberar todas las sillas de este grupo (terminaron de consumir)?' 
            : '¿El cliente de la silla ${silla['id']} terminó y deseas liberarla?',
          style: TextStyle(color: textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              setState(() {
                if (esGrupo) {
                  // Liberamos a todas las sillas que tengan este mismo número de grupo
                  for (var s in _sillas) {
                    if (s['grupo'] == silla['grupo']) {
                      s['ocupada'] = false;
                      s['grupo'] = null;
                    }
                  }
                } else {
                  // Liberamos solo esta silla
                  _sillas[index]['ocupada'] = false;
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Liberar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CONSTRUCCIÓN DE LA PANTALLA
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera y Botones de Control
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gestión de Barra',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            
            // Botones dinámicos según el modo
            if (_modoJuntar) ...[
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _modoJuntar = false;
                        _sillasSeleccionadasParaJuntar.clear();
                      });
                    },
                    child: const Text('Cancelar', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _confirmarGrupo,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Confirmar Grupo', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              )
            ] else ...[
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _modoJuntar = true;
                  });
                },
                icon: const Icon(Icons.link, color: Colors.white),
                label: const Text('Juntar Sillas', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: copperPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]
          ],
        ),
        
        if (_modoJuntar)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              'Selecciona las sillas libres que deseas unir y presiona Confirmar.',
              style: TextStyle(color: copperPrimary, fontSize: 16, fontStyle: FontStyle.italic),
            ),
          ),
        
        const SizedBox(height: 32),

        // Grilla de las 6 sillas
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 columnas (2 filas de 3 sillas)
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.2, // Proporción de las tarjetas
            ),
            itemCount: _sillas.length,
            itemBuilder: (context, index) {
              final silla = _sillas[index];
              final bool estaOcupada = silla['ocupada'];
              final bool estaSeleccionada = _sillasSeleccionadasParaJuntar.contains(index);
              final bool tieneGrupo = silla['grupo'] != null;

              // Lógica de colores visuales
              Color colorFondo = sidebarBackground;
              Color colorBorde = Colors.white24;
              Color colorIcono = textLight;

              if (_modoJuntar && estaSeleccionada) {
                colorFondo = copperPrimary.withOpacity(0.3);
                colorBorde = copperPrimary;
                colorIcono = copperPrimary;
              } else if (estaOcupada) {
                colorFondo = copperPrimary;
                colorBorde = copperPrimary;
                colorIcono = Colors.white;
              }

              return InkWell(
                onTap: () => _alTocarSilla(index),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: colorFondo,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorBorde, width: 2),
                    boxShadow: estaOcupada 
                      ? [BoxShadow(color: copperPrimary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
                      : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chair_alt, size: 50, color: colorIcono),
                          const SizedBox(height: 12),
                          Text(
                            'Silla ${silla['id']}',
                            style: TextStyle(
                              color: estaOcupada ? Colors.white : textLight,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            estaOcupada ? 'Ocupada' : 'Disponible',
                            style: TextStyle(
                              color: estaOcupada ? Colors.white.withOpacity(0.8) : Colors.greenAccent,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      
                      // Si la silla pertenece a un grupo, mostramos una etiqueta en la esquina superior
                      if (tieneGrupo)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Grupo ${silla['grupo']}',
                              style: TextStyle(color: copperPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        
                      // Check visual en modo selección
                      if (_modoJuntar && estaSeleccionada)
                        const Positioned(
                          top: 12,
                          right: 12,
                          child: Icon(Icons.check_circle, color: Colors.white, size: 28),
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
}