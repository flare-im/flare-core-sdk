# Flutter 插件按类名反射调 FlareGetuiPush.install(Context)：应用开了混淆也要留下类名与入口。
-keep class com.flare.im.push.getui.FlareGetuiPush {
    public static ** INSTANCE;
    public void install(android.content.Context);
}
