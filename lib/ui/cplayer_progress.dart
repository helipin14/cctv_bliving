import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class CPlayerProgress extends StatefulWidget {

  final VlcPlayerController controller;

  final Color activeColor;
  final Color inactiveColor;

  const CPlayerProgress(this.controller, {
    Key key,
    @required this.activeColor,
    @required this.inactiveColor
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _CPlayerProgressState();

}

class _CPlayerProgressState extends State<CPlayerProgress> {

  VoidCallback listener;
  VlcPlayerController get controller => widget.controller;

  double _sliderValue = 0.0;

  @override
  void initState(){
    super.initState();

    listener = (){
      if(controller == null || !mounted) return;

      setState(() {
        _sliderValue = controller.getPosition.toDouble();
      });
    };

    controller.addListener(listener);
  }

  @override
  void deactivate() {
    controller.removeListener(listener);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return new Slider(
      value: _sliderValue,
      onChanged: (newValue){
        controller.setTime(newValue.toInt());
      },
      onChangeStart: (oldValue){
        controller.pause();
      },
      onChangeEnd: (newValue){
        controller.setTime(newValue.toInt());
        controller.play();
      },
      min: 0.0,
      max: (
          controller.getDuration != null ?
          controller.getDuration.toDouble()
              : 0.0
      ),
      // Watched: side of the slider between thumb and minimum value.
      activeColor: widget.activeColor,
      // To watch: side of the slider between thumb and maximum value.
      inactiveColor: widget.inactiveColor,
    );
  }

}