import 'dart:io';

import 'package:flutter/material.dart';

import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/startup/tasks/app_window_size_manager.dart';
import 'package:appflowy/workspace/application/home/home_setting_bloc.dart';
import 'package:appflowy/workspace/application/settings/appearance/appearance_cubit.dart';
import 'package:appflowy/workspace/application/sidebar/rename_view/rename_view_bloc.dart';
import 'package:appflowy/workspace/application/tabs/tabs_bloc.dart';
import 'package:appflowy/workspace/presentation/home/menu/sidebar/shared/sidebar_setting.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_profile.pb.dart';
import 'package:collection/collection.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';
import 'package:scaled_app/scaled_app.dart';

typedef KeyDownHandler = void Function(HotKey hotKey);

/// Helper class that utilizes the global [HotKeyManager] to easily
/// add a [HotKey] with different handlers.
///
/// Makes registration of a [HotKey] simple and easy to read, and makes
/// sure the [KeyDownHandler], and other handlers, are grouped with the
/// relevant [HotKey].
///
class HotKeyItem {
  HotKeyItem({
    required this.hotKey,
    this.keyDownHandler,
  });

  final HotKey hotKey;
  final KeyDownHandler? keyDownHandler;

  void register() =>
      hotKeyManager.register(hotKey, keyDownHandler: keyDownHandler);

  void unregister() => hotKeyManager.unregister(hotKey);

  HotKeyItem copyWith(HotKey? hotKey) => HotKeyItem(
        hotKey: hotKey ?? this.hotKey,
        keyDownHandler: keyDownHandler,
      );
}

class HomeHotKeys extends StatefulWidget {
  const HomeHotKeys({
    super.key,
    required this.userProfile,
    required this.child,
  });

  final UserProfilePB userProfile;
  final Widget child;

  @override
  State<HomeHotKeys> createState() => _HomeHotKeysState();
}

class _HomeHotKeysState extends State<HomeHotKeys> {
  final windowSizeManager = WindowSizeManager();

  late final items = [
    // Collapse sidebar menu
    HotKeyItem(
      hotKey: HotKey(
        Platform.isMacOS ? KeyCode.period : KeyCode.backslash,
        modifiers: [Platform.isMacOS ? KeyModifier.meta : KeyModifier.control],
        // Set hotkey scope (default is HotKeyScope.system)
        scope: HotKeyScope.inapp, // Set as inapp-wide hotkey.
        identifier: 'collapse-sidebar-menu-backslash',
      ),
      keyDownHandler: (_) => context
          .read<HomeSettingBloc>()
          .add(const HomeSettingEvent.collapseMenu()),
    ),

    // Toggle theme mode light/dark
    HotKeyItem(
      hotKey: HotKey(
        KeyCode.keyL,
        modifiers: [
          Platform.isMacOS ? KeyModifier.meta : KeyModifier.control,
          KeyModifier.shift,
        ],
        scope: HotKeyScope.inapp,
        identifier: 'toggle-theme-mode',
      ),
      keyDownHandler: (_) =>
          context.read<AppearanceSettingsCubit>().toggleThemeMode(),
    ),

    // Close current tab
    HotKeyItem(
      hotKey: HotKey(
        KeyCode.keyW,
        modifiers: [Platform.isMacOS ? KeyModifier.meta : KeyModifier.control],
        scope: HotKeyScope.inapp,
        identifier: 'close-current-tab',
      ),
      keyDownHandler: (_) =>
          context.read<TabsBloc>().add(const TabsEvent.closeCurrentTab()),
    ),

    // Go to previous tab
    HotKeyItem(
      hotKey: HotKey(
        KeyCode.pageUp,
        modifiers: [Platform.isMacOS ? KeyModifier.meta : KeyModifier.control],
        scope: HotKeyScope.inapp,
        identifier: 'navigate-previous-tab',
      ),
      keyDownHandler: (_) => _selectTab(context, -1),
    ),

    // Go to next tab
    HotKeyItem(
      hotKey: HotKey(
        KeyCode.pageDown,
        modifiers: [Platform.isMacOS ? KeyModifier.meta : KeyModifier.control],
        scope: HotKeyScope.inapp,
        identifier: 'navigate-next-tab',
      ),
      keyDownHandler: (_) => _selectTab(context, 1),
    ),

    // Rename current view
    HotKeyItem(
      hotKey: HotKey(
        KeyCode.f2,
        scope: HotKeyScope.inapp,
        identifier: 'rename-current-view',
      ),
      keyDownHandler: (_) =>
          getIt<RenameViewBloc>().add(const RenameViewEvent.open()),
    ),

    // Scale up/down the app
    HotKeyItem(
      hotKey: HotKey(
        KeyCode.equal,
        modifiers: [Platform.isMacOS ? KeyModifier.meta : KeyModifier.control],
        scope: HotKeyScope.inapp,
        identifier: 'scale-application-up',
      ),
      keyDownHandler: (_) => _scaleWithStep(0.1),
    ),

    HotKeyItem(
      hotKey: HotKey(
        KeyCode.minus,
        modifiers: [Platform.isMacOS ? KeyModifier.meta : KeyModifier.control],
        scope: HotKeyScope.inapp,
        identifier: 'scale-application-down',
      ),
      keyDownHandler: (_) => _scaleWithStep(-0.1),
    ),

    // Reset app scaling
    HotKeyItem(
      hotKey: HotKey(
        KeyCode.digit0,
        modifiers: [Platform.isMacOS ? KeyModifier.meta : KeyModifier.control],
        scope: HotKeyScope.inapp,
        identifier: 'reset-application-scaling',
      ),
      keyDownHandler: (_) => _scaleToSize(1),
    ),

    // Open settings dialog
    openSettingsHotKey(context, widget.userProfile),
  ];

  @override
  void initState() {
    super.initState();

    _registerHotKeys(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _registerHotKeys(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void updateHotkey(
    String identifier, {
    KeyCode? keyCode,
    List<KeyModifier>? modifiers,
  }) {
    final hotKeyItem =
        items.firstWhereOrNull((item) => item.hotKey.identifier == identifier);
    if (hotKeyItem == null) {
      return;
    }

    hotKeyManager.unregister(hotKeyItem.hotKey);
    final newItem = hotKeyItem.copyWith(
      HotKey(
        identifier: identifier,
        keyCode ?? hotKeyItem.hotKey.keyCode,
        modifiers: modifiers,
      ),
    );

    items.remove(hotKeyItem);
    items.add(newItem);

    newItem.register();
  }

  void _registerHotKeys(BuildContext context) {
    for (final element in items) {
      element.register();
    }
  }

  void _selectTab(BuildContext context, int change) {
    final bloc = context.read<TabsBloc>();
    bloc.add(TabsEvent.selectTab(bloc.state.currentIndex + change));
  }

  Future<void> _scaleWithStep(double step) async {
    final currentScaleFactor = await windowSizeManager.getScaleFactor();
    final textScale = (currentScaleFactor + step).clamp(
      WindowSizeManager.minScaleFactor,
      WindowSizeManager.maxScaleFactor,
    );

    Log.info('scale the app from $currentScaleFactor to $textScale');

    await _scaleToSize(textScale);
  }

  Future<void> _scaleToSize(double size) async {
    ScaledWidgetsFlutterBinding.instance.scaleFactor = (_) => size;
    await windowSizeManager.setScaleFactor(size);
  }
}
