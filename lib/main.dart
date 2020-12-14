// For performing some operations asynchronously
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

// For using PlatformException
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_sparkline/flutter_sparkline.dart';
import 'package:oscilloscope/oscilloscope.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BluetoothApp(),
    );
  }
}

class BluetoothApp extends StatefulWidget {
  @override
  _BluetoothAppState createState() => _BluetoothAppState();
}

class _BluetoothAppState extends State<BluetoothApp> {
  // Initializing the Bluetooth connection state to be unknown
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  // Initializing a global key, as it would help us in showing a SnackBar later
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  // Get the instance of the Bluetooth
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  // Track the Bluetooth connection with the remote device
  BluetoothConnection connection;

  int _deviceState;

  // List<double> sampleData = List<double>(100);
  var sampleData = [0.0, 1.0, 1.5, 2.0, 0.0, 0.0, -0.5, -1.0, -0.5, 0.0, 0.0];

  var sampleData1 = [0.0, 0.0];
  var sampleData2 = [0.0, 0.0];

  List<double> traceOne = List();
  List<double> traceTwo = List();

  List<int> outList = List<int>(19);
  List<int> intList = [
    0,
    7,
    16,
    25,
    34,
    44,
    54,
    63,
    72,
    81,
    91,
    101,
    111,
    121,
    131,
    141,
    151,
    161,
    171,
    181
  ];
  bool isReadyToGo = false;
  final int linelength = 183;
  int buffHead = 0, buffTail = 0;
  Uint8List buffByteList = Uint8List(100000);
  String buffString;
  // List<List<double>> buffDoubleList = new List.generate(1000, (index) => []);

  bool isDisconnecting = false;

  Map<String, Color> colors = {
    'onBorderColor': Colors.green,
    'offBorderColor': Colors.red,
    'neutralBorderColor': Colors.transparent,
    'onTextColor': Colors.green[700],
    'offTextColor': Colors.red[700],
    'neutralTextColor': Colors.blue,
  };

  // To track whether the device is still connected to Bluetooth
  bool get isConnected => connection != null && connection.isConnected;

  // Define some variables, which will be required later
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice _device;
  bool _connected = false;
  bool _isButtonUnavailable = false;

  void outView() {
    // int temp = 0;
    // print(outList[2]);
    // sampleData1.add(outList[2].toDouble() / 1000000.0);
    // sampleData2.add(outList[3].toDouble() / 1000000.0);
    setState(() {
      sampleData1.add(0.70.toDouble());
      sampleData2.add(0.80.toDouble());
    });
  }

  int parseBuffer() {
    // int buffHead = 0, buffTail = 0;
    // Uint8List buffByteList = Uint8List(100000);
    // String buffString;

    Uint8List ui8 = Uint8List(linelength);
    var ui8Temp;
    bool readyNow = false;
    bool absolutelyReadyNow = false;

    for (int i = 0; i < linelength + 1; i++) {
      if ((buffTail + i) < buffByteList.length) {
        if (buffByteList[buffTail + i] == 0x0D) {
          readyNow = true;
          buffTail = buffTail + i + 1;
          break;
        }
      } else {
        if (buffByteList[buffTail + i - buffByteList.length] == 0x0D) {
          readyNow = true;
          buffTail = buffTail + i - buffByteList.length + 1;
          break;
        }
      }
    }

    if (readyNow && (buffTail + linelength < buffByteList.length)) {
      if (buffByteList[buffTail + linelength] == 0x0D) {
        absolutelyReadyNow = true;
      }
    } else if (readyNow && (buffTail + linelength >= buffByteList.length)) {
      if (buffByteList[buffTail + linelength - buffByteList.length] == 0x0D) {
        absolutelyReadyNow = true;
      }
    } else {
      return 1;
    }

    if (absolutelyReadyNow == false) {
      return 2;
    }

    for (int i = 0; i < linelength; i++) {
      if ((buffTail + i) < buffByteList.length) {
        ui8Temp = buffByteList[buffTail + i];
      } else {
        ui8Temp = buffByteList[buffTail + i - buffByteList.length];
      }

      // Only ' ', '+', '-', '0'... '9' are accepted
      if (ui8Temp != 0x20 &&
          ui8Temp != 0x2B &&
          ui8Temp != 0x2D &&
          ui8Temp != 0x30 &&
          ui8Temp != 0x31 &&
          ui8Temp != 0x32 &&
          ui8Temp != 0x33 &&
          ui8Temp != 0x34 &&
          ui8Temp != 0x35 &&
          ui8Temp != 0x36 &&
          ui8Temp != 0x37 &&
          ui8Temp != 0x38 &&
          ui8Temp != 0x39) {
        buffTail = buffTail + i + 1;
        return 3;
      }
    }

    for (int i = 0; i < linelength; i++) {
      if ((buffTail + i) < buffByteList.length) {
        ui8[i] = buffByteList[buffTail + i];
      } else {
        ui8[i] = buffByteList[buffTail + i - buffByteList.length];
      }
    }

    try {
      for (int i = 0; i < 19; i++) {
        outList[i] =
            int.parse(ascii.decode(ui8.sublist(intList[i], intList[i + 1])));
      }
    } catch (e) {
      return 4;
    }

    return 0;
  }

