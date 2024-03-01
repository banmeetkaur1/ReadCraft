library animated_splash_screen;

import 'package:flutter/material.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:readcraft/login.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      splash: Center(
        //mainAxisAlignment: MainAxisAlignment.center,
        //crossAxisAlignment: CrossAxisAlignment.center,
        child: Column(
          children: [
            Image.asset(
              'assets/logo.png',
              width: 45,
              height: 45,
            ),
            const Text(
              'ReadCraft',
              style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            )
          ],
        ),
      ),
      nextScreen: LoginPage(),
      splashTransition: SplashTransition.decoratedBoxTransition,
      duration: 3000,
    );
  }
}
