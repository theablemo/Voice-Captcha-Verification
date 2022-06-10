import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:page_transition/page_transition.dart';

import './main.dart';

class RouteSplash extends StatefulWidget {
  @override
  _RouteSplashState createState() => _RouteSplashState();
}

class _RouteSplashState extends State<RouteSplash> {
  var words = <String>[];
  String _captchaText = "";
  Future<String> loadAsset() async {
    return await rootBundle.loadString('assets/words.txt');
  }

  String get generateCaptchaText {
    words.shuffle();
    final selectedWords = words.take(3);
    final generated = selectedWords.join(" ");
    return generated;
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      String fileText = await loadAsset();
      words = fileText.split("\n");

      setState(() {
        _captchaText = generateCaptchaText;
      });

      Timer(Duration(milliseconds: 500), () {
        Navigator.pushReplacement(
          context,
          PageTransition(
            type: PageTransitionType.fade,
            child: MyHomePage(
              words: words,
              captchaString: _captchaText,
            ),
          ),
        );
      });
    });

    super.initState();
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
          child: Center(
            child: Hero(
              tag: "hero",
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xffE04D01),
                ),
                child: Padding(
                  padding: EdgeInsets.all(_mediaQuery.size.width * 0.1),
                  child: Icon(
                    Icons.mic_none,
                    size: _mediaQuery.size.width * 0.15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
