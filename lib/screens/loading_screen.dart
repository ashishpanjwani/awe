import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:wanderwell/theme.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    super.key,
    this.generateTask,
    this.progressStream,
    this.initialProgressText,
  });

  final Future<Map<String, dynamic>>? generateTask;
  final Stream<String>? progressStream;
  final String? initialProgressText;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
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

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _lines.length);
    });

    if (widget.initialProgressText != null && widget.initialProgressText!.trim().isNotEmpty) {
      _liveLine = widget.initialProgressText;
    }

    if (widget.progressStream != null) {
      _sub = widget.progressStream!.listen((msg) {
        if (!mounted) return;
        setState(() => _liveLine = msg);
      });
    }

    final task = widget.generateTask;
    if (task != null) {
      task.then((data) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/itinerary_result', arguments: data);
      }).catchError((e, st) {
        debugPrint('[LoadingScreen] Generation failed: $e');
        debugPrintStack(stackTrace: st);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generation failed: $e')));
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
      backgroundColor: AweColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Lottie.asset('assets/animations/camping_car.json', repeat: true),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        final slideAnim = Tween<Offset>(
                          begin: const Offset(0, 0.10),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: slideAnim, child: child),
                        );
                      },
                      child: Text(
                        _liveLine ?? _lines[_index],
                        key: ValueKey<String>(_liveLine ?? _lines[_index]),
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: 18,
                          color: AweColors.accentTeal,
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
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Almost there!',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 18,
                      color: AweColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This may take a little while. Thanks for hanging tight.',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 13,
                      color: AweColors.textSecondary,
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
