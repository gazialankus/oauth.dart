library oauth.utils_browser;
import 'dart:html';
import 'dart:typed_data';

bool _haveWarned = false;

List<int> getRandomBytes(int count) {
  // this is supposed to be cryptographically secure in the browsers that support it
  // http://stackoverflow.com/questions/11674820/how-do-i-generate-random-numbers-in-dart
  // http://stackoverflow.com/questions/16084766/compatibility-of-window-crypto-getrandomvalues
  Int32List l = new Int32List(count);
  window.crypto.getRandomValues(l);
  return new List<int>.generate(count, (int i) {
    int val = l[i].abs();
    while(val > 255) {
      val = val >> 1;
    }
    assert(val >= 0 && val <=255);
    return val;
  }, growable: false);
}
