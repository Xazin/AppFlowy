import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/plugins/ai_chat/presentation/layout_define.dart';
import 'package:flowy_infra_ui/style_widget/icon_button.dart';
import 'package:flutter/material.dart';

class ChatMessageSelector extends StatelessWidget {
  const ChatMessageSelector({
    super.key,
    required this.isSelected,
    required this.onToggle,
  });

  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: DesktopAIConvoSizes.avatarSize,
      height: DesktopAIConvoSizes.avatarSize,
      child: FlowyIconButton(
        hoverColor: Colors.transparent,
        onPressed: onToggle,
        icon: FlowySvg(
          isSelected ? FlowySvgs.check_filled_s : FlowySvgs.uncheck_s,
          blendMode: BlendMode.dst,
          size: const Size.square(20),
        ),
        width: 20,
      ),
    );
  }
}
