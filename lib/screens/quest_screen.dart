import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:wanderwell/models/quest_models.dart';
import 'package:wanderwell/services/quest_service.dart';
import 'package:wanderwell/theme.dart';

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  DailyQuests? _daily;
  bool _loading = true;
  bool _busyQuest = false;
  bool _busyMicro = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _loading = true);
    final data = await QuestService().getOrCreateToday();
    setState(() {
      _daily = data;
      _loading = false;
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: FlowColors.primaryDark,
      appBar: AppBar(
        backgroundColor: FlowColors.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: Text('Quest', style: theme.textTheme.titleLarge?.copyWith(color: FlowColors.textLight, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const _Loading()
          : _daily == null
              ? _buildSignedOut()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _QuestCard(
                          label: 'Quest of the Moment',
                          title: _daily!.quest.title,
                          steps: _daily!.quest.steps,
                          reflection: _daily!.quest.reflectionPrompt,
                          completed: _daily!.quest.completed,
                          busy: _busyQuest,
                          onComplete: _daily!.quest.completed
                              ? null
                              : () async {
                                  await QuestService().markCompleted(QuestEntryType.quest, _daily!);
                                  await _load(showSpinner: false);
                                  if (!mounted) return;
                                  final messenger = ScaffoldMessenger.of(context);
                                  messenger.hideCurrentSnackBar();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: const Text('Marked as completed'),
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        onPressed: () async {
                                          await QuestService().markUncompleted(QuestEntryType.quest);
                                          await _load();
                                          _toast('Restored');
                                        },
                                      ),
                                    ),
                                  );
                                },
                          onReset: () async {
                            final updated = await QuestService().resetQuest();
                            setState(() {
                              _daily = updated ?? _daily;
                            });
                            _toast('New quest generated');
                          },
                        ),
                        const SizedBox(height: 24),
                        _MicroCard(
                          label: '1-Hour Micro Adventure',
                          title: _daily!.microAdventure.title,
                          description: _daily!.microAdventure.description,
                          completed: _daily!.microAdventure.completed,
                          busy: _busyMicro,
                          onComplete: _daily!.microAdventure.completed
                              ? null
                              : () async {
                                  await QuestService().markCompleted(QuestEntryType.microAdventure, _daily!);
                                  await _load(showSpinner: false);
                                  if (!mounted) return;
                                  final messenger = ScaffoldMessenger.of(context);
                                  messenger.hideCurrentSnackBar();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: const Text('Marked as completed'),
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        onPressed: () async {
                                          await QuestService().markUncompleted(QuestEntryType.microAdventure);
                                          await _load();
                                          _toast('Restored');
                                        },
                                      ),
                                    ),
                                  );
                                },
                          onReset: () async {
                            final updated = await QuestService().resetMicroAdventure();
                            setState(() {
                              _daily = updated ?? _daily;
                            });
                            _toast('New micro adventure generated');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSignedOut() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: FlowColors.paleBlue.withValues(alpha: 0.7), size: 36),
            const SizedBox(height: 12),
            Text('Sign in to get your daily quest', style: theme.textTheme.titleMedium?.copyWith(color: FlowColors.textLight)),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _QuestCard extends StatefulWidget {
  final String label;
  final String title;
  final List<String> steps;
  final String reflection;
  final bool completed;
  final Future<void> Function()? onComplete;
  final Future<void> Function() onReset;
  final bool busy;

  const _QuestCard({
    required this.label,
    required this.title,
    required this.steps,
    required this.reflection,
    required this.completed,
    required this.onComplete,
    required this.onReset,
    required this.busy,
  });

  @override
  State<_QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<_QuestCard> with SingleTickerProviderStateMixin {
  late final AnimationController _confetti;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    if (widget.onComplete == null) return;
    await _showConfirmActionSheet(
      context,
      title: 'Mark as completed?',
      message: 'You can undo from the SnackBar if needed.',
      confirmLabel: 'Complete',
      icon: Icons.check_circle,
      iconColor: Colors.greenAccent,
      cancelLabel: 'Not Now',
      onConfirm: widget.onComplete!,
    );
    // Play a short confetti to celebrate
    if (mounted) {
      setState(() => _playing = true);
      _confetti
        ..reset()
        ..forward();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = FlowColors.cardBorderDark.withValues(alpha: 0.08);
    return Stack(
      children: [
        Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: FlowColors.cardSurfaceDark,
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department, color: FlowColors.accentAmber, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.label, style: theme.textTheme.titleSmall?.copyWith(color: FlowColors.textLight.withValues(alpha: 0.9), height: 1.2))),
              Tooltip(
                message: 'Reset',
                child: _IconCircleButton(
                  icon: Icons.restart_alt,
                  onPressed: widget.busy
                      ? null
                      : () => _showConfirmActionSheet(
                            context,
                            title: 'Reset quest?',
                            message: 'This will replace today\'s quest with a new one.',
                            confirmLabel: 'Reset',
                            icon: Icons.warning_amber_rounded,
                            iconColor: Colors.amber,
                            onConfirm: widget.onReset,
                          ),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.completed) _CompletedPill(),
            ],
          ),
          const SizedBox(height: 16),
          Text(widget.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: FlowColors.textLight, height: 1.25)),
          const SizedBox(height: 16),
          for (final s in widget.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BulletDot(),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s, style: theme.textTheme.bodyMedium?.copyWith(color: FlowColors.textLight.withValues(alpha: 0.9), height: 1.45))),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlowColors.chipSelectedDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.psychology_alt, color: FlowColors.accentTeal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.reflection, style: theme.textTheme.bodyMedium?.copyWith(color: FlowColors.textLight, height: 1.45)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            label: widget.completed ? 'Completed' : 'Mark Completed',
            icon: widget.completed ? Icons.check_circle : Icons.task_alt,
            onPressed: (widget.onComplete == null || widget.busy) ? null : _handleComplete,
          )
        ],
      ),
        ),
        if (widget.busy)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 3)),
              ),
            ),
          ),
        if (_playing) _ConfettiOverlay(animation: _confetti),
      ],
    );
  }
}

