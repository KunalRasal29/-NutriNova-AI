import 'package:flutter_test/flutter_test.dart';
import 'package:nutrinova_ai/src/core/api/api_client.dart';
import 'package:nutrinova_ai/src/core/widgets/nova_widgets.dart';

void main() {
  group('friendlyErrorMessage', () {
    test('hides backend non-field key for invalid credentials', () {
      const error = ApiException(
        'non_field_errors: Invalid email or password.',
        statusCode: 400,
      );

      expect(
        friendlyErrorMessage(error),
        'The email or password is incorrect. Please try again.',
      );
    });

    test('turns browser connection errors into an actionable message', () {
      final error = Exception(
        'The connection errored: XMLHttpRequest onError callback',
      );

      expect(
        friendlyErrorMessage(error),
        'We could not connect to LaPulgaFit. Check your connection and try again.',
      );
    });
  });
}
