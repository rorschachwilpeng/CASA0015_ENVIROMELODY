import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/pixel_theme.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  final VoidCallback? onSplashComplete;
  
  const SplashScreen({
    Key? key, 
    required this.nextScreen,
    this.onSplashComplete,
  }) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Set the animation controller - extend to 5 seconds
    _controller = AnimationController(
      duration: const Duration(milliseconds: 5000), // Extend the animation duration to 5 seconds
      vsync: this,
    );
    
    // Fade in animation - complete in the first 2 seconds
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.3, curve: Curves.easeIn), // Complete in the first 30% of the time
      ),
    );
    
    // Scale animation - complete in the first 2 seconds
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.3, curve: Curves.easeOut), // Complete in the first 30% of the time
      ),
    );
    
    // Progress bar animation - complete the entire 5 seconds at a constant rate
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    
    // Start the animation
    _controller.forward();
    
    // Automatically navigate to the main interface after 5 seconds
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
          
          if (widget.onSplashComplete != null) {
            widget.onSplashComplete!();
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PixelTheme.background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo container
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: PixelTheme.surface,
                        border: Border.all(color: PixelTheme.text, width: 2),
                        boxShadow: PixelTheme.cardShadow,
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '🎵',
                              style: TextStyle(fontSize: 36),
                            ),
                            Text(
                              '🌍',
                              style: TextStyle(fontSize: 36),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Application name
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: PixelTheme.surface,
                        border: Border.all(color: PixelTheme.text, width: 2),
                        boxShadow: PixelTheme.cardShadow,
                      ),
                      child: Text(
                        'EnviroMelody',
                        style: PixelTheme.titleStyle.copyWith(
                          fontSize: 28,
                          letterSpacing: 1.0,
                          color: PixelTheme.primary,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Subtitle
                    Text(
                      'Tune into your surroundings.',
                      style: PixelTheme.bodyStyle.copyWith(
                        fontSize: 16,
                        color: PixelTheme.textLight,
                        letterSpacing: 0.5,
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Loading progress bar - display actual progress
                    Column(
                      children: [
                        // Add progress percentage text
                        Text(
                          '${(_progressAnimation.value * 100).toInt()}%',
                          style: PixelTheme.labelStyle.copyWith(
                            color: PixelTheme.primary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Progress bar
                        Container(
                          width: 160,
                          height: 20,
                          decoration: BoxDecoration(
                            color: PixelTheme.surface,
                            border: Border.all(color: PixelTheme.text.withOpacity(0.5), width: 1),
                          ),
                          child: Stack(
                            children: [
                              // Progress bar fill part
                              AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  return Container(
                                    width: 160 * _progressAnimation.value,
                                    height: 18,
                                    color: PixelTheme.primary.withOpacity(0.4),
                                  );
                                },
                              ),
                              
                              // "Loading..." text
                              Center(
                                child: Text(
                                  'Loading...',
                                  style: PixelTheme.labelStyle.copyWith(
                                    color: PixelTheme.text,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Add some interesting loading messages
                    const SizedBox(height: 20),
                    _buildLoadingMessage(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  // Loading messages based on progress
  Widget _buildLoadingMessage() {
    // Display different loading messages based on progress
    String message = '';
    double progress = _progressAnimation.value;
    
    if (progress < 0.2) {
      message = 'Initializing sound engine...';
    } else if (progress < 0.4) {
      message = 'Tuning environmental sensors...';
    } else if (progress < 0.6) {
      message = 'Capturing ambient sounds...';
    } else if (progress < 0.8) {
      message = 'Harmonizing with nature...';
    } else {
      message = 'Ready to create music!';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: PixelTheme.surface.withOpacity(0.7),
        border: Border.all(color: PixelTheme.text.withOpacity(0.3), width: 1),
      ),
      child: Text(
        message,
        style: PixelTheme.labelStyle.copyWith(
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
} 