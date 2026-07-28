/// Centralized admin authorization for private-handler flows.
final class AdminGate {
  const AdminGate(this._adminUserIds);

  final Set<int> _adminUserIds;

  bool isConfiguredAdmin(int? userId) => userId != null && _adminUserIds.contains(userId);

  bool canRunAdminAction({required bool isConfiguredAdmin}) => isConfiguredAdmin;
}
