import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zxing2/qrcode.dart';

import '../models/gym.dart';
import '../models/gym_access_request.dart';
import '../services/auth_service.dart';
import '../services/gym_service.dart';
import '../theme/app_theme.dart';

class GymAccessQrScreen extends StatefulWidget {
  final Gym gym;
  final String memberCode;

  const GymAccessQrScreen({
    super.key,
    required this.gym,
    required this.memberCode,
  });

  @override
  State<GymAccessQrScreen> createState() => _GymAccessQrScreenState();
}

class _GymAccessQrScreenState extends State<GymAccessQrScreen> {
  final _gymService = const GymService();
  GymAccessRequest? _accessRequest;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isAutoRefreshQueued = false;
  String? _errorMessage;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  int _requestDurationSeconds = 60;

  @override
  void initState() {
    super.initState();
    _loadAccessRequest();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _cancelTimers() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _pollTimer = null;
    _countdownTimer = null;
  }

  int _resolveInitialSeconds(GymAccessRequest request) {
    final now = DateTime.now();

    if (request.expiresAt != null) {
      return math.max(0, request.expiresAt!.difference(now).inSeconds);
    }

    return math.max(0, request.expiresInSeconds);
  }

  int _resolveRequestDurationSeconds(
    GymAccessRequest request,
    int initialSeconds,
  ) {
    return [
      request.refreshAfterSeconds,
      request.expiresInSeconds,
      initialSeconds,
      60,
    ].where((value) => value > 0).fold<int>(60, math.max);
  }

  void _markRequestExpiredLocally() {
    final currentRequest = _accessRequest;
    if (currentRequest == null || currentRequest.isScanned || currentRequest.isExpired) {
      return;
    }

    setState(() {
      _accessRequest = currentRequest.copyWith(
        status: 'expired',
        displayState: 'expired',
        expiresInSeconds: 0,
        refreshAfterSeconds: 0,
        isExpired: true,
        flashType: currentRequest.flashType.isNotEmpty ? currentRequest.flashType : 'warning',
        flashTitle: currentRequest.flashTitle.isNotEmpty ? currentRequest.flashTitle : 'QR sudah expired',
        flashMessage: currentRequest.flashMessage.isNotEmpty
            ? currentRequest.flashMessage
            : 'Masa berlaku QR sudah habis. Meminta QR baru...',
      );
    });
  }

