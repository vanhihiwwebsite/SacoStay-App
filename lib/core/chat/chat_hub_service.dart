import 'package:signalr_netcore/signalr_client.dart';

import '../../config/environment.dart';

class ChatHubService {
  HubConnection? _connection;

  Future<void> connect(String token) async {
    if (_connection?.state == HubConnectionState.Connected) return;

    final hub = HubConnectionBuilder()
        .withUrl(
          Environment.chatHubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection = hub;
    await hub.start();
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
    _connection?.on('ReceivePrivateMessage', (arguments) {
      if (arguments == null || arguments.length < 2) return;
      handler(arguments[0]?.toString() ?? '', arguments[1]?.toString() ?? '');
    });
  }

  Future<void> sendPrivateMessage(String receiverId, String message) async {
    final conn = _connection;
    if (conn == null || conn.state != HubConnectionState.Connected) {
      throw Exception('Chưa kết nối máy chủ chat');
    }
    await conn.invoke('SendPrivateMessage', args: [receiverId, message]);
  }
}
