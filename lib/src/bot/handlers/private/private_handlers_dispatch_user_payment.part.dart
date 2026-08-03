part of '../private_handlers.dart';

extension PrivateHandlersDispatchUserPayment on PrivateHandlers {
  Future<bool> _dispatchUserPaymentCommands(PrivateRequestContext ctx) async {
    if (await _dispatchInlineCallbackCommands(ctx)) {
      return true;
    }
    if (await _dispatchUserProfileCommands(ctx)) {
      return true;
    }
    if (await _dispatchUserActionCommands(ctx)) {
      return true;
    }
    return false;
  }
}
