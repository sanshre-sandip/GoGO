import '../models/ride_preferences.dart';

/// Turns free text into weighted priorities. The MVP implementation is
/// rule-based and offline; a Gemini-backed one can implement this later.
abstract class PreferenceInterpreter {
  Future<RidePreferences> interpret(String input);
}

class RuleBasedPreferenceInterpreter implements PreferenceInterpreter {
  const RuleBasedPreferenceInterpreter();

  static final _wait = RegExp(r'(\d+)\s*min');

  @override
  Future<RidePreferences> interpret(String input) async {
    final text = input.toLowerCase();
    bool has(List<String> words) => words.any(text.contains);

    final prefs = RidePreferences(
      pricePriority: has(['cheap', 'cheapest', 'budget', 'affordable', 'price']) ? 1 : 0,
      distancePriority: has(['near', 'nearest', 'close', 'closest']) ? 1 : 0,
      etaPriority: has(['fast', 'fastest', 'quick', 'soon', 'hurry', 'wait']) ? 1 : 0,
      maxWaitMinutes: int.tryParse(_wait.firstMatch(text)?.group(1) ?? ''),
    );
    return prefs.orBalanced;
  }
}
