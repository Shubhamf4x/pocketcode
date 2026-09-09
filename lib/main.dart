import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kReleaseMode) debugPrint('Flutter error: ${details.exceptionAsString()}');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Unhandled platform error: $error');
      return true;
    };

    ErrorWidget.builder = (details) => const _SafeErrorWidget();

    runApp(const PocketCodeApp());
  }, (error, stack) {
    debugPrint('Unhandled zone error: $error');
  });
}

class _SafeErrorWidget extends StatelessWidget {
  const _SafeErrorWidget();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xff0d0f10),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Something went wrong rendering this view.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xffb9bdc1), fontSize: 13, decoration: TextDecoration.none),
            ),
          ),
        ),
      );
}
