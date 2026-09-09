import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../state/app_controller.dart';
import 'provider_screen.dart';

const _panel = Color(0xff111315);
const _assistantBubble = Color(0xff171a1c);
const _userBubble = Color(0xff21262a);
const _chipSurface = Color(0xff22262a);
const _muted = Color(0xff9aa0a6);
const _onSurface = Color(0xffe8eaed);

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(children: [
            Icon(Icons.code_rounded, color: _onSurface),
            SizedBox(width: 10),
            Text('PocketCode'),
          ]),
          actions: [
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) => IconButton(
                tooltip: 'Providers',
                onPressed: controller.sending ? null : () => _openProviders(context),
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        drawer: _ConversationDrawer(controller: controller),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 850;
              return Row(children: [
                if (wide) SizedBox(width: 285, child: _ConversationPanel(controller: controller)),
                if (wide) const VerticalDivider(width: 1),
                Expanded(child: _ChatPanel(controller: controller)),
              ]);
            },
          ),
        ),
      );

  Future<void> _openProviders(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProviderScreen(controller: controller)));
}

class _ConversationDrawer extends StatelessWidget {
  const _ConversationDrawer({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => Drawer(
        child: SafeArea(child: _ConversationPanel(controller: controller, closeOnTap: true)),
      );
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({required this.controller, this.closeOnTap = false});

  final AppController controller;
  final bool closeOnTap;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ColoredBox(
          color: _panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                child: Row(children: [
                  const Expanded(child: Text('Conversations', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                  IconButton(
                    tooltip: 'New conversation',
                    onPressed: controller.sending ? null : () => _newConversation(context),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: controller.conversations.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Start a conversation to see it here.', style: TextStyle(color: _muted)),
                        ),
                      )
                    : ListView.builder(
                        primary: false,
                        itemCount: controller.conversations.length,
                        itemExtent: 72,
                        itemBuilder: (context, index) {
                          final conversation = controller.conversations[index];
                          final selected = conversation.id == controller.activeConversationId;
                          return ListTile(
                            key: ValueKey(conversation.id),
                            selected: selected,
                            leading: Icon(selected ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded, size: 19),
                            title: Text(conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${conversation.messages.length} messages',
                                style: const TextStyle(fontSize: 12, color: _muted)),
                            onTap: controller.sending ? null : () => _select(context, conversation.id),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                tooltip: 'Rename',
                                onPressed: controller.sending ? null : () => _rename(context, conversation),
                                icon: const Icon(Icons.edit_outlined, size: 19),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: controller.sending ? null : () => _delete(context, conversation),
                                icon: const Icon(Icons.delete_outline, size: 19),
                              ),
                            ]),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );

  Future<void> _newConversation(BuildContext context) async {
    final navigator = Navigator.of(context);
    await controller.addConversation();
    if (closeOnTap && navigator.canPop()) navigator.pop();
  }

  Future<void> _select(BuildContext context, String id) async {
    final navigator = Navigator.of(context);
    await controller.selectConversation(id);
    if (closeOnTap && navigator.canPop()) navigator.pop();
  }

  Future<void> _rename(BuildContext context, Conversation conversation) async {
    final field = TextEditingController(text: conversation.title);
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Rename conversation'),
          content: TextField(
            controller: field,
            autofocus: true,
            maxLength: 80,
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, field.text), child: const Text('Save')),
          ],
        ),
      );
      if (name != null && name.trim().isNotEmpty) await controller.renameConversation(conversation.id, name);
    } finally {
      field.dispose();
    }
  }

  Future<void> _delete(BuildContext context, Conversation conversation) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text('“${conversation.title}” will be removed from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true) await controller.deleteConversation(conversation.id);
  }
}

class _ChatPanel extends StatefulWidget {
  const _ChatPanel({required this.controller});

