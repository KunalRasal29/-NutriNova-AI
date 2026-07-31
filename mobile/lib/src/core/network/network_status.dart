import 'package:flutter/foundation.dart';

class NetworkStatus {
  NetworkStatus._();

  static final NetworkStatus instance = NetworkStatus._();

  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);

  void markOnline() => isOffline.value = false;
  void markOffline() => isOffline.value = true;
}
