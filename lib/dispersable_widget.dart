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

  const DispersableWidget({
    super.key,
    required this.child,
    required this.disperse,
    this.duration = const Duration(milliseconds: 1200),
    this.particleConfig = const ParticleConfig(),
    this.onComplete,
  });

  @override
  State<DispersableWidget> createState() => _DispersableWidgetState();
}

class _DispersableWidgetState extends State<DispersableWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  final _audioPlayer = AudioPlayer();
  final GlobalKey _key = GlobalKey();

  List<_Particle> _particles = [];
  Size? _widgetSize;
  bool _hasDispersed = false;
  bool _hide = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final boundary =
          _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final pixels = byteData!.buffer.asUint8List();

      final width = image.width;
      final height = image.height;
      final speed = widget.particleConfig.speed;
      final area =
          widget.particleConfig.particleArea ??
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

      final List<_Particle> particles = [];
      final random = Random();
      final step = widget.particleConfig.particleDensity.clamp(1, 10);

      for (int y = area.top.toInt(); y < area.bottom.toInt(); y += step) {
        for (int x = area.left.toInt(); x < area.right.toInt(); x += step) {
          if (x < 0 || x >= width || y < 0 || y >= height) continue;

          final index = (y * width + x) * 4;
          final a = pixels[index + 3];
          if (a < 150) continue;

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
      _audioPlayer.play(AssetSource('disperse_sound_wave.mp3'));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hide) return const SizedBox.shrink();

    return _particles.isEmpty
        ? RepaintBoundary(key: _key, child: widget.child)
        : CustomPaint(size: _widgetSize ?? Size.zero, painter: _painter);
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
  final Animation<double> repaint;
  final double particleSize;
  final Paint _paint;

  _ParticlePainter({
    required List<_Particle> particles,
    required this.repaint,
    required this.particleSize,
  }) : _particles = particles,
       _paint = Paint()..style = PaintingStyle.fill,
       super(repaint: repaint);

  void setParticles(List<_Particle> newParticles) {
    _particles = newParticles;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double progress = repaint.value;
    final double fade = (1.0 - progress).clamp(0.0, 1.0);
    final double moveFactor = progress * 60;

    for (var p in _particles) {
      final Offset pos = p.origin + (p.velocity * moveFactor);
      _paint.color = p.color.withOpacity(fade);
      canvas.drawCircle(pos, particleSize, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

/// 🛠️ Customization Options
class ParticleConfig {
  final double speed; // How fast particles move
  final double size; // Radius of each particle
  final int
  particleDensity; // Step size between particles (1 = max density, 4-6 recommended)
  final Rect? particleArea; // Area within the widget to apply dispersion

  const ParticleConfig({
    this.speed = 4.0,
    this.size = 2.0,
    this.particleDensity = 4,
    this.particleArea,
  });
}

class TelegramTextAnimation extends StatefulWidget {
  const TelegramTextAnimation({super.key});

  @override
  State<TelegramTextAnimation> createState() => _TelegramTextAnimationState();
}

class _TelegramTextAnimationState extends State<TelegramTextAnimation> {
  bool _disperse = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DispersableWidget(
              disperse: _disperse,
              duration: Duration(seconds: 2),
              particleConfig: ParticleConfig(speed: 4.0, size: 2.0),
              child: SizedBox(
                width: 140,
                height: 80,
                child: ElevatedButton(onPressed: () {}, child: Text("Welcome")),
              ),
            ),
            SizedBox(height: 20),
            DispersableWidget(
              disperse: _disperse,
              duration: Duration(seconds: 2),
              particleConfig: ParticleConfig(
                speed: 4.0,
                size: 2.0,
                particleDensity: 2,
              ),

              child: Text(
                "TELEGRAM COPY 👍",
                style: TextStyle(fontSize: 30, color: Colors.blue),
              ),
            ),
            SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _disperse = true;
                });
              },
              child: Text("Trigger Disperse"),
            ),
          ],
        ),
      ),
    );
  }
}
