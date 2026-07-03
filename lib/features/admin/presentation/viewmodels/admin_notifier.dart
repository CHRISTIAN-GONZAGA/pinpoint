import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinpoint/app/dependency_injection.dart';
import 'package:pinpoint/features/admin/presentation/viewmodels/admin_state.dart';

class AdminNotifier extends Notifier<AdminState> {
  @override
  AdminState build() => const AdminState();

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dashboard = await ref.read(adminRepositoryProvider).getDashboard();
      final reports = await ref.read(adminRepositoryProvider).getReports(status: 'open');
      state = state.copyWith(isLoading: false, dashboard: dashboard, reports: reports);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<bool> publishAnnouncement({
    required String title,
    required String content,
    String category = 'general',
    String priority = 'normal',
  }) async {
    state = state.copyWith(isPublishing: true, clearError: true);
    try {
      await ref.read(adminRepositoryProvider).publishAnnouncement(
            title: title,
            content: content,
            category: category,
            priority: priority,
          );
      state = state.copyWith(isPublishing: false);
      await load();
      return true;
    } catch (error) {
      state = state.copyWith(isPublishing: false, errorMessage: error.toString());
      return false;
    }
  }

  Future<void> resolveReport(int reportId) async {
    await ref.read(adminRepositoryProvider).resolveReport(reportId);
    await load();
  }
}

final adminNotifierProvider = NotifierProvider<AdminNotifier, AdminState>(AdminNotifier.new);
