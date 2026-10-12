import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'profile.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The phone lies flat on a table; rotation would only get in the way.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final profile = await Profile.load();
  runApp(PhoneDownApp(profile: profile));
}

class PhoneDownApp extends StatelessWidget {
  const PhoneDownApp({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MaterialApp(
        title: 'Phone Down',
        debugShowCheckedModeBanner: false,
        theme: brewTheme(),
        home: profile.isSetUp
            ? HomeScreen(profile: profile)
            : OnboardingScreen(profile: profile),
      ),
    );
  }
}

/// Fades and lifts a page in, like turning to the next spread.
Route<T> pageRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 420),
  reverseTransitionDuration: const Duration(milliseconds: 320),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, anim, _, child) {
    final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  },
);
