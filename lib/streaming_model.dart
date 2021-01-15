import 'package:flutter/cupertino.dart';

enum StreamingState {
  ready,
  connecting,
  running,
  stopped,
}

class StreamingModel extends ChangeNotifier{
  void Function(StreamingState) callback;

  StreamingState _state = StreamingState.ready;

  set state(StreamingState value) {
    _state = value;

    notifyListeners();
  }

  StreamingState get state => _state;
}