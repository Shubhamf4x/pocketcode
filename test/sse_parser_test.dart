import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcode/services/sse_parser.dart';

void main() {
  test('buffers multiline data and split UTF-8 chunks', () async {
    final source = 'event: message\ndata: {"a":\ndata: "b"}\n\n' 'data: [DONE]\n\n';
    final bytes = utf8.encode(source);
    final events = await SseEventAccumulator.fromBytes(Stream.fromIterable(<List<int>>[
      bytes.sublist(0, 7),
      bytes.sublist(7, 19),
      bytes.sublist(19),
    ])).toList();
    expect(events.first.event, 'message');
    expect(events.first.data, '{"a":\n"b"}');
    expect(events.last.data, '[DONE]');
  });

  test('flushes an event without a trailing blank line', () async {
    final events = await SseEventAccumulator.fromBytes(Stream.value(utf8.encode('data: hello'))).toList();
    expect(events.single.data, 'hello');
  });
}
