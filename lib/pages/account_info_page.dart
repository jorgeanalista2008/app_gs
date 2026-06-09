import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../atoms/avatar_widget.dart';
import '../atoms/app_button.dart';

class AccountInfoPage extends StatefulWidget {
  const AccountInfoPage({super.key});

  @override
  State<AccountInfoPage> createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends State<AccountInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = true;
  bool _isSaving = false;
  
  Map<String, dynamic> _userData = {};
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  String? _photoBase64;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user_data');
      if (userDataStr != null) {
        setState(() {
          _userData = jsonDecode(userDataStr);
          _nameController.text = _userData['name'] ?? '';
          _emailController.text = _userData['email'] ?? '';
          _photoBase64 = _userData['photo'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error cargando datos de usuario: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePhoto(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (image != null) {
        // Leer bytes de forma compatible con web y móvil
        final Uint8List bytes = await image.readAsBytes();
        final String base64String = 'data:image/png;base64,${base64Encode(bytes)}';
        
        setState(() {
          _photoBase64 = base64String;
        });
      }
    } catch (e) {
      print('❌ Error al procesar foto de perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar foto: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Foto de Perfil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppColors.primaryColor),
                  title: const Text('Tomar foto con Cámara'),
                  onTap: () {
                    Navigator.pop(context);
                    _changePhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: AppColors.primaryColor),
                  title: const Text('Seleccionar de Galería'),
                  onTap: () {
                    Navigator.pop(context);
                    _changePhoto(ImageSource.gallery);
                  },
                ),
                if (_photoBase64 != null && _photoBase64!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Eliminar foto actual', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _photoBase64 = '';
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState?.validate() != true) return;
    
    setState(() => _isSaving = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Actualizar mapa local
      _userData['name'] = _nameController.text.trim();
      _userData['email'] = _emailController.text.trim();
      _userData['photo'] = _photoBase64 ?? '';
      
      // Guardar en SharedPreferences
      await prefs.setString('user_data', jsonEncode(_userData));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Perfil actualizado correctamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Retornar true para indicar que hubo cambios
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryColor)),
      );
    }

    final String roleName = _userData['role'] ?? 'Usuario';
    final String branchId = _userData['branch_id'] ?? 'N/A';
    final String tenantId = _userData['tenant_id'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Información de Cuenta'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Avatar & Edición
              Center(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 1),
                        ],
                      ),
                      child: AvatarWidget(
                        name: _nameController.text,
                        photoUrl: _photoBase64,
                        size: 110,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showPhotoOptions,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Inputs editables
              _buildInputCard([
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo',
                    icon: Icon(Icons.person_outline, color: AppColors.primaryColor),
                    border: InputBorder.none,
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'El nombre es requerido' : null,
                  onChanged: (v) => setState(() {}),
                ),
                const Divider(),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    icon: Icon(Icons.email_outlined, color: AppColors.primaryColor),
                    border: InputBorder.none,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'El correo es requerido';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Ingrese un correo válido';
                    }
                    return null;
                  },
                ),
              ]),
              const SizedBox(height: 24),

              // Datos informativos (lectura)
              _buildSectionTitle('Información de la Empresa'),
              const SizedBox(height: 10),
              _buildInputCard([
                _buildReadOnlyField('Rol del Usuario', roleName, Icons.badge_outlined),
                const Divider(),
                _buildReadOnlyField('ID Sucursal', branchId, Icons.storefront),
                const Divider(),
                _buildReadOnlyField('Tenant ID', tenantId, Icons.business),
              ]),
              
              const SizedBox(height: 40),
              
              // Botón Guardar
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'GUARDAR CAMBIOS',
                  onPressed: _saveChanges,
                  isLoading: _isSaving,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInputCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 2),
                Text(
                  value, 
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 14, color: Colors.grey[300]),
        ],
      ),
    );
  }
}
