import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_page.dart';
import 'package:appflowy/workspace/application/settings/shortcuts/settings_shortcuts_service.dart';
import 'package:appflowy/workspace/application/settings/shortcuts/shortcuts_model.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_shortcuts_cubit.freezed.dart';

@freezed
class ShortcutsState with _$ShortcutsState {
  const factory ShortcutsState({
    @Default(<CommandShortcutEvent>[])
    Map<ShortcutGroup, List<CommandShortcutModel>> commandShortcutModels,
    @Default(ShortcutsStatus.initial) ShortcutsStatus status,
    @Default('') String error,
  }) = _ShortcutsState;
}

enum ShortcutsStatus { initial, updating, success, failure }

class ShortcutsCubit extends Cubit<ShortcutsState> {
  ShortcutsCubit(this.service)
      : super(
          const ShortcutsState(commandShortcutModels: {}),
        );

  final SettingsShortcutService service;

  Future<void> fetchShortcuts() async {
    emit(
      state.copyWith(
        status: ShortcutsStatus.updating,
        error: '',
      ),
    );

    try {
      final customizeShortcuts = await service.getCustomizeShortcuts();
      await service.updateCommandShortcuts(
        defaultCommandShortcutEvents,
        customizeShortcuts,
      );

      //sort the shortcuts
      defaultCommandShortcutEvents.sort(
        (a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()),
      );

      emit(
        state.copyWith(
          status: ShortcutsStatus.success,
          commandShortcutModels: groupedCommandShortcutEvents,
          error: '',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ShortcutsStatus.failure,
          error: LocaleKeys.settings_shortcuts_couldNotLoadErrorMsg.tr(),
        ),
      );
    }
  }

  Future<void> updateAllShortcuts() async {
    emit(
      state.copyWith(
        status: ShortcutsStatus.updating,
        error: '',
      ),
    );
    try {
      await service.saveAllShortcuts(state.commandShortcuts);
      emit(
        state.copyWith(
          status: ShortcutsStatus.success,
          error: '',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ShortcutsStatus.failure,
          error: LocaleKeys.settings_shortcuts_couldNotSaveErrorMsg.tr(),
        ),
      );
    }
  }

  Future<void> resetToDefault() async {
    emit(
      state.copyWith(
        status: ShortcutsStatus.updating,
        error: '',
      ),
    );
    try {
      await service.saveAllShortcuts(groupedCommandShortcutEvents);
      await fetchShortcuts();
    } catch (e) {
      emit(
        state.copyWith(
          status: ShortcutsStatus.failure,
          error: LocaleKeys.settings_shortcuts_couldNotSaveErrorMsg.tr(),
        ),
      );
    }
  }

  /// Checks if the new command is conflicting with other shortcut
  /// We also check using the key, whether this command is a codeblock
  /// shortcut, if so we only check a conflict with other codeblock shortcut.
  String getConflict(CommandShortcutEvent currentShortcut, String command) {
    // check if currentShortcut is a codeblock shortcut.
    final isCodeBlockCommand = currentShortcut.isCodeBlockCommand;

    for (final e in state.commandShortcutEvents) {
      if (e.command == command && e.isCodeBlockCommand == isCodeBlockCommand) {
        return e.key;
      }
    }
    return '';
  }
}

extension on CommandShortcutEvent {
  bool get isCodeBlockCommand => localizedCodeBlockCommands.contains(this);
}
