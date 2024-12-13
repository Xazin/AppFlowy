import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/ai_chat/application/chat_message_selector_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/style_widget/button.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

class ChatMessageSelectorBanner extends StatelessWidget {
  const ChatMessageSelectorBanner({super.key, this.allMessages = const []});

  final List<Message> allMessages;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatMessageSelectorBloc, ChatMessageSelectorState>(
      builder: (context, state) {
        if (!state.isSelectingMessages) {
          return const SizedBox.shrink();
        }

        final selectedAmount = state.selectedMessages.length;
        final totalAmount = allMessages.length;
        final allSelected = selectedAmount == totalAmount;

        return Container(
          height: 48,
          color: const Color(0xFF00BCF0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Flexible(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (selectedAmount > 0) {
                            return _unselectAllMessages(context);
                          }

                          _selectAllMessages(context);
                        },
                        child: FlowySvg(
                          allSelected
                              ? FlowySvgs.checkbox_ai_selected_s
                              : selectedAmount > 0
                                  ? FlowySvgs.checkbox_ai_minus_s
                                  : FlowySvgs.checkbox_ai_empty_s,
                          blendMode: BlendMode.dstIn,
                          size: const Size.square(18),
                        ),
                      ),
                      const HSpace(8),
                      FlowyText.semibold(
                        allSelected
                            ? LocaleKeys.chat_selectBanner_allSelected.tr()
                            : selectedAmount > 0
                                ? LocaleKeys.chat_selectBanner_nSelected
                                    .tr(args: [selectedAmount.toString()])
                                : LocaleKeys.chat_selectBanner_selectMessages
                                    .tr(),
                        figmaLineHeight: 16,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                Opacity(
                  opacity: selectedAmount == 0 ? 0.5 : 1,
                  child: FlowyTextButton(
                    LocaleKeys.moreAction_saveAsNewPage.tr(),
                    onPressed: selectedAmount == 0
                        ? null
                        : () => context
                            .read<ChatMessageSelectorBloc>()
                            .add(const ChatMessageSelectorEvent.saveAsPage()),
                    fontColor: Colors.white,
                    borderColor: Colors.white,
                    fillColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
                const HSpace(8),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.read<ChatMessageSelectorBloc>().add(
                          const ChatMessageSelectorEvent
                              .toggleSelectingMessages(),
                        ),
                    child: const FlowySvg(
                      FlowySvgs.close_m,
                      color: Colors.white,
                      size: Size.square(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectAllMessages(BuildContext context) => context
      .read<ChatMessageSelectorBloc>()
      .add(ChatMessageSelectorEvent.selectAllMessages(allMessages));

  void _unselectAllMessages(BuildContext context) => context
      .read<ChatMessageSelectorBloc>()
      .add(const ChatMessageSelectorEvent.unselectAllMessages());
}
