import 'dart:convert';
import 'dart:typed_data';

import 'package:ble_peripheral_plus/ble_peripheral_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

const serviceUuid = 'eecc047d-6260-444a-a198-41f71800e364';
const characteristicUuid = '1dc762e2-84a8-4705-9cc3-e6b5f43a9b70';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isAdvertising = false;
  String _status = 'Not advertising';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stream Deck',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Stream Deck')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_status, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _startOrStopAdvertising,
                  child: Text(
                    _isAdvertising ? 'Stop receiver link' : 'Connect to PC',
                  ),
                ),
                const SizedBox(height: 24),
                for (var button = 1; button <= 3; button++) ...[
                  SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      onPressed: _isAdvertising
                          ? () => _sendCommand('BUTTON_$button')
                          : null,
                      child: Text('Button $button'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startOrStopAdvertising() async {
    if (_isAdvertising) {
      await BlePeripheral.stopAdvertising();
      if (mounted) {
        setState(() {
          _isAdvertising = false;
          _status = 'Not advertising';
        });
      }
      return;
    }

    setState(() => _status = 'Requesting Bluetooth permissions...');
    try {
      final permissions = await <Permission>[
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ].request();
      if (permissions.values.any((status) => !status.isGranted)) {
        throw StateError('Bluetooth permissions were not granted.');
      }

      await BlePeripheral.initialize();
      if (!await BlePeripheral.isSupported()) {
        throw StateError('This device does not support BLE peripheral mode.');
      }

      await BlePeripheral.clearServices();
      await BlePeripheral.addService(
        BleService(
          uuid: serviceUuid,
          primary: true,
          characteristics: [
            BleCharacteristic(
              uuid: characteristicUuid,
              properties: [
                CharacteristicProperties.read.index,
                CharacteristicProperties.notify.index,
              ],
              permissions: [AttributePermissions.readable.index],
              descriptors: null,
              value: Uint8List(0),
            ),
          ],
        ),
      );

      await BlePeripheral.startAdvertising(
        services: [serviceUuid],
        localName: 'StrDeck',
        requireBonding: false,
      );

      if (mounted) {
        setState(() {
          _isAdvertising = true;
          _status = 'Advertising as StrDeck. Waiting for the PC receiver.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Bluetooth setup failed: $error');
    }
  }

  Future<void> _sendCommand(String command) async {
    try {
      await BlePeripheral.updateCharacteristic(
        characteristicId: characteristicUuid,
        value: Uint8List.fromList(utf8.encode(command)),
      );
      if (mounted) setState(() => _status = 'Sent $command');
    } catch (error) {
      if (mounted) setState(() => _status = 'Send failed: $error');
    }
  }
}
