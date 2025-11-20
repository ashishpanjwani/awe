import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:wanderwell/models/user.dart' as models;
import 'package:wanderwell/services/auth_service.dart';

class AuthState extends Equatable {
  final models.User? user;
  final bool loading;

  const AuthState({required this.user, this.loading = false});

  AuthState copyWith({models.User? user, bool? loading}) =>
      AuthState(user: user ?? this.user, loading: loading ?? this.loading);

  @override
  List<Object?> get props => [user, loading];
}

class AuthCubit extends Cubit<AuthState> {
  late final StreamSubscription _sub;

  AuthCubit() : super(AuthState(user: AuthService().currentUser, loading: false)) {
    _sub = fb_auth.FirebaseAuth.instance.authStateChanges().listen((fUser) {
      final current = AuthService().currentUser; // kept in sync by AuthService
      emit(state.copyWith(user: current, loading: false));
    });
  }

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(loading: true));
    final user = await AuthService().signInWithGoogle();
    emit(state.copyWith(user: user, loading: false));
  }

  Future<void> signOut() async {
    emit(state.copyWith(loading: true));
    await AuthService().signOut();
    emit(state.copyWith(user: null, loading: false));
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
