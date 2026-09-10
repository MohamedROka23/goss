import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class AdminTeamTab extends StatefulWidget {
  const AdminTeamTab({super.key});

  @override
  State<AdminTeamTab> createState() => _AdminTeamTabState();
}

class _AdminTeamTabState extends State<AdminTeamTab> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = AdminRole.admin;
  Set<String> _perms = {};
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _perms = defaultPermissionsFor(_role).toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppProvider>();
      if (app.token != null) app.loadAdmins();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _setRole(String role) {
    setState(() {
      _role = role;
      _perms = defaultPermissionsFor(role).toSet();
    });
  }

  /// Permission toggles shown in the add form (team is granted to admins only).
  List<Widget> _permissionTiles(bool en, Set<String> perms) {
    return allPermissionKeys
        .where((p) => p != AdminPerms.team)
        .map((p) => CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              value: perms.contains(p),
              onChanged: (v) => setState(() {
                if (v == true) {
                  perms.add(p);
                } else {
                  perms.remove(p);
                }
              }),
              title: Text(
                permissionLabel(p, ar: !en),
                style: const TextStyle(fontSize: 14),
              ),
            ))
        .toList();
  }

  /// Dialog to review/change a member's role and permissions (admins with team
  /// can manage everyone except the owner and super admins).
  Future<void> _manageMember(BuildContext context, AppProvider app, bool en, AdminUser member) async {
    String role = member.role == AdminRole.super_ ? AdminRole.super_ : member.role;
    final perms = member.permissions.isNotEmpty
        ? member.permissions.toSet()
        : defaultPermissionsFor(member.role).toSet();
    final allowedRoles = member.role == AdminRole.super_ ? [AdminRole.super_] : [AdminRole.admin, AdminRole.delegate];

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('${member.name} — ${en ? 'Permissions' : 'الصلاحيات'}'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (allowedRoles.length > 1) ...[
                    Text(en ? 'Role' : 'الدور', style: const TextStyle(fontWeight: FontWeight.w700)),
                    SegmentedButton<String>(
                      segments: allowedRoles
                          .map((r) => ButtonSegment(value: r, label: Text(adminRoleLabel(r, ar: !en))))
                          .toList(),
                      selected: {role},
                      onSelectionChanged: (s) {
                        setSt(() {
                          role = s.first;
                          perms
                            ..clear()
                            ..addAll(defaultPermissionsFor(role));
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ] else
                    Text(
                      adminRoleLabel(role, ar: !en),
                      style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor),
                    ),
                  const Divider(),
                  Text(en ? 'Panels this member can open' : 'الأقسام المتاح لهذا العضو فتحها', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ...allPermissionKeys.map((p) {
                    final locked = role == AdminRole.super_ || p == AdminPerms.team;
                    if (locked) return const SizedBox.shrink();
                    return CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      value: perms.contains(p),
                      onChanged: role == AdminRole.super_
                          ? null
                          : (v) => setSt(() {
                                if (v == true) {
                                  perms.add(p);
                                } else {
                                  perms.remove(p);
                                }
                              }),
                      title: Text(permissionLabel(p, ar: !en), style: const TextStyle(fontSize: 14)),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(en ? 'Cancel' : 'إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(en ? 'Save' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final err = await app.updateAdminRoleAndPermissions(
      adminId: member.id,
      role: role == member.role ? null : role,
      permissions: member.role == AdminRole.super_ ? null : perms.toList(),
    );
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err.isEmpty
          ? (en ? 'Permissions updated.' : 'تم تحديث الصلاحيات.')
          : err),
      backgroundColor: err.isEmpty ? GossColors.green : GossColors.red,
    ));
  }

  Future<void> _removeMember(BuildContext context, AppProvider app, bool en, AdminUser member) async {
    if (member.role == AdminRole.super_ || member.id == 'u-admin') return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(en ? 'Remove member' : 'إزالة العضو'),
        content: Text(en
            ? 'Remove ${member.name} (${member.email}) from the team? They will no longer be able to sign in.'
            : 'إزالة ${member.name} (${member.email}) من الفريق؟ لن يتمكن من تسجيل الدخول بعد ذلك.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(en ? 'Cancel' : 'إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: GossColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(en ? 'Remove' : 'إزالة'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await app.deleteAdmin(member.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err.isEmpty
          ? (en ? '${member.name} removed from the team.' : 'تمت إزالة ${member.name} من الفريق.')
          : err),
      backgroundColor: err.isEmpty ? GossColors.green : GossColors.red,
    ));
  }

  Future<void> _submit(AppProvider app, bool en) async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (name.isEmpty || email.isEmpty || password.length < 6) {
      setState(() {
        _loading = false;
        _error = en ? 'Enter full name, email and a password of at least 6 characters.' : 'أدخل الاسم الكامل والبريد وكلمة مرور من 6 أحرف على الأقل.';
      });
      return;
    }
    final err = await app.addAdmin(
      name: name,
      email: email,
      password: password,
      role: _role,
      permissions: _perms.toList(),
    );
    if (!mounted) return;
    setState(() { _loading = false; });
    if (err.isNotEmpty) {
      setState(() => _error = err);
    } else {
      _nameCtrl.clear();
      _emailCtrl.clear();
      _passwordCtrl.clear();
      setState(() => _success = en
          ? '${adminRoleLabel(_role, ar: false)} added to the team.'
          : 'تمت إضافة ${adminRoleLabel(_role, ar: true)} إلى الفريق.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final en = !app.isArabic;
    final canManageTeam = app.can(AdminPerms.team);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                en ? 'Team & permissions' : 'الفريق والصلاحيات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.headingColor),
              ),
            ),
            if (!canManageTeam)
              RequestStatusChip(status: app.permissions.isEmpty ? RequestStatus.fresh : RequestStatus.accepted, isArabic: !en),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          en
              ? 'Add admins or delegates and choose exactly which panels each one can open.'
              : 'أضف مسؤولين أو مندوبين وحدد بدقة الأقسام التي يمكن لكل عضو فتحها.',
          style: TextStyle(color: context.mutedColor, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (!canManageTeam) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: GossColors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      en
                          ? 'Only members with the team panel can manage members and permissions.'
                          : 'فقط الأعضاء الذين يملكون قسم الفريق يمكنهم إدارة الأعضاء والصلاحيات.',
                      style: TextStyle(color: context.mutedColor, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    en ? 'Add team member' : 'إضافة عضو جديد',
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: en ? 'Full name' : 'الاسم الكامل',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: en ? 'Email address' : 'البريد الإلكتروني',
                      prefixIcon: const Icon(Icons.mail_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: en ? 'Password' : 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    en ? 'Role' : 'الدور',
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: AdminRole.admin, label: Text(en ? 'Admin' : 'مسؤول')),
                      ButtonSegment(value: AdminRole.delegate, label: Text(en ? 'Delegate' : 'مندوب')),
                    ],
                    selected: {_role},
                    onSelectionChanged: (s) => _setRole(s.first),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    en
                        ? 'Roles default to the recommended panels below — change them freely per member.'
                        : 'الأدوار تبدأ بالأقسام الموصى بها أدناه — ويمكنك تعديلها لكل عضو بحرية.',
                    style: TextStyle(color: context.mutedColor, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    en ? 'Accessible panels' : 'الأقسام المتاحة',
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.headingColor),
                  ),
                  ..._permissionTiles(en, _perms),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: GossButton(
                      label: en ? 'Add member' : 'إضافة العضو',
                      color: GossColors.blue,
                      icon: Icons.person_add_alt,
                      onPressed: _loading ? null : () => _submit(app, en),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: GossColors.red, fontSize: 13)),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 10),
                    Text(_success!, style: const TextStyle(color: GossColors.green, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          en ? 'Team members' : 'أعضاء الفريق',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: context.headingColor),
        ),
        const SizedBox(height: 8),
        if (app.admins.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              en ? 'No members yet.' : 'لا يوجد أعضاء بعد.',
              style: TextStyle(color: context.mutedColor, fontSize: 13),
            ),
          )
        else
          ...app.admins.map((a) {
            final isSelf = a.id == app.currentAdmin?.id && app.currentAdmin != null;
            final roleColor = a.role == AdminRole.super_
                ? GossColors.red
                : a.role == AdminRole.delegate
                    ? GossColors.green
                    : GossColors.blue;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: roleColor.withValues(alpha: 0.12),
                  child: Text(
                    a.name.isNotEmpty ? a.name[0].toUpperCase() : 'A',
                    style: TextStyle(color: roleColor, fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${a.email}  ·  ${a.permissions.length} ${en ? 'panels' : 'أقسام'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        adminRoleLabel(a.role, ar: !en),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: roleColor,
                        ),
                      ),
                    ),
                    if (canManageTeam && !isSelf) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: en ? 'Manage permissions' : 'إدارة الصلاحيات',
                        icon: const Icon(Icons.tune, size: 20),
                        onPressed: () => _manageMember(context, app, en, a),
                      ),
                    ],
                    if (canManageTeam &&
                        !isSelf &&
                        a.role != AdminRole.super_ &&
                        a.id != 'u-admin') ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: en ? 'Remove member' : 'إزالة العضو',
                        icon: const Icon(Icons.delete_outline, size: 20, color: GossColors.red),
                        onPressed: () => _removeMember(context, app, en, a),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}