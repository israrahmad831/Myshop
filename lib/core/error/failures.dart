import 'package:equatable/equatable.dart';

/// A user-facing failure produced by the repository/domain layer.
/// UI layers switch on the subtype or simply display [message].
sealed class Failure extends Equatable {
  const Failure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Network is unavailable or the request timed out.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

/// The backend returned an error (auth, RLS, constraint, etc.).
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on the server.']);
}

/// Authentication/authorisation problem.
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed.']);
}

/// Local cache (Hive) problem.
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local storage error.']);
}

/// Validation or "not found" style problems.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
