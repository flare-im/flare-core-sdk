// GENERATED. Do not edit by hand.
export 'common.dart';
export 'access.dart';
export 'connection.dart';
export 'conversation.dart';
export 'lifecycle.dart';
export 'media.dart';
export 'message.dart';
export 'notification.dart';
export 'plugin.dart';
export 'sync.dart';
export 'update.dart';
export 'view.dart';

import 'access.dart';
import 'connection.dart';
import 'conversation.dart';
import 'lifecycle.dart';
import 'media.dart';
import 'message.dart';
import 'notification.dart';
import 'plugin.dart';
import 'sync.dart';
import 'update.dart';
import 'view.dart';

/// Optional callback surface for apps that prefer one listener object.
abstract class FlareImEventListener
    implements AccessEventListener, ConnectionEventListener, ConversationEventListener, LifecycleEventListener, MediaEventListener, MessageEventListener, NotificationEventListener, PluginEventListener, SyncEventListener, UpdateEventListener, ViewEventListener {
  const FlareImEventListener();
}
