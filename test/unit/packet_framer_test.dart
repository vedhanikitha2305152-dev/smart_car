import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_car/data/ble/packet_framer.dart';

void main() {
  group('PacketFramer Unit Tests', () {
    late PacketFramer framer;

    setUp(() {
      framer = PacketFramer();
    });

    test('emits single complete line in one packet', () {
      final input = utf8.encode('{"v":1,"fuel":54.2}\n');
      final lines = framer.feed(input);
      expect(lines, hasLength(1));
      expect(lines.first, '{"v":1,"fuel":54.2}');
    });

    test('buffers fragmented packets across MTU boundary', () {
      final chunk1 = utf8.encode('{"v":1,"fuel":5');
      final chunk2 = utf8.encode('4.2,"cap":60}\n');

      final firstResult = framer.feed(chunk1);
      expect(firstResult, isEmpty);

      final secondResult = framer.feed(chunk2);
      expect(secondResult, hasLength(1));
      expect(secondResult.first, '{"v":1,"fuel":54.2,"cap":60}');
    });

    test('extracts multiple lines delivered in a single payload', () {
      final multiLine = utf8.encode('{"line":1}\n{"line":2}\n{"line":3}\n');
      final lines = framer.feed(multiLine);
      expect(lines, hasLength(3));
      expect(lines[0], '{"line":1}');
      expect(lines[1], '{"line":2}');
      expect(lines[2], '{"line":3}');
    });

    test('preserves trailing incomplete fragment after extracting line', () {
      final payload = utf8.encode('{"complete":true}\n{"incomplete":');
      final lines1 = framer.feed(payload);
      expect(lines1, hasLength(1));
      expect(lines1.first, '{"complete":true}');

      final finish = utf8.encode('false}\n');
      final lines2 = framer.feed(finish);
      expect(lines2, hasLength(1));
      expect(lines2.first, '{"incomplete":false}');
    });

    test('reset clears internal buffer', () {
      framer.feed(utf8.encode('{"partial"'));
      framer.reset();

      final lines = framer.feed(utf8.encode('{"fresh":1}\n'));
      expect(lines, hasLength(1));
      expect(lines.first, '{"fresh":1}');
    });
  });
}
