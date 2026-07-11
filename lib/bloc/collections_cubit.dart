import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/models/wonder_collection.dart';
import 'package:wanderwell/services/collection_service.dart';

abstract class CollectionsState {}

class CollectionsInitial extends CollectionsState {}

class CollectionsLoading extends CollectionsState {}

class CollectionsListLoaded extends CollectionsState {
  final List<WonderCollection> collections;
  CollectionsListLoaded(this.collections);
}

class CollectionDetailLoaded extends CollectionsState {
  final WonderCollection collection;
  final List<Wonder> wonders;
  CollectionDetailLoaded(this.collection, this.wonders);
}

class CollectionsError extends CollectionsState {
  final String message;
  CollectionsError(this.message);
}

class CollectionsCubit extends Cubit<CollectionsState> {
  CollectionsCubit() : super(CollectionsInitial());

  Future<void> loadCollections() async {
    emit(CollectionsLoading());
    try {
      final collections = await CollectionService().getCollections();
      emit(CollectionsListLoaded(collections));
    } catch (e) {
      debugPrint('[CollectionsCubit] Error: $e');
      emit(CollectionsError(e.toString()));
    }
  }

  Future<void> loadCollection(String id) async {
    emit(CollectionsLoading());
    try {
      final collection = await CollectionService().getCollectionById(id);
      if (collection == null) {
        emit(CollectionsError('Collection not found'));
        return;
      }
      final wonders = await CollectionService().getWondersForCollection(collection);
      emit(CollectionDetailLoaded(collection, wonders));
    } catch (e) {
      debugPrint('[CollectionsCubit] Error: $e');
      emit(CollectionsError(e.toString()));
    }
  }
}
