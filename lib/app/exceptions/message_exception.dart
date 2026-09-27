/// MessageException 带消息体的异常
class MessageException implements Exception {
  final String _message;

  MessageException(this._message);

  String getMessage() => _message;

  @override
  String toString() => _message;
}
