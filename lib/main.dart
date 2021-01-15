import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foreground_service/foreground_service.dart';
import 'package:provider/provider.dart';
import 'package:screen_share_janus/streaming_model.dart';
import 'package:screen_share_janus/video_room_page.dart';
import 'video_room_page.dart';
import 'publisher_info.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = new MyHttpOverrides();

  runApp(
    ChangeNotifierProvider(
        create: (context) => StreamingModel(),
        child: MyApp()
    ),
  );
}

Future<void> startForegroundService() async {
  if (!(await ForegroundService.foregroundServiceIsStarted())) {
    await ForegroundService.notification.startEditMode();

    await ForegroundService.setContinueRunningAfterAppKilled(false);

    await ForegroundService.notification.setTitle("On the Live");
    await ForegroundService.notification.setText("화면공유중");

    await ForegroundService.notification.finishEditMode();

    await ForegroundService.startForegroundService(null);
    await ForegroundService.getWakeLock();
  }
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

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  VideoRoomPage videoRoom = VideoRoomPage();


  void _entryVideoRoom() async {
    await startForegroundService();

    var model = PublisherInfo.instance.streamingModel;

    model.state = StreamingState.connecting;

    var isInit = await videoRoom.init();

    if(!isInit) {
      await ForegroundService.stopForegroundService();

      model.state = StreamingState.ready;
    }
  }

  void _exitVideoRoom() async {
    var model = PublisherInfo.instance.streamingModel;

    model.state = StreamingState.stopped;

    videoRoom.disconnect();

    await ForegroundService.stopForegroundService();

    model.state = StreamingState.ready;
  }

  @override
  void initState() {
    super.initState();

    PublisherInfo.instance.streamingModel = context.read<StreamingModel>();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if(state == AppLifecycleState.detached) {
      // videoRoom.leave();
      // videoRoom.temp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("room : " + PublisherInfo.instance.room + ", id : " + PublisherInfo.instance.id),
      ),
      body: Center(
        child: Consumer<StreamingModel>(
          builder: (context, model, child) {
            Icon icon;
            VoidCallback onPressed;

            if(model.state == StreamingState.ready) {
              icon = Icon(Icons.not_started_outlined);

              onPressed = () => _entryVideoRoom();
            }

            if(model.state == StreamingState.connecting)
              icon = Icon(Icons.contactless_outlined);

            if(model.state == StreamingState.running) {
              icon = Icon(Icons.not_started_sharp);

              onPressed = () => _exitVideoRoom();
            }

            if(model.state == StreamingState.stopped)
              icon = Icon(Icons.cancel_presentation_rounded);

            return IconButton(icon: icon, onPressed: onPressed, iconSize: 100,);
          },
        ),
      ),
    );
  }
}