package com.flare.im.model.entity

/** GENERATED. Do not edit by hand. */
/** PushTokenInput */
data class PushTokenInput(
    /** wire: `appBundle`. iOS bundle id or Android applicationId. The server sends APNs to this topic. */
    val appBundle: String? = null,
    /** wire: `appVersion`. App version string. */
    val appVersion: String? = null,
    /** wire: `capabilities`. What the app can do with a push: dataMessages (Android FCM data messages) and serviceExtension (iOS notification service extension). Unknown values are rejected. */
    val capabilities: List<String>? = null,
    /** wire: `environment`. APNs only: sandbox or production, the APNs host the token belongs to. */
    val environment: String? = null,
    /** wire: `locale`. BCP 47 language tag the server renders notification text in, e.g. zh-CN. */
    val locale: String? = null,
    /** wire: `platform`. Native platform: android, ios or harmony. */
    val platform: String = "",
    /** wire: `provider`. OS delivery provider: fcm, apns or getui. */
    val provider: String = "",
    /** wire: `timeZone`. IANA time zone, e.g. Asia/Shanghai. */
    val timeZone: String? = null,
    /** wire: `token`. OS-issued token. Never log or persist outside protected native storage. */
    val token: String = "",
)