  void _setCountdownFromAccess(GymAccessRequest request) {
    _countdownTimer?.cancel();
    if (request.isExpired || request.isScanned) {
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      if (request.expiresAt != null) {
        _secondsRemaining = request.expiresAt!.difference(now).inSeconds;
      } else {
        // fallback jika tidak ada expiresAt, kurangi dari initial
        _secondsRemaining = (_secondsRemaining - 1).clamp(0, 99999);
      }
      if (_secondsRemaining < 0) {
        _secondsRemaining = 0;
      }
      setState(() {});
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _markRequestExpiredLocally();
        _onExpired();
      }
    });
  }

  void _setupPolling() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _accessRequest == null) {
        timer.cancel();
        return;
      }

      if (_accessRequest!.isScanned || _accessRequest!.isExpired) {
        timer.cancel();
        return;
      }

      try {
        final statusRequest = await _gymService.fetchGymAccessStatus(
          requestToken: _accessRequest!.requestToken,
        );

        if (!mounted) return;

        setState(() {
          _accessRequest = statusRequest;
        });

        if (statusRequest.isScanned) {
          _cancelTimers();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(statusRequest.flashMessage.isNotEmpty
                  ? statusRequest.flashMessage
                  : 'QR sudah discan. Silakan masuk.'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }

        if (statusRequest.isExpired) {
          timer.cancel();
          _onExpired();
        }
      } on AuthException catch (error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = error.message;
        });
      } catch (_) {
        // tetap polling, tapi catat error singkat.
      }
    });
  }

  Future<void> _loadAccessRequest() async {
    _cancelTimers();

    setState(() {
      _isLoading = true;
      _isAutoRefreshQueued = false;
      _errorMessage = null;
      _accessRequest = null;
      _secondsRemaining = 0;
      _requestDurationSeconds = 60;
    });

    try {
      final request = await _gymService.requestGymAccess(
        memberCode: widget.memberCode,
        gymCode: widget.gym.gymCode,
      );

      if (!mounted) return;

      final initialSeconds = _resolveInitialSeconds(request);

      setState(() {
        _accessRequest = request;
        _isLoading = false;
        _secondsRemaining = initialSeconds;
        _requestDurationSeconds = _resolveRequestDurationSeconds(
          request,
          initialSeconds,
        );
      });

      _setCountdownFromAccess(request);
      _setupPolling();

      if (request.isScanned) {
        _cancelTimers();
      }

      if (request.isExpired) {
        _onExpired();
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal membuat request QR. Coba lagi.';
        _isLoading = false;
      });
    }
  }

  Future<void> _onExpired() async {
    if (!mounted || _isRefreshing || _isAutoRefreshQueued || (_accessRequest?.isScanned ?? false)) {
      return;
    }

    _markRequestExpiredLocally();
    _isAutoRefreshQueued = true;

    try {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('QR sudah expired. Membuat request baru...'),
            backgroundColor: Colors.orange,
          ),
        );

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      await _refreshNow();
    } finally {
      _isAutoRefreshQueued = false;
    }
  }

  Future<void> _refreshNow() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      await _loadAccessRequest();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  String get _statusLabel {
    if (_accessRequest == null) {
      return 'Menunggu request';
    }
    if (_accessRequest!.isScanned) {
      return 'Discan';
    }
    if (_accessRequest!.isExpired) {
      return 'Expired';
    }
    return _accessRequest!.displayState.isNotEmpty
        ? _accessRequest!.displayState
        : _accessRequest!.status;
  }

  @override
  Widget build(BuildContext context) {
    final qrPayload = _accessRequest?.qrPayload ??
        const GymService().buildMemberAccessUri(
              memberCode: widget.memberCode,
              gymCode: widget.gym.gymCode,
            ).toString();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text(
          'QR Access Brand',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF4F1), AppTheme.surface],
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppTheme.heroGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryDark.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scan QR untuk akses gym',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _accessRequest == null
                            ? 'Membuat request QR...' 
                            : _accessRequest!.isScanned
                                ? 'QR sudah discan. Silakan masuk.'
                                : _accessRequest!.isExpired
                                    ? 'QR expired. Memperbarui...'
                                    : 'QR aktif selama 1 menit. Status: $_statusLabel',
                        style: const TextStyle(color: Colors.white, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _secondsRemaining > 0
                            ? 'Status: $_statusLabel • $_secondsRemaining detik tersisa'
                            : 'Status: $_statusLabel',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final qrSize = (constraints.maxWidth - 108)
                        .clamp(190.0, 320.0)
                        .toDouble();

                    return Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: _QrMatrix(value: qrPayload, size: qrSize),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.gym.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.gym.city.isEmpty ? 'Brand Gym' : widget.gym.city,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_secondsRemaining > 0 && !_accessRequest!.isScanned && !_accessRequest!.isExpired)
                            Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              child: Column(
                                children: [
                                  const Text(
                                    'Waktu tersisa',
                                    style: TextStyle(
                                      color: AppTheme.muted,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 120,
                                    height: 120,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: _requestDurationSeconds <= 0
                                              ? 0
                                              : (_secondsRemaining / _requestDurationSeconds)
                                                    .clamp(0.0, 1.0),
                                          strokeWidth: 8,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            _secondsRemaining > 10 ? AppTheme.primary : Colors.red,
                                          ),
                                        ),
                                        Text(
                                          '$_secondsRemaining',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            color: _secondsRemaining > 10 ? AppTheme.primary : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F3F3),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'QR Payload',
                                  style: TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  qrPayload,
                                  style: const TextStyle(
                                    color: AppTheme.ink,
                                    fontWeight: FontWeight.w800,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'QR berlaku 1 menit. Kalau belum discan sampai habis, halaman ini akan otomatis meminta QR baru dan tetap menampilkan status masuk saat scan berhasil.',
                          style: const TextStyle(color: AppTheme.muted, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading || _isRefreshing ? null : _refreshNow,
                  icon: const Icon(Icons.refresh),
                  label: Text(_isRefreshing ? 'Menyegarkan...' : 'Refresh QR Sekarang'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QrMatrix extends StatelessWidget {
  final String value;
  final double size;

  const _QrMatrix({required this.value, required this.size});

  @override
  Widget build(BuildContext context) {
    final matrix = Encoder.encode(value, ErrorCorrectionLevel.m).matrix!;
    const quietZone = 4; // modules
    final matrixSize = matrix.width + (quietZone * 2);
    final targetSize = size.floorToDouble();
    final cellSize = (targetSize / matrixSize)
        .floorToDouble()
        .clamp(3.0, double.infinity)
        .toDouble();
    final qrSize = cellSize * matrixSize;

    return SizedBox(
      width: qrSize + 28,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFECE3E3)),
        ),
        child: SizedBox(
          width: qrSize,
          height: qrSize,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              matrixSize,
              (y) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  matrixSize,
                  (x) {
                    final mx = x - quietZone;
                    final my = y - quietZone;
                    final isDark = mx >= 0 &&
                        my >= 0 &&
                        mx < matrix.width &&
                        my < matrix.height &&
                        matrix.get(mx, my) == 1;
                    return SizedBox(
                      width: cellSize,
                      height: cellSize,
                      child: ColoredBox(
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