class _MicroCard extends StatefulWidget {
  final String label;
  final String title;
  final String description;
  final bool completed;
  final Future<void> Function()? onComplete;
  final Future<void> Function() onReset;
  final bool busy;

  const _MicroCard({
    required this.label,
    required this.title,
    required this.description,
    required this.completed,
    required this.onComplete,
    required this.onReset,
    required this.busy,
  });

  @override
  State<_MicroCard> createState() => _MicroCardState();
}

class _MicroCardState extends State<_MicroCard> with SingleTickerProviderStateMixin {
  late final AnimationController _confetti;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    if (widget.onComplete == null) return;
    await _showConfirmActionSheet(
      context,
      title: 'Mark as completed?',
      message: 'You can undo from the SnackBar if needed.',
      confirmLabel: 'Complete',
      icon: Icons.check_circle,
      iconColor: Colors.greenAccent,
      cancelLabel: 'Not Now',
      onConfirm: widget.onComplete!,
    );
    if (mounted) {
      setState(() => _playing = true);
      _confetti
        ..reset()
        ..forward();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = FlowColors.cardBorderDark.withValues(alpha: 0.08);
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: FlowColors.cardSurfaceDark,
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt, color: FlowColors.accentGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(widget.label, style: theme.textTheme.titleSmall?.copyWith(color: FlowColors.textLight.withValues(alpha: 0.9), height: 1.2))),
                  Tooltip(
                    message: 'Reset',
                    child: _IconCircleButton(
                      icon: Icons.restart_alt,
                      onPressed: widget.busy
                          ? null
                          : () => _showConfirmActionSheet(
                                context,
                                title: 'Reset micro adventure?',
                                message: 'This will replace today\'s micro adventure.',
                                confirmLabel: 'Reset',
                                icon: Icons.warning_amber_rounded,
                                iconColor: Colors.amber,
                                onConfirm: widget.onReset,
                              ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.completed) _CompletedPill(),
                ],
              ),
              const SizedBox(height: 16),
              Text(widget.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: FlowColors.textLight, height: 1.25)),
              const SizedBox(height: 12),
              Text(widget.description, style: theme.textTheme.bodyMedium?.copyWith(color: FlowColors.textLight.withValues(alpha: 0.9), height: 1.45)),
              const SizedBox(height: 16),
              _PrimaryButton(
                label: widget.completed ? 'Completed' : 'Mark Completed',
                icon: widget.completed ? Icons.check_circle : Icons.task_alt,
                onPressed: (widget.onComplete == null || widget.busy) ? null : _handleComplete,
              )
            ],
          ),
        ),
        if (widget.busy)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 3)),
              ),
            ),
          ),
        if (_playing) _ConfettiOverlay(animation: _confetti),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _PrimaryButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.secondary,
          foregroundColor: cs.onSecondary,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, color: cs.onSecondary),
        label: Text(label, style: TextStyle(color: cs.onSecondary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _GhostButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: FlowColors.textLight.withValues(alpha: 0.18)),
        foregroundColor: FlowColors.textLight,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, color: FlowColors.textLight),
      label: Text(label, style: const TextStyle(color: FlowColors.textLight, fontWeight: FontWeight.w600)),
    );
  }
}

