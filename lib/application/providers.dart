import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models.dart';
import '../domain/replace_engine.dart';

final rawInputProvider = StateProvider<String>((ref) => '');
final debouncedInputProvider = StateProvider<String>((ref) => '');

/// Directory where rules, profiles, and the selected profile are persisted.
/// Defaults to the user's home directory; tests override it so they never
/// read or write real user data.
final storageDirProvider = Provider<String>((ref) {
  return Platform.environment['HOME'] ?? Directory.current.path;
});

class RulesNotifier extends StateNotifier<List<Rule>> {
  RulesNotifier(this._storageDir) : super([]) {
    _load(); // load saved rules at startup
  }

  final String _storageDir;

  int _nextId = 0;

  // Rule ids in their "natural" order (before match-count sorting).
  // Captured on every mutation except reorderByMatchCounts itself.
  List<String>? _originalOrder;
  bool _reordering = false;

  @override
  set state(List<Rule> value) {
    if (_reordering) {
      super.state = value;
    } else {
      _originalOrder = value.map((r) => r.id).toList();
      super.state = value;
    }
  }

  String _generateId() => 'rule_${_nextId++}';

  // Stored as <storageDir>/.masktext_rules.json
  String get _storageFile => '$_storageDir/.masktext_rules.json';

  void _load() {
    try {
      final file = File(_storageFile);
      if (!file.existsSync()) return;
      final data = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      final loaded =
          data.map((e) => Rule.fromJson(e as Map<String, dynamic>)).toList();
      state = loaded;
      // Update _nextId to avoid ID collisions
      for (final rule in loaded) {
        final idNum = int.tryParse(rule.id.replaceFirst('rule_', ''));
        if (idNum != null && idNum >= _nextId) _nextId = idNum + 1;
      }
    } catch (_) {
      // If load fails, start empty
    }
  }

  void _save() {
    try {
      final data = state.map((r) => r.toJson()).toList();
      File(_storageFile).writeAsStringSync(jsonEncode(data));
    } catch (_) {
      // Ignore save errors
    }
  }

  void addRule() {
    state = [
      ...state,
      Rule(
        id: _generateId(),
        pattern: '',
        replacement: '',
        enabled: true,
        caseSensitive: false,
        wholeWord: true,
        colorIndex: state.length % 10,
      ),
    ];
    _save();
  }

  void updatePattern(String id, String pattern) {
    state = state
        .map((r) => r.id == id ? _copyWith(r, pattern: pattern) : r)
        .toList();
    _save();
  }

  void updateReplacement(String id, String replacement) {
    state = state
        .map((r) => r.id == id ? _copyWith(r, replacement: replacement) : r)
        .toList();
    _save();
  }

  void toggleEnabled(String id) {
    state = state
        .map((r) => r.id == id ? _copyWith(r, enabled: !r.enabled) : r)
        .toList();
    _save();
  }

  void toggleCaseSensitive(String id) {
    state = state
        .map((r) =>
            r.id == id ? _copyWith(r, caseSensitive: !r.caseSensitive) : r)
        .toList();
    _save();
  }

  void toggleWholeWord(String id) {
    state = state
        .map((r) => r.id == id ? _copyWith(r, wholeWord: !r.wholeWord) : r)
        .toList();
    _save();
  }

  void deleteRule(String id) {
    state = state.where((r) => r.id != id).toList();
    _save();
  }

  void clearAll() {
    state = [];
    _save();
  }

  /// Sort rules by match count (descending) after text was pasted/edited.
  /// Rules with zero matches keep their original relative order (stable).
  /// When no rule matched at all (e.g. input cleared), the original order
  /// from before the last count-based sort is restored.
  void reorderByMatchCounts(Map<String, int> counts) {
    final totalMatches = counts.values.fold<int>(0, (sum, c) => sum + c);
    List<Rule> sorted;
    if (totalMatches == 0 && _originalOrder != null) {
      final positions = {
        for (var i = 0; i < _originalOrder!.length; i++) _originalOrder![i]: i,
      };
      sorted = [...state]..sort((a, b) {
          final pa = positions[a.id] ?? _originalOrder!.length;
          final pb = positions[b.id] ?? _originalOrder!.length;
          return pa.compareTo(pb);
        });
    } else {
      final indexed = state.asMap().entries.toList();
      indexed.sort((a, b) {
        final ca = counts[a.value.id] ?? 0;
        final cb = counts[b.value.id] ?? 0;
        if (ca != cb) return cb.compareTo(ca);
        return a.key.compareTo(b.key); // stable for ties / zero counts
      });
      sorted = indexed.map((e) => e.value).toList();
    }
    // Skip if order is unchanged to avoid provider update loops
    bool same = true;
    for (int i = 0; i < sorted.length; i++) {
      if (sorted[i].id != state[i].id) {
        same = false;
        break;
      }
    }
    if (same) return;
    _reordering = true;
    state = sorted;
    _reordering = false;
    _save();
  }

  /// Replace the whole active rule list (used when loading a profile).
  void loadRules(List<Rule> rules) {
    state = rules
        .map((r) => Rule(
              id: _generateId(), // fresh IDs to avoid collisions
              pattern: r.pattern,
              replacement: r.replacement,
              enabled: r.enabled,
              caseSensitive: r.caseSensitive,
              wholeWord: r.wholeWord,
              colorIndex: r.colorIndex,
            ))
        .toList();
    _save();
  }

  void swapAll() {
    state = state.map((r) {
      if (r.pattern == r.replacement) return r;
      return Rule(
        id: r.id,
        pattern: r.replacement,
        replacement: r.pattern,
        enabled: r.enabled,
        caseSensitive: r.caseSensitive,
        wholeWord: r.wholeWord,
        colorIndex: r.colorIndex,
      );
    }).toList();
    _save();
  }

