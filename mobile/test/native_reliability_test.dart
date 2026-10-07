import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_scanner/src/mobile_scanner_view_attributes.dart';
import 'package:mobile_scanner/src/objects/start_options.dart';
import 'package:nutrinova_ai/src/core/api/api_client.dart';
import 'package:nutrinova_ai/src/core/models/app_models.dart';
import 'package:nutrinova_ai/src/core/photo_picker.dart';
import 'package:nutrinova_ai/src/core/repositories/nutrition_repository.dart';
import 'package:nutrinova_ai/src/core/repositories/providers.dart';
import 'package:nutrinova_ai/src/core/theme/nova_theme.dart';
import 'package:nutrinova_ai/src/features/barcode/barcode_scan_screen.dart';
import 'package:nutrinova_ai/src/features/body/log_weight_screen.dart';
import 'package:nutrinova_ai/src/features/foods/food_detail_screen.dart';
import 'package:nutrinova_ai/src/features/photos/nutrition_label_scan_screen.dart';
import 'package:nutrinova_ai/src/features/photos/photo_scan_screen.dart';

XFile testImage() => XFile.fromData(
      base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
          'AAAAC0lEQVR42mP8/x8AAwMCAO+aWqkAAAAASUVORK5CYII='),
      name: 'meal.png',
      mimeType: 'image/png',
    );

class FakePicker extends ImagePicker {
  int pickCalls = 0;
  int recoveryCalls = 0;
  Object? error;
  XFile? selected;
  Completer<XFile?>? pending;
  LostDataResponse? recovered;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    pickCalls++;
    if (error != null) throw error!;
    return pending == null ? selected : pending!.future;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    recoveryCalls++;
    return recovered ?? LostDataResponse.empty();
  }
}

class NativeRepository extends MockNutritionRepository {
  int uploads = 0;
  int manualSaves = 0;
  Map<String, Object?>? manualPayload;
  int weightSaves = 0;
  Completer<void>? saveGate;
  bool uploadFails = false;

  @override
  Future<PhotoReview> uploadMealPhoto({
    required String fileName,
    required List<int> bytes,
  }) async {
    uploads++;
    await saveGate?.future;
    if (uploadFails) {
      throw const ApiException('Connection lost', isConnectionError: true);
    }
    return const PhotoReview(
      analysisId: 'native-test',
      status: 'needs_review',
      imageUrl: '',
      disclaimer: 'Test review',
      items: [],
      warnings: [],
      totalPreview:
          MacroPreview(caloriesKcal: 0, proteinG: 0, carbsG: 0, fatG: 0),
    );
  }

  @override
  Future<void> addManualFood({
    required String foodId,
    required double quantity,
    required String unit,
    required String mealType,
    double? totalGrams,
  }) async {
    manualSaves++;
    manualPayload = {
      'food': foodId,
      'quantity': quantity,
      'unit': unit,
      'meal': mealType,
      'grams': totalGrams
    };
    await saveGate?.future;
  }

  @override
  Future<void> logBodyMetric(
      {required double weightKg, DateTime? recordedOn}) async {
    weightSaves++;
    await saveGate?.future;
  }
}

class FakeScannerPlatform extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  int starts = 0;
  int stops = 0;
  bool denyCamera = false;
  Completer<void>? stopGate;

  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox(key: Key('fake-camera'));
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    if (denyCamera) {
      throw const MobileScannerException(
          errorCode: MobileScannerErrorCode.permissionDenied);
    }
    return const MobileScannerViewAttributes(
      currentTorchMode: TorchState.unavailable,
      numberOfCameras: 1,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
    await stopGate?.future;
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> dispose() async {}
}

