import 'dart:convert';
import 'enums.dart';

enum CommandResult { success, failure, timeout }

class VehicleCommand {
  VehicleCommand({
    required this.seq,
    required this.cmd,
    this.val,
  });

  final int seq;
  final String cmd;
  final dynamic val;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'seq': seq,
        'cmd': cmd,
        if (val != null) 'val': val,
      };

  String toJsonString() => '${jsonEncode(toJson())}\n';

  factory VehicleCommand.lock(int seq) =>
      VehicleCommand(seq: seq, cmd: 'lock', val: true);

  factory VehicleCommand.unlock(int seq) =>
      VehicleCommand(seq: seq, cmd: 'lock', val: false);

  factory VehicleCommand.driveMode(int seq, DriveMode mode) => VehicleCommand(
        seq: seq,
        cmd: 'drive_mode',
        val: mode.name.toUpperCase(),
      );

  factory VehicleCommand.snapshot(int seq) =>
      VehicleCommand(seq: seq, cmd: 'snapshot');

  factory VehicleCommand.lights(int seq, {required bool on}) =>
      VehicleCommand(seq: seq, cmd: 'lights', val: on);
}
