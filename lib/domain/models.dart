enum Direction { forward, reverse }

class Rule {
  final String id;
  String pattern;
  String replacement;
  bool enabled;
  bool caseSensitive;
  bool wholeWord;
  int colorIndex;

  Rule({
    required this.id,
    required this.pattern,
    required this.replacement,
    this.enabled = true,
    this.caseSensitive = false,
    this.wholeWord = true,
    this.colorIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'pattern': pattern,
        'replacement': replacement,
        'enabled': enabled,
        'caseSensitive': caseSensitive,
        'wholeWord': wholeWord,
        'colorIndex': colorIndex,
      };

  static Rule fromJson(Map<String, dynamic> e) => Rule(
        id: e['id'] as String,
        pattern: e['pattern'] as String,
        replacement: e['replacement'] as String,
        enabled: e['enabled'] as bool,
        caseSensitive: e['caseSensitive'] as bool,
        wholeWord: e['wholeWord'] as bool,
        colorIndex: e['colorIndex'] as int,
      );
}

class Profile {
  final String id;
  String name;
  List<Rule> rules;

  Profile({required this.id, required this.name, required this.rules});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rules': rules.map((r) => r.toJson()).toList(),
      };

  static Profile fromJson(Map<String, dynamic> e) => Profile(
        id: e['id'] as String,
        name: e['name'] as String,
        rules: (e['rules'] as List<dynamic>)
            .map((r) => Rule.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

class MatchEvent {
  final int start; // offset in OUTPUT text
  final int end;
  final String ruleId;
  final String originalText; // the matched input substring

  MatchEvent({
    required this.start,
    required this.end,
    required this.ruleId,
    required this.originalText,
  });
}

class EngineResult {
  final String outputText;
  final List<MatchEvent> events;
  final Map<String, int> countsPerRuleId;
  final List<String> warnings;

  EngineResult({
    required this.outputText,
    required this.events,
    required this.countsPerRuleId,
    required this.warnings,
  });
}