Future<void> mountScreen(WidgetTester tester, Widget screen,
    {FakePicker? picker, NativeRepository? repository}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => screen),
    GoRoute(
        path: '/meals',
        builder: (_, __) => const Scaffold(body: Text('Diary destination'))),
    GoRoute(
        path: '/analytics',
        builder: (_, __) => const Scaffold(body: Text('Progress destination'))),
    GoRoute(
        path: '/photos/review',
        builder: (_, __) =>
            const Scaffold(body: Text('Photo review destination'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      photoPickerProvider.overrideWithValue(picker ?? FakePicker()),
      nutritionRepositoryProvider
          .overrideWithValue(repository ?? NativeRepository()),
    ],
    child: MaterialApp.router(theme: NovaTheme.dark(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder,
    {double delta = 200}) async {
  await tester.scrollUntilVisible(finder, delta,
      scrollable: find.byType(Scrollable).first);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.3);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets(
      'exact serving rejects invalid text and saves decimal grams once to Dinner',
      (tester) async {
    final repository = NativeRepository()..saveGate = Completer<void>();
    await mountScreen(tester,
        const FoodDetailScreen(foodId: 'egg', initialMealType: 'dinner'),
        repository: repository);
    final quantity = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'Quantity');
    final grams = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Exact total grams');
    await reveal(tester, quantity);
    await tester.enterText(quantity, 'abc');
    await reveal(tester, find.text('Add to Dinner'));
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Add to Dinner'))
            .onPressed,
        isNull);
    await reveal(tester, quantity, delta: -200);
    await tester.enterText(quantity, '2');
    await reveal(tester, grams);
    await tester.enterText(grams, '125.5');
    await reveal(tester, find.text('Add to Dinner'));
    final callback = tester
        .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Add to Dinner'))
        .onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(repository.manualSaves, 1);
    expect(repository.manualPayload?['meal'], 'dinner');
    expect(repository.manualPayload?['grams'], 125.5);
    repository.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Diary destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('picker errors offer permission recovery and cancellation guidance', () {
    for (final code in [
      'camera_access_denied',
      'camera_access_denied_without_prompt',
      'camera_access_restricted'
    ]) {
      final message = photoPickerErrorMessage(
          PlatformException(code: code), ImageSource.camera);
      expect(message, contains('Settings'));
      expect(message, contains('Gallery'));
    }
    expect(
        photoPickerErrorMessage(PlatformException(code: 'photo_access_denied'),
            ImageSource.gallery),
        contains('Allow Photos'));
    expect(
        photoPickerErrorMessage(
            PlatformException(code: 'already_active'), ImageSource.camera),
        contains('Finish or cancel'));
  });

  test('only Android recovers interrupted picker results', () async {
    final picker = FakePicker()
      ..recovered = LostDataResponse(files: [testImage()]);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await recoverInterruptedPhoto(picker), isNull);
    expect(picker.recoveryCalls, 0);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await recoverInterruptedPhoto(picker),
        same(picker.recovered!.files!.first));
    expect(picker.recoveryCalls, 1);
    picker.recovered = LostDataResponse(
        exception: PlatformException(code: 'photo_access_denied'));
    await expectLater(
        recoverInterruptedPhoto(picker), throwsA(isA<PlatformException>()));
  });

  for (final screen in [
    const PhotoScanScreen(),
    const NutritionLabelScanScreen()
  ]) {
    testWidgets('${screen.runtimeType}: camera denial permits gallery recovery',
        (tester) async {
      final picker = FakePicker()
        ..error = PlatformException(code: 'camera_access_denied');
      await mountScreen(tester, screen, picker: picker);
      await reveal(tester, find.text('Camera'));
      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Allow Camera'), findsOneWidget);
      picker.error = null;
      picker.selected = testImage();
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Allow Camera'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancelled or duplicate picker actions never upload',
      (tester) async {
    final picker = FakePicker()..pending = Completer<XFile?>();
    final repository = NativeRepository();
    await mountScreen(tester, const PhotoScanScreen(),
        picker: picker, repository: repository);
    await reveal(tester, find.text('Camera'));
    final button = tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Camera'));
    button.onPressed!();
    button.onPressed!();
    expect(picker.pickCalls, 1);
    picker.pending!.complete(null);
    await tester.pumpAndSettle();
    expect(repository.uploads, 0);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('recovered Android photo requires explicit upload',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final picker = FakePicker()
      ..recovered = LostDataResponse(files: [testImage()]);
    final repository = NativeRepository();
    await mountScreen(tester, const PhotoScanScreen(),
        picker: picker, repository: repository);
    expect(picker.recoveryCalls, 1);
    expect(find.byType(Image), findsOneWidget);
    expect(repository.uploads, 0);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('failed upload can retry and rapid taps submit only once',
      (tester) async {
    final picker = FakePicker()..selected = testImage();
    final repository = NativeRepository()..uploadFails = true;
    await mountScreen(tester, const PhotoScanScreen(initialMealType: 'dinner'),
        picker: picker, repository: repository);
    await reveal(tester, find.text('Gallery'));
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Upload and analyze'));
    await tester.tap(find.text('Upload and analyze'));
    await tester.pumpAndSettle();
    expect(repository.uploads, 1);
    repository.uploadFails = false;
    repository.saveGate = Completer<void>();
    final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Upload and analyze'));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(repository.uploads, 2);
    repository.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Photo review destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weight rejects NaN and simultaneous keyboard/button saves',
      (tester) async {
    final repository = NativeRepository()..saveGate = Completer<void>();
    await mountScreen(tester, const LogWeightScreen(), repository: repository);
    await tester.enterText(find.byType(TextFormField), 'NaN');
    await tester.tap(find.text('Save weight'));
    await tester.pumpAndSettle();
    expect(repository.weightSaves, 0);
    await tester.enterText(find.byType(TextFormField), '75.5');
    final save = tester
        .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Save weight'))
        .onPressed!;
    save();
    save();
    await tester.pump();
    expect(repository.weightSaves, 1);
    repository.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Progress destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('barcode camera stops in background and restarts on resume',
      (tester) async {
    final previous = MobileScannerPlatform.instance;
    final platform = FakeScannerPlatform();
    MobileScannerPlatform.instance = platform;
    addTearDown(() async {
      MobileScannerPlatform.instance = previous;
      await platform.captures.close();
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await mountScreen(tester, const BarcodeScanScreen());
    expect(platform.starts, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(platform.stops, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(platform.starts, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('barcode permission denial retains manual lookup and retry',
      (tester) async {
    final previous = MobileScannerPlatform.instance;
    final platform = FakeScannerPlatform()..denyCamera = true;
    MobileScannerPlatform.instance = platform;
    addTearDown(() async {
      MobileScannerPlatform.instance = previous;
      await platform.captures.close();
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await mountScreen(tester, const BarcodeScanScreen());
    expect(find.textContaining('Allow Camera'), findsOneWidget);
    expect(find.byTooltip('Lookup barcode'), findsOneWidget);
    platform.denyCamera = false;
    await tester.tap(find.text('Try camera again'));
    await tester.pumpAndSettle();
    expect(platform.starts, 2);
    expect(find.textContaining('Allow Camera'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('barcode resume waits for a slow native stop to finish',
      (tester) async {
    final previous = MobileScannerPlatform.instance;
    final platform = FakeScannerPlatform()..stopGate = Completer<void>();
    MobileScannerPlatform.instance = platform;
    addTearDown(() async {
      MobileScannerPlatform.instance = previous;
      await platform.captures.close();
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await mountScreen(tester, const BarcodeScanScreen());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.starts, 1);
    platform.stopGate!.complete();
    await tester.pumpAndSettle();
    expect(platform.starts, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('weight remains scrollable above a phone keyboard',
      (tester) async {
    await mountScreen(tester, const LogWeightScreen());
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '75.5');
    await reveal(tester, find.text('Save weight'));
    await tester.tap(find.text('Save weight'));
    await tester.pumpAndSettle();
    expect(find.text('Progress destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
