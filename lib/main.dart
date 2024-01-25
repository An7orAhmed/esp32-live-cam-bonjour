import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controller.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ctx = Get.put(Controller());

    Widget appBody() {
      if (ctx.isConnected.value) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              SizedBox(
                width: context.mediaQuery.size.width,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  child: ctx.imageBytes.isNotEmpty
                      ? Image.memory(
                          Uint8List.fromList(ctx.imageBytes),
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.high,
                        )
                      : const Center(child: Text('Waiting for image frame...')),
                ),
              ),
              Positioned(
                top: 20,
                left: 20,
                child: Text(
                  "FPS: ${ctx.fps.value}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: Colors.deepOrange,
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: ElevatedButton(
                  onPressed: () => ctx.captureFrame(),
                  child: const Text('Capture'),
                ),
              ),
            ],
          ),
        );
      }

      return Obx(
        () => ctx.services.isEmpty
            ? const Center(child: Text('Scan for services...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)))
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: ListView(
                  children: ctx.services
                      .map(
                        (service) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            child: ListTile(
                              title:
                                  Text(service['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                              subtitle: Text(service['type'] ?? ''),
                              trailing: Text("${service['host'] ?? ''}:${service['port'] ?? ''}",
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              onTap: () => ctx.connectToESP(service['host'] ?? '', service['port'] ?? 0),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
      );
    }

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.all(5),
            child: Image.asset('assets/logo.png'),
          ),
          title: const Text('Safety Camera LIVE'),
          actions: [
            Obx(
              () => ElevatedButton(
                onPressed: () => ctx.mDNSScanner(),
                child: Text(ctx.isConnected.value ? 'Disconnect' : 'Scan'),
              ),
            ),
            const SizedBox(width: 10)
          ],
        ),
        body: Obx(() => appBody()),
      ),
    );
  }
}
