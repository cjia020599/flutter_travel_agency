import 'api_client.dart';

class ChatbotApi {
  static final _client = ApiClient.instance;

  static Future<ChatbotAskResponse> ask(
    String question, {
    ChatbotContext? context,
  }) async {
    final payload = <String, dynamic>{'question': question};
    if (context != null) {
      final isMore = _isMoreMessage(question);
      if (isMore) {
        context.lastTopK = (context.lastTopK + 3).clamp(1, 10);
        payload['topK'] = context.lastTopK;
        if (context.lastIntent != null) payload['intent'] = context.lastIntent;
        if (context.lastModuleType != null) payload['moduleType'] = context.lastModuleType;
        if (context.seen.isNotEmpty) payload['exclude'] = context.seen;
      } else {
        context.lastTopK = 3;
        context.lastIntent = null;
        context.lastModuleType = null;
        context.seen.clear();
      }
    }

    final res = await _client.post('/api/chatbot/ask', payload);
    final response = ChatbotAskResponse.fromJson(res);

    if (context != null) {
      final matched = response.matched;
      if (matched != null) {
        context.lastIntent = matched['intent']?.toString();
        context.lastModuleType = matched['moduleType']?.toString();
      }

      final suggestions = response.suggestions;
      for (final item in suggestions) {
        if (item is! Map) continue;
        final id = item['id'];
        final kind = item['kind'] ?? item['moduleType'];
        if (id == null || kind == null) continue;
        context.seen.add({'id': id, 'kind': kind});
      }
    }

    return response;
  }

  static Future<List<dynamic>> listQuestions() async {
    final res = await _client.get('/api/chatbot/questions');
    final data = res['data'];
    if (data is List) return data;
    return [];
  }

  static Future<Map<String, dynamic>> createQuestion({
    required String question,
    required String answer,
  }) async {
    return _client.post('/api/chatbot/questions', {
      'question': question,
      'answer': answer,
    });
  }

  static Future<Map<String, dynamic>> updateQuestion(
    String id, {
    required String question,
    required String answer,
  }) async {
    return _client.put('/api/chatbot/questions/$id', {
      'question': question,
      'answer': answer,
    });
  }

  static Future<void> deleteQuestion(String id) async {
    await _client.delete('/api/chatbot/questions/$id');
  }
}

class ChatbotContext {
  String? lastIntent;
  String? lastModuleType;
  int lastTopK = 3;
  final List<Map<String, dynamic>> seen = [];
}

bool _isMoreMessage(String text) {
  final q = text.toLowerCase().trim();
  return q.contains('show more') || q == 'more' || q.contains('more') || q.contains('another');
}

class ChatbotAskResponse {
  ChatbotAskResponse({
    required this.answer,
    this.matched,
    this.suggestions = const [],
    this.top,
  });

  final String answer;
  final Map<String, dynamic>? matched;
  final List<dynamic> suggestions;
  final List<dynamic>? top;

  factory ChatbotAskResponse.fromJson(Map<String, dynamic> json) {
    return ChatbotAskResponse(
      answer: json['answer']?.toString() ?? '',
      matched: json['matched'] is Map ? Map<String, dynamic>.from(json['matched'] as Map) : null,
      suggestions: json['suggestions'] is List
          ? (json['suggestions'] as List)
          : (json['top'] is List ? (json['top'] as List) : const []),
      top: json['top'] is List ? (json['top'] as List) : null,
    );
  }
}
