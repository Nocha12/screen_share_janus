import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:janus_client_plugin/janus_client_plugin.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:random_string/random_string.dart';
import 'package:screen_share_janus/main.dart';
import 'package:screen_share_janus/streaming_model.dart';

import 'publisher_info.dart';

class VideoRoom {
  String url = 'wss://bs010.onthe.live:8989/janus';
  bool withCredentials = false;
  String apiSecret = "SecureIt";
  String pluginName = 'janus.plugin.videoroom';
  List<RTCIceServer> iceServers;
  JanusSignal _signal;

  MediaStream _localStream;
  InAppWebViewController webViewController;

  String opaqueId = 'videoroomtest-${randomString(12)}';
  Map<int, JanusConnection> peerConnectionMap = <int, JanusConnection>{};
  int selfHandleId = -1;

  void disconnect() {
    if(_signal != null) {
      leave();

      peerConnectionMap?.forEach((key, jc) => jc.disConnect());
      peerConnectionMap.clear();

      _localStream?.dispose();
      _signal?.disconnect();
      _signal = null;
    }
  }

  Future<bool> init(InAppWebViewController controller) async {
    webViewController = controller;

    this._signal = JanusSignal.getInstance(url: url, apiSecret: apiSecret, withCredentials: withCredentials);

    this.onMessage();

    return await this._initRenderers();
  }

  Future<bool> _initRenderers() async {
    this._localStream = await this.createStream();

    if(_localStream == null) {
      var model = PublisherInfo.instance.streamingModel;

      model.state = StreamingState.stopped;

      return false;
    }

    this.connect();
    this.createSessionAndAttach();

    return true;
  }

  void stopForeground() async {
    disconnect();

    await platform.invokeMethod('stopForeground');

    var model = PublisherInfo.instance.streamingModel;

    model.state = StreamingState.ready;
  }

  void onMessage() {

    this._signal.onMessage = (JanusHandle handle, Map plugin, Map jsep, JanusHandle feedHandle) {
      String videoroom = plugin['videoroom'];

      if(videoroom == 'event') {
        if(plugin['configured'] != null && plugin['configured'] == "ok") {
          if(plugin['configured'] == "ok") {
            webViewController.evaluateJavascript(source: "window.parent.onPublished();");
          }
        }

        if(plugin['error'] != null) {
          var model = PublisherInfo.instance.streamingModel;

          model.state = StreamingState.stopped;

          stopForeground();
        }
      }

      if(videoroom == 'joined') {
        handle.onJoined(handle);
      }

      if(feedHandle != null) {
        feedHandle.onLeaving(feedHandle);
      }

      if(jsep != null) {
        handle.onRemoteJsep(handle, jsep);
      }
      return;
    };
  }

  void connect() async{
    this._signal.connect();
  }

  /// janus create
  /// janus attach
  /// join room
  void createSessionAndAttach() {
    this._signal.createSession(
        success: (Map<String, dynamic> data) {
          this._signal.attach(
              plugin: 'janus.plugin.videoroom',
              opaqueId: opaqueId,
              success: (Map<String, dynamic> attachData) {
                // this.joinRoom(data);
                this.checkRoom(attachData);
              },
              error: (Map<String, dynamic> data) {
                debugPrint('join room failed...');
              }
          );
        },
        error: (Map<String, dynamic> data){
          debugPrint('createSession failed...');
        }
    );
  }

  void checkRoom(Map<String, dynamic> attachData){
    var info = PublisherInfo.instance;

    this._signal.videoRoomHandle(
        req: RoomReq(request: 'exists', room: info.room).toMap(),
        success: (data){
          debugPrint('exists room=====>>>>>>$data');
          if(data['plugindata']['data'] != null &&  data['plugindata']['data']['exists']){
            this.joinRoom(attachData);
          }else {
            this._signal.videoRoomHandle(
                req: RoomReq(request: 'create', room: info.room, description: 'this is my room').toMap(),
                success: (data){
                  debugPrint('create room=====>>>>>>$data');
                  joinRoom(attachData);
                },
                error: (data){
                  print('create room error========>$data');
                }
            );
          }
        },
        error: (data){
          print('find room error========>$data');
        }
    );

  }

  void joinRoom(Map<String, dynamic> data){
    var info = PublisherInfo.instance;

    Map<String, dynamic> body ={
      "request": "join",
      "room": info.room,
      "ptype": "publisher",
      "id": info.id,
      'secret': '',
      'pin': ''
    };

    this._signal.joinRoom(
        data: data,
        body: body,
        onJoined: (handle){
          //　createOffer
          this.onPublisherJoined(handle);
        },
        onRemoteJsep: (handle, jsep){
          onPublisherRemoteJsep(handle, jsep);
        }
    );
  }

  void onPublisherJoined(JanusHandle handle) async{
    var model = PublisherInfo.instance.streamingModel;

    model.state = StreamingState.running;

    this.selfHandleId = handle.handleId;
    this._localStream ??= await this.createStream();
    JanusConnection jc = await createJanusConnection(handle: handle);
    debugPrint('selfHandleId====>$selfHandleId');
    // createOffer
    Map body = {
      "request": "configure",
      "audio": true,
      "video": true
    };

    RTCSessionDescription sdp = await jc.createOffer();
    Map<String, dynamic> jsep = sdp.toMap();
    this._signal.sendMessage(
        handleId: handle.handleId,
        body: body,
        jsep: jsep
    );
  }

  void onPublisherRemoteJsep(JanusHandle handle, Map jsep){
    JanusConnection jc = this.peerConnectionMap[handle.feedId];
    jc.setRemoteDescription(jsep);
  }

  Future<JanusConnection> createJanusConnection({@required JanusHandle handle}) async {
    JanusConnection jc = JanusConnection(handleId: handle.handleId, iceServers: iceServers, display: handle.display);
    debugPrint('${this.peerConnectionMap.length} ====${handle.handleId}');
    this.peerConnectionMap[handle.feedId] = jc;
    await jc.initConnection();

    jc.addLocalStream(this._localStream);
    jc.onAddStream = (connection, stream){
      if(stream.getVideoTracks().length > 0){
        connection.remoteStream = stream;
        connection.remoteRenderer.srcObject = stream;
      }
    };
    jc.onIceCandidate = (connection,  candidate){
      Map candidateMap = candidate != null ? candidate.toMap() : {"completed": true};
      this._signal.trickleCandidata(handleId: handle.handleId, candidate: candidateMap);
    };

    return jc;
  }

  Future<MediaStream> createStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': true,
    };

    MediaStream stream;

    try {
      stream = await MediaDevices.getDisplayMedia(mediaConstraints);
    } catch (error) {

    }

    return stream;
  }

  void leave(){
    _signal.sendMessage(
      handleId: selfHandleId,
      body: RoomLeaveReq().toMap(),
    );
  }
}