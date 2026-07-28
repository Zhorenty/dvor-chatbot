part of '../private_handlers.dart';

extension PrivateHandlersDispatchAdminMenu on PrivateHandlers {
  Future<bool> _dispatchAdminMenuCommands(PrivateRequestContext ctx) async {
    if (await _dispatchAdminToolsCommands(ctx)) {
      return true;
    }
    if (await _dispatchAdminBookingCommands(ctx)) {
      return true;
    }
    return false;
  }
}
