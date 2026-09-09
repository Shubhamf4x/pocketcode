import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'state/app_controller.dart';

const _surface = Color(0xff111315);
const _background = Color(0xff0d0f10);
const _field = Color(0xff171a1c);
const _onSurface = Color(0xffe8eaed);
const _muted = Color(0xff9aa0a6);
const _outline = Color(0xff33383c);

class PocketCodeApp extends StatefulWidget {
  const PocketCodeApp({super.key});

  @override
  State<PocketCodeApp> createState() => _PocketCodeAppState();

  static final ThemeData theme = _buildTheme();

  static ThemeData _buildTheme() {
    const scheme = ColorScheme.dark(
      primary: Colors.white,
      onPrimary: _background,
      primaryContainer: Color(0xff2a2f33),
      onPrimaryContainer: _onSurface,
      secondary: _onSurface,
      onSecondary: _background,
      secondaryContainer: Color(0xff2a2f33),
      onSecondaryContainer: _onSurface,
      surface: _surface,
      onSurface: _onSurface,
      surfaceContainerHighest: Color(0xff1d2124),
      onSurfaceVariant: _muted,
      outline: _outline,
      outlineVariant: Color(0xff262b2f),
      error: Color(0xffef5350),
      onError: Colors.black,
      inverseSurface: _onSurface,
      onInverseSurface: _background,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'GoogleSans',
      colorScheme: scheme,
      scaffoldBackgroundColor: _background,
      canvasColor: _background,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        foregroundColor: _onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: _background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: _surface, surfaceTintColor: Colors.transparent),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _field,
        hintStyle: const TextStyle(color: _muted),
        helperStyle: const TextStyle(color: _muted),
        labelStyle: const TextStyle(color: _muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white, width: 1.4)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xffef5350))),
      ),
      cardTheme: const CardThemeData(color: Color(0xff151819), surfaceTintColor: Colors.transparent, margin: EdgeInsets.zero),
      dialogTheme: const DialogThemeData(backgroundColor: _field, surfaceTintColor: Colors.transparent),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _field,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: _outline,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xff23282b),
        contentTextStyle: TextStyle(color: _onSurface, fontFamily: 'GoogleSans'),
        actionTextColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xff23282a), space: 1, thickness: 1),
      listTileTheme: const ListTileThemeData(
        iconColor: _muted,
        textColor: _onSurface,
        selectedColor: Colors.white,
        selectedTileColor: Color(0xff1d2124),
      ),
      iconTheme: const IconThemeData(color: _onSurface),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Colors.white),
      sliderTheme: const SliderThemeData(activeTrackColor: Colors.white, thumbColor: Colors.white, inactiveTrackColor: _outline),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.white : _muted),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xff4a4f53) : const Color(0xff262b2f)),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.white,
        selectionColor: Color(0x40ffffff),
        selectionHandleColor: Colors.white,
      ),
      popupMenuTheme: const PopupMenuThemeData(color: _field, surfaceTintColor: Colors.transparent),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(color: Color(0xff2a2f33), borderRadius: BorderRadius.all(Radius.circular(8))),
        textStyle: TextStyle(color: _onSurface, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _background),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Colors.white)),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(_field),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      chipTheme: const ChipThemeData(backgroundColor: Color(0xff22262a), side: BorderSide(color: _outline)),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      }),
    );
  }
}

class _PocketCodeAppState extends State<PocketCodeApp> {
  late final Future<StorageService> _storage = StorageService.open();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PocketCode',
        theme: PocketCodeApp.theme,
        themeMode: ThemeMode.dark,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.4,
          child: child ?? const SizedBox.shrink(),
        ),
        home: FutureBuilder<StorageService>(
          future: _storage,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _StartupError(error: snapshot.error!);
            if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            return _AppWithController(storage: snapshot.data!);
          },
        ),
      );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 42, color: _muted),
                const SizedBox(height: 14),
                const Text('PocketCode could not start', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'Local storage is unavailable on this device.\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
}

class _AppWithController extends StatefulWidget {
  const _AppWithController({required this.storage});

  final StorageService storage;

  @override
  State<_AppWithController> createState() => _AppWithControllerState();
}

class _AppWithControllerState extends State<_AppWithController> {
  late final AppController controller = AppController(widget.storage);

  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HomeScreen(controller: controller);
}
