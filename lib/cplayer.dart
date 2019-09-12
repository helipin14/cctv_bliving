library cplayer;

import 'dart:async';

//import 'package:cplayer/cast/Cast.dart';
import 'package:flutter_vlc_player/res/UI.dart';
import 'package:flutter_vlc_player/ui/cplayer_interrupt.dart';
import 'package:flutter_vlc_player/ui/cplayer_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen/screen.dart';
import 'package:connectivity/connectivity.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:auto_orientation/auto_orientation.dart';
import 'utils/fileutils.dart';
import 'dart:typed_data';

class CPlayer extends StatefulWidget {

  final String mimeType;
  final String title;
  final String url; // = "http://distribution.bbb3d.renderfarming.net/video/mp4/bbb_sunflower_1080p_60fps_normal.mp4";
  final String iduser;
  final String idcctv;
  final Color primaryColor;
  final Color accentColor;
  final Color highlightColor;

  CPlayer({
    Key key,
    this.mimeType,
    @required this.title,
    @required this.url,
    this.primaryColor,
    this.accentColor,
    this.highlightColor,
    this.iduser,
    this.idcctv,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => CPlayerState();
}

class CPlayerState extends State<CPlayer> {

  Map<String, Timer> timerStates = new Map();
  //Cast _cast;

  VlcPlayerController _controller;
  VoidCallback _controllerListener;
  StreamSubscription<ConnectivityResult> networkSubscription;

  Widget _interruptWidget;

  //bool _isBuffering = false;
  bool _isControlsVisible = true;
  bool _player = true;
  int _aspectRatio = 0;
  int lastValidPosition;
  double opacity = 1.0;
  int _timeDelta = 0;
  double volume = 1.0;

  Function _getCenterPanel = (){
    return Container();
  };

  @override
  void initState() {
    _beginInitState();

    // Initialise the cast driver
    //_cast = new Cast();

    // Start the video controller
    _controllerListener = (){
      if (!this.mounted || _controller == null) {
        return;
      }

      if(_controller.initialized)  lastValidPosition = 0;
//        lastValidPosition = _controller.currentTime;
    };

    _controller = VlcPlayerController(
        onInit: (){
          // VIDEO PLAYER: Ensure the first frame is shown after the video is
          // initialized, even before the play button has been pressed.
          //if(!this.mounted) return;
          setState((){});
          _isControlsVisible = false;
          _orientationHandler("landscape");
          bool connectivityCheckInactive = true;
          VoidCallback handleOfflinePlayback;
          handleOfflinePlayback = (){
            if(!_controller.initialized) {
              // UNABLE TO CONNECT TO THE INTERNET (show error)
              _interruptWidget = ErrorInterruptMixin(
                icon: Icons.offline_bolt,
                title: "You're offline...",
                message: "Failed to connect to the internet. Please check your connection."
              );
              _controller.removeListener(handleOfflinePlayback);
            }
          };

          // Activate network connectivity subscription.
          networkSubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
            _controller.removeListener(handleOfflinePlayback);
            if(connectivityCheckInactive){
              connectivityCheckInactive = false;
              return;
            }
            print("Detected connection change.");
            http.Response connectivityCheck;
            try {
              connectivityCheck =
              await http.head("https://static.apollotv.xyz/generate_204");
            }catch(ex) { connectivityCheck = null; }

            if(connectivityCheck != null && connectivityCheck.statusCode == 204){
              // ABLE TO CONNECT TO THE INTERNET (re-initialize the player)
              print("Re-initializing player to position $lastValidPosition...");
              int resumePosition = lastValidPosition;

              if(!_controller.initialized) await _controller.setStreamUrl(widget.url);
              await _controller.setTime(resumePosition);
              //_isBuffering = false;
              _interruptWidget = null;
              setState(() {});
            }else{
              _controller.addListener(handleOfflinePlayback);
            }
          });
          _controller.soundActive(1);
          //_total = _controller.value.duration.inMilliseconds;
        }
    )..addListener(_controllerListener);
    _controller.addListener(() {
      print("Duration : ${_controller.position.inSeconds}");
      if(_controller.position.inSeconds == 3) {
        print("\n\n SAVING FILE \n\n");
        saveFrame();
      }
    });
    super.initState();
  }

  Future<void> saveFrame() async {
    Uint8List imageBytes = await _controller.makeSnapshot();
    FileUtils.saveImage(imageBytes, "${widget.iduser}_${widget.idcctv}");
  }

  Future<void> _beginInitState() async {
    await SystemChrome.setEnabledSystemUIOverlays([]);
    await Screen.keepOn(true);
  }

