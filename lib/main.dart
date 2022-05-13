import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:captcha_verification/splash.dart';
import 'package:flutter/material.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound_lite/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:simple_tooltip/simple_tooltip.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:collection/collection.dart';

import 'widgets/breathing_button.dart';
import 'widgets/captcha_generator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Captcha Verification',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: RouteSplash(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    Key? key,
    required this.words,
    required this.captchaString,
  }) : super(key: key);
  final List<String> words;
  final String captchaString;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _holdLongEnough = false;
  bool _showToolTip = false;
  bool _receivingData = false;
  bool _showResult = false;
  late Timer _holdTimer;
  late Timer _releasedTimer;

  late AnimationController _animationController;
  late Animation<Color?> _innerButtonColorAnimation;
  late Animation<Color?> _glowButtonColorAnimation;

  final FlutterSoundRecorder _myRecorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _myPlayer = FlutterSoundPlayer();
  late bool _mRecorderIsInited;

  late Map _captchaDrawData;
  bool _newCaptchaWanted = true;

  String _speakedText = "";
  bool _success = false;
  String _captchaText = "";
  String _debugText = "";

  var words = <String>[];

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700),
    );

    _innerButtonColorAnimation = ColorTween(
      begin: Color(0xffE04D01),
      end: Color(0xffFFEF82),
    ).animate(_animationController);
    _glowButtonColorAnimation = ColorTween(
      begin: Color(0xffFF8D29).withAlpha(150),
      end: Color(0xffF32424).withAlpha(100),
    ).animate(_animationController);

    _myRecorder.openAudioSession().then((value) {
      setState(() {
        _mRecorderIsInited = true;
      });
    });

    _myPlayer.openAudioSession();

    _captchaText = widget.captchaString;
    words = widget.words;
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _myRecorder.closeAudioSession();
    _mRecorderIsInited = false;
    _myPlayer.closeAudioSession();

    super.dispose();
  }

  Future<void> playSound() async {
    setState(() {
      _debugText = "playing sound";
    });
    await _myPlayer.startPlayer(
        fromURI: await recordingFilePath,
        // codec: Codec.pcm16WAV,
        whenFinished: () {
          setState(() {
            _debugText = "finished playing";
          });
        });
  }

  String get generateCaptchaText {
    words.shuffle();
    final selectedWords = words.take(3);
    final generated = selectedWords.join(" ");
    return generated;
  }

  Future<String> get systemPath async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  Future<String> get recordingFilePath async {
    final rawPath = await systemPath;
    return "$rawPath/recorded_captcha.wav";
  }

  Future<void> record() async {
    print("dar hale record");
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException(
        "Microphone permission should be allowed.",
      );
    }

    if (_mRecorderIsInited) {
      await _myRecorder.startRecorder(
        toFile: await recordingFilePath,
        codec: Codec.pcm16WAV,
      );
    }
    print("record done");
  }

  Future<void> stopRecorder() async {
    await _myRecorder.stopRecorder();
  }

  Map getRandomData(double width, double height, int dotCount, String code) {
    if (!_newCaptchaWanted) {
      return _captchaDrawData;
    }
    print("injaaa ${code}");
    List list = code.split(" ");
    double x = 0.0;
    double maxFontSize = 35.0;
    List mList = [];
    for (String item in list) {
      Color color = Color.fromARGB(
        255,
        Random().nextInt(255),
        Random().nextInt(255),
        Random().nextInt(255),
      );
      int fontWeight = Random().nextInt(5);
      TextSpan span = TextSpan(
        text: item,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.values[fontWeight],
          fontSize: maxFontSize - Random().nextInt(10),
        ),
      );
      TextPainter painter =
          TextPainter(text: span, textDirection: TextDirection.rtl);
      painter.layout();
      double y = Random().nextInt(height.toInt()).toDouble() - painter.height;
      if (y < 0) {
        y = 0;
      }
      Map strMap = {"painter": painter, "x": x, "y": y};
      mList.add(strMap);
      x += painter.width + 3;
    }
    double offsetX = (width - x) / 2;
    List dotData = [];

    for (var i = 0; i < dotCount; i++) {
      int r = Random().nextInt(255);
      int g = Random().nextInt(255);
      int b = Random().nextInt(255);
      double x = Random().nextInt(width.toInt() - 5).toDouble();
      double y = Random().nextInt(height.toInt() - 5).toDouble();
      double dotWidth = Random().nextInt(6).toDouble();
      Color color = Color.fromARGB(255, r, g, b);
      Map dot = {"x": x, "y": y, "dotWidth": dotWidth, "color": color};
      dotData.add(dot);
    }

    Map checkCodeDrawData = {
      "painterData": mList,
      "offsetX": offsetX,
      "dotData": dotData,
    };
    _captchaDrawData = checkCodeDrawData;
    _newCaptchaWanted = false;
    return checkCodeDrawData;
  }

  Future<void> upload(String filename, String url) async {
    setState(() {
      _debugText = "upload start";
    });
    setState(() {
      _receivingData = true;
    });
    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.files.add(await http.MultipartFile.fromPath('file', filename));

    // request.headers['Accept'] = '*/*';
    // request.headers['Content-Type'] = 'multipart/form-data';
    // request.headers['Connection'] = 'keep-alive';
    request.fields['remark'] = 'filename';
    var res = await request.send();
    setState(() {
      _debugText = "${res.statusCode} gereftim";
    });

    res.stream.transform(utf8.decoder).listen((value) {
      String modifiedGotten = value.substring(1, value.length - 1);
      setState(() {
        _debugText = "got the data  $modifiedGotten";

        _receivingData = false;
        _showResult = true;
        _speakedText = modifiedGotten;
        _success = true;
        final listofWordsSpeak = _speakedText.split(" ");
        final listofWordsCaptcha = _captchaText.split(" ");
        Function unOrdDeepEq = const DeepCollectionEquality.unordered().equals;
        _success = unOrdDeepEq(listofWordsCaptcha, listofWordsSpeak);
        // print(
        //     "listss : ${_speakedText},${listofWordsSpeak}, ${listofWordsCaptcha}");
        // print("succc: ${_success}");
      });
      Timer(Duration(seconds: 3), () {
        setState(() {
          _showResult = false;
          if (_success) {
            _newCaptchaWanted = true;
            _captchaText = generateCaptchaText;
          }
        });
      });
    });
  }

  void checkOK() {
    setState(() {});
    // for (String wordSpoken in listofWordsSpeak) {
    //   if (_captchaText.contains(wordSpoken)) {
    //     setState(() {
    //       _success = false;
    //     });
    //     break;
    //   }
    // }
  }

  // Future<String> _read() async {
  //   String text = "";
  //   try {
  //     final directory = await getApplicationDocumentsDirectory();
  //     final file = File('${directory.path}/assets/words.txt');
  //     text = await file.readAsString();
  //   } catch (e) {
  //     print("Couldn't read file");
  //   }
  //   return text;
  // }

  @override
  Widget build(BuildContext context) {
    final _mediaQuery = MediaQuery.of(context);

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF15133C),
                Color(0xFF16003B),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      left: _mediaQuery.size.width * 0.2,
                      right: _mediaQuery.size.width * 0.2,
                      top: _mediaQuery.size.height * 0.1,
                    ),
                    child: Text(
                      "لطفا پس از فشار دادن دکمه ضبط صدا، سه کلمه ای در تصویر آمده را با صدای شیوا تکرار کنید.",
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: _mediaQuery.textScaleFactor * 17,
                        fontFamily: "Vazir",
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            // color: Colors.white,
                            offset: Offset(
                              -1,
                              -1,
                            ),
                          ),
                        ],
                      ),
                      softWrap: true,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _mediaQuery.size.width * 0.1,
                      vertical: 20,
                    ),
                    child: Divider(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Spacer(),
                  Container(
                    alignment: Alignment.center,
                    child: CaptchaGenerator(
                      drawData: getRandomData(
                        _mediaQuery.size.width * 0.5,
                        _mediaQuery.size.height * 0.15,
                        300,
                        _captchaText,
                      ),
                      code: _captchaText,
                      height: _mediaQuery.size.height * 0.15,
                      width: _mediaQuery.size.width * 0.5,
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _captchaText = generateCaptchaText;
                            _newCaptchaWanted = true;
                          });
                        },
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: Colors.deepOrange,
                        ),
                        splashColor: Colors.orange,
                        highlightColor: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: Duration(milliseconds: 1000),
                child: _receivingData
                    ? SizedBox(
                        height: 30,
                        width: 90,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 5),
                          child: LoadingIndicator(
                            indicatorType: Indicator.ballBeat,
                            colors: [
                              Color(0xff79DAE8),
                              Color(0xff0AA1DD),
                              Color(0xff2155CD)
                            ],
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 30,
                        width: 150,
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            _speakedText,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: "Sadgan",
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: _mediaQuery.size.height * 0.09,
                ),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _innerButtonColorAnimation,
                      builder: (_, ch) {
                        return SimpleTooltip(
                          animationDuration: Duration(milliseconds: 500),
                          show: _showToolTip,
                          tooltipDirection: TooltipDirection.right,
                          child: AnimatedSwitcher(
                            duration: Duration(seconds: 1),
                            child: !_showResult
                                ? Hero(
                                    tag: "hero",
                                    child: BreathingButton(
                                      icon: Icons.mic_none,
                                      height: 90,
                                      width: 90,
                                      iconSize: 35,
                                      buttonBackgroundColor:
                                          _innerButtonColorAnimation.value!,
                                      glowColor:
                                          _glowButtonColorAnimation.value!,
                                      iconColor: Color(0xff251D3A),
                                      onTapDown: (_) {
                                        setState(() {
                                          _showToolTip = false;
                                        });
                                        _holdTimer = Timer(
                                            Duration(milliseconds: 500), () {
                                          _holdLongEnough = true;
                                        });
                                        _animationController.forward();

                                        record();

                                        setState(
                                          () {
                                            _isRecording = true;
                                          },
                                        );
                                      },
                                      onTapUp: (_) async {
                                        stopRecorder();
                                        _animationController.reverse();

                                        _holdTimer.cancel();
                                        if (!_holdLongEnough) {
                                          setState(
                                            () {
                                              _showToolTip = true;
                                            },
                                          );
                                          _releasedTimer = Timer(
                                            Duration(seconds: 2),
                                            () {
                                              setState(
                                                () {
                                                  _showToolTip = false;
                                                },
                                              );
                                            },
                                          );
                                          return;
                                        }
                                        _holdLongEnough = false;

                                        await upload(
                                          await recordingFilePath,
                                          "http://81.31.168.187/speech_recognition/file/upload/wave2vec/",
                                        ).then((value) => checkOK());
                                      },
                                    ),
                                  )
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          _success ? Colors.green : Colors.red,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Icon(
                                        _success
                                            ? Icons.check_rounded
                                            : Icons.close_rounded,
                                        size: 50,
                                      ),
                                    ),
                                  ),
                          ),
                          content: Text(
                            "دکمه را نگه دارید.",
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                decoration: TextDecoration.none,
                                fontFamily: "Vazir"),
                          ),
                          borderColor: Colors.transparent,
                          ballonPadding: EdgeInsets.all(5),
                          // customShadows: [],
                          hideOnTooltipTap: true,
                          borderRadius: 15,
                          backgroundColor: Color(0xFFEC994B),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: SizedBox(
                        child: Text(
                          _showResult
                              ? _success
                                  ? "ورود شما با موفقیت انجام شد!"
                                  : "لطفا مجددا امتحان نمایید."
                              : "",
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: "Vazir",
                            color: _success
                                ? Colors.greenAccent
                                : Colors.redAccent,
                          ),
                        ),
                        height: 20,
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
