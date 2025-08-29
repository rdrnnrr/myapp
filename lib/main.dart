import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';
import 'dart:developer' as developer;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FlutterBluetoothSerial bluetooth = FlutterBluetoothSerial.instance;
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice? _selectedDevice;
  BluetoothConnection? _connection;
  bool _isDiscovering = false;
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  void _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
      _devicesList = [];
    });

    bluetooth.startDiscovery().listen((r) {
      setState(() {
        final existingIndex = _devicesList.indexWhere((element) => element.address == r.device.address);
        if (existingIndex < 0) {
          _devicesList.add(r.device);
        }
      });
    }).onDone(() {
      setState(() {
        _isDiscovering = false;
      });
    });
  }

  void _pairDevice(BluetoothDevice device) async {
    try {
      bool? paired = await bluetooth.bondDeviceAtAddress(device.address);
      if (paired == true) {
        developer.log('Paired with ${device.name}');
        _startDiscovery();
      } else {
        developer.log('Failed to pair with ${device.name}');
      }
    } catch (e) {
      developer.log('Error pairing with device: $e');
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      developer.log('Connected to ${device.name}');
      _listenForAudio();
    } catch (e) {
      developer.log('Error connecting to device: $e');
    }
  }

  @override
  void dispose() {
    _connection?.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _listenForAudio() {
    _connection?.input?.listen((Uint8List data) {
      _audioPlayer.play(BytesSource(data));
    }).onDone(() {
      developer.log('Disconnected by remote device');
    });
  }

  void _startRecordingAndStreaming() async {
    if (await _audioRecorder.hasPermission()) {
      await _audioRecorder.start(
        RecordConfig(),
        path: 'temp_audio.m4a',
      );
      developer.log('Recording started: temp_audio.m4a');

      _audioRecorder.onStateChanged().listen((state) {
        developer.log('Recorder state changed: $state');
      });
    }
    setState(() {
      _isRecording = true;
    });
  }

  void _stopRecordingAndStreaming() async {
    final path = await _audioRecorder.stop();
    developer.log('Recording stopped: $path');
    setState(() {
      _isRecording = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: <Widget>[
          _isDiscovering
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _startDiscovery,
                )
        ],
      ),
      body: ListView.builder(
        itemCount: _devicesList.length,
        itemBuilder: (context, index) {
          final device = _devicesList[index];
          return ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(device.name ?? 'Unknown Device'),
            subtitle: Text(device.address.toString()),
            onTap: () {
              setState(() {
                _selectedDevice = device;
              });
            },
            trailing: _selectedDevice != null && _selectedDevice!.address == device.address
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => _pairDevice(device),
                        child: const Text('Pair'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _connectToDevice(device),
                        child: const Text('Connect'),
                      ),
                    ],
                  )
                : null,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isRecording ? _stopRecordingAndStreaming : _startRecordingAndStreaming,
        tooltip: _isRecording ? 'Stop Recording' : 'Start Recording',
        child: Icon(_isRecording ? Icons.mic_off : Icons.mic),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _selectedDevice != null ? 'Selected Device: ${_selectedDevice!.name ?? _selectedDevice!.address}' : 'Select a device',
          ),
        ),
      ),
    );
  }
}
