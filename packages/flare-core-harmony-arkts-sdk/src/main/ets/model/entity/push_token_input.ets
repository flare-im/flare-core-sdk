// GENERATED. Do not edit by hand.

/** PushTokenInput */
export interface PushTokenInput {
  /** wire: `appBundle`. iOS bundle id or Android applicationId. The server sends APNs to this topic. */
  appBundle?: string;
  /** wire: `appVersion`. App version string. */
  appVersion?: string;
  /** wire: `capabilities`. What the app can do with a push: dataMessages (Android FCM data messages) and serviceExtension (iOS notification service extension). Unknown values are rejected. */
  capabilities?: Array<string>;
  /** wire: `environment`. APNs only: sandbox or production, the APNs host the token belongs to. */
  environment?: string;
  /** wire: `locale`. BCP 47 language tag the server renders notification text in, e.g. zh-CN. */
  locale?: string;
  /** wire: `platform`. Native platform: android, ios or harmony. */
  platform: string;
  /** wire: `provider`. OS delivery provider: fcm, apns or getui. */
  provider: string;
  /** wire: `timeZone`. IANA time zone, e.g. Asia/Shanghai. */
  timeZone?: string;
  /** wire: `token`. OS-issued token. Never log or persist outside protected native storage. */
  token: string;
}
