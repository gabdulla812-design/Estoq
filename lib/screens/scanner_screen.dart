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
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.all],
  );

  bool _saving = false;
  bool _changed = false;
  int _sessionScans = 0;
  late int _positionCount;
  late int _totalQuantity;
  String? _candidateBarcode;
  String? _lastBarcode;
  String? _message;

  @override
  void initState() {
    super.initState();
    _positionCount = widget.initialPositionCount;
    _totalQuantity = widget.initialTotalQuantity;
  }

  void _handleDetection(BarcodeCapture capture) {
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
    if (!mounted || canonicalBarcode == _candidateBarcode) return;

    setState(() {
      _candidateBarcode = canonicalBarcode;
      _message = 'Код в рамке. Нажмите «Сканировать».';
    });
  }

  Future<void> _commitCandidate() async {
    final barcode = _candidateBarcode;
    if (_saving || barcode == null) {
      if (mounted) {
        setState(() {
          _message = 'Поместите штрихкод внутрь белой рамки.';
        });
      }
      return;
    }

    _saving = true;
    try {
      await widget.repository.addOrIncrementItem(
        inventoryId: widget.inventoryId,
        barcode: barcode,
        quantity: 1,
      );
      final items = await widget.repository.listItems(widget.inventoryId);
      if (!mounted) return;

      final total = items.fold<int>(0, (sum, item) => sum + item.quantity);
      HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);

      setState(() {
        _changed = true;
        _sessionScans += 1;
        _positionCount = items.length;
        _totalQuantity = total;
        _lastBarcode = barcode;
        _candidateBarcode = null;
        _message = 'Добавлено +1. Наведите следующий товар.';
      });

      // Короткая пауза не даёт камере немедленно вернуть тот же кадр как
      // новый кандидат. Повторное добавление возможно только новым нажатием.
      await _controller.stop();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        await _controller.start();
      }
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            const frameWidth = 300.0;
            const frameHeight = 170.0;
            final scanWindow = Rect.fromCenter(
              center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
              width: frameWidth,
              height: frameHeight,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  scanWindow: scanWindow,
                  onDetect: _handleDetection,
                  errorBuilder: (context, error) => _ScannerError(error: error),
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: frameWidth,
                      height: frameHeight,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _candidateBarcode == null ? Colors.white : Colors.greenAccent,
                          width: 3,
                        ),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Color(0xCC000000),
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _candidateBarcode ?? _lastBarcode ?? 'Наведите код внутрь белой рамки',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _message ?? 'Считывание происходит только внутри рамки и только после нажатия кнопки.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _commitCandidate,
                          icon: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.qr_code_scanner, size: 30),
                          label: Text(
                            _saving ? 'Сохраняю…' : 'СКАНИРОВАТЬ',
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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
