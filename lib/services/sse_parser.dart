import 'dart:convert';

class SseEvent {
  const SseEvent({required this.data, this.event});

  final String data;
  final String? event;
}

class SseEventAccumulator {
  static const _maxEventBytes = 8 * 1024 * 1024;

  final List<String> _data = <String>[];
  String? _event;
  int _bufferedBytes = 0;

  SseEvent? addLine(String line) {
    if (line.isEmpty) return _emit();
    if (line.startsWith(':')) return null;
    final separator = line.indexOf(':');
    final field = separator < 0 ? line : line.substring(0, separator);
    var value = separator < 0 ? '' : line.substring(separator + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    if (field == 'data') {
      if (_bufferedBytes + value.length > _maxEventBytes) {
        _data.clear();
        _bufferedBytes = 0;
        return null;
      }
      _data.add(value);
      _bufferedBytes += value.length;
    }
    if (field == 'event') _event = value;
    return null;
  }

  SseEvent? flush() => _emit();

  SseEvent? _emit() {
    if (_data.isEmpty && _event == null) return null;
    final event = SseEvent(data: _data.join('\n'), event: _event);
    _data.clear();
    _bufferedBytes = 0;
    _event = null;
    return event;
  }

  static Stream<SseEvent> fromBytes(Stream<List<int>> bytes) async* {
    final accumulator = SseEventAccumulator();
    final lines = bytes.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter());
    await for (final line in lines) {
      final event = accumulator.addLine(line);
      if (event != null) yield event;
    }
    final finalEvent = accumulator.flush();
    if (finalEvent != null) yield finalEvent;
  }
}
