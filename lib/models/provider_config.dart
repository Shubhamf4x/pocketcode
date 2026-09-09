enum ProviderProtocol { openAiCompatible, anthropic }

class ProviderConfig {
  const ProviderConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.protocol,
    required this.models,
    this.allowInsecureHttp = false,
    this.activeModel,
  });

  final String id;
  final String name;
  final String baseUrl;
  final ProviderProtocol protocol;
  final List<String> models;
  final bool allowInsecureHttp;
  final String? activeModel;

  ProviderConfig copyWith({
    String? name,
    String? baseUrl,
    ProviderProtocol? protocol,
    List<String>? models,
    bool? allowInsecureHttp,
    String? activeModel,
    bool clearActiveModel = false,
  }) => ProviderConfig(
        id: id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        protocol: protocol ?? this.protocol,
        models: models ?? this.models,
        allowInsecureHttp: allowInsecureHttp ?? this.allowInsecureHttp,
        activeModel: clearActiveModel ? null : (activeModel ?? this.activeModel),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'protocol': protocol.name,
        'models': models,
        'allowInsecureHttp': allowInsecureHttp,
        if (activeModel != null) 'activeModel': activeModel,
      };

  factory ProviderConfig.fromJson(Map<String, dynamic> json) => ProviderConfig(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? 'Provider',
        baseUrl: json['baseUrl'] as String? ?? '',
        protocol: ProviderProtocol.values.firstWhere(
          (value) => value.name == json['protocol'],
          orElse: () => ProviderProtocol.openAiCompatible,
        ),
        models: (json['models'] as List<dynamic>? ?? const []).whereType<String>().toList(),
        allowInsecureHttp: json['allowInsecureHttp'] as bool? ?? false,
        activeModel: json['activeModel'] as String?,
      );
}
