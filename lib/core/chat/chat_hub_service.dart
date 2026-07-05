import 'package:signalr_netcore/signalr_client.dart';

import '../../config/environment.dart';
import '../storage/token_storage.dart';

class ChatHubService {
  HubConnection? _connection;
  TokenStorage? _tokenStorage;
  void Function(String senderId, String text)? _messageHandler;
  String? lastError;

  Future<void> connect(TokenStorage tokenStorage) async {
    _tokenStorage = tokenStorage;
    if (_connection?.state == HubConnectionState.Connected) return;

    await _connection?.stop();
    _connection = null;
    lastError = null;

    final hub = HubConnectionBuilder()
        .withUrl(
          Environment.chatHubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async {
              final t = await tokenStorage.read();
              return t ?? '';
            },
            requestTimeout: 30000,
          ),
        )
        .withAutomaticReconnect()
        .build();

    hub.on('ReceiveMessage', (arguments) {
      if (arguments == null || arguments.length < 2) return;
      _messageHandler?.call(
        arguments[0]?.toString() ?? '',
        arguments[1]?.toString() ?? '',
      );
    });

    _connection = hub;
    try {
      await hub.start();
      lastError = null;
    } catch (e) {
      lastError = e.toString();
      rethrow;
    }
  }

  Future<void> reconnect() async {
    final storage = _tokenStorage;
    if (storage == null) {
      throw Exception('Chưa cấu hình token cho chat hub');
    }
    await disconnect();
    await connect(storage);
    if (_messageHandler != null) {
      onIncomingMessage(_messageHandler!);
    }
  }

  Future<void> disconnect() async {
    final conn = _connection;
    _connection = null;
    if (conn != null) {
      await conn.stop();
    }
  }

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  void onIncomingMessage(void Function(String senderId, String text) handler) {
    _messageHandler = handler;
  }

  Future<void> sendPrivateMessage(String receiverId, String message) async {
    var conn = _connection;
    if (conn == null || conn.state != HubConnectionState.Connected) {
      await reconnect();
      conn = _connection;
    }
    if (conn == null || conn.state != HubConnectionState.Connected) {
      throw Exception(lastError ?? 'Chưa kết nối máy chủ chat');
    }
    try {
      await conn.invoke('SendPrivateMessage', args: [receiverId, message]);
    } catch (e) {
      lastError = e.toString();
      rethrow;
    }
  }
}
