import 'dart:async';

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

          _timer?.cancel();
          _timer = Timer.periodic(
            const Duration(milliseconds: 100),
            (_) => _evaluateEmit,
          );
        },
        addDrag: (Offset position) => _endOffset = position,
        notifyDrag: () => emit(state.copyWith(endPosition: _endOffset)),
        endDragging: () {
          _timer?.cancel();
          _timer = null;
          emit(state.copyWith(isDragging: false));
        },
      );
    });
  }

  Timer? _timer;

  Offset? _startOffset;
  Offset? _endOffset;

  void _evaluateEmit() {
    if (!state.isDragging) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    if (state.startPosition != _startOffset ||
        state.endPosition != _endOffset) {
      add(const BoardSelectorEvent.notifyDrag());
    }
  }
}

@freezed
class BoardSelectorEvent with _$BoardSelectorEvent {
  const factory BoardSelectorEvent.startDragging(Offset startPosition) =
      _StartDragging;
  const factory BoardSelectorEvent.addDrag(Offset position) = _AddDrag;
  const factory BoardSelectorEvent.notifyDrag() = _NotifyDrag;
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
