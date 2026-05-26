class ParsedThinking {
  final List<String> segments;
  final String? pending;
  final String body;
  final bool hasThinking;

  ParsedThinking({
    required this.segments,
    this.pending,
    required this.body,
    required this.hasThinking,
  });
}

class ParseOptions {
  final bool streaming;

  ParseOptions({required this.streaming});
}

// Standard English-style tags: <think>...
final _tagRe = RegExp(r'<(think|thinking|reasoning)>([\s\S]*?)<\/\1>', caseSensitive: false);
// Chinese-style opening: <think> followed by content and 」 (U+300D) or ) as closing
final _chineseTagOpenRe = RegExp(r'<think>', caseSensitive: false);
final _chineseTagCloseRe = RegExp('[』)]', caseSensitive: false);
const _placeholderPrefix = '\x00THKCODE';
const _placeholderSuffix = '\x00';

final _fencedRe = RegExp(r'(^|\n)( {0,3})(`{3,}|~{3,})[^\n]*\n[\s\S]*?\n\2\3[ \t]*(?=\n|$)');
final _inlineCodeRe = RegExp(r'`[^`\n]*`');

class _ProtectedBlocks {
  final String masked;
  final List<String> blocks;

  _ProtectedBlocks({required this.masked, required this.blocks});
}

_ProtectedBlocks _protectCodeBlocks(String input) {
  final blocks = <String>[];
  var masked = input.replaceAllMapped(_fencedRe, (m) {
    blocks.add(m.group(0)!);
    return '$_placeholderPrefix${blocks.length - 1}$_placeholderSuffix';
  });
  masked = masked.replaceAllMapped(_inlineCodeRe, (m) {
    blocks.add(m.group(0)!);
    return '$_placeholderPrefix${blocks.length - 1}$_placeholderSuffix';
  });
  return _ProtectedBlocks(masked: masked, blocks: blocks);
}

String _restoreCodeBlocks(String text, List<String> blocks) {
  if (blocks.isEmpty) return text;

  var restored = text;

  for (var i = 0; i < blocks.length; i++) {
    final placeholder = '$_placeholderPrefix$i$_placeholderSuffix';
    if (restored.contains(placeholder)) {
      restored = restored.replaceFirst(placeholder, blocks[i]);
    }
  }

  return restored;
}

bool _containsThinkingMarkers(String text) {
  return text.contains('<think>') || text.contains('<thinking') || text.contains('<reasoning');
}

ParsedThinking parseThinking(String content, ParseOptions opts) {
  final protected = _protectCodeBlocks(content);

  final segments = <String>[];
  String? pending;
  var body = '';
  var lastIndex = 0;

  // First, extract standard English-style closed tags: <think>...
  for (final m in _tagRe.allMatches(protected.masked)) {
    body += protected.masked.substring(lastIndex, m.start);
    segments.add(m.group(2)!);
    lastIndex = m.start + m.group(0)!.length;
  }
  var rest = protected.masked.substring(lastIndex);

  // Check for Chinese-style thinking tags: <think> ... 」 or )
  if (segments.isEmpty && _containsThinkingMarkers(rest)) {
    final chineseOpen = _chineseTagOpenRe.firstMatch(rest);
    final chineseClose = _chineseTagCloseRe.firstMatch(rest);

    if (chineseOpen != null && chineseClose != null && chineseClose.start > chineseOpen.start) {
      // Extract thinking content between <think> and closing bracket
      final thinkingContent = rest.substring(chineseOpen.end, chineseClose.start);
      body = rest.substring(0, chineseOpen.start) + rest.substring(chineseClose.end);

      // If streaming and thinking tag is still open, add to pending
      if (opts.streaming && chineseClose.input.endsWith(')') && !rest.endsWith('』') && !rest.endsWith(')')) {
        pending = thinkingContent;
      } else {
        segments.add(thinkingContent);
      }
      rest = '';
    }
  }

  // Check for unclosed English-style tags at end (streaming)
  if (segments.isEmpty) {
    final openRe = RegExp(r'<(think|thinking|reasoning)>([\s\S]*)$', caseSensitive: false);
    final openMatch = openRe.firstMatch(rest);
    if (openMatch != null) {
      body += rest.substring(0, openMatch.start);
      if (opts.streaming) {
        pending = openMatch.group(2);
      } else {
        body += rest.substring(openMatch.start);
      }
    } else {
      body += rest;
    }
  } else {
    body += rest;
  }

  return ParsedThinking(
    segments: segments.map((s) => _restoreCodeBlocks(s, protected.blocks)).toList(),
    pending: pending == null ? null : _restoreCodeBlocks(pending, protected.blocks),
    body: _restoreCodeBlocks(body, protected.blocks),
    hasThinking: segments.isNotEmpty || pending != null || _containsThinkingMarkers(protected.masked),
  );
}

int countThinkingChars(ParsedThinking parsed) {
  int len(String s) => s.codeUnits.length;
  return parsed.segments.fold(0, (a, s) => a + len(s)) + len(parsed.pending ?? '');
}

ParsedThinking parseThinkingFromContent(String content, {bool isStreaming = false}) {
  return parseThinking(content, ParseOptions(streaming: isStreaming));
}

String extractBodyWithoutThinking(String content, {bool isStreaming = false}) {
  final parsed = parseThinkingFromContent(content, isStreaming: isStreaming);
  // Only strip thinking content if we successfully extracted closed segments
  if (parsed.segments.isNotEmpty) {
    return parsed.body;
  }
  // No closed thinking tags found - return original content
  return content;
}

bool contentHasThinking(String content, {bool isStreaming = false}) {
  final parsed = parseThinkingFromContent(content, isStreaming: isStreaming);
  return parsed.hasThinking;
}

// Debug function to check what the parser sees
String debugThinking(String content) {
  final parsed = parseThinkingFromContent(content);
  return '''
Content: "$content"
Contains <think>: ${content.contains('<think>')}
Contains ): ${content.contains(')')}
Contains 』: ${content.contains('』')}
hasThinking: ${parsed.hasThinking}
segments: ${parsed.segments}
pending: "${parsed.pending}"
body: "${parsed.body}"
''';
}