  void addElement2Buff(Uint8List ui8l) {
    for (int i = 0; i < ui8l.length; i++) {
      if ((buffHead + i) < buffByteList.length)
        buffByteList[buffHead + i] = ui8l[i];
      else
        buffByteList[buffHead + i - buffByteList.length] = ui8l[i];
    }

    if ((buffHead + ui8l.length) < buffByteList.length)
      buffHead = buffHead + ui8l.length;
    else
      buffHead = buffHead + ui8l.length - buffByteList.length;
  }

  @override
  void initState() {
    super.initState();

    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    _deviceState = 0; // neutral

    // If the bluetooth of the device is not enabled,
    // then request permission to turn on bluetooth
    // as the app starts up
    enableBluetooth();

    // Listen for further state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
        if (_bluetoothState == BluetoothState.STATE_OFF) {
          _isButtonUnavailable = true;
        }
        getPairedDevices();
      });
    });
  }

  @override
  void dispose() {
    // Avoid memory leak and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }

    super.dispose();
  }

  // Request Bluetooth permission from the user
  Future<void> enableBluetooth() async {
    // Retrieving the current Bluetooth state
    _bluetoothState = await FlutterBluetoothSerial.instance.state;

    // If the bluetooth is off, then turn it on first
    // and then retrieve the devices that are paired.
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      await FlutterBluetoothSerial.instance.requestEnable();
      await getPairedDevices();
      return true;
    } else {
      await getPairedDevices();
    }
    return false;
  }

  // For retrieving and storing the paired devices
  // in a list.
  Future<void> getPairedDevices() async {
    List<BluetoothDevice> devices = [];

    // To get the list of paired devices
    try {
      devices = await _bluetooth.getBondedDevices();
    } on PlatformException {
      print("Error");
    }

    // It is an error to call [setState] unless [mounted] is true.
    if (!mounted) {
      return;
    }

    // Store the [devices] list in the [_devicesList] for accessing
    // the list outside this class
    setState(() {
      _devicesList = devices;
    });
  }

  // Now, its time to build the UI
  @override
  Widget build(BuildContext context) {
    // Create A Scope Display for Sine
    Oscilloscope scopeOne = Oscilloscope(
      showYAxis: true,
      yAxisColor: Colors.orange,
      padding: 20.0,
      backgroundColor: Colors.white,
      traceColor: Colors.green,
      yAxisMax: 1.0,
      yAxisMin: -1.0,
      dataSet: sampleData1,
    );

    // Create A Scope Display for Cosine
    Oscilloscope scopeTwo = Oscilloscope(
      showYAxis: true,
      padding: 20.0,
      backgroundColor: Colors.white,
      traceColor: Colors.yellow,
      yAxisMax: 1.0,
      yAxisMin: -1.0,
      dataSet: sampleData2,
    );

    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text("Flutter Bluetooth"),
          backgroundColor: Colors.deepPurple,
          actions: <Widget>[
            FlatButton.icon(
              icon: Icon(
                Icons.refresh,
                color: Colors.white,
              ),
              label: Text(
                "Refresh",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              splashColor: Colors.deepPurple,
              onPressed: () async {
                // So, that when new devices are paired
                // while the app is running, user can refresh
                // the paired devices list.
                await getPairedDevices().then((_) {
                  show('Device list refreshed');
                });
              },
            ),
          ],
        ),
        body: Container(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Visibility(
                visible: _isButtonUnavailable &&
                    _bluetoothState == BluetoothState.STATE_ON,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.yellow,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: <Widget>[
                              SizedBox(height: 6),
                              RaisedButton(
                                elevation: 2,
                                child: Text("Bluetooth Settings"),
                                onPressed: () {
                                  FlutterBluetoothSerial.instance
                                      .openSettings();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 50, top: 2),
                        child: Text(
                          'Enable Bluetooth',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    Switch(
                      value: _bluetoothState.isEnabled,
                      onChanged: (bool value) {
                        future() async {
                          if (value) {
                            await FlutterBluetoothSerial.instance
                                .requestEnable();
                          } else {
                            await FlutterBluetoothSerial.instance
                                .requestDisable();
                          }

                          await getPairedDevices();
                          _isButtonUnavailable = false;

                          if (_connected) {
                            _disconnect();
                          }
                        }

                        future().then((_) {
                          setState(() {});
                        });
                      },
                    )
                  ],
                ),
              ),
              Stack(
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          "PAIRED DEVICES",
                          style: TextStyle(fontSize: 18, color: Colors.blue),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Device:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            DropdownButton(
                              items: _getDeviceItems(),
                              onChanged: (value) =>
                                  setState(() => _device = value),
                              value: _devicesList.isNotEmpty ? _device : null,
                            ),
                            RaisedButton(
                              onPressed: _isButtonUnavailable
                                  ? null
                                  : _connected
                                      ? _disconnect
                                      : _connect,
                              child:
                                  Text(_connected ? 'Disconnect' : 'Connect'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: new Container(
                          width: 300,
                          height: 200,
                          child: new Flexible(flex: 1, child: scopeOne),
                          // child: new Sparkline(
                          //   data: sampleData,
                          // ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: new Container(
                          width: 300,
                          height: 200,
                          child: new Flexible(flex: 2, child: scopeTwo),
                          // child: new Sparkline(
                          //   data: sampleData,
                          // ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Create the List of devices to be shown in Dropdown Menu
  List<DropdownMenuItem<BluetoothDevice>> _getDeviceItems() {
    List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (_devicesList.isEmpty) {
      items.add(DropdownMenuItem(
        child: Text('NONE'),
      ));
    } else {
      _devicesList.forEach((device) {
        items.add(DropdownMenuItem(
          child: Text(device.name),
          value: device,
        ));
      });
    }
    return items;
  }

  // Method to connect to bluetooth
  void _connect() async {
    setState(() {
      _isButtonUnavailable = true;
    });
    if (_device == null) {
      show('No device selected');
    } else {
      if (!isConnected) {
        await BluetoothConnection.toAddress(_device.address)
            .then((_connection) {
          print('Connected to the device');
          connection = _connection;
          setState(() {
            _connected = true;
          });

          connection.input.listen((Uint8List data) {
            //Data entry point

            var returnVar = 9;
            var buffACSII = data;

            addElement2Buff(buffACSII);

            if ((buffHead > buffTail) &&
                ((buffHead - buffTail) > (2 * linelength + 2))) {
              returnVar = parseBuffer();
            } else if ((buffHead < buffTail) &&
                ((buffByteList.length - (buffTail - buffHead)) >
                    (2 * linelength + 2))) {
              returnVar = parseBuffer();
            }

            // if (returnVar != 2 && returnVar != 9) {
            //   print('Error? ');
            //   print(returnVar);
            // }

            if (returnVar == 0) {
              // Everything is done right and the outputs are in outList[19]
              outView();
            }
          }).onDone(() {
            if (isDisconnecting) {
              print('Disconnecting locally!');
            } else {
              print('Disconnected remotely!');
            }
            if (this.mounted) {
              setState(() {});
            }
          });
        }).catchError((error) {
          print('Cannot connect, exception occurred');
          print(error);
        });
        show('Device connected');
        isReadyToGo = true;

        setState(() => _isButtonUnavailable = false);
      }
    }
  }

  // Method to disconnect bluetooth
  void _disconnect() async {
    setState(() {
      _isButtonUnavailable = true;
      _deviceState = 0;
    });

    await connection.close();
    show('Device disconnected');
    if (!connection.isConnected) {
      setState(() {
        _connected = false;
        _isButtonUnavailable = false;
      });
    }
  }

  // Method to show a Snackbar,
  // taking message as the text
  Future show(
    String message, {
    Duration duration: const Duration(seconds: 3),
  }) async {
    await new Future.delayed(new Duration(milliseconds: 100));
    _scaffoldKey.currentState.showSnackBar(
      new SnackBar(
        content: new Text(
          message,
        ),
        duration: duration,
      ),
    );
  }
}
