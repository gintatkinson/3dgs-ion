import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

class BackgroundWorker {
  Timer? _timer;
  int _counter = 0;
  int? _lastResult;
  final StreamController<int> _controller = StreamController<int>.broadcast();

  Stream<int> get results => _controller.stream;
  int? get lastResult => _lastResult;

  void start() {
    stop();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _counter++;
      _runCalculation(_counter.toDouble());
    });
  }

  Future<void> _runCalculation(double value) async {
    try {
      final result = await Isolate.run(() {
        double sum = 0.0;
        for (int i = 0; i < 1000000; i++) {
          sum += math.sin(value + i);
        }
        return sum.round();
      });
      _lastResult = result;
      if (!_controller.isClosed) {
        _controller.add(result);
      }
    } catch (e) {
      double sum = 0.0;
      for (int i = 0; i < 1000000; i++) {
        sum += math.sin(value + i);
      }
      _lastResult = sum.round();
      if (!_controller.isClosed) {
        _controller.add(sum.round());
      }
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
