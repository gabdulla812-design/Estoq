import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/inventory_repository.dart';
import '../utils/barcode_normalizer.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    required this.repository,
    required this.inventoryId,
    required this.initialPositionCount,
    required this.initialTotalQuantity,
  });

  final InventoryRepository repository;
  final int inventoryId;
  final int initialPositionCount;
  final int initialTotalQuantity;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.all],
  );

  final Map<String, DateTime> _lastAcceptedAt = <String, DateTime>{};

  bool _saving = false;
  bool _changed = false;
  int _sessionScans = 0;
  late int _positionCount;
  late int _totalQuantity;
  String? _lastBarcode;
  String? _message;

  static const Duration _sameCodeCooldown = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _positionCount = widget.initialPositionCount;
    _totalQuantity = widget.initialTotalQuantity;
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_saving) return;

    String? rawValue;
    for (final barcode in capture.barcodes) {
      final candidate = barcode.rawValue?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        rawValue = candidate;
        break;
      }
    }
    if (rawValue == null) return;

    final canonicalBarcode = BarcodeNormalizer.normalize(rawValue);
    final now = DateTime.now();
    final previous = _lastAcceptedAt[canonicalBarcode];
    if (previous != null && now.difference(previous) < _sameCodeCooldown) {
      return;
    }

    _lastAcceptedAt[canonicalBarcode] = now;
    _saving = true;

    try {
      await widget.repository.addOrIncrementItem(
        inventoryId: widget.inventoryId,
        barcode: canonicalBarcode,
        quantity: 1,
      );
      final items = await widget.repository.listItems(widget.inventoryId);
      if (!mounted) return;

      final total = items.fold<int>(0, (sum, item) => sum + item.quantity);
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);

      setState(() {
        _changed = true;
        _sessionScans += 1;
        _positionCount = items.length;
        _totalQuantity = total;
        _lastBarcode = canonicalBarcode;
        _message = 'Добавлено +1';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Не удалось сохранить сканирование';
      });
    } finally {
      _saving = false;
    }
  }

  Future<bool> _onWillPop() async {
    Navigator.of(context).pop(_changed);
    return false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Готово',
            onPressed: () => Navigator.of(context).pop(_changed),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Быстрое сканирование'),
          actions: [
            IconButton(
              tooltip: 'Фонарик',
              onPressed: _controller.toggleTorch,
              icon: const Icon(Icons.flashlight_on_outlined),
            ),
            IconButton(
              tooltip: 'Сменить камеру',
              onPressed: _controller.switchCamera,
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _handleDetection,
              errorBuilder: (context, error) => _ScannerError(error: error),
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 300,
                  height: 170,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: _ScanStats(
                sessionScans: _sessionScans,
                positionCount: _positionCount,
                totalQuantity: _totalQuantity,
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xCC000000),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _lastBarcode ?? 'Наведите камеру на код товара',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _message ??
                            'Каждый успешный скан сразу добавляет 1 единицу. Можно сканировать подряд.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (_saving) ...[
                        const SizedBox(height: 10),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanStats extends StatelessWidget {
  const _ScanStats({
    required this.sessionScans,
    required this.positionCount,
    required this.totalQuantity,
  });

  final int sessionScans;
  final int positionCount;
  final int totalQuantity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xCC000000),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(label: 'Сканов', value: '$sessionScans'),
            _Stat(label: 'Позиций', value: '$positionCount'),
            _Stat(label: 'Единиц', value: '$totalQuantity'),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Не удалось открыть камеру',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Проверьте разрешение на использование камеры в настройках Android и попробуйте снова.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.errorCode.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