  @override
  void deactivate() {
    // Re-enable screen rotation and UI
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    // Dispose controller
    //_controller.setVolume(0.0);
    if(_controller != null) {
      _controller.removeListener(_controllerListener);
      _controller.dispose();
    }

    // Cancel wake-lock
    Screen.keepOn(false);

    // Stop cast device discovery
    //_cast.destroy();

    // Cancel network connectivity subscription.
    if(networkSubscription != null) networkSubscription.cancel();

    // Pass to super
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    if(!mounted || _controller == null){
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () { 
        _back();
       },
      child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                // Player
                GestureDetector(
                    onTap: () {
                      print("is controller visible $_isControlsVisible");
                      setState(() => _isControlsVisible = !_isControlsVisible);
                    },
                    child: LayoutBuilder(builder: (_, BoxConstraints constraints) {
                      return Container(
                        color: Colors.black,
                        height: constraints.maxHeight,
                        width: constraints.maxWidth,
                        child: Center(
                            child: VlcPlayer(
                              url: widget.url,
                              controller: _controller,
                              aspectRatio: 16 / 9,//buildAspectRatio(_aspectRatio, context, _controller),
                              placeholder: Container(),
                            )
                        ),
                      );
                    })
                ),

                // Controls Layer
                new AnimatedOpacity(
                    opacity: _isControlsVisible ? 1.0 : 0.0,
//                  opacity:  1.0 ,
                    duration: Duration(seconds: 1),
                    child: Stack(
                      children: <Widget>[
                        // Top Bar
                        GestureDetector(
                            onTap: (){
                              print("is control visible bef : $_isControlsVisible");
                              setState(() {
                                _isControlsVisible = !_isControlsVisible;
                                print("is control visible  aft: $_isControlsVisible");
                              });
                            },
                            child:Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                    height: 72,
                                    child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 10.0,
                                            vertical: 3.0
                                        ),
                                        child: Builder(builder: (BuildContext ctx){
                                          if(MediaQuery.of(ctx).size.width < 500) return Container();
                                          return Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: <Widget>[
                                              Row(
                                                children: <Widget>[
                                                  Container(
                                                      margin: EdgeInsets.symmetric(horizontal: 10),
                                                      child: new Material(
                                                          color: Colors.transparent,
                                                          borderRadius: BorderRadius.circular(100),
                                                          child: new InkWell(
                                                              borderRadius: BorderRadius.circular(100),
                                                              onTap: () => _back(),
                                                              child: new Padding(
                                                                child: new Container(
                                                                    width: 28,
                                                                    height: 28,
                                                                    child: new Icon(
                                                                        Icons.arrow_back,
                                                                        size: 28,
                                                                        color: Colors.white
                                                                    )
                                                                ),
                                                                padding: EdgeInsets.all(10),
                                                              )
                                                          )
                                                      )
                                                  ),
                                                  // Title
                                                  new Padding(
                                                    padding: EdgeInsets.all(20),
                                                    child: Text(
                                                      widget.title,
                                                      style: TextStyle(
                                                        fontFamily: 'GlacialIndifference',
                                                        fontSize: 24,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ],
                                          );
                                        })
                                    )
                                )
                              ],
                            )
                        ),

                        // Center Controls (play/pause)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            new Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                _buildPlayPause()
                              ],
                            )
                          ],
                        ),