class _CompletedPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FlowColors.accentGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FlowColors.accentGreen.withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
          SizedBox(width: 6),
          Text('Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _IconCircleButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final color = FlowColors.textLight.withValues(alpha: 0.85);
    return Semantics(
      button: true,
      child: InkResponse(
        onTap: onPressed,
        radius: 22,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: FlowColors.chipBgDark,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: FlowColors.cardBorderDark.withValues(alpha: 0.12)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

class _BulletDot extends StatelessWidget {
  const _BulletDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: FlowColors.paleBlue.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _ConfettiOverlay extends StatelessWidget {
  final Animation<double> animation;
  const _ConfettiOverlay({required this.animation});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return CustomPaint(
            painter: _ConfettiPainter(progress: animation.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  _ConfettiPainter({required this.progress});

  final List<Color> colors = const [
    FlowColors.accentTeal,
    FlowColors.warmCoral,
    FlowColors.accentAmber,
    FlowColors.accentGreen,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = progress * 1000.0;
    final paint = Paint()..style = PaintingStyle.fill;
    const count = 24;
    for (int i = 0; i < count; i++) {
      final t = (i / count + progress) % 1.0;
      final dx = size.width * (i / count);
      final dy = size.height * 0.1 + t * size.height * 0.6;
      final sz = 3.0 + (1.0 + (i % 3)) * 1.2;
      paint.color = colors[i % colors.length].withValues(alpha: (1 - t) * 0.9);
      canvas.save();
      canvas.translate(dx + (i.isEven ? 8.0 : -8.0) * (1 - t), dy);
      canvas.rotate((i * 17 + rnd) * 0.005);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: sz, height: sz * 2), const Radius.circular(1.5)), paint);
      canvas.restore();
    }
    // soft check pulse
    final checkAlpha = (progress < 0.6) ? (progress / 0.6) : (1 - (progress - 0.6) / 0.4);
    final checkPaint = Paint()..color = Colors.white.withValues(alpha: checkAlpha.clamp(0, 1) * 0.8);
    final center = Offset(size.width - 28, 28);
    canvas.drawCircle(center, 14, checkPaint);
    final path = Path();
    path.moveTo(center.dx - 6, center.dy + 0);
    path.lineTo(center.dx - 1, center.dy + 5);
    path.lineTo(center.dx + 8, center.dy - 6);
    final stroke = Paint()
      ..color = FlowColors.accentGreen.withValues(alpha: checkAlpha.clamp(0, 1))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}

Future<void> _showConfirmActionSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required IconData icon,
  required Color iconColor,
  String cancelLabel = 'Cancel',
  required Future<void> Function() onConfirm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: FlowColors.cardSurfaceDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      bool running = false;
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final cs = theme.colorScheme;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 22),
                    const SizedBox(width: 8),
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(color: FlowColors.textLight, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: FlowColors.textLight.withValues(alpha: 0.9), height: 1.45)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          foregroundColor: FlowColors.textLight,
                          side: BorderSide(color: FlowColors.cardBorderDark.withValues(alpha: 0.16)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        onPressed: running ? null : () => Navigator.of(ctx).pop(),
                        child: Text(cancelLabel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: cs.secondary,
                          foregroundColor: cs.onSecondary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        onPressed: running
                            ? null
                            : () async {
                                setModalState(() => running = true);
                                try {
                                  await onConfirm();
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                } catch (e, st) {
                                  debugPrint('Confirm action failed: $e');
                                  debugPrint('$st');
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('Something went wrong. Please try again.')),
                                    );
                                  }
                                  setModalState(() => running = false);
                                }
                              },
                        child: running
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  valueColor: AlwaysStoppedAnimation<Color>(cs.onSecondary),
                                ),
                              )
                            : Text(confirmLabel),
                      ),
                    ),
                  ],
                )
              ],
            ),
          );
        },
      );
    },
  );
}
