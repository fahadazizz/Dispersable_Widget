import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/rendering.dart';

class DispersableWidget extends StatefulWidget {
  final Widget child;
  final bool disperse;
  final Duration duration;
  final ParticleConfig particleConfig;
  final VoidCallback? onComplete;
  final bool enableSound;

  const DispersableWidget({
    super.key,
    required this.child,
    required this.disperse,
    this.duration = const Duration(milliseconds: 1200),
    this.particleConfig = const ParticleConfig(),
    this.onComplete,
    this.enableSound = true,
  });

  @override
  State<DispersableWidget> createState() => _DispersableWidgetState();
}

class _DispersableWidgetState extends State<DispersableWidget>
    with SingleTickerProviderStateMixin {
  final _globalKey = GlobalKey();
  final _audioPlayer = AudioPlayer();

  late final AnimationController _controller;
  late final Animation<double> _animation;

  List<_Particle> _particles = [];
  Size? _widgetSize;
  bool _hasDispersed = false;

  late _ParticlePainter _painter;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete?.call();
        }
      });

    _painter = _ParticlePainter(
      particles: _particles,
      repaint: _animation,
      particleSize: widget.particleConfig.size,
      spread: widget.particleConfig.spread,
    );
  }

  @override
  void didUpdateWidget(covariant DispersableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disperse && !_hasDispersed) {
      _hasDispersed = true;
      _disperse();
    }
  }

  Future<void> _disperse() async {
    final boundary =
        _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;

    final pixels = byteData.buffer.asUint8List();
    final width = image.width;
    final height = image.height;

    final List<_Particle> particles = [];
    final random = Random();
    final density = widget.particleConfig.particleDensity.clamp(1, 10);
    final speed = widget.particleConfig.speed;

    for (int y = 0; y < height; y += density) {
      for (int x = 0; x < width; x += density) {
        final index = (y * width + x) * 4;
        final a = pixels[index + 3];
        if (a < 128) continue;

        final color = Color.fromARGB(
          a,
          pixels[index],
          pixels[index + 1],
          pixels[index + 2],
        );

        final origin = Offset(x.toDouble(), y.toDouble());
        final velocity = Offset(
          (random.nextDouble() - 0.5) * speed,
          (random.nextDouble() - 0.5) * speed,
        );

        particles.add(_Particle(origin, velocity, color));
      }
    }

    setState(() {
      _particles = particles;
      _widgetSize = Size(width.toDouble(), height.toDouble());
      _painter.setParticles(particles);
    });

    _controller.forward(from: 0);

    if (widget.enableSound) {
      _audioPlayer.play(AssetSource('disperse_sound_wave.mp3'));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) {
      return RepaintBoundary(key: _globalKey, child: widget.child);
    } else {
      return CustomPaint(size: _widgetSize ?? Size.zero, painter: _painter);
    }
  }
}

class _Particle {
  final Offset origin;
  final Offset velocity;
  final Color color;

  const _Particle(this.origin, this.velocity, this.color);
}

class _ParticlePainter extends CustomPainter {
  List<_Particle> _particles;
  final double particleSize;
  final double spread;
  final Paint _paint;
  final Animation<double> repaint;

  _ParticlePainter({
    required List<_Particle> particles,
    required this.repaint,
    required this.particleSize,
    required this.spread,
  }) : _particles = particles,
       _paint = Paint()..style = PaintingStyle.fill,
       super(repaint: repaint);

  void setParticles(List<_Particle> particles) {
    _particles = particles;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final progress = repaint.value;
    final fade = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in _particles) {
      final pos = p.origin + (p.velocity * spread * progress);
      _paint.color = p.color.withOpacity(fade);
      canvas.drawCircle(pos, particleSize, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class ParticleConfig {
  final double speed; // Particle velocity
  final double size; // Particle radius
  final int particleDensity; // Lower = more particles
  final double spread; // How far particles fly

  const ParticleConfig({
    this.speed = 4.0,
    this.size = 2.0,
    this.particleDensity = 4,
    this.spread = 20.0,
  });
}
