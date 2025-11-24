import 'dart:async';
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
            aiStepIndex: 0,
          ),
        );

  final DestinationService _destinationService;

  Future<void> fetchRichDescription({bool force = true}) async {
    // If not forcing and we already have a fairly rich text, skip
    if (!force && (state.description.trim().length >= 180)) return;
    // Reset and start agentic steps
    emit(state.copyWith(loadingDescription: true, description: '', aiStepIndex: 0));

    // Kick off a soft step ticker to make progress visible while the model runs.
    bool cancelled = false;
    Future<void> stepTicker() async {
      // We expose 4 visual steps (0..3); index 4 means done.
      for (int i = 0; i < 4 && !cancelled; i++) {
        await Future.delayed(Duration(milliseconds: i == 0 ? 200 : 900));
        if (cancelled) break;
        // When the final visual step completes (i == 3 -> step 4),
        // we immediately flip loadingDescription to false so the UI can
        // show the brief "Warming up the details…" state if the text
        // hasn't started streaming yet.
        if (i == 3) {
          emit(state.copyWith(aiStepIndex: 4, loadingDescription: false));
        } else {
          emit(state.copyWith(aiStepIndex: i + 1));
        }
      }
    }

    // Start the ticker in background
    unawaited(stepTicker());

    try {
      debugPrint('[DestinationDetailCubit] Enriching description (deterministic stream) for ${state.destination.name}');
      // Generate the final text once (avoids fragile web streaming issues), then drip-feed it.
      final full = await _destinationService.enrichDescriptionWithAI(state.destination);
      final text = (full ?? '').trim();
      if (text.isEmpty) {
        // Leave the placeholder; we'll finish without emitting text.
        return;
      }

      // Pseudo-stream the text so the user sees it building up.
      final buffer = StringBuffer();
      await for (final chunk in _destinationService.pseudoStreamFromFullText(text)) {
        buffer.write(chunk);
        emit(state.copyWith(description: buffer.toString()));
      }
    } catch (e, st) {
      debugPrint('[DestinationDetailCubit] fetchRichDescription error: $e');
      debugPrint('$st');
    } finally {
      cancelled = true;
      // Mark steps as complete
      emit(state.copyWith(loadingDescription: false, aiStepIndex: 4));
    }
  }

  void setDays(int days) {
    emit(state.copyWith(days: days.clamp(1, 21)));
  }

  void setGenerating(bool value) {
    emit(state.copyWith(generatingItinerary: value));
  }
}
