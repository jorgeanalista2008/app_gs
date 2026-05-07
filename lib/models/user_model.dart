class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String tenantId;
  final String companyId;
  final String branchId;
  final RoleModel role;
  final List<MenuModel> menus;
  final Map<String, ModuleAccess> moduleAccess;
  final List<PermissionModel> permissions;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.tenantId,
    required this.companyId,
    required this.branchId,
    required this.role,
    required this.menus,
    required this.moduleAccess,
    required this.permissions,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      companyId: json['company_id'] ?? '',
      branchId: json['branch_id'] ?? '',
      role: RoleModel.fromJson(json['role'] ?? {}),
      menus: json['menus'] != null 
          ? (json['menus'] as List).map((m) => MenuModel.fromJson(m)).toList() 
          : [],
      moduleAccess: json['module_access'] != null
          ? (json['module_access'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, ModuleAccess.fromJson(v)),
            )
          : {},
      permissions: json['permissions'] != null
          ? (json['permissions'] as List)
              .map((p) => PermissionModel.fromJson(p))
              .toList()
          : [],
    );
  }
}

class RoleModel {
  final String id;
  final String name;

  RoleModel({required this.id, required this.name});

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class MenuModel {
  final String id;
  final String? parentId;
  final String label;
  final String icon;
  final String route;
  final int sortOrder;
  final bool visible;
  final List<MenuModel> children;

  MenuModel({
    required this.id,
    this.parentId,
    required this.label,
    required this.icon,
    required this.route,
    required this.sortOrder,
    required this.visible,
    required this.children,
  });

  factory MenuModel.fromJson(Map<String, dynamic> json) {
    return MenuModel(
      id: json['id'] ?? '',
      parentId: json['parent_id'],
      label: json['label'] ?? '',
      icon: json['icon'] ?? '',
      route: json['route'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      visible: json['visible'] ?? true,
      children: json['children'] != null
          ? (json['children'] as List)
              .map((c) => MenuModel.fromJson(c))
              .toList()
          : [],
    );
  }
}

class ModuleAccess {
  final bool read;
  final bool write;
  final bool delete;
  final List<String> permissionCodes;

  ModuleAccess({
    required this.read,
    required this.write,
    required this.delete,
    required this.permissionCodes,
  });

  factory ModuleAccess.fromJson(Map<String, dynamic> json) {
    return ModuleAccess(
      read: json['read'] ?? false,
      write: json['write'] ?? false,
      delete: json['delete'] ?? false,
      permissionCodes: json['permission_codes'] != null
          ? List<String>.from(json['permission_codes'])
          : [],
    );
  }
}

class PermissionModel {
  final String permissionCode;
  final String module;
  final bool canRead;
  final bool canWrite;
  final bool canDelete;

  PermissionModel({
    required this.permissionCode,
    required this.module,
    required this.canRead,
    required this.canWrite,
    required this.canDelete,
  });

  factory PermissionModel.fromJson(Map<String, dynamic> json) {
    return PermissionModel(
      permissionCode: json['permission_code'] ?? '',
      module: json['module'] ?? '',
      canRead: json['can_read'] ?? false,
      canWrite: json['can_write'] ?? false,
      canDelete: json['can_delete'] ?? false,
    );
  }
}