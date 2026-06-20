import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tomar_pedido_screen.dart';
import '../tema_global.dart'; // <-- 1. IMPORTAMOS LA VARIABLE GLOBAL

class VistaSillas extends StatefulWidget {
  const VistaSillas({super.key});

  @override
  State<VistaSillas> createState() => _VistaSillasState();
}

class _VistaSillasState extends State<VistaSillas> {
  final Color copperPrimary = const Color(0xFFC07C46);

  bool _isLoading = true;
  bool _modoJuntar = false;
  final List<int> _sillasSeleccionadasParaJuntar = [];
  
  // Ahora las sillas vienen del backend
  List<dynamic> _sillas = [];

  @override
  void initState() {
    super.initState();
    _cargarSillas();
  }

  // ==========================================
  // CONEXIONES CON EL BACKEND (NestJS)
  // ==========================================
  
  Future<void> _cargarSillas() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('http://192.168.18.194:3000/sillas');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _sillas = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión con el servidor'), backgroundColor: Colors.redAccent)
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _ocuparSillaAPI(int idSilla) async {
    try {
      final url = Uri.parse('http://192.168.18.194:3000/sillas/$idSilla/ocupar');
      await http.patch(url);
      _cargarSillas(); // Recargamos para ver el cambio
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _liberarSillaAPI(int idSilla) async {
    try {
      final url = Uri.parse('http://192.168.18.194:3000/sillas/$idSilla/liberar');
      await http.patch(url);
      _cargarSillas();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _agruparSillasAPI(List<int> ids) async {
    try {
      final url = Uri.parse('http://192.168.18.194:3000/sillas/agrupar');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sillasIds': ids}),
      );
      _cargarSillas();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _liberarGrupoAPI(int grupoId) async {
    try {
      final url = Uri.parse('http://192.168.18.194:3000/sillas/grupo/$grupoId/liberar');
      await http.patch(url);
      _cargarSillas();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // ==========================================
  // LÓGICA DE INTERACCIÓN
  // ==========================================

  void _alTocarSilla(int index) {
    final silla = _sillas[index];
    
    if (_modoJuntar) {
      if (!silla['ocupada']) {
        setState(() {
          if (_sillasSeleccionadasParaJuntar.contains(silla['id'])) {
            _sillasSeleccionadasParaJuntar.remove(silla['id']);
          } else {
            _sillasSeleccionadasParaJuntar.add(silla['id']);
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No puedes juntar una silla que ya está ocupada'))
        );
      }
    } else {
      if (silla['ocupada']) {
        _mostrarDialogoOpcionesSilla(silla);
      } else {
        _ocuparSillaAPI(silla['id']);
      }
    }
  }

  void _confirmarGrupo() {
    if (_sillasSeleccionadasParaJuntar.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar al menos 2 sillas para juntarlas'))
      );
      return;
    }

    _agruparSillasAPI(_sillasSeleccionadasParaJuntar);
    
    setState(() {
      _modoJuntar = false;
      _sillasSeleccionadasParaJuntar.clear();
    });
  }

  void _mostrarDialogoOpcionesSilla(Map<String, dynamic> silla) {
    final bool esGrupo = silla['grupo'] != null;

    showDialog(
      context: context,
      builder: (context) {
        // Hacemos que el diálogo también reaccione al tema actual
        return ValueListenableBuilder<bool>(
          valueListenable: isDarkModeGlobal,
          builder: (context, isDark, child) {
            final Color dialogBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
            final Color dialogText = isDark ? Colors.white : const Color(0xFF222222);
            final Color dialogSubtext = isDark ? Colors.white70 : Colors.black54;

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text(
                esGrupo ? 'Opciones de Grupo ${silla['grupo']}' : 'Opciones de Silla ${silla['id']}', 
                style: TextStyle(color: dialogText, fontWeight: FontWeight.bold)
              ),
              content: Text(
                '¿Qué acción deseas realizar con este cliente?',
                style: TextStyle(color: dialogSubtext),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(isDark ? 'Volver' : 'Cancelar', style: TextStyle(color: dialogSubtext)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: copperPrimary),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => TomarPedidoScreen(silla: silla)),
                    );
                  },
                  child: const Text('Tomar Pedido', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    Navigator.pop(context);
                    if (esGrupo) {
                      _liberarGrupoAPI(silla['grupo']);
                    } else {
                      _liberarSillaAPI(silla['id']);
                    }
                  },
                  child: const Text('Liberar Silla', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  // ==========================================
  // CONSTRUCCIÓN VISUAL
  // ==========================================
  @override
  Widget build(BuildContext context) {
    // 2. ENVOLVEMOS EL RETORNO EN EL VALUE LISTENABLE BUILDER
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeGlobal,
      builder: (context, isDark, child) {

        // 3. ADAPTAMOS LA PALETA DE COLORES SEGÚN EL MODO
        final Color textColor = isDark ? Colors.white : const Color(0xFF222222);
        final Color textLightColor = isDark ? Colors.white70 : Colors.black54;
        final Color cardBgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
        final Color cardBorderColor = isDark ? Colors.white12 : Colors.black12;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Gestión de Barra', style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.bold)),
                if (_modoJuntar) ...[
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() { _modoJuntar = false; _sillasSeleccionadasParaJuntar.clear(); }),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.redAccent, fontSize: 15)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _confirmarGrupo,
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text('Confirmar Unión', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                  )
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: () => setState(() { _modoJuntar = true; }),
                    icon: const Icon(Icons.link, color: Colors.white),
                    label: const Text('Juntar Sillas', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: copperPrimary),
                  ),
                ]
              ],
            ),
            const SizedBox(height: 25),
            
            Expanded(
              child: _isLoading 
                ? Center(child: CircularProgressIndicator(color: copperPrimary))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: _sillas.length,
                    itemBuilder: (context, index) {
                      final silla = _sillas[index];
                      final bool estaOcupada = silla['ocupada'];
                      final bool estaSeleccionada = _sillasSeleccionadasParaJuntar.contains(silla['id']);
                      final bool tieneGrupo = silla['grupo'] != null;

                      Color colorFondo = cardBgColor;
                      Color colorBorde = cardBorderColor;
                      Color colorIcono = textLightColor;
                      Color colorTextoSilla = textColor;

                      if (_modoJuntar && estaSeleccionada) {
                        colorFondo = copperPrimary.withValues(alpha: 0.25);
                        colorBorde = copperPrimary;
                        colorIcono = copperPrimary;
                      } else if (estaOcupada) {
                        colorFondo = copperPrimary;
                        colorBorde = copperPrimary;
                        colorIcono = Colors.white;
                        colorTextoSilla = Colors.white;
                      }

                      return InkWell(
                        onTap: () => _alTocarSilla(index),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: colorFondo,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colorBorde, width: 2),
                            boxShadow: [
                              if (!isDark && !estaOcupada)
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3)
                                )
                            ]
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chair_alt, size: 44, color: colorIcono),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Silla ${silla['id']}', 
                                    style: TextStyle(color: colorTextoSilla, fontSize: 18, fontWeight: FontWeight.bold)
                                  ),
                                  Text(
                                    estaOcupada ? 'Ocupada' : 'Disponible', 
                                    style: TextStyle(
                                      color: estaOcupada ? Colors.white70 : (isDark ? Colors.greenAccent : Colors.green), 
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold
                                    )
                                  ),
                                ],
                              ),
                              if (tieneGrupo)
                                Positioned(
                                  top: 10, right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white, 
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: copperPrimary, width: 1)
                                    ),
                                    child: Text('G-${silla['grupo']}', style: TextStyle(color: copperPrimary, fontWeight: FontWeight.bold, fontSize: 10)),
                                  ),
                                ),
                              if (_modoJuntar && estaSeleccionada)
                                const Positioned(
                                  top: 10, right: 10,
                                  child: Icon(Icons.check_circle, color: Colors.white, size: 24),
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
    );
  }
}