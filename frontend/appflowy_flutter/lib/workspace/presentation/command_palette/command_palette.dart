import 'dart:io';

import 'package:flutter/material.dart';

import 'package:appflowy/workspace/application/command_palette/command_palette_bloc.dart';
import 'package:appflowy/workspace/presentation/home/hotkeys.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

HotKeyItem commandPaletteHotKey(BuildContext context) => HotKeyItem(
      hotKey: HotKey(
        KeyCode.keyP,
        modifiers: [
          Platform.isMacOS ? KeyModifier.meta : KeyModifier.control,
        ],
      ),
      keyDownHandler: (_) => CommandPalette.of(context).toggle(),
    );

class CommandPalette extends InheritedWidget {
  CommandPalette({
    super.key,
    required Widget? child,
    required ValueNotifier<bool> toggleNotifier,
  })  : _toggleNotifier = toggleNotifier,
        super(
          child: _CommandPaletteController(
            toggleNotifier: toggleNotifier,
            child: child,
          ),
        );

  final ValueNotifier<bool> _toggleNotifier;

  void toggle() => _toggleNotifier.value = !_toggleNotifier.value;

  static CommandPalette of(BuildContext context) {
    final CommandPalette? result =
        context.dependOnInheritedWidgetOfExactType<CommandPalette>();

    assert(result != null, "CommandPalette could not be found");

    return result!;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

class _CommandPaletteController extends StatefulWidget {
  const _CommandPaletteController({
    required this.toggleNotifier,
    required this.child,
  });

  final Widget? child;
  final ValueNotifier<bool> toggleNotifier;

  @override
  State<_CommandPaletteController> createState() =>
      _CommandPaletteControllerState();
}

class _CommandPaletteControllerState extends State<_CommandPaletteController> {
  late ValueNotifier<bool> _toggleNotifier = widget.toggleNotifier;
  bool _isOpen = false;

  @override
  void didUpdateWidget(covariant _CommandPaletteController oldWidget) {
    if (oldWidget.toggleNotifier != widget.toggleNotifier) {
      _toggleNotifier.removeListener(_onToggle);
      _toggleNotifier.dispose();
      _toggleNotifier = widget.toggleNotifier;

      // If widget is changed, eg. on theme mode hotkey used
      // while modal is shown, set the value before listening
      _toggleNotifier.value = _isOpen;

      _toggleNotifier.addListener(_onToggle);
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void initState() {
    super.initState();
    _toggleNotifier.addListener(_onToggle);
  }

  @override
  void dispose() {
    _toggleNotifier.removeListener(_onToggle);
    _toggleNotifier.dispose();
    super.dispose();
  }

  void _onToggle() {
    if (widget.toggleNotifier.value && !_isOpen) {
      _isOpen = true;
      FlowyOverlay.show(
        context: context,
        builder: (BuildContext context) => const CommandPaletteModal(),
      ).then((_) {
        _isOpen = false;
        widget.toggleNotifier.value = false;
      });
    } else if (!widget.toggleNotifier.value && _isOpen) {
      FlowyOverlay.pop(context);
      _isOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child != null) {
      return widget.child!;
    }

    return const SizedBox.shrink();
  }
}

class CommandPaletteModal extends StatelessWidget {
  const CommandPaletteModal({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CommandPaletteBloc>(
      create: (_) => CommandPaletteBloc(),
      child: BlocBuilder<CommandPaletteBloc, CommandPaletteState>(
        builder: (context, state) {
          return FlowyDialog(
            alignment: Alignment.topCenter,
            insetPadding: const EdgeInsets.only(top: 100),
            constraints: const BoxConstraints(maxHeight: 400, maxWidth: 510),
            expandHeight: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FlowyTextField(
                  controller: TextEditingController(),
                  onChanged: (value) => context
                      .read<CommandPaletteBloc>()
                      .add(CommandPaletteEvent.searchChanged(search: value)),
                ),
                // TODO: Show results based on state of CommandPaletteBloc
              ],
            ),
          );
        },
      ),
    );
  }
}