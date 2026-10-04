import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import 'role_screen.dart';

/// App loading screen shown at launch: the animated GOSST logo plays on the
/// navy gradient, then the user is taken to the role selection screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _showDuration = Duration(milliseconds: 2200);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Start the countdown only AFTER the first frame is actually rendered,
    // otherwise the timer fires before anything is displayed (especially in
    // debug builds where engine warm-up takes seconds) and the animated logo
    // never becomes visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer(_showDuration, _goToRoleScreen);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goToRoleScreen() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const RoleScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pure-white background, matching the native splash, so the animated logo
    // (designed on a near-white backdrop) sits seamlessly on one uniform tone.
    // The logo is sized from the shorter screen edge instead of a fixed 190, so
    // it stays fully visible on a 5" phone and does not look lost on a 10"
    // tablet.
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final shortest = constraints.biggest.shortestSide;
          final logoSize = (shortest * 0.46).clamp(120.0, 260.0);
          return Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 0),
                child: AnimatedLogo(size: logoSize),
              ),
            ),
          );
        },
      ),
    );
  }
}