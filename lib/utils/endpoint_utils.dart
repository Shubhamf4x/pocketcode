import '../models/provider_config.dart';

class EndpointException implements Exception {
  const EndpointException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EndpointUtils {
  const EndpointUtils._();

  static Uri parseBase(String input, {required bool allowInsecureHttp}) {
    var value = input.trim();
    if (value.isEmpty) throw const EndpointException('Base URL is required.');
    if (!value.contains('://')) value = 'https://$value';
    Uri uri;
    try {
      uri = Uri.parse(value);
    } catch (_) {
      throw const EndpointException('Base URL is not a valid URL.');
    }
    if (uri.host.isEmpty || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const EndpointException('Base URL must use https:// (or explicitly enabled http://).');
    }
    if (uri.scheme == 'http' && !allowInsecureHttp) {
      throw const EndpointException('HTTP is disabled. Enable “Allow insecure HTTP” for a local development endpoint.');
    }
    return uri;
  }

  static Uri apiRoot(String input, {required bool allowInsecureHttp}) {
    final uri = parseBase(input, allowInsecureHttp: allowInsecureHttp);
    var path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    for (final suffix in const ['/chat/completions', '/messages', '/models']) {
      if (path.endsWith(suffix)) {
        path = path.substring(0, path.length - suffix.length);
        break;
      }
    }
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path.isEmpty ? '' : path,
    );
  }

  static Uri endpoint(ProviderConfig provider, String resource) {
    final root = apiRoot(provider.baseUrl, allowInsecureHttp: provider.allowInsecureHttp);
    final rootPath = root.path.replaceFirst(RegExp(r'/+$'), '');
    final clean = resource.replaceFirst(RegExp(r'^/+'), '');
    return root.replace(path: '$rootPath/$clean');
  }

  static Uri modelsEndpoint(ProviderConfig provider) => endpoint(provider, 'models');
  static Uri chatEndpoint(ProviderConfig provider) => endpoint(provider, 'chat/completions');
  static Uri messagesEndpoint(ProviderConfig provider) => endpoint(provider, 'messages');
}
