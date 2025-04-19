import 'dart:async';

class EventBus {
  static final EventBus _instance = EventBus._internal();
  
  factory EventBus() => _instance;
  
  EventBus._internal();
  
  final _eventController = StreamController<dynamic>.broadcast();
  
  Stream<T> on<T>() {
    return _eventController.stream.where((event) => event is T).cast<T>();
  }
  
  void fire(event) {
    _eventController.add(event);
  }
  
  void dispose() {
    _eventController.close();
  }
}

// Music deletion event
class MusicDeletedEvent {
  final String musicId;
  MusicDeletedEvent(this.musicId);
} 