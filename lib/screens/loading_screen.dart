import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:wanderwell/theme.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, this.generateTask});

  // Optional generation future passed from the Builder screen.
  final Future<Map<String, dynamic>>? generateTask;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  // Rotating status lines (sync with illustrations)
  final List<String> _lines = const [
    'Crafting your adventure…',
    'Charting the waves…',
    'Sketching the skyline…',
    'Pinning tasty stops…',
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // rotate artwork and lines every 1 second per request
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _lines.length);
    });

    // Kick off the generation if provided.
    final task = widget.generateTask;
    if (task != null) {
      task.then((data) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/itinerary_result',
          arguments: data,
        );
      }).catchError((e, st) {
        debugPrint('[LoadingScreen] Generation failed: $e');
        debugPrintStack(stackTrace: st);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
        Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: FlowColors.primaryDark,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/animations/camping_car.json',
                   repeat: true),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  // Subtle vertical slide (incoming from slightly below) + fade
                  final slideAnim = Tween<Offset>(
                    begin: const Offset(0, 0.10), // small movement
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic));

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slideAnim, child: child),
                  );
                },
                child: Text(
                  _lines[_index],
                  key: ValueKey<int>(_index),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:
                        FlowColors.paleBlue, // keep your `accent` or `stroke`
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
