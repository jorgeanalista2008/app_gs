import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/app_colors.dart';
import '../molecules/stat_card.dart';
import '../molecules/dolar_indicator.dart';
import '../models/dolar_model.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../repositories/cliente_repository.dart';

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
  int _totalProspectos = 0;
  int _visitasHoy = 0;
  bool _isLoading = true;

  // Dólar (solo vendedor)
  Map<String, dynamic>? dolarData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final db = await _db.database;

      // Cargar estadísticas según rol
      if (_authService.isAdmin) {
        await _loadAdminStats(db);
      } else {
        // Intentar sincronizar clientes con backend (no bloquea si offline).
        await _sincronizarClientesSiOnline();
        await _loadVendedorStats(db);
        _fetchDolares();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Trae clientes del backend si hay conexión + credenciales locales.
  /// Silencioso: cualquier error queda en logs, no rompe el dashboard.
  Future<void> _sincronizarClientesSiOnline() async {
    try {
      final online = await ConnectivityService.instance.isConnected();
      if (!online) return;
      final user = _authService.currentUser;
      final email = user?['username']?.toString();
      final password = user?['password']?.toString();
      if (email == null || email.isEmpty || password == null || password.isEmpty) {
        return;
      }
      await ClienteRepository().sincronizarClientes(email: email, password: password);
    } catch (e) {
      print('⚠️ Dashboard sync clientes: $e');
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
    final clientesRows = await db.rawQuery(
      "SELECT COUNT(*) as total FROM clientes WHERE is_prospect = 0",
    );
    _totalClientes = (clientesRows.first['total'] as int?) ?? 0;

    final prospectosRows = await db.rawQuery(
      "SELECT COUNT(*) as total FROM clientes WHERE is_prospect = 1",
    );
    _totalProspectos = (prospectosRows.first['total'] as int?) ?? 0;

    final pendientes = await db.rawQuery(
      "SELECT COUNT(*) as total FROM visitas WHERE status = 'PENDING'",
    );
    _visitasPendientes = (pendientes.first['total'] as int?) ?? 0;

    final completadas = await db.rawQuery(
      "SELECT COUNT(*) as total FROM visitas WHERE status = 'COMPLETED'",
    );
    _visitasCompletadas = (completadas.first['total'] as int?) ?? 0;

    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    final visitasHoyRows = await db.rawQuery(
      "SELECT COUNT(*) as total FROM visitas WHERE status = 'COMPLETED' AND substr(visit_date_from, 1, 10) = ?",
      [hoy],
    );
    _visitasHoy = (visitasHoyRows.first['total'] as int?) ?? 0;
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
    return SingleChildScrollView(
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
    );
  }

  // ═══════════════════════════════════════
  // DASHBOARD VENDEDOR
  // ═══════════════════════════════════════
  Widget _buildVendedorDashboard() {
    final rol = _authService.userRole ?? 'vendedor';
    final esForaneo = rol == 'vendedor_foraneo';

    return RefreshIndicator(
      color: AppColors.primaryColor,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header saludo con gradiente Solsumed ───
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primaryColor,
                    AppColors.secondaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.waving_hand_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Hola, ${widget.userName}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      esForaneo ? 'Vendedor Foráneo' : 'Vendedor',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Resumen de tu cartera',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Dólar (paleta Solsumed) ───
            if (dolarData != null &&
                (dolarData!['bcv']?.isNotEmpty ?? false) &&
                (dolarData!['usdt']?.isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: DolarIndicator(
                        title: "Dólar BCV",
                        dolar: DolarModel.fromJson(dolarData!['bcv'] as Map<String, dynamic>),
                        backgroundColor: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DolarIndicator(
                        title: "USDT Paralelo",
                        dolar: DolarModel.fromJson(dolarData!['usdt'] as Map<String, dynamic>),
                        backgroundColor: AppColors.secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),

            // ─── Sección KPIs ───
            _buildSectionTitle(Icons.insights_rounded, 'Mi Cartera'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _statCard(
                  title: 'Clientes',
                  value: _totalClientes,
                  icon: Icons.people_alt_rounded,
                  color: AppColors.primaryColor,
                ),
                _statCard(
                  title: 'Prospectos',
                  value: _totalProspectos,
                  icon: Icons.person_add_alt_1_rounded,
                  color: AppColors.secondaryColor,
                ),
                _statCard(
                  title: 'Visitas Pendientes',
                  value: _visitasPendientes,
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.warningColor,
                ),
                _statCard(
                  title: 'Visitas Hechas',
                  value: _visitasCompletadas,
                  icon: Icons.check_circle_rounded,
                  color: AppColors.successColor,
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ─── Actividad de hoy ───
            _buildSectionTitle(Icons.today_rounded, 'Hoy'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.pin_drop_rounded,
                      color: AppColors.primaryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_visitasHoy visita${_visitasHoy == 1 ? '' : 's'} completada${_visitasHoy == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Registro del día actual',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dividerColor),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
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