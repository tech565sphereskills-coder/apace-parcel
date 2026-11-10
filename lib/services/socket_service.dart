import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';

class SocketService {
  static final SocketService instance = SocketService._internal();
  SocketService._internal();

  io.Socket? _socket;

  bool get isConnected => _socket?.connected == true;

  void connect(String accessToken) {
    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }

    _socket = io.io(
      AppConfig.socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': accessToken})
          .enableReconnection()
          .build(),
    );
    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void joinOrder(String orderId) {
    _socket?.emit('joinOrderTracking', {'orderId': orderId});
  }

  void joinRiderRadar() {
    _socket?.emit('riderJoinRadar');
  }

  void emitRiderLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
  }) {
    _socket?.emit('updateRiderLocation', {
      'orderId': orderId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': ?speed,
      'heading': ?heading,
    });
  }

  void sendOrderChatMessage(String orderId, String message) {
    _socket?.emit('sendOrderChatMessage', {
      'orderId': orderId,
      'message': message,
    });
  }

  void onOrderStatus(void Function(Map<String, dynamic> data) handler) {
    _socket?.off('orderStatusUpdated');
    _socket?.on('orderStatusUpdated', (data) {
      if (data is Map) {
        handler(Map<String, dynamic>.from(data));
      }
    });
  }

  void onRiderLocation(void Function(Map<String, dynamic> data) handler) {
    _socket?.off('riderLocationUpdated');
    _socket?.on('riderLocationUpdated', (data) {
      if (data is Map) {
        handler(Map<String, dynamic>.from(data));
      }
    });
  }

  void onGeofenceTriggered(void Function(Map<String, dynamic> data) handler) {
    _socket?.off('geofenceTriggered');
    _socket?.on('geofenceTriggered', (data) {
      if (data is Map) {
        handler(Map<String, dynamic>.from(data));
      }
    });
  }

  void onGeofenceRejected(void Function(Map<String, dynamic> data) handler) {
    _socket?.off('geofenceRejected');
    _socket?.on('geofenceRejected', (data) {
      if (data is Map) {
        handler(Map<String, dynamic>.from(data));
      }
    });
  }

  void onOrderStopCompleted(void Function(Map<String, dynamic> data) handler) {
    _socket?.off('orderStopCompleted');
    _socket?.on('orderStopCompleted', (data) {
      if (data is Map) {
        handler(Map<String, dynamic>.from(data));
      }
    });
  }

  void onOrderDelayReported(void Function(Map<String, dynamic> data) handler) {
    _socket?.off('orderDelayReported');
    _socket?.on('orderDelayReported', (data) {
      if (data is Map) {
        handler(Map<String, dynamic>.from(data));
      }
    });
  }

  void onChatMessage(void Function(Map<String, dynamic> data) handler) {
    _socket?.off('orderChatMessage');
    _socket?.on('orderChatMessage', (data) {
      if (data is Map) {
        handler(Map<String, dynamic>.from(data));
      }
    });
  }

  void onDispatchOffer(void Function(Map<String, dynamic> data) handler) {
    _socket?.off('dispatchOffer');
    _socket?.on('dispatchOffer', (data) {
      if (data is Map) {
        handler(Map<String, dynamic>.from(data));
      }
    });
  }

  void onDispatchOfferExpired(void Function(Map<String, dynamic> data) handler) {
    _socket?.off('dispatchOfferExpired');
    _socket?.on('dispatchOfferExpired', (data) {
      if (data is Map) {
        handler(Map<String, dynamic>.from(data));
      }
    });
  }

  void onDispatchSearching(void Function(Map<String, dynamic> data) handler) {
    _socket?.off('dispatchSearching');
    _socket?.on('dispatchSearching', (data) {
      if (data is Map) {
        handler(Map<String, dynamic>.from(data));
      }
    });
  }
}
