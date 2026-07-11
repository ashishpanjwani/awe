import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanderwell/models/quest_card.dart';
import 'package:wanderwell/services/location_service.dart';
import 'package:wanderwell/services/quest_rag_service.dart';

abstract class QuestsTabState {}

class QuestsTabInitial extends QuestsTabState {}

class QuestsTabLoading extends QuestsTabState {
  final String city;
  QuestsTabLoading(this.city);
}

class QuestsTabLoaded extends QuestsTabState {
  final String city;
  final List<QuestCard> quests;
  QuestsTabLoaded(this.city, this.quests);
}

class QuestsTabError extends QuestsTabState {
  final String message;
  final String city;
  QuestsTabError(this.message, this.city);
}

class QuestsTabCubit extends Cubit<QuestsTabState> {
  QuestsTabCubit() : super(QuestsTabInitial());

  Future<void> loadForCurrentLocation() async {
    try {
      final loc = await LocationService().getCurrentLocationWithName();
      final city = loc?.name ?? 'New Delhi';
      await loadQuests(city);
    } catch (e) {
      debugPrint('[QuestsTab] Location failed, using default: $e');
      await loadQuests('New Delhi');
    }
  }

  Future<void> loadQuests(String city) async {
    emit(QuestsTabLoading(city));
    try {
      final quests = await QuestRagService().getQuestsForLocation(city);
      emit(QuestsTabLoaded(city, quests));
    } catch (e) {
      emit(QuestsTabError(e.toString(), city));
    }
  }

  Future<void> refresh() async {
    final current = state;
    final city = current is QuestsTabLoaded
        ? current.city
        : current is QuestsTabLoading
            ? current.city
            : current is QuestsTabError
                ? current.city
                : 'New Delhi';
    await loadQuests(city);
  }
}
