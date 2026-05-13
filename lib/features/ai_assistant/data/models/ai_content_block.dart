sealed class AiContentBlock {
  const AiContentBlock();

  Map<String, dynamic> toJson();

  factory AiContentBlock.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'text' => AiTextBlock.fromJson(json),
      'image' => AiImageBlock.fromJson(json),
      'tool_use' => AiToolUseBlock.fromJson(json),
      'tool_result' => AiToolResultBlock.fromJson(json),
      _ => throw ArgumentError('Unknown block type: ${json['type']}'),
    };
  }
}

class AiTextBlock extends AiContentBlock {
  final String text;
  const AiTextBlock(this.text);

  @override
  Map<String, dynamic> toJson() => {'type': 'text', 'text': text};

  factory AiTextBlock.fromJson(Map<String, dynamic> json) =>
      AiTextBlock(json['text'] as String);
}

class AiImageBlock extends AiContentBlock {
  final String mediaType;
  final String data;
  const AiImageBlock({required this.mediaType, required this.data});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'image',
    'source': {
      'type': 'base64',
      'media_type': mediaType,
      'data': data,
    },
  };

  factory AiImageBlock.fromJson(Map<String, dynamic> json) {
    final src = json['source'] as Map<String, dynamic>;
    return AiImageBlock(
      mediaType: src['media_type'] as String,
      data: src['data'] as String,
    );
  }
}

class AiToolUseBlock extends AiContentBlock {
  final String id;
  final String name;
  final Map<String, dynamic> input;
  const AiToolUseBlock({
    required this.id,
    required this.name,
    required this.input,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'tool_use',
    'id': id,
    'name': name,
    'input': input,
  };

  factory AiToolUseBlock.fromJson(Map<String, dynamic> json) =>
      AiToolUseBlock(
        id: json['id'] as String,
        name: json['name'] as String,
        input:
            (json['input'] as Map<String, dynamic>).cast<String, dynamic>(),
      );
}

class AiToolResultBlock extends AiContentBlock {
  final String toolUseId;
  final String content;
  final bool isError;
  const AiToolResultBlock({
    required this.toolUseId,
    required this.content,
    this.isError = false,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'tool_result',
    'tool_use_id': toolUseId,
    'content': content,
    'is_error': isError,
  };

  factory AiToolResultBlock.fromJson(Map<String, dynamic> json) =>
      AiToolResultBlock(
        toolUseId: json['tool_use_id'] as String,
        content: json['content'] as String,
        isError: json['is_error'] as bool? ?? false,
      );
}
