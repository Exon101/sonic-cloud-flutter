import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/api_auth_service.dart';
import '../services/api_client.dart';
import '../services/vercel_sync_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart' as r;
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/glass_card.dart';
import '../widgets/top_app_bar.dart';

/// Settings screen.
///
/// Sections (per the HTML mockup):
///   1. Profile card (avatar, name, tier, edit) — now driven by [auth]
///   2. Connections group → Cloud Accounts, Server URL, Devices
///   3. Playback group → Audio Quality, Offline Mode toggle, Sync Now
///   4. Log Out button — wired to [auth.signOut]
class SettingsScreen extends StatefulWidget {
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenPlayer;
  final VoidCallback onOpenCloud;
  final ApiAuthService auth;
  final VercelSyncService sync;
  final ApiClient client;

  const SettingsScreen({
    super.key,
    required this.onOpenLibrary,
    required this.onOpenPlayer,
    required this.onOpenCloud,
    required this.auth,
    required this.sync,
    required this.client,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _offlineMode = false;
  List<DeviceInfo> _devices = [];
  bool _loadingDevices = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChange);
    widget.sync.addListener(_onSyncChange);
    _refreshDevices();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChange);
    widget.sync.removeListener(_onSyncChange);
    super.dispose();
  }

  void _onAuthChange() {
    if (mounted) setState(() {});
  }

  void _onSyncChange() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshDevices() async {
    setState(() => _loadingDevices = true);
    try {
      _devices = await widget.sync.listDevices();
    } catch (e) {
      _statusMessage = 'Could not load devices: $e';
    } finally {
      if (mounted) setState(() => _loadingDevices = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _statusMessage = 'Syncing…');
    try {
      await widget.sync.fullSync();
      setState(() => _statusMessage = 'Sync complete');
    } catch (e) {
      setState(() => _statusMessage = 'Sync failed: $e');
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Sign out?', style: TextStyle(color: AppColors.onSurface)),
        content: const Text(
          'Your local library and playlists remain on this device. '
          'Cloud sync will pause until you sign in again.',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.auth.signOut();
    }
  }

  Future<void> _editServerUrl() async {
    final ctrl = TextEditingController(text: widget.client.baseUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Server URL', style: TextStyle(color: AppColors.onSurface)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'https://your-host.com',
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          style: const TextStyle(color: AppColors.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) {
      await widget.auth.setBaseUrl(url);
      setState(() => _statusMessage = 'Server set to $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.currentUser;
    final displayName = user?.name.isNotEmpty == true
        ? user!.name
        : (user?.email.isNotEmpty == true ? user!.email : 'Sonic Cloud User');
    final displayTier = user?.isAnonymous == true ? 'Guest' : (user?.tier.isNotEmpty == true ? user!.tier : 'Signed in');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SonicTopAppBar(avatarUrl: MockData.userProfile.avatarUrl),
      body: SafeArea(
        minimum: const EdgeInsets.only(top: 16),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.edgeMargin,
            8,
            AppSpacing.edgeMargin,
            120,
          ),
          children: [
            Text(
              'Settings',
              style: AppTypography.headlineXl.copyWith(color: AppColors.onSurface),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Profile
            _ProfileCard(
              displayName: displayName,
              tier: displayTier,
              email: user?.email ?? '',
              isAnonymous: user?.isAnonymous ?? false,
            ),
            const SizedBox(height: AppSpacing.md),

            // Sync status banner
            if (_statusMessage != null) ...[
              _StatusBanner(message: _statusMessage!),
              const SizedBox(height: AppSpacing.md),
            ],

            // Connections group
            _SettingsGroup(
              heading: 'Connections',
              children: [
                _SettingsTile(
                  icon: Icons.dns_rounded,
                  title: 'Server URL',
                  subtitle: widget.client.baseUrl,
                  onTap: _editServerUrl,
                ),
                _SettingsTile(
                  icon: Icons.cloud_sync_rounded,
                  title: 'Cloud Accounts',
                  subtitle: 'Link or unlink external drives',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.devices_rounded,
                  title: 'Devices',
                  subtitle: _loadingDevices
                      ? 'Loading…'
                      : _devices.isEmpty
                          ? 'No other active sessions'
                          : '${_devices.length} active session${_devices.length == 1 ? '' : 's'}',
                  onTap: () => _showDevicesSheet(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Playback group
            _SettingsGroup(
              heading: 'Playback',
              children: [
                _SettingsTile(
                  icon: Icons.graphic_eq_rounded,
                  title: 'Audio Quality',
                  subtitle: 'High (Lossless)',
                  subtitleColor: AppColors.secondaryContainer,
                  onTap: () {},
                ),
                _ToggleTile(
                  icon: Icons.offline_pin_rounded,
                  title: 'Offline Mode',
                  subtitle: 'Play downloaded tracks only',
                  value: _offlineMode,
                  onChanged: (v) => setState(() => _offlineMode = v),
                ),
                _SettingsTile(
                  icon: Icons.sync_rounded,
                  title: 'Sync Now',
                  subtitle: _syncStatusLabel(),
                  subtitleColor: AppColors.secondaryContainer,
                  onTap: _syncNow,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Log out
            TextButton(
              onPressed: _signOut,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.AppRadius.lg),
                ),
              ),
              child: Text(
                'Log Out',
                style: AppTypography.labelMd.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SonicBottomNavBar(
        currentIndex: 3,
        onTap: (i) {
          if (i == 0) widget.onOpenLibrary();
          if (i == 1) widget.onOpenPlayer();
          if (i == 2) widget.onOpenCloud();
        },
      ),
    );
  }

  String _syncStatusLabel() {
    switch (widget.sync.state) {
      case SyncState.idle:
        return 'Up to date';
      case SyncState.syncing:
        return 'Syncing…';
      case SyncState.success:
        return 'Last sync OK';
      case SyncState.error:
        return 'Sync error';
      case SyncState.offline:
        return 'Offline';
    }
  }

  void _showDevicesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.AppRadius.xl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Sessions',
                      style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppColors.onSurfaceVariant),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _refreshDevices();
                      },
                    ),
                  ],
                ),
              ),
              if (_devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'No other active sessions.\nThis is the only device signed in.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                )
              else
                ..._devices.map((d) => ListTile(
                      leading: const Icon(Icons.devices_other, color: AppColors.secondaryContainer),
                      title: Text(d.name, style: const TextStyle(color: AppColors.onSurface)),
                      subtitle: Text(
                        'Last seen ${d.lastSeen.toLocal()}',
                        style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          await widget.sync.revokeDevice(d.id);
                          Navigator.pop(ctx);
                          _refreshDevices();
                        },
                        child: Text('Revoke', style: TextStyle(color: AppColors.error)),
                      ),
                    )),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status banner (transient feedback)
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final String message;
  const _StatusBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withOpacity(0.10),
        borderRadius: BorderRadius.circular(r.AppRadius.lg),
        border: Border.all(color: AppColors.secondaryContainer.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.secondaryContainer, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.labelMd.copyWith(color: AppColors.secondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile card
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final String displayName;
  final String tier;
  final String email;
  final bool isAnonymous;

  const _ProfileCard({
    required this.displayName,
    required this.tier,
    required this.email,
    required this.isAnonymous,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              gradient: const RadialGradient(
                colors: [AppColors.secondaryContainer, AppColors.primaryContainer],
              ),
            ),
            child: Icon(
              isAnonymous ? Icons.person_outline : Icons.person,
              color: AppColors.surface,
              size: 32,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email.isEmpty ? tier : '$tier · $email',
                  style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            isAnonymous ? Icons.lock_outline : Icons.verified_user_outlined,
            color: AppColors.secondaryContainer,
            size: 22,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings group (heading + card containing tiles)
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsGroup extends StatelessWidget {
  final String heading;
  final List<Widget> children;

  const _SettingsGroup({required this.heading, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Text(
            heading.toUpperCase(),
            style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 4),
        GlassCard(padding: EdgeInsets.zero, child: Column(children: children)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings tile (tap → chevron)
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.labelSm.copyWith(
                        color: subtitleColor ?? AppColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle tile
// ─────────────────────────────────────────────────────────────────────────────
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
                ),
                Text(
                  subtitle,
                  style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _SettingsToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value
              ? AppColors.secondaryContainer.withOpacity(0.20)
              : AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(r.AppRadius.full),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? AppColors.secondaryContainer : AppColors.onSurfaceVariant,
              shape: BoxShape.circle,
              boxShadow: value
                  ? [BoxShadow(color: AppColors.sonicGlow.withOpacity(0.5), blurRadius: 8)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
