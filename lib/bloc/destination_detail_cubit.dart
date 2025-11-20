import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanderwell/models/destination.dart';
import 'package:wanderwell/services/destination_service.dart';

part 'destination_detail_state.dart';

class DestinationDetailCubit extends Cubit<DestinationDetailState> {
  DestinationDetailCubit({
    required Destination destination,
    DestinationService? destinationService,
  })  : _destinationService = destinationService ?? DestinationService(),
        super(
          DestinationDetailState(
            destination: destination,
            days: destination.idealDays.clamp(1, 21),
            description: destination.description,
            loadingDescription: false,
            generatingItinerary: false,
          ),
        );

  final DestinationService _destinationService;

  Future<void> fetchRichDescription({bool force = true}) async {
    // If not forcing and we already have a fairly rich text, skip
    if (!force && (state.description.trim().length >= 180)) return;
    emit(state.copyWith(loadingDescription: true));
    try {
      debugPrint('[DestinationDetailCubit] Enriching description for ${state.destination.name}');
      final enriched = await _destinationService.enrichDescriptionWithAI(state.destination);
      if (enriched != null && enriched.trim().isNotEmpty) {
        emit(state.copyWith(description: enriched.trim()));
      }
    } catch (e) {
      // Errors logged within the service; keep existing description
    } finally {
      emit(state.copyWith(loadingDescription: false));
    }
  }

  void setDays(int days) {
    emit(state.copyWith(days: days.clamp(1, 21)));
  }

  void setGenerating(bool value) {
    emit(state.copyWith(generatingItinerary: value));
  }
}
