// GENERATED. Do not edit by hand.
import '../entity/message.dart';

/// A local lookup within one conversation and sender. Missing or ambiguous messages have no value.
final class MessageByKeyResponse {
  /// wire: `message`. 
  final Message? message;

  const MessageByKeyResponse({
    this.message,
  });
}
