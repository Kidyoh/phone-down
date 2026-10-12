import 'package:flutter_test/flutter_test.dart';
import 'package:phone_down/game/face_down.dart';

void main() {
  test('needs a steady face-down reading before counting it', () {
    final d = FaceDownDetector();
    expect(d.add(-9.7, 0), isFalse);
    expect(d.add(-9.7, 200), isFalse);
    expect(d.add(-9.7, 360), isTrue);
  });

  test('ignores a knock on the table, catches a real pickup', () {
    final d = FaceDownDetector();
    d.add(-9.8, 0);
    d.add(-9.8, 400);
    expect(d.isDown, isTrue);
    // Bump: a spike for 80 ms.
    d.add(-2.0, 1000);
    d.add(-9.8, 1080);
    expect(d.isDown, isTrue);
    // Pickup: tilted up and staying there.
    d.add(-1.0, 2000);
    d.add(3.0, 2100);
    expect(d.add(6.0, 2230), isFalse);
  });

  test('a slight lean on the table still counts as down', () {
    final d = FaceDownDetector();
    d.add(-9.0, 0);
    d.add(-9.0, 400);
    expect(d.add(-6.5, 900), isTrue);
    expect(d.add(-6.5, 1500), isTrue);
  });
}
