# flare_core_flutter_update_ui

The Flare update center on the Flare IM UI Kit, for Flutter apps. The Kit holds
no SDK and `flare_core_flutter_update` holds no UI; what joins them lives here,
so an app places these widgets and writes no update flow.

```dart
final updates = flutterUpdateController(engine);

FlareUpdateScope(                 // above the navigator
  controller: updates,
  child: MaterialApp(
    home: FlareUpdatePromptHost(  // below it, around a page
      child: page,
    ),
  ),
);
```

| Piece | Use |
|---|---|
| `FlareUpdateScope` | Above the navigator. `controllerOf`, `statusOf`, `readOnlyOf`, `badgeOf` serve deep widgets |
| `FlareUpdatePromptHost` | Binds the Kit prompt to `status.prompt` and reports it with `markPrompted` |
| `FlareUpdateResourceScope` | Under the strings and the theme it goes over, above the navigator. Puts this run's resource packs on them once they are read. `materialTheme` derives the app's Material theme again when a token pack changes the colours; `onOverlay` hands the overlay to what reads no Kit scope |
| `FlareUpdateVersionPanel` | The Kit version panel on the current status |
| `FlareUpdateAboutScreen` | The page a settings row opens |

Start the controller once the SDK is initialized, not at sign-in: an app has to
offer an update before anyone can sign in. Call `onLoginSucceeded()` and
`onLoginFailed()` from the sign-in flow.

The engine (`FlareClientUpdateEngine` for the core client,
`FlareSocialUpdateEngine` for the social SDK) comes from the SDK the app runs.
