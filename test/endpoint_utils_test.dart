import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcode/models/provider_config.dart';
import 'package:pocketcode/utils/endpoint_utils.dart';

void main() {
  test('preserves an explicit API root and strips pasted endpoint', () {
    final provider = ProviderConfig(id: '1', name: 'x', baseUrl: 'https://example.test/v1/chat/completions', protocol: ProviderProtocol.openAiCompatible, models: const []);
    expect(EndpointUtils.chatEndpoint(provider).toString(), 'https://example.test/v1/chat/completions');
    expect(EndpointUtils.modelsEndpoint(provider).toString(), 'https://example.test/v1/models');
  });

  test('does not blindly append v1 to a root without it', () {
    final provider = ProviderConfig(id: '1', name: 'x', baseUrl: 'https://example.test/api', protocol: ProviderProtocol.openAiCompatible, models: const []);
    expect(EndpointUtils.chatEndpoint(provider).toString(), 'https://example.test/api/chat/completions');
  });

  test('requires explicit opt-in for insecure HTTP', () {
    expect(() => EndpointUtils.parseBase('http://127.0.0.1:8080', allowInsecureHttp: false), throwsA(isA<EndpointException>()));
    expect(EndpointUtils.parseBase('http://127.0.0.1:8080', allowInsecureHttp: true).host, '127.0.0.1');
  });

  test('drops query strings and fragments from pasted endpoints', () {
    final provider = ProviderConfig(id: '1', name: 'x', baseUrl: 'https://example.test/v1/chat/completions?foo=bar#frag', protocol: ProviderProtocol.openAiCompatible, models: const []);
    expect(EndpointUtils.chatEndpoint(provider).toString(), 'https://example.test/v1/chat/completions');
    expect(EndpointUtils.modelsEndpoint(provider).toString(), 'https://example.test/v1/models');
  });
}
