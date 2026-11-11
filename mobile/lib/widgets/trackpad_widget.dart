import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/host_device.dart';
import '../services/connection_service.dart';

class TrackpadWidget extends StatefulWidget {
  final ConnectionService connectionService;

  const TrackpadWidget({super.key, required this.connectionService});

  @override
  State<TrackpadWidget> createState() => _TrackpadWidgetState();
}

class _TrackpadWidgetState extends State<TrackpadWidget> {
  // Pointers tracking for multi-touch gestures
  final Map<int, Offset> _pointerPositions = {};
  Offset? _lastPanPosition;
  Offset? _dragStartPosition;
  DateTime? _firstPointerDownTime;
  int _maxPointersInGesture = 0;
  double _totalMovement = 0.0;
  double _accumulatedScrollY = 0.0;
  bool _isMovingCursor = false;
  bool _isScrolling = false;

  // Thresholds for gesture discrimination
  static const double _kCursorDeadzone = 5.0;
  static const double _kScrollStartThreshold = 18.0;
  static const double _kScrollStep = 12.0;
  static const double _kTapMaxMovement = 16.0;
  static const int _kTapMaxDurationMs = 350;

  // Sensitivity settings
  double _sensitivity = 1.4;

  @override
  void initState() {
    super.initState();
    _loadSensitivity();
  }

