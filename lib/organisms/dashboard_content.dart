import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/app_colors.dart';
import '../molecules/stat_card.dart';
import '../molecules/dolar_indicator.dart';
import '../models/dolar_model.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';

import 'dart:async';
import '../services/sync_service.dart';
import '../services/sync_queue_service.dart';

class DashboardContent extends StatefulWidget {
  final String userName;
  final String userRole;

  const DashboardContent({
    super.key,
    required this.userName,
    required this.userRole,
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final AuthService _authService = AuthService.instance;

  StreamSubscription<bool>? _syncServiceSub;
  StreamSubscription<bool>? _syncQueueSub;
  StreamSubscription<int>? _pendingCountSub;

  // Estadísticas
  int _totalUsuarios = 0;
  int _totalVendedores = 0;
  int _totalEncuestas = 0;
  int _totalPreguntas = 0;
  int _totalRespuestas = 0;
  int _totalVisitas = 0;
  int _visitasPendientes = 0;
  int _visitasCompletadas = 0;
  int _totalClientes = 0;
  bool _isLoading = true;

  // Dólar (solo vendedor)
  Map<String, dynamic>? dolarData;

  @override
  void initState() {
    super.initState();
    _loadData();

    _syncServiceSub = SyncService.instance.syncingStream.listen((syncing) {
      if (!syncing && mounted) {
        _loadData(showSpinner: false);
      }
    });

    _syncQueueSub = SyncQueueService.instance.syncingStream.listen((syncing) {
      if (!syncing && mounted) {
        _loadData(showSpinner: false);
      }
    });

    _pendingCountSub = SyncQueueService.instance.pendingCountStream.listen((_) {
      if (mounted) {
        _loadData(showSpinner: false);
      }
    });
  }

  @override
  void dispose() {
    _syncServiceSub?.cancel();
    _syncQueueSub?.cancel();
    _pendingCountSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);

    try {
      final db = await _db.database;

      // Cargar estadísticas según rol
      if (_authService.isAdmin) {
        await _loadAdminStats(db);
      } else {
        await _loadVendedorStats(db);
        // _fetchDolares(); // Deshabilitado por ahora
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAdminStats(dynamic db) async {
    // Usuarios
    final usuarios = await db.rawQuery('SELECT COUNT(*) as total FROM usuarios');
    _totalUsuarios = (usuarios.first['total'] as int?) ?? 0;
    final vendedores = await db.rawQuery("SELECT COUNT(*) as total FROM usuarios WHERE role = 'vendedor'");
    _totalVendedores = (vendedores.first['total'] as int?) ?? 0;

    // Encuestas
    final encuestas = await db.rawQuery('SELECT COUNT(*) as total FROM encuestas');
    _totalEncuestas = (encuestas.first['total'] as int?) ?? 0;

    // Preguntas
    final preguntas = await db.rawQuery('SELECT COUNT(*) as total FROM preguntas');
    _totalPreguntas = (preguntas.first['total'] as int?) ?? 0;

    // Respuestas realizadas
    final respuestas = await db.rawQuery('SELECT COUNT(*) as total FROM respuestas_pendientes');
    _totalRespuestas = (respuestas.first['total'] as int?) ?? 0;

    // Visitas
    final visitas = await db.rawQuery('SELECT COUNT(*) as total FROM visitas');
    _totalVisitas = (visitas.first['total'] as int?) ?? 0;
    final pendientes = await db.rawQuery("SELECT COUNT(*) as total FROM visitas WHERE status = 'PENDING'");
    _visitasPendientes = (pendientes.first['total'] as int?) ?? 0;
    final completadas = await db.rawQuery("SELECT COUNT(*) as total FROM visitas WHERE status = 'COMPLETED'");
    _visitasCompletadas = (completadas.first['total'] as int?) ?? 0;

    // Clientes
    final clientes = await db.rawQuery('SELECT COUNT(*) as total FROM clientes');
    _totalClientes = (clientes.first['total'] as int?) ?? 0;
  }

  Future<void> _loadVendedorStats(dynamic db) async {
    _totalClientes = (await db.rawQuery('SELECT COUNT(*) as total FROM clientes').then((r) => r.first['total'] as int?)) ?? 0;
    final pendientes = await db.rawQuery("SELECT COUNT(*) as total FROM visitas WHERE status = 'PENDING'");
    _visitasPendientes = (pendientes.first['total'] as int?) ?? 0;
    final completadas = await db.rawQuery("SELECT COUNT(*) as total FROM visitas WHERE status = 'COMPLETED'");
    _visitasCompletadas = (completadas.first['total'] as int?) ?? 0;
  }

  Future<void> _fetchDolares() async {
    try {
      final response = await http.get(Uri.parse('https://ve.dolarapi.com/v1/dolares'));
      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);
        setState(() {
          dolarData = {
            'bcv': jsonList.firstWhere((e) => e['fuente'] == 'oficial', orElse: () => {}),
            'usdt': jsonList.firstWhere((e) => e['fuente'] == 'paralelo', orElse: () => {}),
          };
        });
      }
    } catch (e) {
      // Silencioso
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    }

    if (_authService.isAdmin) {
      return _buildAdminDashboard();
    }
    return _buildVendedorDashboard();
  }

  // ═══════════════════════════════════════
  // DASHBOARD ADMIN
  // ═══════════════════════════════════════
  Widget _buildAdminDashboard() {
    return RefreshIndicator(
      onRefresh: () => _loadData(showSpinner: false),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Saludo
          Text(
            'Panel de Administración',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Bienvenido, ${widget.userName}',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),

          // Sección: Usuarios
          _buildSectionTitle(Icons.people, 'Usuarios'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Total Usuarios',
                  value: _totalUsuarios.toString(),
                  icon: Icons.group,
                  iconColor: AppColors.primaryColor,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Vendedores',
                  value: _totalVendedores.toString(),
                  icon: Icons.person,
                  iconColor: Colors.teal,
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Clientes',
                  value: _totalClientes.toString(),
                  icon: Icons.business,
                  iconColor: Colors.orange,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 24),

          // Sección: Encuestas
          _buildSectionTitle(Icons.quiz, 'Encuestas'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Plantillas',
                  value: _totalEncuestas.toString(),
                  icon: Icons.assignment,
                  iconColor: Colors.indigo,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Preguntas',
                  value: _totalPreguntas.toString(),
                  icon: Icons.help_outline,
                  iconColor: Colors.purple,
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Encuestas Realizadas',
                  value: _totalRespuestas.toString(),
                  icon: Icons.check_circle,
                  iconColor: Colors.green,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 24),

          // Sección: Visitas
          _buildSectionTitle(Icons.assignment_turned_in, 'Visitas'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Pendientes',
                  value: _visitasPendientes.toString(),
                  icon: Icons.pending,
                  iconColor: Colors.orange,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Completadas',
                  value: _visitasCompletadas.toString(),
                  icon: Icons.check_circle,
                  iconColor: Colors.green,
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Total Visitas',
                  value: _totalVisitas.toString(),
                  icon: Icons.assignment,
                  iconColor: AppColors.primaryColor,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    ),
  );
  }

  // ═══════════════════════════════════════
  // DASHBOARD VENDEDOR
  // ═══════════════════════════════════════
  Widget _buildVendedorDashboard() {
    return RefreshIndicator(
      onRefresh: () => _loadData(showSpinner: false),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dólar (Deshabilitado por ahora)
          /*
          if (dolarData != null && dolarData!['bcv'].isNotEmpty && dolarData!['usdt'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Expanded(
                    child: DolarIndicator(
                      title: "Dólar BCV",
                      dolar: DolarModel.fromJson(dolarData!['bcv'] as Map<String, dynamic>),
                      backgroundColor: Colors.greenAccent.shade700,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: DolarIndicator(
                      title: "USDT Paralelo",
                      dolar: DolarModel.fromJson(dolarData!['usdt'] as Map<String, dynamic>),
                      backgroundColor: Colors.blueAccent.shade700,
                    ),
                  ),
                ],
              ),
            ),
          */

          // Saludo
          Text(
            'Hola, ${widget.userName} 👋',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 30),

          // Stats vendedor
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Clientes',
                  value: _totalClientes.toString(),
                  icon: Icons.people,
                  iconColor: AppColors.primaryColor,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Pendientes',
                  value: _visitasPendientes.toString(),
                  icon: Icons.pending,
                  iconColor: Colors.orange,
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Completadas',
                  value: _visitasCompletadas.toString(),
                  icon: Icons.check_circle,
                  iconColor: Colors.green,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}