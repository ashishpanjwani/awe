import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wanderwell/models/wonder.dart';
import 'package:wanderwell/models/wonder_user_state.dart';
import 'package:wanderwell/services/wonder_user_service.dart';

abstract class WonderMapState {}

class WonderMapInitial extends WonderMapState {}

class WonderMapLoading extends WonderMapState {}

class WonderMapLoaded extends WonderMapState {
  final List<Wonder> wonders;
  final WonderUserState userState;
  WonderMapLoaded(this.wonders, this.userState);
}

class WonderMapError extends WonderMapState {
  final String message;
  WonderMapError(this.message);
}

class WonderMapCubit extends Cubit<WonderMapState> {
  WonderMapCubit() : super(WonderMapInitial());

  final _db = FirebaseFirestore.instance;

  Future<void> loadViewedWonders() async {
    emit(WonderMapLoading());
    try {
      WonderUserService().invalidateCache();
      final userState = await WonderUserService().getState();

      final allIds = <String>{...userState.engagedWonderIds};

      debugPrint('[WonderMap] allIds: ${allIds.length} engaged wonders');

      if (allIds.isEmpty) {
        debugPrint('[WonderMap] No wonders to show, emitting empty');
        emit(WonderMapLoaded([], userState));
        return;
      }

      final wonders = <Wonder>[];

      final batches = _chunk(allIds.toList(), 10);
      for (final batch in batches) {
        try {
          final snap = await _db
              .collection('daily_wonders')
              .where(FieldPath.documentId, whereIn: batch)
              .get();
          for (final doc in snap.docs) {
            final data = doc.data();
            if (data['status'] != 'ready') continue;
            data['id'] = doc.id;
            if (data['createdAt'] is Timestamp) {
              data['createdAt'] =
                  (data['createdAt'] as Timestamp).toDate().toIso8601String();
            }
            data.remove('updatedAt');
            final w = Wonder.fromJson(data);
            if (w.place.lat != 0 || w.place.lon != 0) {
              wonders.add(w);
            }
          }
        } catch (e) {
          debugPrint('[WonderMap] Firestore batch query failed: $e');
        }
      }

      debugPrint('[WonderMap] Loaded ${wonders.length} pins');
      emit(WonderMapLoaded(wonders, userState));
    } catch (e, st) {
      debugPrint('[WonderMap] Error: $e');
      debugPrint('$st');
      emit(WonderMapError(e.toString()));
    }
  }

  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }
}
