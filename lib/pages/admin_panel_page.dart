import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../services/database_helper.dart';
import '../services/auth_service.dart';
import 'admin_encuesta_editor_page.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final AuthService _authService = AuthService.instance;

  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _plantillas = [];
  Map<String, int> _preguntasCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _dbHelper.getUsuarios();
      final templates = await _dbHelper.getPlantillasEncuestas();

      final Map<String, int> counts = {};
      for (var temp in templates) {
        final id = temp['id'] as String;
        final questions = await _dbHelper.getPreguntasByEncuestaId(id);
        counts[id] = questions.length;
      }

      if (mounted) {
        setState(() {
          _usuarios = users;
          _plantillas = templates;
          _preguntasCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  // Helper para insignias de rol
  Widget _buildRoleBadge(String? role) {
    Color bg;
    Color fg;
    String label;

    switch (role?.toLowerCase()) {
      case 'superadmin':
      case 'admin':
        bg = const Color(0xFFFEE2E2); // Light red
        fg = const Color(0xFFEF4444); // Red
        label = 'Admin';
        break;
      case 'vendedor':
      default:
        bg = const Color(0xFFD1FAE5); // Light green
        fg = const Color(0xFF10B981); // Emerald
        label = 'Vendedor';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Confirmar y eliminar usuario
  void _confirmarEliminarUsuario(Map<String, dynamic> user) {
    final current = _authService.currentUser;
    final userId = user['id']?.toString() ?? '';
    final username = user['username']?.toString() ?? '';

    // No permitir eliminarse a sí mismo ni al administrador maestro
    if (username == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede eliminar el usuario administrador maestro.'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    if (userId == current?['id']?.toString() || username == current?['username']?.toString()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes eliminar tu propio usuario activo.'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Usuario'),
        content: Text('¿Estás seguro de que deseas eliminar al usuario "${user['full_name']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _dbHelper.eliminarUsuario(userId);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Usuario eliminado exitosamente.'),
                    backgroundColor: AppColors.successColor,
                  ),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: AppColors.errorColor)),
          ),
        ],
      ),
    );
  }

  // Dialog de creación de usuario
  void _mostrarCrearUsuarioDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final tenantIdController = TextEditingController(text: 'A1000000-0000-0000-0000-000000000001');
    final companyIdController = TextEditingController(text: 'A1000000-0000-0000-0000-000000000001');
    final branchIdController = TextEditingController(text: 'E8CCCF7B-F658-4FC4-B348-28EDCB8E229B');
    String selectedRole = 'vendedor';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.person_add, color: AppColors.primaryColor),
                  SizedBox(width: 10),
                  Text('Nuevo Usuario', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre Completo',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingresa el nombre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Usuario / Email',
                          prefixIcon: Icon(Icons.alternate_email),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingresa el usuario';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingresa la contraseña';
                          }
                          if (value.length < 4) {
                            return 'Debe tener al menos 4 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Rol del Usuario',
                          prefixIcon: Icon(Icons.manage_accounts_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'vendedor', child: Text('Vendedor')),
                          DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedRole = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: tenantIdController,
                        decoration: const InputDecoration(
                          labelText: 'Tenant ID (UUID)',
                          prefixIcon: Icon(Icons.business),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingresa el Tenant ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: companyIdController,
                        decoration: const InputDecoration(
                          labelText: 'Company ID (UUID)',
                          prefixIcon: Icon(Icons.location_city_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingresa el Company ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: branchIdController,
                        decoration: const InputDecoration(
                          labelText: 'Branch ID (UUID)',
                          prefixIcon: Icon(Icons.storefront_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingresa el Branch ID';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        await _dbHelper.crearUsuario(
                          username: usernameController.text.trim(),
                          password: passwordController.text,
                          fullName: nameController.text.trim(),
                          role: selectedRole,
                          tenantId: tenantIdController.text.trim(),
                          companyId: companyIdController.text.trim(),
                          branchId: branchIdController.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Usuario creado exitosamente.'),
                              backgroundColor: AppColors.successColor,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          // Mostrar error en el dialog si es por usuario duplicado
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('El usuario ya existe o hubo un error: $e'),
                              backgroundColor: AppColors.errorColor,
                            ),
                          );
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog de creación de plantilla de encuesta
  void _mostrarCrearEncuestaDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.quiz_outlined, color: AppColors.primaryColor),
              SizedBox(width: 10),
              Text('Nueva Encuesta', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título de la Encuesta',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa el título';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción / Instrucciones',
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newId = 'enc_${DateTime.now().microsecondsSinceEpoch}';
                  await _dbHelper.guardarPlantillaEncuesta(
                    id: newId,
                    titulo: titleController.text.trim(),
                    descripcion: descController.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Plantilla de encuesta creada.'),
                        backgroundColor: AppColors.successColor,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Crear', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Confirmar y eliminar encuesta
  void _confirmarEliminarEncuesta(Map<String, dynamic> survey) {
    final surveyId = survey['id']?.toString() ?? '';
    final titulo = survey['titulo']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Encuesta'),
        content: Text('¿Estás seguro de que deseas eliminar la encuesta "$titulo" junto con todas sus preguntas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _dbHelper.eliminarPlantillaEncuesta(surveyId);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Encuesta eliminada exitosamente.'),
                    backgroundColor: AppColors.successColor,
                  ),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: AppColors.errorColor)),
          ),
        ],
      ),
    );
  }

  // Construir pestaña de usuarios
  Widget _buildUsuariosTab() {
    if (_usuarios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 70, color: Colors.grey[300]),
            const SizedBox(height: 15),
            const Text(
              'No hay usuarios registrados',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _usuarios.length,
      itemBuilder: (context, index) {
        final user = _usuarios[index];
        final fullName = user['full_name'] ?? 'Sin Nombre';
        final username = user['username'] ?? '';
        final role = user['role'] ?? 'vendedor';
        final fechaStr = user['fecha_creacion'];
        
        String formatedDate = 'N/D';
        if (fechaStr != null) {
          final parsed = DateTime.tryParse(fechaStr);
          if (parsed != null) {
            formatedDate = DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
          }
        }

        final initials = fullName.isNotEmpty ? fullName.substring(0, 1).toUpperCase() : 'U';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildRoleBadge(role),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        username,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (user['tenant_id'] != null && user['tenant_id'].toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Tenant: ${user['tenant_id']}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                      if (user['company_id'] != null && user['company_id'].toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Company: ${user['company_id']}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                      if (user['branch_id'] != null && user['branch_id'].toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Branch: ${user['branch_id']}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Creado: $formatedDate',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.errorColor),
                  onPressed: () => _confirmarEliminarUsuario(user),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Construir pestaña de encuestas
  Widget _buildEncuestasTab() {
    if (_plantillas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 70, color: Colors.grey[300]),
            const SizedBox(height: 15),
            const Text(
              'No hay plantillas de encuestas creadas',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _mostrarCrearEncuestaDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Crear Primera Encuesta', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
              ),
            )
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plantillas.length,
      itemBuilder: (context, index) {
        final survey = _plantillas[index];
        final id = survey['id'] as String;
        final title = survey['titulo'] ?? 'Encuesta Sin Título';
        final desc = survey['descripcion'] ?? 'Sin descripción';
        final qCount = _preguntasCounts[id] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.withValues(alpha: 0.1),
              child: const Icon(Icons.quiz, color: Colors.teal),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              '$qCount ${qCount == 1 ? 'pregunta' : 'preguntas'}',
              style: TextStyle(
                color: qCount > 0 ? Colors.teal : AppColors.textSecondary,
                fontWeight: qCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              if (desc.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    desc,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminEncuestaEditorPage(
                            encuestaId: id,
                            encuestaTitulo: title,
                          ),
                        ),
                      ).then((_) => _loadData());
                    },
                    icon: const Icon(Icons.edit_note, color: AppColors.primaryColor),
                    label: const Text('Gestionar Preguntas'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _confirmarEliminarEncuesta(survey),
                    icon: const Icon(Icons.delete_outline, color: AppColors.errorColor),
                    label: const Text('Eliminar'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.errorColor),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryColor,
          tabs: const [
            Tab(
              icon: Icon(Icons.people),
              text: 'Usuarios',
            ),
            Tab(
              icon: Icon(Icons.quiz),
              text: 'Encuestas',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsuariosTab(),
                _buildEncuestasTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _mostrarCrearUsuarioDialog();
          } else {
            _mostrarCrearEncuestaDialog();
          }
        },
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
