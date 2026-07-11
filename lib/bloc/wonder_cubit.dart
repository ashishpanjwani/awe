import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/models/wonder_user_state.dart';
import 'package:wanderwell/services/wonder_service.dart';
import 'package:wanderwell/services/wonder_user_service.dart';

abstract class WonderState {}

class WonderInitial extends WonderState {}

class WonderLoading extends WonderState {}

class WonderLoaded extends WonderState {
  final Wonder wonder;
  final WonderUserState userState;
  final int globalLikeCount;
  WonderLoaded(this.wonder, this.userState, this.globalLikeCount);
}

class WonderError extends WonderState {
  final String message;
  WonderError(this.message);
}

class WonderCubit extends Cubit<WonderState> {
  WonderCubit() : super(WonderInitial());

  Future<void> loadTodayWonder({bool refresh = false}) async {
    emit(WonderLoading());
    try {
      var wonder = await WonderService().getTodayWonder(refresh: refresh);
      wonder = await WonderService().enrichWithImage(wonder);
      // Streak: user showed up today
      await WonderUserService().markStreak();
      final userState = await WonderUserService().getState();
      final likeCount = await WonderUserService().getLikeCount(wonder.id);
      emit(WonderLoaded(wonder, userState, likeCount));
    } catch (e) {
      emit(WonderError(e.toString()));
    }
  }

  Future<void> toggleLike(String wonderId) async {
    final current = state;
    if (current is! WonderLoaded) return;
    final wasLiked = current.userState.isWonderSaved(wonderId);
    await WonderUserService().toggleSave(wonderId);
    // Only update stats on like, not on unlike
    if (!wasLiked) {
      await WonderUserService().markEngaged(current.wonder);
    }
    final updatedState = await WonderUserService().getState();
    final likeCount = await WonderUserService().getLikeCount(wonderId);
    emit(WonderLoaded(current.wonder, updatedState, likeCount));
  }
}
