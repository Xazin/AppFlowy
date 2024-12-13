import 'package:appflowy/plugins/ai_chat/application/chat_entity.dart';
import 'package:appflowy/plugins/document/application/document_data_pb_extension.dart';
import 'package:appflowy/shared/markdown_to_document.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/tabs/tabs_bloc.dart';
import 'package:appflowy/workspace/application/view/prelude.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_message_selector_bloc.freezed.dart';

class ChatMessageSelectorBloc
    extends Bloc<ChatMessageSelectorEvent, ChatMessageSelectorState> {
  ChatMessageSelectorBloc({required this.parentViewId})
      : super(const ChatMessageSelectorState()) {
    on<ChatMessageSelectorEvent>(
      (event, emit) {
        event.when(
          toggleSelectingMessages: () {
            if (state.isSelectingMessages) {
              // Clear selected messages when exiting selection mode
              return emit(
                state.copyWith(
                  selectedMessages: [],
                  isSelectingMessages: false,
                ),
              );
            }

            emit(state.copyWith(isSelectingMessages: true));
          },
          toggleSelectMessage: (Message message) {
            if (state.selectedMessages.contains(message)) {
              emit(
                state.copyWith(
                  selectedMessages: state.selectedMessages
                      .where((m) => m != message)
                      .toList(),
                ),
              );
            } else {
              final selection = [...state.selectedMessages, message]..sort(
                  (a, b) => a.createdAt.compareTo(b.createdAt),
                );
              emit(state.copyWith(selectedMessages: selection));
            }
          },
          selectAllMessages: (List<Message> messages) {
            final filtered = messages.where(isAIMessage).toList();
            emit(state.copyWith(selectedMessages: filtered));
          },
          unselectAllMessages: () {
            emit(state.copyWith(selectedMessages: const []));
          },
          saveAsPage: () async {
            String completeMessage = '';
            for (final message in state.selectedMessages) {
              if (message is TextMessage) {
                completeMessage += '${message.text}\n\n';
              }
            }

            // Reset state when saving as page
            emit(
              state.copyWith(
                selectedMessages: const [],
                isSelectingMessages: false,
              ),
            );

            if (completeMessage.isEmpty) {
              return;
            }

            final document = customMarkdownToDocument(completeMessage);
            final initialBytes =
                DocumentDataPBFromTo.fromDocument(document)?.writeToBuffer();
            if (initialBytes != null) {
              final name = _extractNameFromNodes(document.root.children);

              final result = await ViewBackendService.createView(
                name: name,
                layoutType: ViewLayoutPB.Document,
                parentViewId: parentViewId,
                initialDataBytes: DocumentDataPBFromTo.fromDocument(document)
                    ?.writeToBuffer(),
              );

              result.fold(
                (view) {
                  getIt<TabsBloc>().add(
                    TabsEvent.openSecondaryPlugin(
                      plugin: view.plugin(),
                    ),
                  );
                },
                (error) => Log.error(error),
              );
            }
          },
        );
      },
    );
  }

  final String parentViewId;

  bool isMessageSelected(String messageId) =>
      state.selectedMessages.any((m) => m.id == messageId);

  bool isAIMessage(Message message) {
    return message.author.id == aiResponseUserId ||
        message.author.id == systemUserId ||
        message.author.id.startsWith("streamId:");
  }

  String _extractNameFromNodes(List<Node>? nodes) {
    if (nodes == null || nodes.isEmpty) {
      return '';
    }

    String name = '';
    for (final node in nodes) {
      if (name.length > 30) {
        return name.substring(0, name.length > 30 ? 30 : name.length);
      }

      final plainText = node.delta?.toPlainText();
      if (plainText != null) {
        name += plainText;
      }
    }

    return name.substring(0, name.length > 30 ? 30 : name.length);
  }
}

@freezed
class ChatMessageSelectorEvent with _$ChatMessageSelectorEvent {
  const factory ChatMessageSelectorEvent.toggleSelectingMessages() =
      _ToggleSelectingMessages;
  const factory ChatMessageSelectorEvent.toggleSelectMessage(Message message) =
      _ToggleSelectMessage;
  const factory ChatMessageSelectorEvent.selectAllMessages(
    List<Message> messages,
  ) = _SelectAllMessages;
  const factory ChatMessageSelectorEvent.unselectAllMessages() =
      _UnselectAllMessages;
  const factory ChatMessageSelectorEvent.saveAsPage() = _SaveAsPage;
}

@freezed
class ChatMessageSelectorState with _$ChatMessageSelectorState {
  const factory ChatMessageSelectorState({
    @Default(false) bool isSelectingMessages,
    @Default([]) List<Message> selectedMessages,
  }) = _ChatMessageSelectorState;
}
