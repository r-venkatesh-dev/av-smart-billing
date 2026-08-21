import 'package:flutter/material.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key, this.error = false, this.onRetry});

  final bool error;
  final VoidCallback? onRetry;

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> scale;
  late final Animation<double> glow;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    scale = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    glow = Tween<double>(
      begin: 0.12,
      end: 0.28,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff7fbfa),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffffffff), Color(0xffedf8f6)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) => Transform.scale(
                    scale: scale.value,
                    child: Container(
                      width: 116,
                      height: 116,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromRGBO(5, 124, 115, glow.value),
                            blurRadius: 34,
                            spreadRadius: 3,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/branding/av-smartbilling-icon-concept-3.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'AV Smartbilling',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xff17312e),
                            ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Fast, simple billing for your business',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xff58716d),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                if (widget.error) ...[
                  const Icon(
                    Icons.error_outline,
                    color: Colors.orange,
                    size: 28,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'AV Smartbilling could not start. Please try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ] else ...[
                  const SizedBox(
                    width: 150,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      backgroundColor: Color(0xffd5eeeb),
                    ),
                  ),
                  const SizedBox(height: 13),
                  const Text(
                    'Preparing your billing workspace…',
                    style: TextStyle(color: Color(0xff6b817e), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
