part of '../private_handlers.dart';

extension PrivateHandlersDispatchAdmin on PrivateHandlers {
  Future<bool> _dispatchAdminCommands(PrivateRequestContext ctx) async {
    if (await _dispatchAdminMenuCommands(ctx)) {
      return true;
    }
    if (await _dispatchAdminModerationCommands(ctx)) {
      return true;
    }
    return false;
  }
}
