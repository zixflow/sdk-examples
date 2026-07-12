import 'package:flutter_test/flutter_test.dart';
import 'package:zixflow_flutter_demo/config.dart';

void main() {
  test('AppConfig exposes API key from environment or placeholder', () {
    expect(AppConfig.zixflowApiKey, isNotEmpty);
  });
}
