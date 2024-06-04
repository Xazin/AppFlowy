import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appflowy/plugins/document/presentation/editor_page.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/align_toolbar_item/custom_text_align_command.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/copy_and_paste/custom_copy_command.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/copy_and_paste/custom_cut_command.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/copy_and_paste/custom_paste_command.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/toggle/toggle_block_shortcut_event.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/settings/application_data_storage.dart';
import 'package:appflowy/workspace/presentation/home/hotkeys.dart';
import 'package:appflowy/workspace/presentation/settings/widgets/emoji_picker/emoji_shortcut_event.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:path/path.dart' as p;

part 'shortcuts.freezed.dart';
part 'shortcuts.g.dart';

List<ShortcutGroup> _getDefaultShortcutGroups() {
  final standardCommandShortcuts = standardCommandShortcutEvents
    ..removeWhere(
      (shortcut) => [
        copyCommand,
        cutCommand,
        pasteCommand,
        toggleTodoListCommand,
      ].contains(shortcut),
    );

  return [
    ShortcutGroup(
      category: ShortcutCategory.general,
      shortcuts: [
        ...standardCommandShortcuts
            .map((c) => AFShortcut(commandShortcut: c.toDescription())),
      ],
    ),
  ];
}

final _defaultCommandShortcutEvents = [
  toggleToggleListCommand,
  ...localizedCodeBlockCommands,
  customCopyCommand,
  customPasteCommand,
  customCutCommand,
  ...customTextAlignCommands,

  // remove standard shortcuts for copy, cut, paste, todo
  ...standardCommandShortcutEvents
    ..removeWhere(
      (shortcut) => [
        copyCommand,
        cutCommand,
        pasteCommand,
        toggleTodoListCommand,
      ].contains(shortcut),
    ),

  emojiShortcutEvent,
];

/// Used to manage shortcuts across the application, both for
/// application-wide or localized for eg. the AppFlowyEditor.
///
abstract class IShortcutService {
  const IShortcutService();

  /// Retrieves all [AFShortcut]s, primarily used in eg. Settings
  /// to show all shortcuts in the application.
  ///
  List<ShortcutGroup> getAllShortcuts();

  /// Updates the [command] value for a [CommandShortcutEvent] by
  /// it's [key] value.
  ///
  void updateCommandShortcut(String key, String command);

  /// Retrieves all [CommandShortcutEvent]s, used primarily in cases of
  /// [AppFlowyEditor].
  ///
  List<CommandShortcutEvent> getCommandShortcuts();

  /// Used to update the [KeyCode] and [KeyModifier]s of a [HotKeyItem] by
  /// its [identifier].
  ///
  void updateApplicationShortcut(
    String identifier,
    KeyCode keyCode, [
    List<KeyModifier>? modifiers,
  ]);
}

class ShortcutService implements IShortcutService {
  ShortcutService({File? file}) {
    _initialize(file);
  }

  late final File _storage;
  final Completer<void> _completer = Completer();

  Future<void> _initialize(File? file) async {
    _storage = file ?? await _defaultShortcutsFile();

    try {
      final json = jsonDecode(await _storage.readAsString())
          as List<Map<String, dynamic>>?;
      if (json == null) {}
    } catch (e) {}

    _completer.complete();
  }

  Future<File> _defaultShortcutsFile() async {
    final path = await getIt<ApplicationDataStorage>().getPath();
    return File(
      p.join(path, 'shortcuts', 'shortcuts.json'),
    )..createSync(recursive: true);
  }

  @override
  List<ShortcutGroup> getAllShortcuts() {
    throw UnimplementedError();
  }

  @override
  List<CommandShortcutEvent> getCommandShortcuts() {
    return _defaultCommandShortcutEvents;
  }

  @override
  void updateApplicationShortcut(
    String identifier,
    KeyCode keyCode, [
    List<KeyModifier>? modifiers,
  ]) {}

  @override
  void updateCommandShortcut(String key, String command) {}
}

