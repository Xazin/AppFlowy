import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/settings/application_data_storage.dart';
import 'package:appflowy/workspace/application/settings/shortcuts/shortcuts.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import 'shortcuts_model.dart';

class SettingsShortcutService {
  /// If file is non-null then the SettingsShortcutService uses that file
  /// to store all the shortcuts, otherwise uses the default Document Directory.
  ///
  /// Typically we only intend to pass a file during testing.
  ///
  SettingsShortcutService({File? file}) {
    _initializeService(file);
  }

  late final File _file;
  final _initCompleter = Completer<void>();

  /// Takes in commandShortcuts as an input and saves them to the shortcuts.JSON file.
  Future<void> saveAllShortcuts(
    List<ShortcutGroup> shortcutGroups,
  ) async {
    final List<CommandShortcutModel> shortcutModels = [];

    await _file.writeAsString(
      jsonEncode(EditorShortcuts(commandShortcuts: shortcutModels).toJson()),
      flush: true,
    );
  }

  /// Checks the file for saved shortcuts. If shortcuts do NOT exist then returns
  /// an empty list. If shortcuts exist
  /// then calls an utility method i.e getShortcutsFromJson which returns the saved shortcuts.
  Future<List<CommandShortcutModel>> getCustomizeShortcuts() async {
    await _initCompleter.future;
    final shortcutsInJson = await _file.readAsString();

    if (shortcutsInJson.isEmpty) {
      return [];
    } else {
      return getShortcutsFromJson(shortcutsInJson);
    }
  }

  /// Extracts shortcuts from the saved json file. The shortcuts in the saved file consist of [List<CommandShortcutModel>].
  /// This list needs to be converted to List<CommandShortcutEvent\>. This function is intended to facilitate the same.
  List<CommandShortcutModel> getShortcutsFromJson(String savedJson) {
    final shortcuts = EditorShortcuts.fromJson(jsonDecode(savedJson));
    return shortcuts.commandShortcuts;
  }

  Future<void> updateCommandShortcuts(
    List<CommandShortcutEvent> commandShortcuts,
    List<CommandShortcutModel> customizeShortcuts,
  ) async {
    for (final shortcut in customizeShortcuts) {
      final shortcutEvent = commandShortcuts.firstWhereOrNull(
        (s) => s.key == shortcut.key && s.command != shortcut.command,
      );
      shortcutEvent?.updateCommand(command: shortcut.command);
    }
  }

  Future<void> resetToDefaultShortcuts() async {
    await _initCompleter.future;
    await saveAllShortcuts([]);
  }

  // Accesses the shortcuts.json file within the default AppFlowy Document Directory or creates a new file if it already doesn't exist.
  Future<void> _initializeService(File? file) async {
    _file = file ?? await _defaultShortcutFile();
    _initCompleter.complete();
  }

  //returns the default file for storing shortcuts
  Future<File> _defaultShortcutFile() async {
    final path = await getIt<ApplicationDataStorage>().getPath();
    return File(
      p.join(path, 'shortcuts', 'shortcuts.json'),
    )..createSync(recursive: true);
  }
}

extension ToGroupedModel on List<CommandShortcutEvent> {
  List<CommandShortcutModel> toGroupedList(ShortcutGroup group) {
    return map(
      (shortcut) => CommandShortcutModel.fromCommandEvent(shortcut),
    ).toList();
  }
}
