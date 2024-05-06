import 'package:flutter/widgets.dart';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'board_selector_bloc.freezed.dart';

class BoardSelectorBloc extends Bloc<BoardSelectorEvent, BoardSelectorState> {
  BoardSelectorBloc() : super(const BoardSelectorState()) {
    on<BoardSelectorEvent>((event, emit) {
      event.when(
        startDragging: (Offset startPosition) {
          emit(
            state.copyWith(
              isDragging: true,
              startPosition: startPosition,
              endPosition: startPosition,
            ),
          );
        },
        addDrag: (Offset position) {
          emit(state.copyWith(endPosition: position));
        },
        endDragging: () {
          emit(state.copyWith(isDragging: false));
        },
      );
    });
  }
}

@freezed
class BoardSelectorEvent with _$BoardSelectorEvent {
  const factory BoardSelectorEvent.startDragging(Offset startPosition) =
      _StartDragging;
  const factory BoardSelectorEvent.addDrag(Offset position) = _AddDrag;
  const factory BoardSelectorEvent.endDragging() = _EndDragging;
}

@freezed
class BoardSelectorState with _$BoardSelectorState {
  const factory BoardSelectorState({
    @Default(false) bool isDragging,
    @Default(null) Offset? startPosition,
    @Default(null) Offset? endPosition,
  }) = _BoardSelectorState;
}

  // const factory DocumentPageStyleState({
  //   @Default(PageStyleFontLayout.normal) PageStyleFontLayout fontLayout,
  //   @Default(PageStyleLineHeightLayout.normal)
  //   PageStyleLineHeightLayout lineHeightLayout,
  //   // the default font family is null, which means the system font
  //   @Default(null) String? fontFamily,
  //   @Default(2.0) double iconPadding,
  //   required PageStyleCover coverImage,
  // }) = _DocumentPageStyleState;
