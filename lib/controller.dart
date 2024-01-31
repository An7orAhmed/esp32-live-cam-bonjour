import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

class Controller extends GetxController {
  Socket? socket;
  var isConnected = false.obs;
  var imageBytes = <int>[].obs;
  var services = <Map<String, dynamic>>[].obs;
  List<int> packetBytes = [];
  var fps = 0.obs;
  var lastFrameTime = 0;
  Timer? timer;

  Future<void> mDNSScanner() async {
    if (isConnected.value) {
      disconnect();
      return;
    }

    try {
      String type = '_keo-cam._tcp';
      BonsoirDiscovery discovery = BonsoirDiscovery(type: type, printLogs: false);
      await discovery.ready;

      discovery.eventStream!.listen((event) {
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
          print('Service found : ${event.service?.toJson()}');
          event.service!.resolve(discovery.serviceResolver);
        } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
          print('Service resolved : ${event.service?.toJson()}');
          services.addIf(event.service!.name.isNotEmpty && !services.any((key) => key['name'] == event.service!.name),
              event.service!.toJson(prefix: ''));
        } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
          print('Service lost : ${event.service?.toJson()}');
          services.removeWhere((key) => key['name'] == event.service!.name);
        }
      });

      await discovery.start();
    } catch (e) {
      printError(info: "$e");
    }
  }

  void disconnect() {
    timer?.cancel();
    socket?.destroy();
    isConnected.value = false;
    Get.snackbar('info', 'Keo-Cam disconnected.');
  }

  void captureFrame() async {
    final dir = await getDownloadsDirectory();
    final filename = '${dir!.path}/${DateTime.now().millisecondsSinceEpoch}.jpeg';
    final file = await File(filename).create(recursive: true);
    await file.writeAsBytes(imageBytes);
  }

  Future<void> connectToESP(String socketIP, int socketPort) async {
    if (socketIP == '' || socketPort == 0) {
      Get.snackbar('error', 'IP or port invalid!');
      return;
    }

    try {
      socket = await Socket.connect(socketIP, socketPort);
      isConnected.value = true;
      Get.snackbar('info', 'Keo-Cam connected.');

      timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        socket?.write("GETDATA");
      });

      socket?.listen(
        (data) {
          try {
            final header = (data[0] << 16) | (data[1] << 8) | data[2];
            final footer = (data[data.length - 2] << 8) | data[data.length - 1];
            if (header == 0xFFD8FF) {
              packetBytes.assignAll(data);
            } else if (footer == 0xFFD9) {
              packetBytes.addAll(data);
              if (packetBytes.length < 5000) return;
              imageBytes.assignAll(packetBytes);
              int ct = DateTime.now().millisecondsSinceEpoch;
              fps.value = 1000 ~/ (ct - lastFrameTime);
              lastFrameTime = DateTime.now().millisecondsSinceEpoch;
            } else {
              packetBytes.addAll(data);
            }
          } catch (e) {
            print('Packet error: $e');
          }
        },
        onError: (error) {
          print('Socket error: $error');
          disconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      print('Error connecting to the server: $e');
      Get.snackbar('error', 'Something wrong!');
      isConnected.value = false;
    }
  }
}
