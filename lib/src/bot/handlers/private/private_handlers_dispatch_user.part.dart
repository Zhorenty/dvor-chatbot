part of '../private_handlers.dart';

extension PrivateHandlersDispatchUser on PrivateHandlers {
  Future<bool> _dispatchUserCommands(PrivateRequestContext ctx) async {
    if (await _dispatchUserBookingCommands(ctx)) {
      return true;
    }
    if (await _dispatchUserPaymentCommands(ctx)) {
      return true;
    }
    return false;
  }
}