  @override
  void didUpdateWidget(TrackpadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectionService.activeDevice?.id !=
        widget.connectionService.activeDevice?.id) {
      _loadSensitivity();
    }
  }

  String _getSensitivityKey(HostDevice? device) {
    if (device != null) {
      return 'sensitivity_${device.ip}_${device.hostname}';
    }
    return 'sensitivity_default';
  }

  Future<void> _loadSensitivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getSensitivityKey(widget.connectionService.activeDevice);
      final saved = prefs.getDouble(key);
      if (saved != null && mounted) {
        final clamped = saved.clamp(0.5, 3.0);
        setState(() {
          _sensitivity = (clamped * 10).roundToDouble() / 10.0;
        });
      }
    } catch (_) {
      // Fallback to default sensitivity if preferences fail to load
    }
  }

  Future<void> _saveSensitivity(double val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getSensitivityKey(widget.connectionService.activeDevice);
      await prefs.setDouble(key, val);
    } catch (_) {
      // Ignored
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointerPositions.isEmpty) {
      _firstPointerDownTime = DateTime.now();
      _maxPointersInGesture = 1;
      _totalMovement = 0.0;
      _accumulatedScrollY = 0.0;
      _isMovingCursor = false;
      _isScrolling = false;
      _dragStartPosition = event.position;
      _lastPanPosition = event.position;
    }

    _pointerPositions[event.pointer] = event.position;

    if (_pointerPositions.length > _maxPointersInGesture) {
      _maxPointersInGesture = _pointerPositions.length;
    }

    // A multi-touch gesture should never move the cursor
    if (_maxPointersInGesture > 1) {
      _isMovingCursor = false;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    _pointerPositions[event.pointer] = event.position;

    // 1 Finger: Cursor movement (only allowed if this interaction has NEVER exceeded 1 pointer)
    if (_maxPointersInGesture == 1 && _pointerPositions.length == 1) {
      final currentPos = event.position;
      final startPos = _dragStartPosition ?? currentPos;
      final distFromStart = (currentPos - startPos).distance;

      _totalMovement += event.delta.dx.abs() + event.delta.dy.abs();

      // Enforce a small deadzone so intentional taps do not cause slight cursor jumps
      if (!_isMovingCursor) {
        if (distFromStart >= _kCursorDeadzone) {
          _isMovingCursor = true;
          _lastPanPosition = startPos;
        }
      }

      if (_isMovingCursor && _lastPanPosition != null) {
        final rawDx = currentPos.dx - _lastPanPosition!.dx;
        final rawDy = currentPos.dy - _lastPanPosition!.dy;

        final dx = rawDx * _sensitivity;
        final dy = rawDy * _sensitivity;

        if (dx.abs() >= 0.5 || dy.abs() >= 0.5) {
          widget.connectionService.sendMouseMove(dx.round(), dy.round());
          _lastPanPosition = currentPos;
        }
      }
    } else if (_maxPointersInGesture == 2 && _pointerPositions.length == 2) {
      // 2 Fingers: Vertical scroll
      final delta = event.delta;
      _totalMovement += delta.dx.abs() + delta.dy.abs();
      _accumulatedScrollY += delta.dy;

      // Only enter scrolling state once past deadzone to avoid scroll events during 2-finger taps
      if (!_isScrolling && _accumulatedScrollY.abs() >= _kScrollStartThreshold) {
        _isScrolling = true;
      }

      // Invert delta.dy for natural scroll feel
      if (_isScrolling && _accumulatedScrollY.abs() >= _kScrollStep) {
        final scrollUnits = (_accumulatedScrollY / _kScrollStep).round();
        if (scrollUnits != 0) {
          widget.connectionService.sendMouseScroll(0, scrollUnits);
          _accumulatedScrollY -= scrollUnits * _kScrollStep;
        }
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointerPositions.remove(event.pointer);

    // Only evaluate tap gesture when all fingers have left the surface
    if (_pointerPositions.isEmpty) {
      final gestureDuration = _firstPointerDownTime != null
          ? DateTime.now().difference(_firstPointerDownTime!).inMilliseconds
          : 1000;

      // Check if it was a quick tap with minimal movement (< 16 pixels) and no active move/scroll
      if (!_isMovingCursor &&
          !_isScrolling &&
          _totalMovement < _kTapMaxMovement &&
          gestureDuration < _kTapMaxDurationMs) {
        if (_maxPointersInGesture == 1) {
          // Fast single tap -> Left click
          HapticFeedback.lightImpact();
          widget.connectionService.sendMouseButton('left', 'click');
        } else if (_maxPointersInGesture == 2) {
          // Fast two-finger tap -> Right click in place
          HapticFeedback.mediumImpact();
          widget.connectionService.sendMouseButton('right', 'click');
        }
      }

      _resetGestureState();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerPositions.remove(event.pointer);
    if (_pointerPositions.isEmpty) {
      _resetGestureState();
    }
  }

  void _resetGestureState() {
    _lastPanPosition = null;
    _dragStartPosition = null;
    _isMovingCursor = false;
    _isScrolling = false;
    _firstPointerDownTime = null;
    _maxPointersInGesture = 0;
    _totalMovement = 0.0;
    _accumulatedScrollY = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // Sensitivity slider bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
          child: Row(
            children: [
              const Icon(Icons.speed, size: 18),
              const SizedBox(width: 8),
              Text(l10n.sensitivity, style: const TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _sensitivity,
                  min: 0.5,
                  max: 3.0,
                  divisions: 25,
                  label: '${_sensitivity.toStringAsFixed(1)}x',
                  onChanged: (val) {
                    setState(() => _sensitivity = val);
                    _saveSensitivity(val);
                  },
                  onChangeEnd: (val) {
                    _saveSensitivity(val);
                  },
                ),
              ),
              Text(
                '${_sensitivity.toStringAsFixed(1)}x',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Main Touch Surface
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(100),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurface.withAlpha(50),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.touchpadArea,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withAlpha(80),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.touchpadInstructions,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withAlpha(70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Dedicated Bottom Mouse Buttons (Multi-touch aware, supports tap & hold-drag)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              // Left Click Button
              Expanded(
                flex: 5,
                child: _MouseButtonItem(
                  button: 'left',
                  connectionService: widget.connectionService,
                  icon: Icons.mouse,
                  label: l10n.leftClick,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 8),

              // Middle Click Button (Wheel click)
              Expanded(
                flex: 2,
                child: _MouseButtonItem(
                  button: 'middle',
                  connectionService: widget.connectionService,
                  icon: Icons.circle_outlined,
                  tooltip: l10n.middleClick,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),

              // Right Click Button
              Expanded(
                flex: 4,
                child: _MouseButtonItem(
                  button: 'right',
                  connectionService: widget.connectionService,
                  icon: Icons.mouse_outlined,
                  label: l10n.rightClick,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom interactive mouse button that handles press/release seamlessly
/// and allows simultaneous dragging with trackpad navigation.
class _MouseButtonItem extends StatefulWidget {
  final String button;
  final ConnectionService connectionService;
  final IconData icon;
  final String? label;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const _MouseButtonItem({
    required this.button,
    required this.connectionService,
    required this.icon,
    this.label,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<_MouseButtonItem> createState() => _MouseButtonItemState();
}

class _MouseButtonItemState extends State<_MouseButtonItem> {
  bool _isDown = false;

  void _onDown(PointerDownEvent event) {
    setState(() => _isDown = true);
    HapticFeedback.lightImpact();
    widget.connectionService.sendMouseButton(widget.button, 'press');
  }

  void _onUp(PointerUpEvent event) {
    if (_isDown) {
      setState(() => _isDown = false);
      widget.connectionService.sendMouseButton(widget.button, 'release');
    }
  }

  void _onCancel(PointerCancelEvent event) {
    if (_isDown) {
      setState(() => _isDown = false);
      widget.connectionService.sendMouseButton(widget.button, 'release');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = widget.backgroundColor ?? theme.colorScheme.primaryContainer;
    final fg = widget.foregroundColor ?? theme.colorScheme.onPrimaryContainer;

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, size: 18, color: fg),
        if (widget.label != null) ...[
          const SizedBox(width: 8),
          Text(
            widget.label!,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );

    if (widget.tooltip != null) {
      content = Tooltip(
        message: widget.tooltip!,
        child: content,
      );
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _isDown ? bg.withAlpha(200) : bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isDown ? theme.colorScheme.primary : theme.colorScheme.outlineVariant.withAlpha(80),
            width: _isDown ? 2.0 : 1.0,
          ),
          boxShadow: _isDown
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(child: content),
      ),
    );
  }
}
