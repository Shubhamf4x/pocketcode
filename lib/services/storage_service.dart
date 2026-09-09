import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/conversation.dart';
import '../models/provider_config.dart';

class StorageService {
  StorageService(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _providersKey = 'providers.v1';
  static const _conversationsKey = 'conversations.v1';
  static const _activeProviderKey = 'activeProvider.v1';
  static const _activeModelKey = 'activeModel.v1';
  static const _activeConversationKey = 'activeConversation.v1';

  static Future<StorageService> open() async => StorageService(
        await SharedPreferences.getInstance(),
        const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true)),
      );

  List<ProviderConfig> loadProviders() {
    final raw = _prefs.getString(_providersKey);
    if (raw == null || raw.isEmpty) return <ProviderConfig>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ProviderConfig>[];
      return decoded.whereType<Map<String, dynamic>>().map(ProviderConfig.fromJson).toList();
    } catch (error) {
      debugPrint('Provider data was corrupt and has been ignored: $error');
      return <ProviderConfig>[];
    }
  }

  Future<void> saveProviders(List<ProviderConfig> providers) async {
    try {
      await _prefs.setString(_providersKey, jsonEncode([for (final provider in providers) provider.toJson()]));
    } catch (error) {
      debugPrint('Could not save providers: $error');
    }
  }

  List<Conversation> loadConversations() {
    final raw = _prefs.getString(_conversationsKey);
    if (raw == null || raw.isEmpty) return <Conversation>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Conversation>[];
      return decoded.whereType<Map<String, dynamic>>().map(Conversation.fromJson).toList();
    } catch (error) {
      debugPrint('Conversation data was corrupt and has been ignored: $error');
      return <Conversation>[];
    }
  }

  Future<void> saveConversations(List<Conversation> conversations) async {
    try {
      await _prefs.setString(_conversationsKey, jsonEncode([for (final conversation in conversations) conversation.toJson()]));
    } catch (error) {
      debugPrint('Could not save conversations: $error');
    }
  }

  Future<String?> readApiKey(String providerId) async {
    try {
      return await _secure.read(key: 'apiKey.$providerId');
    } catch (error) {
      debugPrint('Secure storage read failed: $error');
      return null;
    }
  }

  Future<void> writeApiKey(String providerId, String value) async {
    try {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        await _secure.delete(key: 'apiKey.$providerId');
      } else {
        await _secure.write(key: 'apiKey.$providerId', value: trimmed);
      }
    } catch (error) {
      debugPrint('Secure storage write failed: $error');
      rethrow;
    }
  }

  Future<void> deleteApiKey(String providerId) async {
    try {
      await _secure.delete(key: 'apiKey.$providerId');
    } catch (error) {
      debugPrint('Secure storage delete failed: $error');
    }
  }

  String? get activeProviderId => _prefs.getString(_activeProviderKey);
  String? get activeModel => _prefs.getString(_activeModelKey);
  String? get activeConversationId => _prefs.getString(_activeConversationKey);

  Future<void> setActiveProvider(String id) => _prefs.setString(_activeProviderKey, id);
  Future<void> setActiveModel(String model) => _prefs.setString(_activeModelKey, model);
  Future<void> setActiveConversation(String id) => _prefs.setString(_activeConversationKey, id);
}
