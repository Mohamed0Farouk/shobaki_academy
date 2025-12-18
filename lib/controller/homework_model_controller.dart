import 'package:get/get.dart';

class HomeworkModelController extends GetxController {
  final String questionId; // Add this
  
  HomeworkModelController(this.questionId); // Add constructor
  
  final Rx<String?> selectedAnswer = Rx<String?>(null);
  RxBool flag = false.obs;

  void selectAnswer(String answer) {
    if (!flag.value) {
      selectedAnswer.value = answer;
    }
  }

  void resetAnswer() {
    selectedAnswer.value = null;
  }

  void toggleFlag() {
    flag.value = !flag.value;
  }
}