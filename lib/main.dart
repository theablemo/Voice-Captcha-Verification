import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';

import 'package:captcha_verification/splash.dart';
import 'package:flutter/material.dart';

import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_sound_lite/flutter_sound.dart';
import 'package:flutter_sound_lite/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:simple_tooltip/simple_tooltip.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:wave_loading_indicator/wave_progress.dart';
import 'widgets/breathing_button.dart';
import 'widgets/captcha_generator.dart';
import 'package:flutter/services.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum Method {
  w2v,
  aligner,
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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

  late AnimationController _animationController;
  late Animation<Color?> _innerButtonColorAnimation;
  late Animation<Color?> _glowButtonColorAnimation;

  final FlutterSoundRecorder _myRecorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _myPlayer = FlutterSoundPlayer();
  late bool _mRecorderIsInited;

  late Map _captchaDrawData;
  bool _newCaptchaWanted = true;
  var _captchaWordsWidgets = <Widget>[];

  String _googleText = "";
  bool _googleSuccess = false;
  bool _success = false;
  String _captchaText = "";

  var words = <String>[];

  double fromTop = 0;
  double fromSide = 0;

  var _verficationMethod = Method.w2v;

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
    // _myRecorder.openRecorder().then((_) {
    //   setState(() {
    //     _mRecorderIsInited = true;
    //   });
    // });

    _captchaText = widget.captchaString;
    words = widget.words;
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _myRecorder.closeAudioSession();
    _myPlayer.closeAudioSession();
    // _myRecorder.closeRecorder();

    _mRecorderIsInited = false;
    super.dispose();
  }

  Future<void> playSound() async {
    await _myPlayer.startPlayer(
      fromURI: await recordingFilePath,
      codec: Codec.pcm16WAV,
    );
  }

  String get generateCaptchaText {
    words.shuffle();
    final selectedWords = words.take(3);
    final generated = selectedWords.join(" ");
    return generated;
  }

  Future<String> get systemPath async {
    final dir = await getTemporaryDirectory();
    // final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<String> get recordingFilePath async {
    final rawPath = await systemPath;
    return "$rawPath/recorded_captcha.wav";
  }

  Future<void> deleteFile(File file) async {
    await file.delete();
  }

  Future<bool> checkMicPermission() async {
    final status = await Permission.microphone.request();
    if (status == PermissionStatus.granted) {
      return true;
    } else {
      return false;
    }
  }

  Future<void> record() async {
    // final status = await Permission.microphone.request();
    // if (status != PermissionStatus.granted) {
    //   throw RecordingPermissionException(
    //     "Microphone permission should be allowed.",
    //   );
    // }

    final path = await recordingFilePath;
    // deleteFile(File(path));

    if (_mRecorderIsInited) {
      await _myRecorder.startRecorder(
        toFile: path,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );
    }
  }

  Future<void> stopRecorder() async {
    await _myRecorder.stopRecorder();
  }

  Map getRandomData(double width, double height, int dotCount, String code) {
    if (!_newCaptchaWanted) {
      return _captchaDrawData;
    }
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
      int fontWeight = Random().nextInt(8);
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

  String getRandomString(int length) {
    String randomString = "";
    final random = Random();
    for (var i = 0; i < length; i++) {
      int codeUnit = random.nextInt(26) + 97;
      randomString += String.fromCharCode(codeUnit);
    }
    return randomString;
  }

  Future<void> upload(String filename, String url) async {
    setState(() {
      _receivingData = true;
    });

    final fName = '${getRandomString(15)}.wav';

    var request = http.MultipartRequest('POST', Uri.parse(url));

    request.fields['remark'] = _verficationMethod == Method.w2v
        ? "1 $_captchaText"
        : "2 $_captchaText";

    var multiFile = await http.MultipartFile.fromPath(
      'file',
      filename,
      contentType: MediaType('audio', 'wav'),
      filename: fName,
    );

    request.files.add(
      multiFile,
    );

    // request.files.add(
    //   http.MultipartFile.fromBytes(
    //     'file',
    //     await File.fromUri(Uri.parse(filename)).readAsBytes(),
    //     contentType: MediaType('audio', 'wav'),
    //   ),
    // );

    var res = await request.send();

    var innerSuccess = false;
    var googleSuccess = false;
    var googleRecieved = "";

    if (res.statusCode == 201) {
      innerSuccess = true;
    } else {
      innerSuccess = false;
    }

    res.stream.transform(utf8.decoder).listen((value) {
      String modifiedGotten = value.substring(1, value.length - 1);
      print("value: $modifiedGotten");

      googleRecieved = modifiedGotten;
      if (_captchaText == modifiedGotten) {
        googleSuccess = true;
      } else {
        googleSuccess = false;
      }

      setState(() {
        _receivingData = false;
        _showResult = true;
        // _speakedText = listOfMappedWords.join(" ");
        _googleText = googleRecieved.split(" ").join("        ");
        _googleSuccess = googleSuccess;
        _success = innerSuccess;
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

    // res.stream.transform(utf8.decoder).listen((value) {
    //   // print(value);
    //   String modifiedGotten = value.substring(1, value.length - 1);
    //   print(modifiedGotten);
    //   var innerSucces = false;

    //   if (modifiedGotten == "OK") {
    //     innerSucces = true;
    //   } else if (res.statusCode != 400) {
    //     var r = RegExp("\s| ");
    //     var listOfGotten = modifiedGotten.split(r);
    //     listOfGotten = listOfGotten.where((x) => x != "").toList();
    //     final listofWordsCaptcha = _captchaText.split(" ").toList();
    //     print("gotten: $listOfGotten");

    //     var listOfMappedWords = [];
    //     var minED = 10000;
    //     var selectedPoolWord = "";
    //     for (String inputWord in listOfGotten) {
    //       minED = 10000;
    //       selectedPoolWord = "";
    //       for (String poolWord in widget.words) {
    //         var similarity = minEditDistance(inputWord, poolWord);
    //         if (similarity <= minED) {
    //           minED = similarity;
    //           selectedPoolWord = poolWord;
    //         }
    //       }
    //       listOfMappedWords.add(selectedPoolWord);
    //     }
    //     print("mapped: $listOfMappedWords");

    //     innerSucces =
    //         ListEquality().equals(listOfMappedWords, listofWordsCaptcha);

    //     // if (idx >= 2) {
    //     //   for (int i = 0; i < idx; i++) {
    //     //     if (listOfMappedWords[i] != listofWordsCaptcha[i]) {
    //     //       break;
    //     //     }
    //     //     if (i == idx - 1) {
    //     //       innerSucces = true;
    //     //     }
    //     //   }

    //     // }
    //   }

    //   setState(() {
    //     _receivingData = false;
    //     _showResult = true;
    //     // _speakedText = listOfMappedWords.join(" ");
    //     _speakedText = "";
    //     _success = innerSucces;
    //   });

    //   Timer(Duration(seconds: 3), () {
    //     setState(() {
    //       _showResult = false;
    //       if (_success) {
    //         _newCaptchaWanted = true;
    //         _captchaText = generateCaptchaText;
    //       }
    //     });
    //   });
    // });
  }

  // Future<void> newUpload(String filePath, String url) async {
  //   setState(() {
  //     _receivingData = true;
  //   });

  //   var dio = Dio();
  //   FormData formData = FormData.fromMap({
  //     "remark": _captchaText,
  //     "file": await MultipartFile.fromFile(
  //       filePath,
  //     ),
  //   });

  //   var response = await dio.post(url, data: formData);

  //   var innerSuccess = false;

  //   if (response.statusCode == 201) {
  //     innerSuccess = true;
  //   } else {
  //     innerSuccess = false;
  //   }
  //   setState(() {
  //     _receivingData = false;
  //     _showResult = true;
  //     // _speakedText = listOfMappedWords.join(" ");
  //     _speakedText = "";
  //     _success = innerSuccess;
  //   });

  //   Timer(Duration(seconds: 3), () {
  //     setState(() {
  //       _showResult = false;
  //       if (_success) {
  //         _newCaptchaWanted = true;
  //         _captchaText = generateCaptchaText;
  //       }
  //     });
  //   });
  // }

  int minEditDistance(String s1, String s2) {
    if (s1 == s2) {
      return 0;
    }

    if (s1.isEmpty) {
      return s2.length;
    }

    if (s2.isEmpty) {
      return s1.length;
    }

    List<int> v0 = List<int>.filled(s2.length + 1, 0);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);
    List<int> vtemp;

    for (var i = 0; i < v0.length; i++) {
      v0[i] = i;
    }

    for (var i = 0; i < s1.length; i++) {
      v1[0] = i + 1;

      for (var j = 0; j < s2.length; j++) {
        int cost = 1;
        if (s1.codeUnitAt(i) == s2.codeUnitAt(j)) {
          cost = 0;
        }
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }

      vtemp = v0;
      v0 = v1;
      v1 = vtemp;
    }

    return v0[s2.length];
  }

  List<Widget> captchaTextGenerator(MediaQueryData mediaQueryData) {
    if (_newCaptchaWanted || (_success && _showResult)) {
      var words = _captchaText.split(" ");
      var res = <Widget>[];
      int i = 1;
      for (String word in words) {
        fromSide = _newCaptchaWanted
            ? Random().nextInt((mediaQueryData.size.width * 0.1).toInt()) + 20
            : fromSide;
        fromTop = _newCaptchaWanted
            ? Random().nextInt((mediaQueryData.size.width * 0.18).toInt()) + 20
            : fromTop;
        res.add(
          Positioned(
            top: fromTop,
            right: i == 1 ? fromSide : null,
            left: i == 3 ? fromSide : null,
            child: AnimatedDefaultTextStyle(
              child: Text(
                word,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
              ),
              duration: Duration(milliseconds: 400),
              style: TextStyle(
                color: _showResult && _success
                    ? Colors.green
                    : Color((Random().nextDouble() * 0xFFFFFF).toInt())
                        .withOpacity(1.0),
                fontSize:
                    _showResult && _success ? 30 : Random().nextInt(25) + 20,
                fontFamily: "Yekan",
              ),
            ),
          ),
        );
        i++;
      }
      _captchaWordsWidgets = res;
    }
    // _newCaptchaWanted = false;
    return _captchaWordsWidgets;
  }

  Method getMethodByIndex(int index) {
    switch (index) {
      case 0:
        return Method.w2v;
      default:
        return Method.aligner;
    }
  }

  int getIndexByMethod(Method method) {
    switch (method) {
      case Method.w2v:
        return 0;
      default:
        return 1;
    }
  }

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
                  SizedBox(
                    height: _mediaQuery.size.height * 0.05,
                  ),
                  // Text(
                  //   "google",
                  //   style: TextStyle(
                  //     color: Colors.lightBlue,
                  //     fontFamily: 'Sadgan',
                  //     fontSize: 15,
                  //     fontWeight: FontWeight.w100,
                  //   ),
                  // ),
                  Padding(
                    padding: EdgeInsets.only(
                        // left: _mediaQuery.size.width * 0.2,
                        // right: _mediaQuery.size.width * 0.2,
                        // top: 5,
                        ),
                    child: ToggleSwitch(
                      curve: Curves.easeOutExpo,
                      animate: true,
                      minWidth: 100.0,
                      initialLabelIndex: getIndexByMethod(_verficationMethod),
                      cornerRadius: 20,
                      activeFgColor: Colors.black,
                      inactiveBgColor: Colors.grey,
                      inactiveFgColor: Colors.white,
                      totalSwitches: 2,
                      labels: [
                        // '',
                        'W2V',
                        'Aligner',
                      ],
                      icons: [
                        Icons.waving_hand_outlined,
                        Icons.align_horizontal_center,
                      ],
                      activeBgColors: [
                        // [Colors.blue],
                        [Colors.deepOrangeAccent],
                        [Colors.deepOrangeAccent]
                      ],

                      onToggle: (index) {
                        _verficationMethod = getMethodByIndex(index!);
                        print('switched to: $index');
                      },
                      // borderColor: [Colors.blue, Colors.pink, Colors.pink],
                      borderWidth: 1,
                      // customWidths: [60, 100, 100],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: _mediaQuery.size.width * 0.2,
                      right: _mediaQuery.size.width * 0.2,
                      top: 30,
                    ),
                    child: Text(
                      "لطفا پس از فشار دادن دکمه ضبط صدا، سه کلمه ای که در تصویر آمده را با صدای شیوا تکرار کنید.",
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
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ...captchaTextGenerator(_mediaQuery),
                        Container(
                          alignment: Alignment.center,
                          child: SizedBox(
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: 500),
                              child: _success && _showResult
                                  ? SizedBox(
                                      height: _mediaQuery.size.height * 0.2,
                                      width: _mediaQuery.size.width * 0.9,
                                    )
                                  : CaptchaGenerator(
                                      drawData: getRandomData(
                                        _mediaQuery.size.width * 0.9,
                                        _mediaQuery.size.height * 0.2,
                                        350,
                                        _captchaText,
                                      ),
                                      code: _captchaText,
                                      height: _mediaQuery.size.height * 0.2,
                                      width: _mediaQuery.size.width * 0.9,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
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
                ],
              ),
              AnimatedSwitcher(
                duration: Duration(milliseconds: 1000),
                child: _receivingData
                    ? SizedBox(
                        height: 50,
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
                    : !_isRecording
                        ? SizedBox(
                            height: 50,
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: 500),
                              child: _showResult
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _googleText,
                                            textAlign: TextAlign.center,
                                            textDirection: TextDirection.rtl,
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontFamily: "Sadgan",
                                              fontSize:
                                                  _mediaQuery.textScaleFactor *
                                                      15,
                                            ),
                                          ),
                                        ),
                                        SvgPicture.asset(
                                          'assets/google.svg',
                                          semanticsLabel: 'Google Logo',
                                          color: _googleSuccess
                                              ? Colors.greenAccent
                                              : Colors.redAccent,
                                          width: _mediaQuery.size.width * 0.2,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                          child: _googleSuccess
                                              ? Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.greenAccent,
                                                  size: 25,
                                                )
                                              : Icon(
                                                  Icons.close_rounded,
                                                  color: Colors.redAccent,
                                                  size: 25,
                                                ),
                                        )
                                      ],
                                    )
                                  : null,
                            ))
                        : SizedBox(
                            height: 50,
                            width: _mediaQuery.size.width * 0.5,
                            child: WaveProgress(
                              borderSize: 0,
                              size: 90,
                              borderColor: Colors.transparent,
                              foregroundWaveColor: Colors.greenAccent,
                              backgroundWaveColor: Colors.blueAccent,
                              progress: 50, // [0-100]
                              innerPadding:
                                  0, // padding between border and waves
                            ),
                          ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: _mediaQuery.size.height * 0.05,
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
                                      onTapDown: (_) async {
                                        setState(() {
                                          _showToolTip = false;
                                        });
                                        _holdTimer = Timer(
                                          Duration(milliseconds: 500),
                                          () {
                                            _holdLongEnough = true;
                                          },
                                        );

                                        var micPermission =
                                            await checkMicPermission();

                                        if (!micPermission) {
                                          return;
                                        }

                                        await record();
                                        _animationController.forward();
                                        setState(
                                          () {
                                            _isRecording = true;
                                          },
                                        );
                                      },
                                      onTapUp: (_) async {
                                        await stopRecorder();

                                        _animationController.reverse();
                                        setState(
                                          () {
                                            _isRecording = false;
                                          },
                                        );

                                        _holdTimer.cancel();
                                        if (!_holdLongEnough) {
                                          setState(
                                            () {
                                              _showToolTip = true;
                                            },
                                          );
                                          Timer(
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
                                          "http://188.121.120.152/speech_recognition/file/upload/wave2vec-womodel/",
                                        );
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
                    ),
                  ],
                ),
              ),
              Text(
                "build 3.0.0",
                style: TextStyle(
                  fontFamily: "Roboto",
                  color: Colors.grey,
                  fontSize: 10,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
