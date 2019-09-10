import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Screen2 extends StatefulWidget {
  @override
  Screen2State createState() => Screen2State();
}

class Screen2State extends State<Screen2> {

  @override
  void initState() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight
    ]);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 18, color: Colors.black45,),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        child: Column(
          children: <Widget>[
            Text("contoh")
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitDown,
      DeviceOrientation.portraitUp
    ]);
    super.dispose();
  }
}