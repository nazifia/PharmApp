import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapp/core/utils/phone_utils.dart';

void main() {
  test('whatsAppUri builds international wa.me link', () {
    final uri = whatsAppUri('0803 219 4090', 'Hi & bye');
    expect(uri.toString(), 'https://wa.me/2348032194090?text=Hi+%26+bye');
    expect(whatsAppUri('+2348032194090', 'x')!.path, '/2348032194090');
    expect(whatsAppUri('12345', 'x'), isNull);
    expect(whatsAppUri(null, 'x'), isNull);
  });
}
