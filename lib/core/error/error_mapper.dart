import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'failures.dart';

/// Translates low-level exceptions into user-facing [Failure]s so the rest of
/// the app never has to know about Supabase/Postgrest specifics.
Failure mapError(Object error) {
  if (error is Failure) return error;
  if (error is SocketException || error is TimeoutException) {
    return const NetworkFailure();
  }
  if (error is AuthException) {
    return AuthFailure(error.message);
  }
  if (error is PostgrestException) {
    // RLS violations surface as 401/403; unique violations as 23505.
    if (error.code == '23505') {
      return const ValidationFailure('That record already exists.');
    }
    if (error.code == '42501' || error.code == 'PGRST301') {
      return const AuthFailure('You do not have permission to do that.');
    }
    return ServerFailure(error.message);
  }
  if (error is StorageException) {
    return ServerFailure(error.message);
  }
  return ServerFailure(error.toString());
}