                        // Bottom Bar
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Container(
                                height: 52.0,
                                padding: const EdgeInsets.only(right: 10, left: 10),
                                child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10.0,
                                        vertical: 5.0
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.max,
                                      children: <Widget>[
                                        Icon(Icons.volume_up, size: 18, color: Colors.white,),
                                        Container(
                                          width: 100,
                                          child: Slider(
                                            onChanged: (value) => setState(() {
                                              volume = value;
                                              _controller.soundController(value);
                                            }),
                                            min: 0,
                                            max: 1,
                                            value: volume,
                                            activeColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                )
                            )
                          ],
                        ),
                      ],
                    )
                ),

                // Center Panel
                Center(
                    child: (_getCenterPanel())
                ),

                // Buffering loader
                AnimatedOpacity(
                    opacity: _controller.playingState == PlayingState.BUFFERING && _controller == null ? 1.0 : 0.0,
                    duration: Duration(milliseconds: 20),
                    child: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints){
                      return Container(child: Center(
                          child: CircularProgressIndicator(
                              valueColor: new AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)
                          )
                      ), width: constraints.maxWidth, height: constraints.maxHeight
                      );
                    })
                )
              ]
          )
      ),
    );
  }

  _buildPlayPause() {
    return (_controller != null && _controller.initialized) ? new Container(
      child: new Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(100),
          child: new InkWell(
              highlightColor: const Color(0x05FFFFFF),
              borderRadius: BorderRadius.circular(100),
              onTap: () {
                setState((){
                  if(_player) {
                    _player = false;
                    _controller.pause();
                  }else{
                    _player = true;
                    _controller.play();
                  }
                });
              },
              child: new Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Center(
                      child: new Icon(
                        (_player == true ?
                        Icons.pause :
                        Icons.play_arrow
                        ),
                        size: 72.0,
                        color: Colors.white,
                      )
                  )
              )
          )
      ),
    ) : Container(
      child: CircularProgressIndicator(),
    );
  }

  _orientationHandler(orientation) {
    if (orientation == "portrait") {
      AutoOrientation.portraitUpMode();
      AutoOrientation.portraitDownMode();
    } else if(orientation == "landscape") {
      AutoOrientation.landscapeLeftMode();
      AutoOrientation.landscapeRightMode();
    }
  }

  _back() {
    AutoOrientation.portraitUpMode();
    Navigator.popAndPushNamed(context, '/main/${widget.iduser}/4', result: "playback");
  }

  _applyTimeDelta() async {
//    int _newPosition = _controller.currentTime + (_timeDelta * 1000);
    int _newPosition = 0 + (_timeDelta * 1000);
    if(_newPosition < 0) _newPosition = 0;
    if(_newPosition > _controller.getDuration) _newPosition = _controller.getDuration;

    _timeDelta = 0;
    await _controller.setTime(_newPosition);
    await _controller.play();
  }

  ///
  /// Formats a timestamp in milliseconds.
  ///
  String formatTimestamp(int millis){
    if(millis == null) return "00:00:00";
    int seconds = ((millis ~/ 1000)%60);
    int minutes = ((millis ~/ (1000*60))%60);
    int hours = ((millis ~/ (1000*60*60))%24);

    String hourString = (hours < 10) ? "0" + hours.toString() : hours.toString();
    String minutesString = (minutes < 10) ? "0" + minutes.toString() : minutes.toString();
    String secondsString = (seconds < 10) ? "0" + seconds.toString() : seconds.toString();

    return hourString + ":" + minutesString + ":" + secondsString;
  }

  static const Map<int, String> RATIOS = {
    0: "Default",
    1: "Fit to Screen",
    2: "3:2",
    3: "16:9",
    4: "18:9",
    5: "21:9"
  };

  ///
  /// Returns a generated aspect ratio.
  /// Choices: fit, 3-2, 16-9, default.
  ///
  double buildAspectRatio(int ratio, BuildContext context, VlcPlayerController controller){
    if(controller == null || !controller.initialized) ratio = 1;

    switch(ratio) {
      case 1: /* FIT */
        return MediaQuery.of(context).size.width / MediaQuery.of(context).size.height;

      case 2: /* 3:2 */
        return 3/2;

      case 3: /* 16:9 */
        return 16/9;

      case 4: /* 18:9 */
        return 18/9;

      case 5: /* 21/9 */
        return 21/9;

      default:
        return controller.aspectRatio;
    }
  }

  ///
  /// Change Aspect Ratio
  ///
  void _changeAspectRatio(){
    if(_controller.playingState != PlayingState.PLAYING) {
      return;
    }

    if(_aspectRatio < RATIOS.length - 1) {
      _aspectRatio++;
    }else{
      _aspectRatio = 0;
    }

    /* BEGIN: show center panel */
    setState((){
      _getCenterPanel = (){
        return GestureDetector(
          onTap: () => setState(() {
            timerStates['centerPanel'].cancel();
            _getCenterPanel = (){
              return Container();
            };
          }),
          child: Container(
              child: new Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: <Widget>[
                      Icon(
                        Icons.aspect_ratio,
                        size: 48,
                      ),

                      Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                              "Aspect Ratio",
                              style: TextStyle(
                                  fontFamily: "GlacialIndifference",
                                  fontSize: 20
                              )
                          )
                      ),

                      Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Text(RATIOS[_aspectRatio])
                      )
                    ],
                  )
              ),

              decoration: BoxDecoration(
                  color: const Color(0xAF000000),
                  borderRadius: BorderRadius.circular(5.0)
              )
          ),
        );
      };
    });

    if(timerStates['centerPanel'] != null) {
      timerStates['centerPanel'].cancel();
    }
    timerStates['centerPanel'] = new Timer(Duration(seconds: 3), (){
      setState(() {
        _getCenterPanel = (){
          return Container();
        };
      });
    });
    /* END: show center panel */
  }

}