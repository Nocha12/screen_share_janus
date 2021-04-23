import 'dart:io' as di;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:screen_share_janus/streaming_model.dart';
import 'package:screen_share_janus/video_room.dart';
import 'publisher_info.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MyHttpOverrides extends di.HttpOverrides {
  @override
  di.HttpClient createHttpClient(di.SecurityContext context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (di.X509Certificate cert, String host, int port) => true;
  }
}

const platform = const MethodChannel("onthelive.webview/foreground");

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  di.HttpOverrides.global = new MyHttpOverrides();

  await Permission.camera.request();
  await Permission.microphone.request();
  await Permission.storage.request();

  runApp(
    ChangeNotifierProvider(
        create: (context) => StreamingModel(),
        child: MyApp()
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Janus Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Janus Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  VideoRoom videoRoom = VideoRoom();

  TextEditingController roomController = TextEditingController();
  TextEditingController idController = TextEditingController();

  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        useOnDownloadStart: true,
      ),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
      ),
      ios: IOSInAppWebViewOptions(
      )
  );

  void addJavaScriptHandler(InAppWebViewController controller) {
    controller.addJavaScriptHandler(handlerName: "publish", callback: (param) async {
      PublisherInfo.instance.room = param[0].toString().trim();
      PublisherInfo.instance.id = param[1].toString().trim();

      await _entryVideoRoom();

      return "fin";
    });

    controller.addJavaScriptHandler(handlerName: "unpublish", callback: (param) async {
      await _exitVideoRoom();

      return "fin";
    });
  }

  Future<void> _entryVideoRoom() async {
    if(PublisherInfo.instance.room.isEmpty || PublisherInfo.instance.id.isEmpty) {

      return;
    }

    if(di.Platform.isAndroid)
      await platform.invokeMethod('startForeground');

    var model = PublisherInfo.instance.streamingModel;

    model.state = StreamingState.connecting;

    var isInit = await videoRoom.init(webViewController);

    if(!isInit) {
      if(di.Platform.isAndroid)
        await platform.invokeMethod('stopForeground');

      webViewController.evaluateJavascript(source: "window.parent.onUnpublished();");

      model.state = StreamingState.ready;
    }

    return;
  }

  Future<void> _exitVideoRoom() async {
    var model = PublisherInfo.instance.streamingModel;

    model.state = StreamingState.stopped;

    videoRoom.disconnect();

    if(di.Platform.isAndroid)
      await platform.invokeMethod('stopForeground');

    webViewController.evaluateJavascript(source: "window.parent.onUnpublished();");

    model.state = StreamingState.ready;

    return;
  }

  void requestPermission() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  @override
  void initState() {
    super.initState();

    PublisherInfo.instance.streamingModel = context.read<StreamingModel>();
    requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: InAppWebView(
          key: webViewKey,
          initialOptions: options,
          initialUrlRequest:
          URLRequest(url: Uri.parse("https://bs010.onthe.live:10180/flutter")),

          onWebViewCreated: (controller) {
            webViewController = controller;

            addJavaScriptHandler(controller);
          },

          androidOnPermissionRequest: (controller, origin, resources) async {
            return PermissionRequestResponse(
              resources: resources,
              action: PermissionRequestResponseAction.GRANT
            );
          },

          onConsoleMessage: (controller, consoleMessage) {
            print(consoleMessage);
          },
        ),
      ),
    );
  }
}