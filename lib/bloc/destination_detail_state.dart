part of 'destination_detail_cubit.dart';

class DestinationDetailState extends Equatable {
  final Destination destination;
  final int days;
  final String description;
  final bool loadingDescription;
  final bool generatingItinerary;
  final int aiStepIndex; // 0 = not started

  const DestinationDetailState({
    required this.destination,
    required this.days,
    required this.description,
    required this.loadingDescription,
    required this.generatingItinerary,
    required this.aiStepIndex,
  });

  DestinationDetailState copyWith({
    Destination? destination,
    int? days,
    String? description,
    bool? loadingDescription,
    bool? generatingItinerary,
    int? aiStepIndex,
  }) {
    return DestinationDetailState(
      destination: destination ?? this.destination,
      days: days ?? this.days,
      description: description ?? this.description,
      loadingDescription: loadingDescription ?? this.loadingDescription,
      generatingItinerary: generatingItinerary ?? this.generatingItinerary,
      aiStepIndex: aiStepIndex ?? this.aiStepIndex,
    );
  }

  @override
  List<Object?> get props => [destination.id, days, description, loadingDescription, generatingItinerary, aiStepIndex];
}