  final AppController controller;

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _pinned = true;
  bool _scrollScheduled = false;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onControllerChanged);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    _scroll.removeListener(_onScroll);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final atBottom = position.maxScrollExtent - position.pixels <= 80;
    if (_pinned != atBottom && mounted) setState(() => _pinned = atBottom);
  }

  void _onControllerChanged() {
    if (!_pinned || _scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if ((_scroll.position.pixels - target).abs() > 1) _scroll.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        _Toolbar(controller: controller),
        Expanded(child: AnimatedBuilder(animation: controller, builder: _buildMessagesArea)),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(animation: controller, builder: _buildErrorBar),
        ),
        _Composer(controller: controller, input: _input),
      ]);

  Widget _buildMessagesArea(BuildContext context, _) {
    final conversation = controller.activeConversation;
    if (conversation == null || conversation.messages.isEmpty) {
      final isNewAllowed = !controller.sending && conversation == null;
      return _EmptyState(onNew: isNewAllowed ? controller.addConversation : null);
    }
    return _MessageList(conversation: conversation, controller: controller, scrollController: _scroll);
  }

  Widget _buildErrorBar(BuildContext context, _) {
    final error = controller.errorMessage;
    if (error == null) return const SizedBox(width: double.infinity);
    return _ErrorBar(message: error, onDismiss: controller.clearError, onRetry: controller.sending ? null : controller.retryLast);
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final provider = controller.activeProvider;
          final models = provider?.models ?? const <String>[];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: provider?.id,
                  hint: const Text('Provider'),
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    for (final item in controller.providers)
                      DropdownMenuItem(
                        value: item.id,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(item.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                  ],
                  onChanged: controller.sending ? null : (id) { if (id != null) controller.selectProvider(id); },
                ),
                DropdownButton<String>(
                  value: models.contains(controller.activeModel) ? controller.activeModel : null,
                  hint: const Text('Choose model'),
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    for (final model in models)
                      DropdownMenuItem(
                        value: model,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: Text(model, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                  ],
                  onChanged: controller.sending ? null : (model) { if (model != null) controller.selectModel(model); },
                ),
                if (provider == null)
                  TextButton.icon(
                    onPressed: controller.sending
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProviderScreen(controller: controller))),
                    icon: const Icon(Icons.add),
                    label: const Text('Add provider'),
                  ),
                if (controller.activeConversation != null)
                  IconButton(
                    tooltip: 'Conversation settings',
                    onPressed: controller.sending ? null : () => _settings(context),
                    icon: const Icon(Icons.tune_rounded),
                  ),
              ],
            ),
          );
        },
      );

  Future<void> _settings(BuildContext context) async {
    final conversation = controller.activeConversation;
    if (conversation == null) return;
    final prompt = TextEditingController(text: conversation.systemPrompt);
    var temperature = conversation.temperature.clamp(0.0, 2.0);
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Conversation settings'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: prompt,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 4000,
                      decoration: const InputDecoration(labelText: 'System prompt'),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Text('Temperature'),
                      Expanded(
                        child: Slider(
                          value: temperature,
                          min: 0,
                          max: 2,
                          divisions: 20,
                          label: temperature.toStringAsFixed(1),
                          onChanged: (value) => setDialogState(() => temperature = value),
                        ),
                      ),
                      Text(temperature.toStringAsFixed(1)),
                    ]),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final text = prompt.text;
                  Navigator.pop(dialogContext);
                  controller.updateConversationSettings(systemPrompt: text, temperature: temperature);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      prompt.dispose();
    }
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.conversation, required this.controller, required this.scrollController});

  final Conversation conversation;
  final AppController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) => ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        itemCount: conversation.messages.length,
        scrollCacheExtent: const ScrollCacheExtent.pixels(600),
        addAutomaticKeepAlives: false,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemBuilder: (context, index) {
          final message = conversation.messages[index];
          return RepaintBoundary(
            child: _MessageBubble(
              key: ValueKey(message.id),
              message: message,
              busy: controller.sending,
              onEdit: (text) => controller.editUserMessage(message.id, text),
            ),
          );
        },
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({super.key, required this.message, required this.busy, required this.onEdit});

  final ChatMessage message;
  final bool busy;
  final Future<bool> Function(String) onEdit;

  @override
  Widget build(BuildContext context) {
    final user = message.role == MessageRole.user;
    final streaming = message.content.isEmpty && message.status == MessageStatus.streaming;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showActions(context),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 780),
            padding: const EdgeInsets.fromLTRB(15, 11, 15, 11),
            decoration: BoxDecoration(
              color: user ? _userBubble : _assistantBubble,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.attachments.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: message.content.isEmpty && !streaming ? 0 : 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final attachment in message.attachments) _AttachmentView(attachment: attachment)],
                    ),
                  ),
                if (streaming)
                  const _ThinkingIndicator()
                else if (message.content.isNotEmpty)
                  _MarkdownView(data: message.content),
                if (message.status == MessageStatus.canceled)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Generation canceled · partial text saved locally',
                        style: TextStyle(color: Color(0xffe0a33a), fontSize: 12)),
                  ),
                if (message.status == MessageStatus.error)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(message.error ?? 'Generation failed',
                        style: const TextStyle(color: Color(0xffef5350), fontSize: 12)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    if (message.content.isEmpty && message.attachments.isEmpty) return;
    final editable = message.role == MessageRole.user && message.status == MessageStatus.complete && !busy;
    final hasText = message.content.isNotEmpty;
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (hasText)
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(sheetContext);
                _copy(context);
              },
            ),
          if (hasText)
            ListTile(
              leading: const Icon(Icons.select_all_rounded),
              title: const Text('Select text'),
              onTap: () {
                Navigator.pop(sheetContext);
                _selectText(context);
              },
            ),
          if (editable)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editMessage(context);
              },
            ),
        ]),
      ),
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  void _selectText(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(message.role == MessageRole.user ? 'Your message' : 'Assistant message'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(message.content, style: const TextStyle(fontSize: 14, height: 1.4)),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: message.content)),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy all'),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  void _editMessage(BuildContext context) {
    final field = TextEditingController(text: message.content);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: field,
            maxLines: 8,
            minLines: 3,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Update your message and get a new response'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = field.text;
              Navigator.pop(dialogContext);
              onEdit(text);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    ).whenComplete(field.dispose);
  }
}

