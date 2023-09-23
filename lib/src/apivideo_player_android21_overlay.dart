import 'dart:async';
import 'dart:math';

import 'package:apivideo_player_android21/apivideo_player_android21.dart';
import 'package:apivideo_player_android21/src/apivideo_player_android21_selectable_list_view.dart';
import 'package:apivideo_player_android21/src/presentation/apivideo_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class ApiVideoPlayerOverlay extends StatefulWidget {
  const ApiVideoPlayerOverlay({
    super.key,
    required this.controller,
    this.hideControls = false,
    required this.theme,
  });

  final ApiVideoPlayerController controller;
  final bool hideControls;
  final PlayerTheme theme;

  @override
  State<ApiVideoPlayerOverlay> createState() => _ApiVideoPlayerOverlayState();
}

class _ApiVideoPlayerOverlayState extends State<ApiVideoPlayerOverlay>
    with TickerProviderStateMixin {
  _ApiVideoPlayerOverlayState() {
    _listener = ApiVideoPlayerEventsListener(
      onReady: () async {
        _updateCurrentTime();
        _updateDuration();
      },
      onPlay: () {
        _startRemainingTimeUpdates();
        setState(() {
          _isPlaying = true;
          _didEnd = false;
        });
      },
      onPause: () {
        _stopRemainingTimeUpdates();
        setState(() {
          _isPlaying = false;
        });
      },
      onSeek: () {
        _updateCurrentTime();
      },
      onSeekStarted: () {
        if (_didEnd) {
          setState(() {
            _didEnd = false;
          });
        }
      },
      onEnd: () {
        _stopRemainingTimeUpdates();
        setState(() {
          _isPlaying = false;
          _didEnd = true;
        });
      },
    );
  }

  bool _isPlaying = false;
  bool _didEnd = false;

  late ApiVideoPlayerEventsListener _listener;

  Timer? _timeSliderTimer;

  bool _isOverlayVisible = true;
  Timer? _overlayVisibilityTimer;

  Duration _currentTime = const Duration(seconds: 0);
  Duration _duration = const Duration(seconds: 0);
  double _volume = 0.0;
  bool _isMuted = false;

  bool _isSelectedSpeedRateListViewVisible = false;

  late AnimationController expandController;
  late Animation<double> animation;

  @override
  initState() {
    super.initState();
    widget.controller.addEventsListener(_listener);
    _showOverlayForDuration();
    // In case controller is already created
    widget.controller.isCreated.then((bool isCreated) async => {
          if (isCreated)
            {
              _updateCurrentTime(),
              _updateDuration(),
              _updateVolume(),
              _updateMuted(),
              widget.controller.isPlaying.then((isPlaying) => {
                    if (isPlaying) {_onPlay()}
                  })
            }
        });

    expandController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    animation = CurvedAnimation(
      parent: expandController,
      curve: Curves.fastLinearToSlowEaseIn,
    );
  }

  @override
  void dispose() {
    widget.controller.removeEventsListener(_listener);
    _overlayVisibilityTimer?.cancel();
    _stopRemainingTimeUpdates();
    super.dispose();
  }

  void pause() {
    widget.controller.pause();
    _showOverlayForDuration();
  }

  void play() {
    widget.controller.play();
    _showOverlayForDuration();
  }

  void replay() async {
    await widget.controller.setCurrentTime(const Duration(seconds: 0));
    play();
  }

  void seek(Duration duration) {
    widget.controller.seek(duration);
    _showOverlayForDuration();
  }

  void setCurrentTime(Duration duration) async {
    await widget.controller.setCurrentTime(duration);
    setState(() {
      _currentTime = duration;
    });
    _showOverlayForDuration();
  }

  void setVolume(double volume) async {
    await widget.controller.setVolume(volume);
    _updateVolume();
    _showOverlayForDuration();
  }

  void toggleMuted() async {
    final bool muted = await widget.controller.isMuted;
    await widget.controller.setIsMuted(!muted);
    _updateMuted();
    _showOverlayForDuration();
  }

  void _showOverlayForDuration() {
    if (!_isOverlayVisible) {
      showOverlay();
    }
    if (_isSelectedSpeedRateListViewVisible) {
      _hideSpeedRateListView();
    }
    _overlayVisibilityTimer?.cancel();
    _overlayVisibilityTimer = Timer(const Duration(seconds: 5), hideOverlay);
  }

  void showOverlay() {
    setState(() {
      _isOverlayVisible = true;
    });
  }

  void hideOverlay() {
    setState(() {
      _isOverlayVisible = false;
      _isSelectedSpeedRateListViewVisible = false;
    });
  }

  void _hideSpeedRateListView() {
    setState(() {
      _isSelectedSpeedRateListViewVisible = false;
    });
  }

  void _startRemainingTimeUpdates() {
    _timeSliderTimer?.cancel();
    _timeSliderTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _updateCurrentTime(),
    );
  }

  void _stopRemainingTimeUpdates() {
    _timeSliderTimer?.cancel();
  }

  void _onPlay() {
    _startRemainingTimeUpdates();
    setState(() {
      _isPlaying = true;
    });
  }

  void _updateCurrentTime() async {
    Duration currentTime = await widget.controller.currentTime;
    setState(() {
      _currentTime = currentTime;
    });
  }

  void _updateDuration() async {
    Duration duration = await widget.controller.duration;
    setState(() {
      _duration = duration;
    });
  }

  void _updateVolume() async {
    double volume = await widget.controller.volume;
    setState(() {
      _volume = volume;
    });
  }

  void _updateMuted() async {
    bool muted = await widget.controller.isMuted;
    setState(() {
      _isMuted = muted;
    });
  }

  void _animateExpand({required bool open}) {
    if (open) {
      expandController.forward();
    } else {
      expandController.animateBack(0, duration: const Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => showOverlay(),
        onExit: (_) => _showOverlayForDuration(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _showOverlayForDuration();
          },
          child: PointerInterceptor(
            child: Stack(
                children: <Widget>[buildOverlay(), buildSpeedRateSelector()]),
          ),
        ),
      );

  Widget buildOverlay() => Visibility(
      visible: _isOverlayVisible && !widget.hideControls,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          buildVolumeSlider(),
          buildControls(),
          buildActionBar(),
        ],
      ));

  Widget buildSpeedRateSelector() {
    return FutureBuilder(
        future: widget.controller.speedRate,
        builder:
            (BuildContext context, AsyncSnapshot<double> speedRateSnapshot) {
          return Positioned(
            bottom: 70,
            left: 20,
            child: Visibility(
                visible:
                    _isSelectedSpeedRateListViewVisible && _isOverlayVisible,
                child: SizedBox(
                  width: 120,
                  height: 110,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.theme.boxDecorationColor,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(20)),
                      ),
                      child: ApiVideoPlayerSelectableListView(
                        items: const [0.5, 1.0, 1.25, 1.5, 2.0],
                        selectedItem: speedRateSnapshot.data ?? 1.0,
                        onSelected: (Object value) {
                          if (value is double) {
                            widget.controller.setSpeedRate(value);
                          }
                          setState(() {
                            _isSelectedSpeedRateListViewVisible = false;
                          });
                        },
                        theme: widget.theme,
                      )),
                )),
          );
        });
  }

  Widget buildControls() => Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                onPressed: () {
                  seek(const Duration(seconds: -10));
                },
                iconSize: 30,
                icon: Icon(
                  Icons.replay_10_rounded,
                  color: widget.theme.controlsColor,
                )),
            buildBtnVideoControl(),
            IconButton(
                onPressed: () {
                  seek(const Duration(seconds: 10));
                },
                iconSize: 30,
                icon: Icon(
                  Icons.forward_10_rounded,
                  color: widget.theme.controlsColor,
                )),
          ],
        ),
      );

  Widget buildBtnVideoControl() {
    return _didEnd ? buildBtnReplay() : buildBtnPlay();
  }

  Widget buildBtnPlay() => IconButton(
        onPressed: () {
          _isPlaying ? pause() : play();
        },
        iconSize: 60,
        icon: _isPlaying
            ? Icon(
                ApiVideoIcons.pausePrimary,
                color: widget.theme.controlsColor,
              )
            : Icon(
                ApiVideoIcons.playPrimary,
                color: widget.theme.controlsColor,
              ),
      );

  Widget buildBtnReplay() => IconButton(
      onPressed: () {
        replay();
      },
      iconSize: 60,
      icon: Icon(
        ApiVideoIcons.replayPrimary,
        color: widget.theme.controlsColor,
      ));

  Widget buildActionBar() => Container(
        height: 80,
        padding: const EdgeInsets.only(right: 1),
        child: Column(
          children: [buildBottomAction(), buildTimeSlider()],
        ),
      );

  Widget buildBottomAction() => Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () {
                _showOverlayForDuration();
                setState(() {
                  _isSelectedSpeedRateListViewVisible = true;
                });
              },
              iconSize: 30,
              icon: Icon(
                Icons.speed,
                color: widget.theme.controlsColor,
              ),
            ),
          ],
        ),
      );

  Widget buildTimeSlider() => Expanded(
        child: Row(
          children: [
            Expanded(
              child: Slider(
                value: max(
                    0,
                    min(
                      _currentTime.inMilliseconds,
                      _duration.inMilliseconds,
                    )).toDouble(),
                // Ensure that the slider doesn't go over the duration or under 0.0
                min: 0.0,
                max: _duration.inMilliseconds.toDouble(),
                activeColor: widget.theme.activeTimeSliderColor,
                inactiveColor: widget.theme.inactiveTimeSliderColor,
                onChanged: (value) {
                  setCurrentTime(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
            Text((_duration - _currentTime).toPlayerString(),
                style: TextStyle(color: widget.theme.controlsColor)),
          ],
        ),
      );

  Widget buildVolumeSlider() => kIsWeb
      ? Column(
          children: [
            const SizedBox(
              height: 10,
            ),
            MouseRegion(
              onEnter: (_) => _animateExpand(open: true),
              onExit: (_) => _animateExpand(open: false),
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        _volume <= 0 || _isMuted
                            ? Icons.volume_off
                            : Icons.volume_up,
                        color: widget.theme.controlsColor,
                      ),
                      onPressed: () => toggleMuted(),
                    ),
                    SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: SizedBox(
                        height: 30.0,
                        width: 80.0,
                        child: SliderTheme(
                          data: SliderThemeData(
                              activeTrackColor:
                                  widget.theme.activeVolumeSliderColor,
                              trackHeight: 2.0,
                              thumbColor: Colors.white,
                              overlayShape: SliderComponentShape.noOverlay,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6.0,
                              )),
                          child: Slider(
                            activeColor: widget.theme.activeVolumeSliderColor,
                            inactiveColor:
                                widget.theme.inactiveVolumeSliderColor,
                            value: _isMuted ? 0 : _volume,
                            onChanged: (value) => setVolume(value),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
      : const SizedBox(height: 30);
}

extension DurationDisplay on Duration {
  String toPlayerString() {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(inSeconds.remainder(60));
    if (inHours > 0) {
      return "$inHours:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }
}

class ApiVideoColors {
  static const MaterialColor orange = MaterialColor(
    0xFFFA5B30,
    <int, Color>{
      100: Color(0xFFFBDDD4),
      200: Color(0xFFFFD1C5),
      300: Color(0xFFFFB39E),
      400: Color(0xFFFA5B30),
      500: Color(0xFFE53101),
    },
  );
}
