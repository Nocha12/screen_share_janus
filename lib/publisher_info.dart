import 'package:screen_share_janus/streaming_model.dart';

class PublisherInfo {
  PublisherInfo._privateConstructor();

  static final PublisherInfo instance = PublisherInfo._privateConstructor();

  String room = "FlutterDefault";
  String id = "tester";

  StreamingModel streamingModel;
}