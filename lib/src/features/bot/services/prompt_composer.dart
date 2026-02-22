import 'prompt_registry.dart';

class PromptComposer {
  final PromptRegistry _registry;

  PromptComposer(this._registry);

  /// Replace {variable} placeholders in a template string.
  /// Missing variables are replaced with empty string (no crash).
  String inject(String template, Map<String, String> variables) {
    var result = template;
    for (final entry in variables.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    // Clean up any remaining unreplaced placeholders
    result = result.replaceAll(RegExp(r'\{[a-zA-Z_]+\}'), '');
    return result.trim();
  }

  /// Get a prompt from the registry and inject variables.
  String compose(String key, {Map<String, String>? variables, String? fallback}) {
    final template = _registry.get(key, fallback: fallback);
    if (variables == null || variables.isEmpty) return template;
    return inject(template, variables);
  }

  /// Compose a slot-filling question for the given task and slot.
  /// Example: slotPrompt('post_load', 'origin') → "Where is the pickup city?"
  String slotPrompt(String task, String slot, {bool isRetry = false}) {
    final retryKey = 'tasks.$task.slots.${slot}_retry';
    final normalKey = 'tasks.$task.slots.$slot';

    if (isRetry) {
      final retry = _registry.get(retryKey, fallback: retryKey);
      if (retry != retryKey) return retry;
    }
    return _registry.get(normalKey, fallback: 'Please provide $slot');
  }

  /// Compose a confirmation summary for a task.
  String confirmation(String task, Map<String, String> slots) {
    final template = _registry.get(
      'tasks.$task.confirmation.summary',
      fallback: 'Please confirm your details.',
    );
    return inject(template, slots);
  }

  /// Get a system rule prompt (reset, cancel, role gate, etc.)
  String rule(String ruleKey, {String? fallback}) {
    return _registry.get('system.rules.$ruleKey', fallback: fallback ?? ruleKey);
  }

  /// Get an error message for the given error type.
  String error(String errorType, {Map<String, String>? variables}) {
    final template = _registry.get(
      'errors.errors.$errorType',
      fallback: 'An error occurred.',
    );
    if (variables == null) return template;
    return inject(template, variables);
  }

  /// Get the greeting message, optionally with context.
  String greeting({String? userRole, Map<String, String>? context}) {
    if (context != null && context.isNotEmpty) {
      final template = _registry.get('system.identity.greeting_with_context');
      final ctaKey = userRole == 'supplier'
          ? 'system.identity.cta_supplier'
          : userRole == 'trucker'
              ? 'system.identity.cta_trucker'
              : 'system.identity.cta_default';
      final cta = _registry.get(ctaKey);
      return inject(template, {...context, 'cta': cta});
    }
    return _registry.get('system.identity.greeting');
  }

  /// Get the onboarding message for first-time users.
  String onboarding() {
    return _registry.get(
      'system.onboarding.message',
      fallback: 'Welcome to TranZfort!',
    );
  }
}
