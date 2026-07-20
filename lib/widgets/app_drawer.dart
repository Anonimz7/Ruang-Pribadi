import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/app_registry.dart';

/// App-aware sidebar drawer
class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final ApiClient client;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.client,
    required this.onLogout,
  });

  bool _isAccessible(AppDef app) {
    // system (settings, profile) = selalu bisa
    if (app.section == 'system') return true;
    // Hidden menus = owner has hidden this from the user
    if (client.isMenuHidden(app.key)) return false;
    // admin section = owner only
    if (app.section == 'admin') return client.tier == 'owner';
    // sisanya = butuh login + permission
    if (!client.isLoggedIn) return false;
    return client.canAccess(app.key);
  }

  bool _isHidden(AppDef app) {
    // System menus are never hidden
    if (app.section == 'system') return false;
    return client.isMenuHidden(app.key);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group apps by section
    final systemApps = appRegistry.where((a) => a.section == 'system').toList();
    final menuApps = appRegistry.where((a) => a.section == 'menu').toList();
    final marketApps = appRegistry.where((a) => a.section == 'market').toList();
    final adminApps = appRegistry.where((a) => a.section == 'admin').toList();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ─── Header ───────────────────────────
          DrawerHeader(
            decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B263B) : Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Menu Navigasi',
                    style: TextStyle(color: Colors.white, fontSize: 24)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(client.isLoggedIn ? Icons.check_circle : Icons.login,
                        color: client.isLoggedIn
                            ? const Color(0xFF00C87A)
                            : Colors.white70,
                        size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        client.isLoggedIn
                            ? '${client.username} (${client.tier})'
                            : 'Belum login — akses terbatas',
                        style: TextStyle(
                            color: client.isLoggedIn
                                ? const Color(0xFF00C87A)
                                : Colors.white70,
                            fontSize: 12),
                      ),
                    ),
                    if (client.isLoggedIn)
                      GestureDetector(
                          onTap: onLogout,
                          child: const Text('Logout',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12))),
                  ],
                ),
              ],
            ),
          ),

          // ─── System (selalu tampil) ───────────
          ...systemApps.map((app) => _tile(context, app, locked: false)),

          const Divider(),

          // ─── Fitur Lokal ─────────────────────
          _sectionHeader('FITUR', locked: !client.isLoggedIn),
          ...menuApps
              .where((app) => !_isHidden(app))
              .map((app) => _tile(context, app, locked: !_isAccessible(app))),

          const Divider(),

          // ─── AI Radar ─────────────────────────
          _sectionHeader('AI RADAR', locked: !client.isLoggedIn),
          ...marketApps
              .where((app) => !_isHidden(app))
              .map((app) => _tile(context, app, locked: !_isAccessible(app))),

          // ─── Admin ───────────────────────────
          if (client.tier == 'owner') ...[
            const Divider(),
            const _SectionLabel('ADMIN'),
            ...adminApps.map((app) => _tile(context, app, locked: false)),
          ],
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, AppDef app, {required bool locked}) {
    final idx = appRegistry.indexOf(app);
    final isSelected = selectedIndex == idx;

    return ListTile(
      leading: Icon(app.icon, color: locked ? Colors.grey : null),
      title: Row(
        children: [
          Flexible(
              child: Text(app.label,
                  style: TextStyle(
                      color: locked ? Colors.grey : null, fontSize: 14))),
          if (locked)
            const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.lock_outline, size: 14, color: Colors.grey)),
        ],
      ),
      selected: isSelected,
      onTap: () => onItemTapped(idx),
    );
  }

  Widget _sectionHeader(String text, {bool locked = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.5)),
          if (locked) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4)),
              child: const Text('LOGIN',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.5)),
    );
  }
}
