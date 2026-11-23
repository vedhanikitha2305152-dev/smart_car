/// Buffers incoming bytes from BLE notifications and emits complete
/// newline-delimited UTF-8 lines.
///
/// BLE packets may be split across MTU boundaries. This class accumulates
/// bytes until a '\n' delimiter is found, then returns the complete line.
class PacketFramer {
  final _buffer = StringBuffer();

  /// Feed raw bytes; returns a list of complete JSON lines (without '\n').
  List<String> feed(List<int> bytes) {
    final chunk = String.fromCharCodes(bytes);
    _buffer.write(chunk);
    final raw = _buffer.toString();
    final lines = <String>[];
    var start = 0;
    for (var i = 0; i < raw.length; i++) {
      if (raw[i] == '\n') {
        final line = raw.substring(start, i).trim();
        if (line.isNotEmpty) lines.add(line);
        start = i + 1;
      }
    }
    _buffer.clear();
    if (start < raw.length) {
      _buffer.write(raw.substring(start));
    }
    return lines;
  }

  void reset() => _buffer.clear();
}
