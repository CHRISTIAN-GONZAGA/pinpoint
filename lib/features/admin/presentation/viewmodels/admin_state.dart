import 'package:equatable/equatable.dart';

class AdminState extends Equatable {
  const AdminState({
    this.dashboard = const {},
    this.reports = const [],
    this.isLoading = false,
    this.isPublishing = false,
    this.errorMessage,
  });

  final Map<String, dynamic> dashboard;
  final List<Map<String, dynamic>> reports;
  final bool isLoading;
  final bool isPublishing;
  final String? errorMessage;

  AdminState copyWith({
    Map<String, dynamic>? dashboard,
    List<Map<String, dynamic>>? reports,
    bool? isLoading,
    bool? isPublishing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminState(
      dashboard: dashboard ?? this.dashboard,
      reports: reports ?? this.reports,
      isLoading: isLoading ?? this.isLoading,
      isPublishing: isPublishing ?? this.isPublishing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [dashboard, reports, isLoading, isPublishing];
}
