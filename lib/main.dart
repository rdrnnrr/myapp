import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import 'package:record/record.dart';
import 'package:record/record_platform_interface.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';
import 'dart:developer' as developer;
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

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
      bool paired = await bluetooth.bondDeviceAtAddress(device.address);
      if (paired) {
        developer.log('Paired with ${device.name}');
        _startDiscovery(); // Refresh list after pairing
      } else {
        developer.log('Failed to pair with ${device.name}');
      }
    } catch (e) {
      print('Error pairing with device: $e');
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      print('Connected to ${device.name}');
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
      _audioPlayer.playBytes(data.buffer.asUint8List());
    }).onDone(() {
      developer.log('Disconnected by remote device');
    });
  }

  void _startRecordingAndStreaming() async {
    if (await _audioRecorder.hasPermission()) {
      final tempPath = await _audioRecorder.start(
        RecordConfig(),
        path: 'temp_audio.m4a', // Provide a temporary path for recording
      );
 developer.log('Recording started: $tempPath');

      _audioRecorder.onStateChanged().listen((state) {
 developer.log('Recorder state changed: $state');
      });
    }
    setState(() {
      _isRecording = false;
    });
    // TODO: Stop streaming audio data
  }



  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
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
      bottomNavigationBar: BottomAppBar(
        floatingActionButton: FloatingActionButton(
        onPressed: _startDiscovery,
        tooltip: 'Start Discovery',
        child: const Icon(Icons.search),
      ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _selectedDevice != null ? 'Selected Device: ${_selectedDevice!.name ?? _selectedDevice!.address}' : 'Select a device',
            },
          );
        },
      ),
    );
}
}
