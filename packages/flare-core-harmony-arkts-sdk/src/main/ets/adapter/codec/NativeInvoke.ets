// GENERATED. Do not edit by hand.
import { NativeBridge, NativeCallDescriptor } from '../../contract/BridgeContract';
import { FlareSdkException } from '../../bridge/FlareSdkException';
import {
  Conversation,
  LifecycleEventName,
  ListConversationsResponse,
  ListMessagesResponse,
  Message,
  SdkErrorPayload,
  SendMessageResponse,
} from '../../model';
import {
  conversationFromJson,
  listConversationsResponseFromJson,
  listMessagesResponseFromJson,
  listOfMaps,
  messageFromJson,
  sendAckFromJson,
} from './WireCodec';

export interface AdapterLifecycleEmitter {
  emit(event: Object): void;
}

export async function invokeVoid(
  bridge: NativeBridge,
  descriptor: NativeCallDescriptor,
  request?: Object,
): Promise<void> {
  await bridge.invoke<void>(descriptor, request);
}

export async function invokeMap(
  bridge: NativeBridge,
  descriptor: NativeCallDescriptor,
  request?: Object,
): Promise<Record<string, Object>> {
  return await bridge.invoke<Record<string, Object>>(descriptor, request);
}

export async function invokeBool(
  bridge: NativeBridge,
  descriptor: NativeCallDescriptor,
  request?: Object,
): Promise<boolean> {
  return await bridge.invoke<boolean>(descriptor, request);
}

export async function invokeMessage(
  bridge: NativeBridge,
  descriptor: NativeCallDescriptor,
  request?: Object,
): Promise<Message> {
  const raw = await invokeMap(bridge, descriptor, request);
  return messageFromJson((raw["message"] as Object) ?? raw);
}

export async function invokeSendAck(
  bridge: NativeBridge,
  descriptor: NativeCallDescriptor,
  request?: Object,
): Promise<SendMessageResponse> {
  return sendAckFromJson(await invokeMap(bridge, descriptor, request));
}

export async function invokeListConversations(
  bridge: NativeBridge,
  descriptor: NativeCallDescriptor,
  request?: Object,
): Promise<ListConversationsResponse> {
  return listConversationsResponseFromJson(await invokeMap(bridge, descriptor, request));
}

export async function invokeListMessages(
  bridge: NativeBridge,
  descriptor: NativeCallDescriptor,
  request?: Object,
): Promise<ListMessagesResponse> {
  return listMessagesResponseFromJson(await invokeMap(bridge, descriptor, request));
}

export async function invokeConversation(
  bridge: NativeBridge,
  descriptor: NativeCallDescriptor,
  request?: Object,
): Promise<Conversation> {
  const raw = await invokeMap(bridge, descriptor, request);
  const conversations = listOfMaps(raw["conversations"]);
  if (conversations.length > 0) {
    return conversationFromJson(conversations[0]);
  }
  return conversationFromJson(raw);
}

export function sdkErrorPayloadFromError(error: Object, operation: string): SdkErrorPayload {
  if (error instanceof FlareSdkException) {
    const typed: SdkErrorPayload = {
      code: error.code,
      message: error.message,
      operation: error.operation ?? operation,
      retryable: error.retryable,
      details: error.details ?? {},
    };
    if (error.machineReason !== undefined) {
      typed.machineReason = error.machineReason;
    }
    return typed;
  }
  const maybeError = error as Error;
  const message = maybeError?.message ?? `${error}`;
  return {
    code: 'internal',
    message,
    operation,
    retryable: false,
    details: {
      type: maybeError?.name ?? 'Error',
    },
  };
}

export function userIdFromRequest(request: Record<string, Object>): string | undefined {
  const value = request['userId'];
  return typeof value === 'string' ? value : undefined;
}

export function emitLifecycleEvent(
  events: AdapterLifecycleEmitter,
  name: LifecycleEventName,
  operation: string,
  userId?: string,
  error?: SdkErrorPayload,
): void {
  events.emit({
    name,
    operation,
    ...(userId !== undefined ? { userId } : {}),
    ...(error !== undefined ? { error } : {}),
  });
}
