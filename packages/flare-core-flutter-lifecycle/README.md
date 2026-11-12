# Flutter lifecycle input

`flutterOpenedLinks` forwards raw OS links. Use the same `FlutterLinkSchemes` value for startup arguments, native opened links and Windows/Linux registration. The default accepts only Core Recovery; a product host can explicitly add its custom scheme:

```dart
const links = FlutterLinkSchemes(additionalSchemes: ['example-app']);
registerFlutterRecoverScheme(desktopId: 'com.example.links', appName: 'Example', schemes: links);
flutterOpenedLinks(launchArguments: args, schemes: links).listen(sdkIntakeLink);
```

All declarations are normalized and deduplicated before effects. Invalid schemes and `http`/`https` are rejected before any registry write, desktop file or subprocess. URLs remain unchanged, including their escaped contents; the receiving SDK owns classification and validation. Registration remains user-scoped, release-only and is read back. Other platforms declare their schemes in the app bundle. Contract tests exercise Windows commands and Linux files/readbacks without running registration on the developer machine; actual platform installation is a separate check.
