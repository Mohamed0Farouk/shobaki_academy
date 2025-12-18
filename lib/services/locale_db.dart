import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDB extends GetxService {
  SharedPreferences? sharedPref;

  Future<LocalDB> init() async {
    sharedPref = await SharedPreferences.getInstance();
    return this;
  }
}
