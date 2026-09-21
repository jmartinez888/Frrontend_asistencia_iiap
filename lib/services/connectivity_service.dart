import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  static bool get isOnline => isOnlineNotifier.value;

  static Future<void> init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _evaluateConnectivity(results);
    } catch (_) {
      isOnlineNotifier.value = true;
    }

    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _evaluateConnectivity(results);
    });
  }

  static Future<void> _evaluateConnectivity(List<ConnectivityResult> results) async {
    // Si no hay interfaz de red activa (datos móviles apagados y sin wifi)
    final hasInterface = results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);

    if (!hasInterface) {
      isOnlineNotifier.value = false;
      return;
    }

    // Verificar conectividad real a través de DNS
    try {
      final lookup = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 2));
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        isOnlineNotifier.value = true;
      } else {
        isOnlineNotifier.value = false;
      }
    } on SocketException catch (_) {
      isOnlineNotifier.value = false;
    } on TimeoutException catch (_) {
      isOnlineNotifier.value = false;
    } catch (_) {
      isOnlineNotifier.value = false;
    }
  }

  static void dispose() {
    _subscription?.cancel();
  }
}