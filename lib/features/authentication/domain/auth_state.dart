import 'package:equatable/equatable.dart';
import 'package:pinpoint/features/authentication/domain/user.dart';

/// Authentication session state.
class AuthState extends Equatable {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.isInitialized = false,
    this.errorMessage,
  });

  const AuthState.initial()
      : user = null,
        isLoading = false,
        isInitialized = false,
        errorMessage = null;

  final User? user;
  final bool isLoading;
  final bool isInitialized;
  final String? errorMessage;

  bool get isAuthenticated => user != null && !user!.isGuest;
  bool get isGuest => user?.isGuest ?? false;
  bool get hasSession => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isInitialized,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [user, isLoading, isInitialized, errorMessage];
}
