import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanderwell/models/journey.dart';
import 'package:wanderwell/services/journey_service.dart';

abstract class JourneyState {}

class JourneyInitial extends JourneyState {}

class JourneyLoading extends JourneyState {}

class JourneyListLoaded extends JourneyState {
  final List<Journey> journeys;
  JourneyListLoaded(this.journeys);
}

class JourneyDetailLoaded extends JourneyState {
  final Journey journey;
  JourneyDetailLoaded(this.journey);
}

class JourneyError extends JourneyState {
  final String message;
  JourneyError(this.message);
}

class JourneyCubit extends Cubit<JourneyState> {
  JourneyCubit() : super(JourneyInitial());

  Future<void> loadJourneys() async {
    emit(JourneyLoading());
    try {
      final journeys = await JourneyService().getJourneys();
      emit(JourneyListLoaded(journeys));
    } catch (e) {
      emit(JourneyError(e.toString()));
    }
  }

  Future<void> loadJourney(String id) async {
    emit(JourneyLoading());
    try {
      final journey = await JourneyService().getJourneyById(id);
      if (journey != null) {
        emit(JourneyDetailLoaded(journey));
      } else {
        emit(JourneyError('Journey not found'));
      }
    } catch (e) {
      emit(JourneyError(e.toString()));
    }
  }
}
