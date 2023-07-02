import 'dart:async';
import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:oscilloscope/oscilloscope.dart';

class SensorPage extends StatefulWidget {
  const SensorPage({Key? key, required this.device}) : super(key: key);
  final BluetoothDevice device;

  @override
  // ignore: library_private_types_in_public_api
  _SensorPageState createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  late bool isReady;
  late Stream<List<int>> stream;
  List traceDust = [];

  @override
  void initState() {
    super.initState();
    isReady = false;
    connectToDevice();
  }

  connectToDevice() async {
    // ignore: unnecessary_null_comparison
    if (widget.device == null) {
      _pop();
      return;
    }

    Timer(const Duration(seconds: 15), () {
      if (!isReady) {
        disconnectFromDevice();
        _pop();
      }
    });

    await widget.device.connect();
    discoverServices();
  }

  disconnectFromDevice() {
    // ignore: unnecessary_null_comparison
    if (widget.device == null) {
      _pop();
      return;
    }

    widget.device.disconnect();
  }

  discoverServices() async {
    // ignore: unnecessary_null_comparison
    if (widget.device == null) {
      _pop();
      return;
    }

    List<BluetoothService> services = await widget.device.discoverServices();
    for (var service in services) {
      if (service.uuid.toString() == SERVICE_UUID) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == CHARACTERISTIC_UUID) {
            characteristic.setNotifyValue(!characteristic.isNotifying);
            stream = characteristic.value;

            setState(() {
              isReady = true;
            });
          }
        }
      }
    }

    if (!isReady) {
      _pop();
    }
  }

  Future<bool> _onWillPop() async {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Are you sure?'),
              content:
                  const Text('Do you want to disconnect device and go back?'),
              actions: <Widget>[
                ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('No')),
                ElevatedButton(
                    onPressed: () {
                      disconnectFromDevice();
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Yes')),
              ],
            ));
    return true; //or should this be 'false' instead of 'true'?
  }

  _pop() {
    Navigator.of(context).pop(true);
  }

  String _dataParser(List<int> dataFromDevice) {
    return utf8.decode(dataFromDevice);
  }

  @override
  Widget build(BuildContext context) {
    Oscilloscope oscilloscope = Oscilloscope(
        showYAxis: true,
        // ignore: deprecated_member_use
        padding: 0.0,
        backgroundColor: Colors.black,
        traceColor: Colors.white,
        yAxisMax: 3000.0,
        yAxisMin: 0.0,
        dataSet: traceDust.cast<num>());

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Optical Dust Sensor'),
        ),
        body: Container(
            child: !isReady
                ? const Center(
                    child: Text(
                      "Waiting...",
                      style: TextStyle(fontSize: 24, color: Colors.red),
                    ),
                  )
                : StreamBuilder<List<int>>(
                    stream: stream,
                    builder: (BuildContext context,
                        AsyncSnapshot<List<int>> snapshot) {
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }

                      if (snapshot.connectionState == ConnectionState.active) {
                        //     currentValue = _dataParser(snapshot.data);
                        List<int> currentValue;
                        List<int>? data = snapshot.data;

                        if (data != null) {
                          currentValue = List<int>.from(data);

                          // Use the currentValue list as needed
                        } else {
                          int value = 0;
                          currentValue = List<int>.filled(1, value);
                        }
                        traceDust
                            .add(double.tryParse(currentValue.join(', ')) ?? 0);

                        return Center(
                            child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              flex: 1,
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    const Text('Current value from Sensor',
                                        style: TextStyle(fontSize: 14)),
                                    Text('$currentValue ug/m3',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 24))
                                  ]),
                            ),
                            Expanded(
                              flex: 1,
                              child: oscilloscope,
                            )
                          ],
                        ));
                      } else {
                        return const Text('Check the stream');
                      }
                    },
                  )),
      ),
    );
  }
}
