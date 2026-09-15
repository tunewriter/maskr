import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/providers.dart';
import '../domain/models.dart';
import 'theme.dart';
import 'toast_banner.dart';

/// Name given to freshly created profiles until the user saves them.
const kUntitledProfileName = 'Untitled';

/// Bar above the rule list: one dropdown holding all profile management,
/// plus buttons to create a new profile and save into the selected one.
class ProfileBar extends ConsumerWidget {
  const ProfileBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final selectedProfileId = ref.watch(selectedProfileIdProvider);

    // Keep selection valid when profiles change.
    final validSelectedId = profiles.any((p) => p.id == selectedProfileId)
        ? selectedProfileId
        : null;
    final selectedProfile = validSelectedId == null
        ? null
        : profiles.where((p) => p.id == validSelectedId).first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: slide,
                    child: child,
                  ),
                );
              },
              child: _ProfileDropdown(
                key: ValueKey(validSelectedId),
                profiles: profiles,
                selectedProfileId: validSelectedId,
                onSelect: (profile) => _loadProfile(context, ref, profile),
                onDuplicate: (profile) => _closeMenuAndRun(context, () {
                  ref
                      .read(profilesProvider.notifier)
                      .duplicateProfile(profile.id);
                }),
                onRename: (profile) => _closeMenuAndRun(
                    context, () => _renameDialog(context, profile)),
                onDelete: (profile) => _closeMenuAndRun(
                    context, () => _confirmDelete(context, ref, profile)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'New empty profile (clears current rules)',
            icon: const Icon(Icons.note_add_outlined, size: 18),
            hoverColor: const Color(0x0FFFFFFF),
            visualDensity: VisualDensity.compact,
            onPressed: () => _newProfile(context, ref),
          ),
          IconButton(
            tooltip: validSelectedId == null
                ? 'Select a profile to overwrite it'
                : selectedProfile?.name == kUntitledProfileName
                    ? 'Name and save current rules to this profile'
                    : 'Save current rules to selected profile',
            icon: const Icon(Icons.save_outlined, size: 18),
            hoverColor: const Color(0x0FFFFFFF),
            visualDensity: VisualDensity.compact,
            onPressed: validSelectedId == null
                ? null
                : () => _saveToSelected(context, ref),
          ),
        ],
      ),
    );
  }

  void _closeMenuAndRun(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop(); // close the profile menu
    action();
  }

  /// Deletes an untitled profile that was never given a name and never
  /// got any rules — i.e. it holds nothing worth keeping.
  void _cleanupEmptyUntitled(WidgetRef ref, {required String? exceptId}) {
    final selectedId = ref.read(selectedProfileIdProvider);
    if (selectedId == null || selectedId == exceptId) return;
    final current =
        ref.read(profilesProvider).where((p) => p.id == selectedId).firstOrNull;
    if (current != null &&
        current.name == kUntitledProfileName &&
        current.rules.isEmpty) {
      ref.read(profilesProvider.notifier).deleteProfile(current.id);
    }
  }

  void _loadProfile(BuildContext context, WidgetRef ref, Profile profile) {
    final currentRules = ref.read(rulesProvider);
    final selectedId = ref.read(selectedProfileIdProvider);
    final selected = selectedId == null
        ? null
        : ref
            .read(profilesProvider)
            .where((p) => p.id == selectedId)
            .firstOrNull;

    // Clicking the already-selected profile does nothing.
    if (selected?.id == profile.id) return;

    final hasChanges =
        selected == null || !_rulesEqual(selected.rules, currentRules);

    void doLoad() {
      _cleanupEmptyUntitled(ref, exceptId: profile.id);
      ref.read(rulesProvider.notifier).loadRules(profile.rules);
      ref.read(selectedProfileIdProvider.notifier).select(profile.id);
    }

    // NOTE: no Navigator.pop here — PopupMenuButton already closed the
    // menu before onSelected fired; popping again would close the app.

    if (hasChanges && currentRules.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Load profile?',
              style: AppTextStyles.ui(16, weight: FontWeight.w600)),
          content: Text(
            'Your current rules will be replaced by "${profile.name}".',
            style: AppTextStyles.ui(13, color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                doLoad();
              },
              child: const Text('Load'),
            ),
          ],
        ),
      );
    } else {
      doLoad();
    }
  }

  bool _rulesEqual(List<Rule> a, List<Rule> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.pattern != y.pattern ||
          x.replacement != y.replacement ||
          x.enabled != y.enabled ||
          x.caseSensitive != y.caseSensitive ||
          x.wholeWord != y.wholeWord ||
          x.colorIndex != y.colorIndex) {
        return false;
      }
    }
    return true;
  }

  /// Creates a new untitled empty profile immediately (no name prompt).
  /// The name is asked when the user first saves into it.
  Future<void> _newProfile(BuildContext context, WidgetRef ref) async {
    void create() {
      // Drop a previously created, still-empty untitled profile.
      _cleanupEmptyUntitled(ref, exceptId: null);
      ref
          .read(profilesProvider.notifier)
          .saveAsProfile(kUntitledProfileName, []);
      ref.read(rulesProvider.notifier).clearAll();
      final profiles = ref.read(profilesProvider);
      final created = profiles
          .where((p) => p.name.startsWith(kUntitledProfileName))
          .lastOrNull;
      ref.read(selectedProfileIdProvider.notifier).select(created?.id);
    }

    // Only warn if the current rules differ from the loaded profile,
    // i.e. there are actually unsaved changes that would be lost.
    final selectedId = ref.read(selectedProfileIdProvider);
    final selected = selectedId == null
        ? null
        : ref
            .read(profilesProvider)
            .where((p) => p.id == selectedId)
            .firstOrNull;
    final hasUnsavedChanges = ref.read(rulesProvider).isNotEmpty &&
        (selected == null ||
            !_rulesEqual(selected.rules, ref.read(rulesProvider)));

    if (hasUnsavedChanges) {
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('New profile?',
              style: AppTextStyles.ui(16, weight: FontWeight.w600)),
          content: Text(
            'Your current rules will be cleared. Save them to a profile first if you want to keep them.',
            style: AppTextStyles.ui(13, color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                create();
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } else {
      create();
    }
  }

  /// Saves current rules into the selected profile. If the profile is still
  /// untitled, ask for a name first.
  Future<void> _saveToSelected(BuildContext context, WidgetRef ref) async {
    final selectedId = ref.read(selectedProfileIdProvider);
    if (selectedId == null) return;
    final profile =
        ref.read(profilesProvider).where((p) => p.id == selectedId).firstOrNull;
    if (profile == null) return;

    if (profile.name != kUntitledProfileName) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Save to "${profile.name}"?',
              style: AppTextStyles.ui(16, weight: FontWeight.w600)),
          content: Text(
            'The ${ref.read(rulesProvider).length} current rules will replace the existing content of this profile.',
            style: AppTextStyles.ui(13, color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      ref
          .read(profilesProvider.notifier)
          .overwriteProfile(profile.id, ref.read(rulesProvider));
      _showSavedSnackBar(context, profile.name);
      return;
    }

    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Name this profile',
            style: AppTextStyles.ui(16, weight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTextStyles.ui(14),
          decoration: const InputDecoration(hintText: 'Profile name'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    ref.read(profilesProvider.notifier).renameProfile(profile.id, name.trim());
    ref
        .read(profilesProvider.notifier)
        .overwriteProfile(profile.id, ref.read(rulesProvider));
    if (context.mounted) _showSavedSnackBar(context, name.trim());
  }

  void _showSavedSnackBar(BuildContext context, String profileName) {
    showToast(context, 'Saved to "$profileName"');
  }

  /// Creates a new untitled empty profile immediately (no name prompt).
  Future<void> _renameDialog(BuildContext context, Profile profile) async {
    final controller = TextEditingController(text: profile.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Rename profile',
            style: AppTextStyles.ui(16, weight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTextStyles.ui(14),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    _renameProfile(context, profile.id, name);
  }

  void _renameProfile(BuildContext context, String profileId, String name) {
    ProviderScope.containerOf(context, listen: false)
        .read(profilesProvider.notifier)
        .renameProfile(profileId, name);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Profile profile) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete profile?',
            style: AppTextStyles.ui(16, weight: FontWeight.w600)),
        content: Text(
          '"${profile.name}" (${profile.rules.length} rules) will be deleted permanently.',
          style: AppTextStyles.ui(13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE57373),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(profilesProvider.notifier).deleteProfile(profile.id);
              if (ref.read(selectedProfileIdProvider) == profile.id) {
                ref.read(selectedProfileIdProvider.notifier).select(null);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// The dropdown field + its popup menu (profile list with hover actions).
class _ProfileDropdown extends StatelessWidget {
  final List<Profile> profiles;
  final String? selectedProfileId;
  final ValueChanged<Profile> onSelect;
  final ValueChanged<Profile> onDuplicate;
  final ValueChanged<Profile> onRename;
  final ValueChanged<Profile> onDelete;

  const _ProfileDropdown({
    super.key,
    required this.profiles,
    required this.selectedProfileId,
    required this.onSelect,
    required this.onDuplicate,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final selected =
        profiles.where((p) => p.id == selectedProfileId).firstOrNull;

    return PopupMenuButton<Profile>(
      tooltip: 'Profiles',
      color: AppColors.canvas,
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
      onSelected: onSelect,
      itemBuilder: (menuContext) => [
        for (final p in profiles)
          PopupMenuItem<Profile>(
            value: p,
            child: _ProfileMenuRow(
              profile: p,
              isSelected: p.id == selectedProfileId,
              onDuplicate: () => onDuplicate(p),
              onRename: () => onRename(p),
              onDelete: () => onDelete(p),
            ),
          ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          border: Border.all(color: AppColors.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_outlined,
                size: 16,
                color: selected != null ? AppColors.primary : AppColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected?.name ??
                    (profiles.isEmpty ? 'No profiles' : 'Select profile…'),
                style: AppTextStyles.ui(13,
                    color: selected != null ? AppColors.text : AppColors.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// A single profile row in the menu; shows per-profile hover actions.
class _ProfileMenuRow extends StatefulWidget {
  final Profile profile;
  final bool isSelected;
  final VoidCallback onDuplicate;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ProfileMenuRow({
    required this.profile,
    required this.isSelected,
    required this.onDuplicate,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_ProfileMenuRow> createState() => _ProfileMenuRowState();
}

class _ProfileMenuRowState extends State<_ProfileMenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        children: [
          Icon(
            widget.isSelected ? Icons.check : Icons.folder_outlined,
            size: 16,
            color: AppColors.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              p.name,
              style: AppTextStyles.ui(
                13,
                color: widget.isSelected ? AppColors.muted : AppColors.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_hovered)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _rowAction(
                  icon: Icons.copy,
                  tooltip: 'Duplicate',
                  color: AppColors.primary,
                  onTap: widget.onDuplicate,
                ),
                _rowAction(
                  icon: Icons.edit_outlined,
                  tooltip: 'Rename',
                  color: AppColors.success,
                  onTap: widget.onRename,
                ),
                _rowAction(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  color: const Color(0xFFE85D75),
                  onTap: widget.onDelete,
                ),
              ],
            )
          else
            Text(
              '(${p.rules.length})',
              style: AppTextStyles.ui(12, color: AppColors.muted),
            ),
        ],
      ),
    );
  }

  Widget _rowAction({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: color.withValues(alpha: 0.18),
        child: _HoverColorIcon(icon: icon, color: color),
      ),
    );
  }
}

/// Icon that is grey until hovered, then takes on its accent color.
class _HoverColorIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _HoverColorIcon({required this.icon, required this.color});

  @override
  State<_HoverColorIcon> createState() => _HoverColorIconState();
}

class _HoverColorIconState extends State<_HoverColorIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(
          widget.icon,
          size: 16,
          color: _hovered ? widget.color : AppColors.muted,
        ),
      ),
    );
  }
}