  Rule _copyWith(
    Rule r, {
    String? pattern,
    String? replacement,
    bool? enabled,
    bool? caseSensitive,
    bool? wholeWord,
    int? colorIndex,
  }) {
    return Rule(
      id: r.id,
      pattern: pattern ?? r.pattern,
      replacement: replacement ?? r.replacement,
      enabled: enabled ?? r.enabled,
      caseSensitive: caseSensitive ?? r.caseSensitive,
      wholeWord: wholeWord ?? r.wholeWord,
      colorIndex: colorIndex ?? r.colorIndex,
    );
  }
}

final rulesProvider = StateNotifierProvider<RulesNotifier, List<Rule>>(
  (ref) => RulesNotifier(ref.watch(storageDirProvider)),
);

class ProfilesNotifier extends StateNotifier<List<Profile>> {
  ProfilesNotifier(this._storageDir) : super([]) {
    _load();
  }

  final String _storageDir;

  int _nextId = 0;

  String _generateId() => 'profile_${_nextId++}';

  String get _storageFile => '$_storageDir/.masktext_profiles.json';

  void _load() {
    try {
      final file = File(_storageFile);
      if (!file.existsSync()) return;
      final data = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      state =
          data.map((e) => Profile.fromJson(e as Map<String, dynamic>)).toList();
      for (final p in state) {
        final idNum = int.tryParse(p.id.replaceFirst('profile_', ''));
        if (idNum != null && idNum >= _nextId) _nextId = idNum + 1;
      }
    } catch (_) {
      // If load fails, start empty
    }
  }

  void _save() {
    try {
      final data = state.map((p) => p.toJson()).toList();
      File(_storageFile).writeAsStringSync(jsonEncode(data));
    } catch (_) {
      // Ignore save errors
    }
  }

  void saveAsProfile(String name, List<Rule> rules) {
    var uniqueName = name.trim();
    if (uniqueName.isEmpty) uniqueName = 'Unnamed profile';
    int suffix = 2;
    while (state.any((p) => p.name == uniqueName)) {
      uniqueName = '$name ($suffix)';
      suffix++;
    }
    state = [
      ...state,
      Profile(
        id: _generateId(),
        name: uniqueName,
        rules: List.of(rules),
      ),
    ];
    _save();
  }

  void overwriteProfile(String profileId, List<Rule> rules) {
    state = state
        .map((p) => p.id == profileId ? (p..rules = List.of(rules)) : p)
        .toList();
    _save();
  }

  void duplicateProfile(String profileId) {
    final index = state.indexWhere((p) => p.id == profileId);
    if (index == -1) return;
    final source = state[index];
    var name = '${source.name} (copy)';
    int suffix = 2;
    while (state.any((p) => p.name == name)) {
      name = '${source.name} (copy $suffix)';
      suffix++;
    }
    state = [
      ...state.sublist(0, index + 1),
      Profile(
        id: _generateId(),
        name: name,
        rules: source.rules
            .map((r) => Rule(
                  id: r.id,
                  pattern: r.pattern,
                  replacement: r.replacement,
                  enabled: r.enabled,
                  caseSensitive: r.caseSensitive,
                  wholeWord: r.wholeWord,
                  colorIndex: r.colorIndex,
                ))
            .toList(),
      ),
      ...state.sublist(index + 1),
    ];
    _save();
  }

  void renameProfile(String profileId, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    state =
        state.map((p) => p.id == profileId ? (p..name = trimmed) : p).toList();
    _save();
  }

  void deleteProfile(String profileId) {
    state = state.where((p) => p.id != profileId).toList();
    _save();
  }
}

final profilesProvider = StateNotifierProvider<ProfilesNotifier, List<Profile>>(
  (ref) => ProfilesNotifier(ref.watch(storageDirProvider)),
);

/// Currently selected profile id (null = none selected).
/// Persisted so the selection survives app restarts.
class SelectedProfileNotifier extends StateNotifier<String?> {
  SelectedProfileNotifier(this._storageDir) : super(null) {
    _load();
  }

  final String _storageDir;

  String get _storageFile => '$_storageDir/.masktext_selected_profile.json';

  void _load() {
    try {
      final file = File(_storageFile);
      if (!file.existsSync()) return;
      state = jsonDecode(file.readAsStringSync()) as String?;
    } catch (_) {
      // If load fails, start with no selection
    }
  }

  void select(String? id) {
    state = id;
    try {
      File(_storageFile).writeAsStringSync(jsonEncode(id));
    } catch (_) {
      // Ignore save errors
    }
  }
}

final selectedProfileIdProvider =
    StateNotifierProvider<SelectedProfileNotifier, String?>(
  (ref) => SelectedProfileNotifier(ref.watch(storageDirProvider)),
);

final directionProvider = StateProvider<Direction>((ref) => Direction.forward);

/// The most recent forward pass that actually masked something, retained so
/// that reversing the masked text can restore the exact original — including
/// casing — via [restore], instead of the lossy stateless reverse pass.
final lastMaskedResultProvider = StateProvider<EngineResult?>((ref) => null);

// Uses rawInputProvider directly → instant output, no debounce
final resultProvider = Provider<EngineResult>((ref) {
  final input = ref.watch(debouncedInputProvider);
  final rules = ref.watch(rulesProvider);
  final direction = ref.watch(directionProvider);

  if (direction == Direction.reverse) {
    final masked = ref.watch(lastMaskedResultProvider);
    if (masked != null && masked.outputText == input) {
      return restore(masked);
    }
  }

  return apply(input, rules, direction);
});
