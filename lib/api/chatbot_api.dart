import 'api_client.dart';

class ChatbotApi {
  static final _client = ApiClient.instance;

  static Future<ChatbotAskResponse> ask(String question) async {
    final res = await _client.post('/api/chatbot/ask', {'question': question});
    return ChatbotAskResponse.fromJson(res);
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

class ChatbotAskResponse {
  ChatbotAskResponse({
    required this.answer,
    this.matched,
    this.top,
  });

  final String answer;
  final Map<String, dynamic>? matched;
  final List<dynamic>? top;

  factory ChatbotAskResponse.fromJson(Map<String, dynamic> json) {
    return ChatbotAskResponse(
      answer: json['answer']?.toString() ?? '',
      matched: json['matched'] is Map ? Map<String, dynamic>.from(json['matched'] as Map) : null,
      top: json['top'] is List ? (json['top'] as List) : null,
    );
  }
}
