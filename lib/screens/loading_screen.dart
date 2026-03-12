import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:wanderwell/theme.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    super.key,
    this.generateTask,
    this.progressStream,
    this.initialProgressText,
  });

  // Optional generation future passed from the Builder screen.
  final Future<Map<String, dynamic>>? generateTask;
  // Optional progress stream to show live agentic steps.
  final Stream<String>? progressStream;
  // Initial progress line to render immediately (prevents missing the first event
  // if the stream subscriber attaches slightly later after navigation).
  final String? initialProgressText;

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
  StreamSubscription<String>? _sub;
  String? _liveLine;

  @override
  void initState() {
    super.initState();

    // rotate artwork and lines every 1 second per request
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // If we have live progress from the generator, keep showing it and
      // still tick the index for AnimatedSwitcher keys, but do not change
      // the displayed phrase.
      setState(() => _index = (_index + 1) % _lines.length);
    });

    // Prime the line with the initial text if provided.
    if (widget.initialProgressText != null &&
        widget.initialProgressText!.trim().isNotEmpty) {
      _liveLine = widget.initialProgressText;
    }

    // Subscribe to progress stream if provided.
    if (widget.progressStream != null) {
      _sub = widget.progressStream!.listen((msg) {
        if (!mounted) return;
        setState(() => _liveLine = msg);
      });
    }

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
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
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
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        // Subtle vertical slide (incoming from slightly below) + fade
                        final slideAnim = Tween<Offset>(
                          begin: const Offset(0, 0.10), // small movement
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                            parent: animation, curve: Curves.easeOutCubic));

                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                              position: slideAnim, child: child),
                        );
                      },
                      child: Text(
                        _liveLine ?? _lines[_index],
                        // Key by the actual text so the switcher updates immediately
                        // when the live progress line changes.
                        key: ValueKey<String>(_liveLine ?? _lines[_index]),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: FlowColors
                              .paleBlue, // keep your `accent` or `stroke`
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

            // 2. Static Message at the Bottom
            Container(
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.only(bottom: 24.0, left: 24.0, right: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Almost there!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: FlowColors.textLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a little while. Thanks for hanging tight.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: FlowColors.textLight.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
