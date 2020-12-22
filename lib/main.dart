// For performing some operations asynchronously
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
// import 'dart:core';

// For using PlatformException
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:smart_signal_processing/smart_signal_processing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sparkline/flutter_sparkline.dart';
// import 'package:oscilloscope/oscilloscope.dart';

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

  String tempStringTimeNow =
      'Recorded_at_' + DateTime.now().toString().replaceAll(RegExp(':'), '_');

  String fileNameBasedOnTime;

  var sampleData1 = [0.0, 0.0];
  var sampleData2 = [0.0, 0.0];
  var outputObserver;
  int varCeil = 0;
  static const varLength = 1000;
  static const plotLength = 200;
  int traceUpdatePeriod = 5;
  List<double> trace1 = []; //List<double>(varLength);
  double trace1m = 0.0;
  List<double> trace2 = []; //List<double>(varLength);
  double trace2m = 0.0;
  List<double> trace3 = []; //List<double>(varLength);
  double trace3m = 0.0;
  List<double> trace4 = []; //List<double>(varLength);
  double trace4m = 0.0;
  List<double> trace5 = []; //List<double>(varLength);
  double trace5m = 0.0;
  List<double> trace6 = []; //List<double>(varLength);
  double trace6m = 0.0;
  List<double> trace7 = []; //List<double>(varLength);
  double trace7m = 0.0;
  List<double> trace8 = []; //List<double>(varLength);
  double trace8m = 0.0;

  List<double> plotData1 = List<double>(plotLength);
  List<double> plotData2 = List<double>(plotLength);

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
  bool firstReceive = true;
  int traceCount = 0;
  bool keepGoing = false;
  bool ceilingReached = false;
  bool doPlots = false;
  final int linelength = 183;
  int buffHead = 0, buffTail = 0;
  Uint8List buffByteList = Uint8List(100000);
  String buffString;

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
  Future<String> get _localPath async {
    final directory = await getExternalStorageDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/' + fileNameBasedOnTime);
  }

  Future<int> readCounter() async {
    try {
      final file = await _localFile;

      // Read the file
      String contents = await file.readAsString();

      return int.parse(contents);
    } catch (e) {
      // If encountering an error, return 0
      return 0;
    }
  }

  Future<File> writeData(String thisData) async {
    final file = await _localFile;

    // Write the file
    return file.writeAsString(thisData, mode: FileMode.append);
  }

  // Future<File> writeSomething() async {
  //   final file = await _localFile;

  //   // Write the file
  //   return file
  //       .writeAsString('Hello! Hello! Good to be back!! Good to be back!!!');
  // }

  void outView() {
    // 0. Time
    // 1. I7  2. O7_1  3. O7_2   4. D_OD7_1   5. D_OD7_2
    // 6. I8  7. O8_1  8. O8_2   9. D_OD8_1  10. D_OD8_2
    // 11. Delta_C_HbO2_1  12. Delta_C_HbO2_2
    // 13. Delta_C_Hb_1    14. Delta_C_Hb_2
    // 15. OXY_1  16. OXY_2
    // 17. BV_1   18. BV_2

    double tempDouble = 0.0;

    if (doPlots == false && traceCount > 10) doPlots = true;

    if (ceilingReached == false && traceCount > varLength)
      ceilingReached = true;
    // Removing the first element and
    // Adding a number to the end of the list
    if (ceilingReached == true) trace1.removeAt(0);
    trace1.add(outList[2].toDouble()); // O7_1
    if (ceilingReached == true) trace2.removeAt(0);
    trace2.add(outList[4].toDouble()); // D_OD7_1
    if (ceilingReached == true) trace3.removeAt(0);
    trace3.add(outList[7].toDouble()); // O8_1
    if (ceilingReached == true) trace4.removeAt(0);
    trace4.add(outList[9].toDouble()); // D_OD8_1
    if (ceilingReached == true) trace5.removeAt(0);
    trace5.add(outList[11].toDouble()); // Delta_C_HbO2_1
    if (ceilingReached == true) trace6.removeAt(0);
    trace6.add(outList[13].toDouble()); // Delta_C_Hb_1
    if (ceilingReached == true) trace7.removeAt(0);
    trace7.add(outList[15].toDouble()); // OXY_1
    if (ceilingReached == true) trace8.removeAt(0);
    trace8.add(outList[17].toDouble()); // BV_1

    traceCount++;
    if (keepGoing == false && traceCount > traceUpdatePeriod) {
      keepGoing = true;
    }
    if (keepGoing == true) {
      tempDouble = 0.0;
      varCeil = min(traceCount, varLength);
      for (int i = varCeil; i > varCeil - traceUpdatePeriod; i--)
        tempDouble += trace1[i - 1];
      trace1m = tempDouble / traceUpdatePeriod.toDouble();

      tempDouble = 0.0;
      for (int i = varCeil; i > varCeil - traceUpdatePeriod; i--)
        tempDouble += trace2[i - 1];
      trace2m = tempDouble / traceUpdatePeriod.toDouble();

      tempDouble = 0.0;
      for (int i = varCeil; i > varCeil - traceUpdatePeriod; i--)
        tempDouble += trace3[i - 1];
      trace3m = tempDouble / traceUpdatePeriod.toDouble();

      tempDouble = 0.0;
      for (int i = varCeil; i > varCeil - traceUpdatePeriod; i--)
        tempDouble += trace4[i - 1];
      trace4m = tempDouble / traceUpdatePeriod.toDouble();

      tempDouble = 0.0;
      for (int i = varCeil; i > varCeil - traceUpdatePeriod; i--)
        tempDouble += trace5[i - 1];
      trace5m = tempDouble / traceUpdatePeriod.toDouble();

      tempDouble = 0.0;
      for (int i = varCeil; i > varCeil - traceUpdatePeriod; i--)
        tempDouble += trace6[i - 1];
      trace6m = tempDouble / traceUpdatePeriod.toDouble();

      tempDouble = 0.0;
      for (int i = varCeil; i > varCeil - traceUpdatePeriod; i--)
        tempDouble += trace7[i - 1];
      trace7m = tempDouble / traceUpdatePeriod.toDouble();

      tempDouble = 0.0;
      for (int i = varCeil; i > varCeil - traceUpdatePeriod; i--)
        tempDouble += trace8[i - 1];
      trace8m = tempDouble / traceUpdatePeriod.toDouble();

      if (doPlots == true) {
        plotData1 = trace1.sublist(max(1, varCeil - plotLength), varCeil);
        plotData2 = trace3.sublist(max(1, varCeil - plotLength), varCeil);
        if ((traceCount % traceUpdatePeriod) == 0) setState(() {});
      }
    }
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

    writeData(ascii.decode(ui8) + '\r');

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

    fileNameBasedOnTime =
        tempStringTimeNow.substring(1, tempStringTimeNow.length - 7) + '.txt';
    // writeData('Hello! Hello! Good to be back!! Good to be back!!!');
    // outputObserver = writeSomething();
    writeData('fNIRS data is recorded with following columns:\r\n\r\n');
    var tempStringInfo = '0. Time\r\n' +
        '1. I7  2. O7_1  3. O7_2   4. D_OD7_1   5. D_OD7_2\r\n' +
        '6. I8  7. O8_1  8. O8_2   9. D_OD8_1  10. D_OD8_2\r\n' +
        '11. Delta_C_HbO2_1  12. Delta_C_HbO2_2\r\n' +
        '13. Delta_C_Hb_1    14. Delta_C_Hb_2\r\n' +
        '15. OXY_1  16. OXY_2\r\n' +
        '17. BV_1   18. BV_2\r\n\r\n';
    writeData(tempStringInfo);

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
    // Oscilloscope scopeOne = Oscilloscope(
    //   showYAxis: true,
    //   yAxisColor: Colors.orange,
    //   padding: 20.0,
    //   backgroundColor: Colors.white,
    //   traceColor: Colors.green,
    //   yAxisMax: 1.0,
    //   yAxisMin: -1.0,
    //   dataSet: traceOne,
    // );

    // Oscilloscope scopeTwo = Oscilloscope(
    //   showYAxis: true,
    //   padding: 20.0,
    //   backgroundColor: Colors.white,
    //   traceColor: Colors.yellow,
    //   yAxisMax: 1.0,
    //   yAxisMin: -1.0,
    //   dataSet: traceTwo,
    // );

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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            Text(
                              'O730: ' + trace1m.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Delta_OD730: ' + trace2m.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            Text(
                              'O850: ' + trace3m.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Delta_OD850: ' + trace4m.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            Text(
                              'Delta_C_HbO2: ' + trace5m.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Delta_C_Hb: ' + trace6m.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            Text(
                              'OXY: ' + trace7m.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'BV: ' + trace8m.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 1),
                        child: Text(
                          'Detected Output 730 nm',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(1, 10, 10, 10),
                        child: new Container(
                          width: 350,
                          height: 120,
                          // child: new Flexible(flex: 1, child: scopeOne),
                          child: (doPlots == true
                              ? new Sparkline(data: plotData1)
                              : new Text('Please wait!')),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 1),
                        child: Text(
                          'Detected Output 850 nm',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(1, 10, 10, 10),
                        child: new Container(
                          width: 350,
                          height: 120,
                          // child: new Flexible(flex: 2, child: scopeTwo),
                          child: (doPlots == true
                              ? new Sparkline(data: plotData2)
                              : new Text('Please wait!')),
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
            // Data entry point
            // Let's do the following everytime something is recieved.

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

        // Let's Begin! Now that we are connected, do the following once.
        isReadyToGo = true;
        firstReceive = true;

        traceCount = 0;

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

    trace1 = [];
    trace2 = [];
    trace3 = [];
    trace4 = [];
    trace5 = [];
    trace6 = [];
    trace7 = [];
    trace8 = [];

    trace1m = 0.0;
    trace2m = 0.0;
    trace3m = 0.0;
    trace4m = 0.0;
    trace5m = 0.0;
    trace6m = 0.0;
    trace7m = 0.0;
    trace8m = 0.0;

    isReadyToGo = false;
    firstReceive = true;
    traceCount = 0;
    keepGoing = false;
    ceilingReached = false;
    doPlots = false;
    buffHead = 0;
    buffTail = 0;

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
