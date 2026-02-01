import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_info.g.dart';

/// Service to check network connectivity status
abstract class NetworkInfo {
  Future<bool> get isConnected;
  Stream<bool> get onConnectivityChanged;
}

class NetworkInfoImpl implements NetworkInfo {

  NetworkInfoImpl({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();
  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    // connectivity_plus 6.x returns List<ConnectivityResult>
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(
      // connectivity_plus 6.x emits List<ConnectivityResult>
      (results) => results.any((result) => result != ConnectivityResult.none),
    );
  }
}

@riverpod
NetworkInfo networkInfo(NetworkInfoRef ref) {
  return NetworkInfoImpl();
}

@riverpod
Stream<bool> connectivityStream(ConnectivityStreamRef ref) {
  final networkInfo = ref.watch(networkInfoProvider);
  return networkInfo.onConnectivityChanged;
}

@riverpod
Future<bool> isConnected(IsConnectedRef ref) async {
  final networkInfo = ref.watch(networkInfoProvider);
  return networkInfo.isConnected;
}
