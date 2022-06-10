import 'dart:math';

import 'package:flutter/material.dart';

class CaptchaGenerator extends StatefulWidget {
  final String code;
  final int dotCount;
  final double width;
  final double height;
  final Color backgroundColor;
  final Map drawData;

  const CaptchaGenerator({
    required this.code,
    required this.drawData,
    this.dotCount = 350,
    this.width = 120,
    this.height = 40,
    this.backgroundColor = Colors.transparent,
  });

  @override
  _HBCheckCodeState createState() => _HBCheckCodeState();
}

class _HBCheckCodeState extends State<CaptchaGenerator> {
  @override
  Widget build(BuildContext context) {
    double maxWidth = 0.0;
    Map drawData = widget.drawData;

    maxWidth = getTextSize("8" * widget.code.length,
            TextStyle(fontWeight: FontWeight.values[8], fontSize: 10))
        .width;
    return Container(
      color: widget.backgroundColor,
      width: maxWidth > widget.width ? maxWidth : widget.width,
      height: widget.height,
      child: CustomPaint(
        painter: HBCheckCodePainter(drawData: drawData),
      ),
    );
  }

  Size getTextSize(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }
}

class HBCheckCodePainter extends CustomPainter {
  final Map drawData;
  HBCheckCodePainter({
    required this.drawData,
  });

  final Paint _paint = Paint()
    ..color = Colors.grey
    ..strokeCap = StrokeCap.square
    ..isAntiAlias = true
    ..strokeWidth = 1.0
    ..style = PaintingStyle.fill;
  @override
  void paint(Canvas canvas, Size size) {
    List mList = drawData["painterData"];

    double offsetX = drawData["offsetX"];
    //为了能��居中显示移动画布
    canvas.translate(offsetX, 0);
    //从Map中取出值，直接绘制
    // for (var item in mList) {
    //   TextPainter painter = item["painter"];
    //   double x = item["x"];
    //   double y = item["y"];
    //   painter.paint(
    //     canvas,
    //     Offset(x, y),
    //   );
    // }
    // //将画布平移回去

    canvas.translate(-offsetX, 0);
    List dotData = drawData["dotData"];
    for (var item in dotData) {
      double x = item["x"];
      double y = item["y"];
      double dotWidth = item["dotWidth"];
      Color color = item["color"];
      _paint.color = color;
      canvas.drawOval(Rect.fromLTWH(x, y, dotWidth, dotWidth), _paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return this != oldDelegate;
  }
}
