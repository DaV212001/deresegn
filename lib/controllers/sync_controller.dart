import 'package:get/get.dart';

class SyncController extends GetxController {
  var pendingRequests = 0.obs;
  var successfulSyncs = 0.obs;
  
  void addPending() => pendingRequests.value++;
  void removePending() {
    if (pendingRequests.value > 0) {
      pendingRequests.value--;
    }
  }
  
  void recordSuccess() {
    successfulSyncs.value++;
    if (pendingRequests.value > 0) {
      pendingRequests.value--;
    }
  }
}
