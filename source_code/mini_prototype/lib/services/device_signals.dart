import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'api_service.dart';

class DeviceSignalsService {
  static final DeviceSignalsService _instance = DeviceSignalsService._internal();
  factory DeviceSignalsService() => _instance;
  DeviceSignalsService._internal();

  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfo();

  bool _isCollecting = false;
  DateTime? _lastSent;

  Future<Map<String, dynamic>?> collect({Duration sampleDuration = const Duration(seconds: 5)}) async {
    if (_isCollecting) return null;
    _isCollecting = true;
    try {
      final accelSamples = <double>[];
      final gyroSamples = <double>[];

      final accelSub = accelerometerEventStream().listen((e) {
        accelSamples.add(sqrt(e.x * e.x + e.y * e.y + e.z * e.z));
      });
      final gyroSub = gyroscopeEventStream().listen((e) {
        gyroSamples.add(sqrt(e.x * e.x + e.y * e.y + e.z * e.z));
      });

      await Future.delayed(sampleDuration);
      await accelSub.cancel();
      await gyroSub.cancel();

      final accelMean = accelSamples.isEmpty ? 0.0 : accelSamples.reduce((a, b) => a + b) / accelSamples.length;
      final accelVar = accelSamples.isEmpty ? 0.0
          : accelSamples.map((v) => (v - accelMean) * (v - accelMean)).reduce((a, b) => a + b) / accelSamples.length;
      final accelStd = sqrt(accelVar);
      final gyroMean = gyroSamples.isEmpty ? 0.0 : gyroSamples.reduce((a, b) => a + b) / gyroSamples.length;

      String motion;
      if (accelStd < 0.3) {
        motion = 'stationary';
      } else if (accelStd < 1.5) {
        motion = 'walking';
      } else {
        motion = 'vehicle';
      }

      final batteryLevel = await _battery.batteryLevel;
      final batteryState = await _battery.batteryState;
      final isCharging = batteryState == BatteryState.charging || batteryState == BatteryState.full;

      final dynamic conns = await _connectivity.checkConnectivity();
      String connType = 'none';
      bool hasWifi = false, hasMobile = false, hasEthernet = false;
      if (conns is List) {
        hasWifi     = conns.contains(ConnectivityResult.wifi);
        hasMobile   = conns.contains(ConnectivityResult.mobile);
        hasEthernet = conns.contains(ConnectivityResult.ethernet);
      } else {
        hasWifi     = conns == ConnectivityResult.wifi;
        hasMobile   = conns == ConnectivityResult.mobile;
        hasEthernet = conns == ConnectivityResult.ethernet;
      }
      if (hasWifi) {
        connType = 'wifi';
      } else if (hasMobile) {
        connType = 'mobile';
      } else if (hasEthernet) {
        connType = 'ethernet';
      }

      String? networkName;
      if (connType == 'wifi') {
        try {
          networkName = await _networkInfo.getWifiName();
          networkName = networkName?.replaceAll('"', '');
        } catch (_) {}
      }

      return {
        'accelMeanMagnitude': accelMean,
        'accelStdMagnitude': accelStd,
        'gyroMeanMagnitude': gyroMean,
        'motionClassification': motion,
        'batteryLevel': batteryLevel / 100.0,
        'batteryIsCharging': isCharging,
        'connectionType': connType,
        'networkName': networkName,
        'platformOs': Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other',
      };
    } catch (e) {
      return null;
    } finally {
      _isCollecting = false;
    }
  }

  Future<bool> collectAndSend({bool force = false}) async {
    final api = ApiService();
    final workerId = api.currentWorkerId ?? await api.loadWorkerId();
    if (workerId == null) return false;

    if (!force && _lastSent != null) {
      final age = DateTime.now().difference(_lastSent!);
      if (age.inMinutes < 5) return false;
    }

    final signals = await collect();
    if (signals == null) return false;

    final ok = await api.postDeviceSignals(workerId, signals);
    if (ok) _lastSent = DateTime.now();
    return ok;
  }
}
