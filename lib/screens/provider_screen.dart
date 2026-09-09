import 'package:flutter/material.dart';

import '../models/provider_config.dart';
import '../state/app_controller.dart';
import '../utils/endpoint_utils.dart';

const _muted = Color(0xff9aa0a6);
const _onSurface = Color(0xffe8eaed);

class ProviderScreen extends StatelessWidget {
  const ProviderScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Providers')),
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.lock_outline, color: _onSurface),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'API keys are kept in secure device storage. Conversations and provider settings are stored locally in app preferences.',
                        style: TextStyle(fontSize: 13, color: _muted),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              if (controller.providers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No providers yet. Add an API-compatible endpoint to begin.',
                        textAlign: TextAlign.center, style: TextStyle(color: _muted)),
                  ),
                ),
              for (final provider in controller.providers)
                _ProviderCard(key: ValueKey(provider.id), controller: controller, provider: provider),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: controller.sending ? null : () => _edit(context),
                icon: const Icon(Icons.add),
                label: const Text('Add provider'),
              ),
            ],
          ),
        ),
      );

  Future<void> _edit(BuildContext context, {ProviderConfig? provider}) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ProviderForm(controller: controller, provider: provider),
      );
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({super.key, required this.controller, required this.provider});

  final AppController controller;
  final ProviderConfig provider;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          isThreeLine: true,
          leading: Icon(provider.protocol == ProviderProtocol.anthropic ? Icons.auto_awesome : Icons.hub_outlined),
          title: Text(provider.name),
          subtitle: Text(
            '${provider.protocol == ProviderProtocol.anthropic ? 'Anthropic native' : 'OpenAI-compatible'} · ${provider.models.length} saved model(s)\n${provider.baseUrl}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          trailing: PopupMenuButton<String>(
            enabled: !controller.sending,
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  _edit(context);
                case 'discover':
                  _discover(context);
                case 'delete':
                  _delete(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'discover', child: Text('Discover models')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      );

  Future<void> _edit(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ProviderForm(controller: controller, provider: provider),
      );

  Future<void> _discover(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(content: Text('Discovering models…'), duration: Duration(seconds: 1)));
    try {
      final models = await controller.discoverModels(provider);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Found ${models.length} model(s).')));
    } catch (error) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(error.toString()), duration: const Duration(seconds: 5)));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete provider?'),
        content: Text('Remove ${provider.name} and its secure API key?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true) await controller.deleteProvider(provider.id);
  }
}

class _ProviderForm extends StatefulWidget {
  const _ProviderForm({required this.controller, this.provider});

  final AppController controller;
  final ProviderConfig? provider;

  @override
  State<_ProviderForm> createState() => _ProviderFormState();
}

class _ProviderFormState extends State<_ProviderForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.provider?.name ?? '');
  late final _url = TextEditingController(text: widget.provider?.baseUrl ?? '');
  late final _key = TextEditingController();
  late final _models = TextEditingController(text: widget.provider?.models.join(', ') ?? '');
  late ProviderProtocol _protocol = widget.provider?.protocol ?? ProviderProtocol.openAiCompatible;
  late bool _insecure = widget.provider?.allowInsecureHttp ?? false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _key.dispose();
    _models.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Form(
          key: _form,
          child: ListView(
            shrinkWrap: true,
            children: [
              const SizedBox(height: 6),
              Text(widget.provider == null ? 'Add provider' : 'Edit provider', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                maxLength: 60,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'Personal OpenAI'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _url,
                decoration: const InputDecoration(labelText: 'Base URL', hintText: 'https://api.example.com/v1'),
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: _validateUrl,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ProviderProtocol>(
                initialValue: _protocol,
                decoration: const InputDecoration(labelText: 'Protocol'),
                items: const [
                  DropdownMenuItem(value: ProviderProtocol.openAiCompatible, child: Text('OpenAI-compatible (chat/completions)')),
                  DropdownMenuItem(value: ProviderProtocol.anthropic, child: Text('Anthropic native (messages)')),
                ],
                onChanged: _saving ? null : (value) { if (value != null) setState(() => _protocol = value); },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _key,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                validator: widget.provider == null
                    ? (value) => value == null || value.trim().isEmpty ? 'API key is required' : null
                    : null,
                decoration: InputDecoration(
                  labelText: widget.provider == null ? 'API key' : 'API key (leave blank to keep current key)',
                  helperText: 'Never written to chat history or preferences',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _models,
                decoration: const InputDecoration(labelText: 'Manual models', hintText: 'model-id-one, model-id-two'),
                maxLines: 2,
                autocorrect: false,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _insecure,
                onChanged: _saving ? null : (value) => setState(() => _insecure = value),
                title: const Text('Allow insecure HTTP'),
                subtitle: const Text('Only use for trusted local development endpoints.', style: TextStyle(color: _muted, fontSize: 12)),
                secondary: const Icon(Icons.warning_amber_rounded, color: Color(0xffe0a33a)),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save provider'),
              ),
            ],
          ),
        ),
      );

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    try {
      EndpointUtils.parseBase(value, allowInsecureHttp: _insecure);
      return null;
    } on EndpointException catch (error) {
      return error.message;
    } catch (_) {
      return 'Base URL is not a valid URL.';
    }
  }

  Future<void> _save() async {
    final form = _form.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final models = _models.text
          .split(',')
          .map((model) => model.trim())
          .where((model) => model.isNotEmpty)
          .toSet()
          .toList();
      await widget.controller.addOrEditProvider(
        existing: widget.provider,
        name: _name.text,
        baseUrl: _url.text,
        apiKey: _key.text,
        protocol: _protocol,
        models: models,
        allowInsecureHttp: _insecure,
      );
      if (navigator.canPop()) navigator.pop();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      if (mounted) setState(() => _saving = false);
    }
  }
}