class _AttachmentView extends StatelessWidget {
  const _AttachmentView({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(attachment.path),
          width: 132,
          height: 132,
          fit: BoxFit.cover,
          cacheWidth: 264,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => Container(
            width: 132,
            height: 132,
            color: _chipSurface,
            child: const Icon(Icons.broken_image_outlined, color: _muted),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: _chipSurface, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.insert_drive_file_rounded, size: 16, color: _muted),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            attachment.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _onSurface),
          ),
        ),
      ]),
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _opacity = Tween<double>(begin: 0.35, end: 1).animate(
    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: const Text('Thinking…', style: TextStyle(color: _muted, fontSize: 14)),
      );
}

class _MarkdownView extends StatefulWidget {
  const _MarkdownView({required this.data});

  final String data;

  @override
  State<_MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<_MarkdownView> {
  Widget? _cached;
  String? _last;

  @override
  void didUpdateWidget(_MarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_last != widget.data) _cached = null;
  }

  @override
  Widget build(BuildContext context) {
    final cached = _cached;
    if (cached != null && _last == widget.data) return cached;
    final built = MarkdownBody(
      data: widget.data,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: const TextStyle(fontSize: 14.5, height: 1.45, color: _onSurface),
        listBullet: const TextStyle(fontSize: 14.5, height: 1.45, color: _onSurface),
        codeblockDecoration: BoxDecoration(color: const Color(0xff0c0e0f), borderRadius: BorderRadius.circular(8)),
        codeblockPadding: const EdgeInsets.all(10),
        code: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xffd7dade), backgroundColor: Colors.transparent),
        blockquoteDecoration: BoxDecoration(color: const Color(0xff1d2124), borderRadius: BorderRadius.circular(8)),
        horizontalRuleDecoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xff2a2f33)))),
      ),
    );
    _last = widget.data;
    _cached = built;
    return built;
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.controller, required this.input});

  final AppController controller;
  final TextEditingController input;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  static const _maxAttachmentBytes = 20 * 1024 * 1024;
  static const _maxAttachments = 6;

  final List<MessageAttachment> _attachments = <MessageAttachment>[];
  bool _hasText = false;
  bool _picking = false;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    widget.input.addListener(_onInput);
  }

  @override
  void dispose() {
    widget.input.removeListener(_onInput);
    super.dispose();
  }

  void _onInput() {
    final hasText = widget.input.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) setState(() => _hasText = hasText);
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText || _attachments.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final attachment in _attachments) _pendingPreview(attachment)],
                ),
              ),
            ),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) => IconButton(
                tooltip: 'Add photos or files',
                onPressed: controller.sending || _picking || _attachments.length >= _maxAttachments ? null : _showAttachSheet,
                icon: const Icon(Icons.add_rounded, size: 26),
                style: IconButton.styleFrom(
                  backgroundColor: _chipSurface,
                  foregroundColor: _onSurface,
                  padding: const EdgeInsets.all(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.input,
                minLines: 1,
                maxLines: 8,
                maxLength: 32000,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Ask about anything…'),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final sending = controller.sending;
                return IconButton.filled(
                  tooltip: sending ? 'Cancel generation' : 'Send',
                  onPressed: sending ? controller.cancelGeneration : (canSend ? _send : null),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Icon(
                      sending ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                      key: ValueKey(sending),
                    ),
                  ),
                );
              },
            ),
          ]),
        ]),
      ),
    );
  }

  void _send() {
    final text = widget.input.text;
    final attachments = List<MessageAttachment>.unmodifiable(_attachments);
    widget.input.clear();
    setState(() => _attachments.clear());
    FocusScope.of(context).unfocus();
    controller.sendMessage(text, attachments: attachments);
  }

  void _showAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Photos'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pick(FileType.image);
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Files'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pick(FileType.any);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _pick(FileType type) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final remaining = _maxAttachments - _attachments.length;
      final result = await FilePicker.platform.pickFiles(type: type, withData: false, allowMultiple: true);
      final picked = result?.files ?? const <PlatformFile>[];
      for (final file in picked.take(remaining)) {
        if (file.path == null) continue;
        final attachment = await _persistAttachment(file);
        if (attachment != null && mounted) setState(() => _attachments.add(attachment));
      }
    } catch (error) {
      _notify('Could not attach file: $error');
    } finally {
      if (mounted) setState(() => _picking = false);
      _picking = false;
    }
  }

  Future<MessageAttachment?> _persistAttachment(PlatformFile picked) async {
    try {
      final source = File(picked.path!);
      if (!await source.exists()) return null;
      final size = await source.length();
      if (size > _maxAttachmentBytes) {
        _notify('${picked.name} is larger than 20 MB.');
        return null;
      }
      if (size == 0) {
        _notify('${picked.name} is empty.');
        return null;
      }
      final supportDir = await getApplicationSupportDirectory();
      final attachmentsDir = Directory('${supportDir.path}${Platform.pathSeparator}attachments');
      if (!await attachmentsDir.exists()) await attachmentsDir.create(recursive: true);
      final safeName = picked.name.replaceAll(RegExp(r'[^\w.\- ()]'), '_');
      final destination = '${attachmentsDir.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}_$safeName';
      await source.copy(destination);
      final mime = _mimeFor(picked.name);
      return MessageAttachment(
        name: picked.name,
        mimeType: mime,
        isImage: mime.startsWith('image/'),
        path: destination,
      );
    } catch (error) {
      _notify('Could not attach ${picked.name}: $error');
      return null;
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _pendingPreview(MessageAttachment attachment) => Stack(children: [
        if (attachment.isImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(attachment.path),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              cacheWidth: 144,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, __, ___) => Container(
                width: 72,
                height: 72,
                color: _chipSurface,
                child: const Icon(Icons.broken_image_outlined, size: 18, color: _muted),
              ),
            ),
          )
        else
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _chipSurface, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.insert_drive_file_rounded, size: 18, color: _muted),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(attachment.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              ),
            ]),
          ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => setState(() => _attachments.remove(attachment)),
            child: Container(
              decoration: const BoxDecoration(color: Color(0xdd202124), shape: BoxShape.circle),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ),
        ),
      ]);

  String _mimeFor(String name) {
    final extension = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    const map = <String, String>{
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'heic': 'image/heic',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'md': 'text/markdown',
      'csv': 'text/csv',
      'json': 'application/json',
      'html': 'text/html',
      'xml': 'text/xml',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    };
    return map[extension] ?? 'application/octet-stream';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew});

  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.forum_outlined, size: 54, color: _onSurface),
              const SizedBox(height: 16),
              const Text('A calm place to think', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'Ask anything, attach photos or files, and keep every conversation on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
              if (onNew != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(onPressed: onNew, icon: const Icon(Icons.add), label: const Text('New conversation')),
              ],
            ],
          ),
        ),
      );
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message, required this.onDismiss, required this.onRetry});

  final String message;
  final VoidCallback onDismiss;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xff3a1d1d),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Expanded(
              child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            ),
            if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
            IconButton(onPressed: onDismiss, icon: const Icon(Icons.close), tooltip: 'Dismiss'),
          ]),
        ),
      );
}