/// A simple wrapper class for a semantic group of [AFShortcut]s
///
@freezed
class ShortcutGroup with _$ShortcutGroup {
  const factory ShortcutGroup({
    required ShortcutCategory category,
    required List<AFShortcut>? shortcuts,
  }) = _ShortcutGroup;

  factory ShortcutGroup.fromJson(Map<String, Object?> json) =>
      _$ShortcutGroupFromJson(json);
}

/// [AFShortcut] is a helper data-class that encapsulates shortcuts used both in
/// the [AppFlowyEditor] in the form of [CommandShortcutEvent]s, [CharacterShortcutEvent]s, as well as
/// shortcuts used application-wide in AppFlowy in form of [HotKeyItem]s.
///
/// An [AFShortcut] instance should only have either a [CommandShortcutEventDescription], or a [CharacterShortcutEventDescription] or a
/// [HotKey], providing two or more is meaningless, and only one value will be retained.
///
@freezed
class AFShortcut with _$AFShortcut {
  AFShortcut._();

  const factory AFShortcut({
    CommandShortcutEventDescription? commandShortcut,
    CharacterShortcutEventDescription? characterShortcut,
    HotKey? appShortcut,
  }) = _AFShortcut;

  factory AFShortcut.fromJson(Map<String, Object?> json) =>
      _$AFShortcutFromJson(json);

  bool get isAppShortcut => appShortcut != null;
  bool get isCommandShortcut => commandShortcut != null;
  bool get isCharacterShortcut => characterShortcut != null;
}

/// Is used to describe a [CommandShortcutEvent], used to persist
/// information about a command shortcut.
///
@freezed
class CommandShortcutEventDescription with _$CommandShortcutEventDescription {
  const factory CommandShortcutEventDescription({
    required String key,
    required String command,
  }) = _CommandShortcutEventDescription;

  factory CommandShortcutEventDescription.fromJson(Map<String, Object?> json) =>
      _$CommandShortcutEventDescriptionFromJson(json);
}

extension ToCommandDescription on CommandShortcutEvent {
  CommandShortcutEventDescription toDescription() =>
      CommandShortcutEventDescription(
        key: key,
        command: command,
      );
}

/// Is used to describe a [CharacterShortcutEvent], used to persist
/// information about a command shortcut.
///
@freezed
class CharacterShortcutEventDescription
    with _$CharacterShortcutEventDescription {
  const factory CharacterShortcutEventDescription({
    required String key,
    required String character,
  }) = _CharacterShortcutEventDescription;

  factory CharacterShortcutEventDescription.fromJson(
          Map<String, Object?> json) =>
      _$CharacterShortcutEventDescriptionFromJson(json);
}

extension ToCharacterDescription on CharacterShortcutEvent {
  CharacterShortcutEventDescription toDescription() =>
      CharacterShortcutEventDescription(
        key: key,
        character: character,
      );
}

/// An enum with the available categories of an [AFShortcut].
///
/// This is used primarily to group shortcuts in settings, to provide better
/// semantic separation of shortcuts to the user.
///
enum ShortcutCategory {
  general,
  navigation,
  textStyling,
  selection,
  codeBlock,
  table,
  list,
  other;

  // Do not edit existing values at will, we use these to
  // store/load the shortcuts from local storage.
  @override
  String toString() => switch (this) {
        ShortcutCategory.general => 'general',
        ShortcutCategory.navigation => 'navigation',
        ShortcutCategory.textStyling => 'textStyling',
        ShortcutCategory.selection => 'selection',
        ShortcutCategory.codeBlock => 'codeBlock',
        ShortcutCategory.table => 'table',
        ShortcutCategory.list => 'list',
        ShortcutCategory.other => 'other',
      };

  static ShortcutCategory fromString(String value) => switch (value) {
        'general' => ShortcutCategory.general,
        'navigation' => ShortcutCategory.navigation,
        'textStyling' => ShortcutCategory.textStyling,
        'selection' => ShortcutCategory.selection,
        'codeBlock' => ShortcutCategory.codeBlock,
        'table' => ShortcutCategory.table,
        'list' => ShortcutCategory.list,
        _ => ShortcutCategory.other,
      };
}
