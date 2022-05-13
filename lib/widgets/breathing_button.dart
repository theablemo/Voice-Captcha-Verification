import 'package:flutter/material.dart';

/// A Breathing Glowing Button widget.
///
/// If properties are not given, default value is used.
class BreathingButton extends StatefulWidget {
  /// Width of the button.
  ///
  /// Default value: 60.0.
  final double width;

  /// Size of the icon.
  ///
  /// Default value: width/2.
  final double? iconSize;

  /// Height of the button.
  ///
  /// Default value: 60.0.
  final double height;

  /// The color for button background.
  ///
  /// Default value: Color(0xFF373A49).
  final Color buttonBackgroundColor;

  /// The color of the breathing glow animation.
  ///
  /// Default value: Color(0xFF777AF9).
  final Color glowColor;

  /// Icon inside the button.
  ///
  /// Default value: Icons.mic.
  final IconData icon;

  /// The color of the icon.
  ///
  /// Default [iconColor] value: Colors.white.
  final Color iconColor;

  /// Function to be executed onTap.
  ///
  /// Default [onTap] value: null
  final Function(TapDownDetails)? onTapDown;
  final Function(TapUpDetails)? onTapUp;

  BreathingButton({
    this.width = 60,
    this.height = 60,
    this.iconSize,
    this.buttonBackgroundColor = const Color(0xFF373A49),
    this.glowColor = const Color(0xFF777AF9),
    required this.icon,
    this.iconColor = Colors.white,
    required this.onTapDown,
    required this.onTapUp,
  });

  @override
  _BreathingButtonState createState() => _BreathingButtonState();
}

class _BreathingButtonState extends State<BreathingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation _animation;

  @override
  void initState() {
    super.initState();
    tenet();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _animation.removeListener(() {});
    super.dispose();
  }

  /// Core animation control is done here.
  /// Animation completes in 2 seconds then repeat by reversing.
  void tenet() {
    _animationController =
        AnimationController(vsync: this, duration: Duration(seconds: 2));
    _animationController.repeat(reverse: true);
    _animation = Tween(begin: 2.0, end: 10.0).animate(_animationController)
      ..addListener(() {
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    final double _width = widget.width;
    final double _height = widget.height;
    final double _iconSize = widget.iconSize ?? widget.width / 2.5;
    final Color _buttonBackgroundColor = widget.buttonBackgroundColor;
    final Color _glowColor = widget.glowColor;
    final IconData _icon = widget.icon;
    final Color _iconColor = widget.iconColor;
    final Function(TapDownDetails)? _onTapDown = widget.onTapDown;
    final Function(TapUpDetails)? _onTapUp = widget.onTapUp;

    /// A simple breathing glowing button.
    /// Built using [Container] and [InkWell].
    return GestureDetector(
      // borderRadius: BorderRadius.circular(30),
      child: Container(
        width: _width,
        height: _height,
        child: Icon(
          _icon,
          color: _iconColor,
          size: _iconSize,
        ),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _buttonBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: _glowColor,
              blurRadius: _animation.value,
              spreadRadius: _animation.value,
            ),
          ],
        ),
      ),
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
    );
  }
}
