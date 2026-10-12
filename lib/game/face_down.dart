import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

/// Turns raw accelerometer readings into "face down on the table" or not.
///
/// Flat and face down, gravity reads about -9.8 on z. Going down needs a
/// steady reading for a moment, so sliding the phone into place doesn't
/// flicker. Coming up is quicker, but still ignores a knock on the table.
class FaceDownDetector {
  FaceDownDetector({
    this.downZ = -7.8,
    this.upZ = -5.5,
    this.settleMs = 350,
    this.liftMs = 220,
  });

  final double downZ;
  final double upZ;
  final int settleMs;
  final int liftMs;

  bool _down = false;
  int? _since;

  bool get isDown => _down;

  /// Feeds one reading taken at [ms]. Returns the (possibly new) state.
  bool add(double z, int ms) {
    final candidate = _down ? z < upZ : z < downZ;
    if (candidate == _down) {
      _since = null;
      return _down;
    }
    _since ??= ms;
    if (ms - _since! >= (_down ? liftMs : settleMs)) {
      _down = candidate;
      _since = null;
    }
    return _down;
  }
}

/// Face down or not, from the real accelerometer. Only emits changes.
Stream<bool> faceDownStream() {
  final detector = FaceDownDetector();
  final clock = Stopwatch()..start();
  late StreamController<bool> out;
  StreamSubscription<AccelerometerEvent>? sub;
  out = StreamController<bool>.broadcast(
    onListen: () {
      var last = detector.isDown;
      out.add(last);
      sub =
          accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
              .listen((e) {
                final now = detector.add(e.z, clock.elapsedMilliseconds);
                if (now != last) {
                  last = now;
                  out.add(now);
                }
              }, onError: (Object _) {});
    },
    onCancel: () => sub?.cancel(),
  );
  return out.stream;
}
