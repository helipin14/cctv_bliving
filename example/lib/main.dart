import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:flutter_vlc_player/cplayer.dart';
import 'package:flutter_vlc_player/utils/fileutils.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Uint8List image;
  GlobalKey imageKey;
  VlcPlayer videoView;
  VlcPlayerController _videoViewController;
  VlcPlayerController _videoViewController2;
  String url = "rtsp://admin:admin@192.168.100.201:554/mode=real&idc=1&ids=1";
  String filePath = "";
  File file;

  @override
  void initState() {
    imageKey = new GlobalKey();
    _loadImage();
    _videoViewController = new VlcPlayerController(
      onInit: (){
        _videoViewController.stop();
      }
    );
    _videoViewController2 = VlcPlayerController(
      onInit: () {
        _videoViewController2.stop();
      }
    );
    _videoViewController.addListener((){
      setState(() {});
    });
    _videoViewController2.addListener((){
      setState(() {});
    });
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  _loadImage() async {
    file = await FileUtils.getImage("a21etxvxy8cm8am56tzd_e3g92psj7k10ry82l5y6");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch(state) {
      case AppLifecycleState.inactive:
        print("\n INACTIVE \n");
        break;
      case AppLifecycleState.paused:
        print("\n PAUSED \n");
        break;
      case AppLifecycleState.suspending:
        print("\n SUSPENDING \n");
        break;
      case AppLifecycleState.resumed:
        print("\n RESUMED \n");
        break;
    }
    super.didChangeAppLifecycleState(state);
  }

  _checkImage() async {
      bool isExist = await FileUtils.isFileExist("a21etxvxy8cm8am56tzd-e3g92psj7k10ry82l5y6");
      if(isExist) {
        Uint8List imageBytes = Uint8List.fromList(File("a21etxvxy8cm8am56tzd-e3g92psj7k10ry82l5y6.png").readAsBytesSync());
        return Image.memory(imageBytes);
      }
      return Image.asset("assets/nopreview.png");
    }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: const Text('Plugin example app'),
           actions: <Widget>[
             GoTo(url)
           ],
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.camera),
          onPressed: _createCameraImage,
        ),
        body: Column(
          children: <Widget>[
            VlcPlayer(
              aspectRatio: 16 / 9,
              url: url,
              controller: _videoViewController,
              placeholder: Container(
                height: 250.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[CircularProgressIndicator()],
                ),
              ),
            ),
            SizedBox(height: 20,),
            Container(
              child: Row(
                children: <Widget>[
                  FlatButton(
                    child: Text("PLAY"),
                    onPressed: () {
                      _videoViewController.play();
                    },
                  ),
                   FlatButton(
                    child: Text("STOP"),
                    onPressed: () {
                      _videoViewController.stop();
                    },
                  ),
                  FlatButton(
                    child: Text("DISPOSE"),
                    onPressed: () {
                      _videoViewController.dispose();
                    },
                  ),
                ],
              ),
            ),
            FutureBuilder(
              builder: (context, snapshot) {
                if(snapshot.hasData) return snapshot.data;
                return Container();
              },
              future: _checkImage(),
            ),
            // file != null ? Image.file(file) : Container(),
            // FlatButton(
            //   child: Text("Change URL"),
            //   onPressed: () => _videoViewController.setStreamUrl("rtsp://admin:admin@192.168.100.201:554/mode=real&idc=1&ids=1"),
            // ),

            // FlatButton(
            //   child: Text("+speed"),
            //   onPressed: () => _videoViewController.setPlaybackSpeed(2.0)
            // ),

            // FlatButton(
            //     child: Text("Normal"),
            //     onPressed: () => _videoViewController.setPlaybackSpeed(1)
            // ),

            // FlatButton(
            //   child: Text("-speed"),
            //   onPressed: () => _videoViewController.setPlaybackSpeed(0.5)
            // ),

            // Text("position=" + _videoViewController.position.inSeconds.toString() + ", duration=" + _videoViewController.duration.inSeconds.toString() + ", speed=" + _videoViewController.playbackSpeed.toString()),
            // Text("ratio=" + _videoViewController.aspectRatio.toString()),
            // Text("size=" + _videoViewController.size.width.toString() + "x" + _videoViewController.size.height.toString()),
            // Text("state=" + _videoViewController.playingState.toString()),
            Expanded(
              child: image == null
                  ? Container()
                  : Container(
                decoration: BoxDecoration(image: DecorationImage(image: MemoryImage(image))),
              ),
            ),
            filePath != "" ? Image.file(File(filePath)) : Container(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    print("DISPOSE");
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _createCameraImage() async {
    // _checkFileExist();
    Uint8List file = await _videoViewController.makeSnapshot();
    setState(() {
      image = file;
    });
    // FileUtils.saveImage(file, "_");
    // setState(() {
    //  FileUtils.getFullPath("a21etxvxy8cm8am56tzd_e3g92psj7k10ry82l5y6").then((path) {
    //    filePath = path;
    //  }); 
    // });
  }

   _checkFileExist() async {
    bool isExist = await FileUtils.isFileExist("a21etxvxy8cm8am56tzd_e3g92psj7k10ry82l5y6");
    print(isExist);
  }
}

class GoTo extends StatelessWidget {
  final String url;
  GoTo(this.url);
  @override
  Widget build(BuildContext context) {
    print("URL $url");
    return FlatButton(
      child: Text("GOTO"),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => CPlayer(
          title: "Video Streaming",
          url: url,
          iduser: "a21etxvxy8cm8am56tzd",
          idcctv: "e3g92psj7k10ry82l5y6",
        )));
      },
    );
  }
}
