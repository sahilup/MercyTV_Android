import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mercy_tv_app/Colors/custom_color.dart';
import 'package:mercy_tv_app/controllers/home_controller.dart';
import 'package:mercy_tv_app/controllers/rotation_helper.dart';
import 'package:mercy_tv_app/widget/Live_View_widget.dart';
import 'package:mercy_tv_app/widget/button_section.dart';
import 'package:mercy_tv_app/widget/new_screen_player.dart';
import 'package:mercy_tv_app/API/dataModel.dart';
import 'package:mercy_tv_app/widget/sugested_video_list.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isFavorite = false;
  Timer? _timer;
  DateTime _currentDateTime = DateTime.now();
  String _currentVideoUrl = 'https://mercyott.com/hls_output/master.m3u8';
  bool _isLiveStream = true;
  String _selectedProgramTitle = 'Mercy TV Live';
  String _selectedProgramDate = '';
  String _selectedProgramTime = '';
  StreamSubscription? _orientationSubscription;
  Stream<bool>? rotationStream;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WakelockPlus.enable();
    _startOrientationListener();
    rotationStream = RotationHelper.autoRotateStream;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentDateTime = DateTime.now();
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _orientationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://mercytv.tv/support-ott/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  void _playVideo(ProgramDetails programDetails) {
    if (!mounted) return;
    setState(() {
      _currentVideoUrl = programDetails.videoUrl;
      _isLiveStream = false;
      _selectedProgramTitle = programDetails.title;
      final HomeController homeController = Get.put(HomeController());
      homeController.initializePlayer(programDetails.videoUrl, false);

      if (programDetails.date != null && programDetails.date!.isNotEmpty) {
        try {
          DateTime parsedDate =
              DateFormat('yyyy-MM-dd').parse(programDetails.date!);
          _selectedProgramDate = DateFormat('EEE dd MMM').format(parsedDate);
        } catch (e) {
          _selectedProgramDate = programDetails.date!;
        }
      } else {
        _selectedProgramDate = '';
      }

      if (programDetails.time != null && programDetails.time!.isNotEmpty) {
        try {
          DateTime parsedTime =
              DateFormat('HH:mm:ss').parse(programDetails.time!);
          _selectedProgramTime = DateFormat('hh:mm a').format(parsedTime);
        } catch (e) {
          _selectedProgramTime = programDetails.time!;
        }
      } else {
        _selectedProgramTime = '';
      }
    });
  }

  Stream<Orientation?> detectOrientation() async* {
    await for (bool autoRotateOn in RotationHelper.autoRotateStream) {
      log("Auto-rotate stream emitted: $autoRotateOn");
      if (!autoRotateOn) {
        log("Auto-rotate is OFF, ignoring orientation changes.");
        yield null;
        continue;
      }

      await for (AccelerometerEvent event in accelerometerEventStream()) {
        log("Accelerometer Event: x=${event.x}, y=${event.y}, z=${event.z}");
        double x = event.x;
        double y = event.y;
        double z = event.z;

        if (z.abs() > 8) {
          log("Device is flat, ignoring orientation change.");
          yield null;
          continue;
        }

        if (y.abs() > x.abs()) {
          yield Orientation.portrait;
        } else {
          yield Orientation.landscape;
        }
      }
    }
  }

  void _startOrientationListener() async {
    final HomeController homeController = Get.put(HomeController());
    log("inside orientation listener");

    _orientationSubscription = detectOrientation().listen((orientation) {
      log("Orientation detected: $orientation");

      if (orientation != null &&
          homeController.currentOrientation.value != orientation) {
        homeController.currentOrientation.value = orientation;

        if (orientation == Orientation.landscape) {
          log("Switching to Landscape mode");
          Future.delayed(const Duration(milliseconds: 100), () {
            homeController.chewieController?.enterFullScreen();
          });
        } else {
          log("Switching to Portrait mode");
          Future.delayed(const Duration(milliseconds: 100), () {
            homeController.chewieController?.exitFullScreen();
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double baseFontSize = screenWidth < 360 ? 14 : 16;
    double titleFontSize = screenWidth < 360 ? 18 : 22;
    double buttonFontSize = screenWidth < 360 ? 16 : 20;

    double horizontalPadding = screenWidth * 0.04;
    double verticalSpacing = screenHeight * 0.015;

    String formattedDate = _selectedProgramDate.isNotEmpty
        ? _selectedProgramDate
        : DateFormat('EEE dd MMM').format(_currentDateTime);
    String formattedTime = _selectedProgramTime.isNotEmpty
        ? _selectedProgramTime
        : DateFormat('hh:mm a').format(_currentDateTime);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Color.fromARGB(255, 0, 90, 87),
              Color(0xFF000000),
            ],
            stops: [0.0, 0.9],
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: screenHeight * 0.3,
              child: NewScreenPlayer(),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalSpacing,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: screenWidth * 0.75,
                            child: GestureDetector(
                              child: Text(
                                _selectedProgramTitle,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Mulish-Bold',
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          if (_isLiveStream)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: verticalSpacing * 0.5),
                              child: const LiveViewWidget(),
                            ),
                        ],
                      ),
                      SizedBox(height: verticalSpacing),
                      Row(
                        children: [
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: baseFontSize,
                              fontFamily: 'Mulish-Medium',
                            ),
                          ),
                          SizedBox(width: horizontalPadding * 0.5),
                          const Text("|", style: TextStyle(color: Colors.white)),
                          SizedBox(width: horizontalPadding * 0.5),
                          Text(
                            formattedTime,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: baseFontSize,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: verticalSpacing),
                      const ButtonSection(),
                      SizedBox(height: verticalSpacing * 2),
                      GestureDetector(
                        onTap: _launchURL,
                        child: Container(
                          height: screenHeight * 0.06,
                          width: screenWidth * 0.9,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(screenWidth * 0.1),
                          ),
                          child: Center(
                            child: Text(
                              'Sponsor us',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Mulish-Medium',
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: verticalSpacing),
                      Text(
                        'Past Programs',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: baseFontSize + 2,
                          fontWeight: FontWeight.w300,
                          fontFamily: 'Mulish-Medium',
                        ),
                      ),
                      SizedBox(height: verticalSpacing * 0.5),
                      Container(
                        width: screenWidth * 0.35,
                        height: 2,
                        color: CustomColors.buttonColor,
                      ),
                      SuggestedVideoCard(
                        onVideoTap: _playVideo,
                      ),
                      SizedBox(height: verticalSpacing * 2),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}