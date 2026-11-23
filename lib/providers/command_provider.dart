import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/enums.dart';
import '../data/models/vehicle_command.dart';
import 'repository_provider.dart';

final _log = Logger('CommandProvider');

const String _prefKeyCommandSeq = 'ble_command_seq';

/// Monotonically increasing command sequence provider backed by SharedPreferences
final commandSeqProvider = StateNotifierProvider<CommandSeqNotifier, int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CommandSeqNotifier(prefs);
});

class CommandSeqNotifier extends StateNotifier<int> {
  CommandSeqNotifier(this._prefs) : super(_prefs.getInt(_prefKeyCommandSeq) ?? 0);

  final SharedPreferences _prefs;

  int next() {
    state = state + 1;
    _prefs.setInt(_prefKeyCommandSeq, state);
    return state;
  }
}

/// State of an active in-flight vehicle command
class VehicleCommandState {
  const VehicleCommandState({
    this.isPending = false,
    this.lastCommand,
    this.lastResult,
    this.errorMessage,
  });

  final bool isPending;
  final String? lastCommand;
  final CommandResult? lastResult;
  final String? errorMessage;

  VehicleCommandState copyWith({
    bool? isPending,
    String? lastCommand,
    CommandResult? lastResult,
    String? errorMessage,
  }) {
    return VehicleCommandState(
      isPending: isPending ?? this.isPending,
      lastCommand: lastCommand ?? this.lastCommand,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: errorMessage,
    );
  }
}

class CommandController extends StateNotifier<VehicleCommandState> {
  CommandController(this.ref) : super(const VehicleCommandState());

  final Ref ref;

  Future<CommandResult> sendLock({required bool locked}) async {
    return _executeCommand(
      'lock',
      (seq) => locked ? VehicleCommand.lock(seq) : VehicleCommand.unlock(seq),
    );
  }

  Future<CommandResult> sendDriveMode(DriveMode mode) async {
    return _executeCommand(
      'drive_mode',
      (seq) => VehicleCommand.driveMode(seq, mode),
    );
  }

  Future<CommandResult> sendLights({required bool on}) async {
    return _executeCommand(
      'lights',
      (seq) => VehicleCommand.lights(seq, on: on),
    );
  }

  Future<CommandResult> requestSnapshot() async {
    return _executeCommand(
      'snapshot',
      (seq) => VehicleCommand.snapshot(seq),
    );
  }

  Future<CommandResult> _executeCommand(
    String commandName,
    VehicleCommand Function(int seq) commandFactory,
  ) async {
    final repo = ref.read(vehicleRepositoryProvider);
    final seq = ref.read(commandSeqProvider.notifier).next();
    final command = commandFactory(seq);

    state = state.copyWith(
      isPending: true,
      lastCommand: commandName,
      errorMessage: null,
    );

    _log.info('Dispatching command: $commandName (seq=$seq)');

    try {
      final result = await repo.send(command).timeout(
        const Duration(seconds: 3),
        onTimeout: () => CommandResult.timeout,
      );

      if (result == CommandResult.success) {
        HapticFeedback.mediumImpact();
        state = state.copyWith(
          isPending: false,
          lastResult: CommandResult.success,
        );
      } else {
        HapticFeedback.heavyImpact();
        state = state.copyWith(
          isPending: false,
          lastResult: result,
          errorMessage: result == CommandResult.timeout
              ? 'Command timed out after 3 seconds'
              : 'Vehicle rejected command',
        );
      }
      return result;
    } catch (e, st) {
      _log.severe('Error dispatching command $commandName: $e\n$st');
      HapticFeedback.heavyImpact();
      state = state.copyWith(
        isPending: false,
        lastResult: CommandResult.failure,
        errorMessage: 'Communication error: $e',
      );
      return CommandResult.failure;
    }
  }
}

final commandControllerProvider =
    StateNotifierProvider<CommandController, VehicleCommandState>((ref) {
  return CommandController(ref);
});
