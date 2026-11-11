import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/connection_service.dart';

class SpecialKeysWidget extends StatefulWidget {
  final ConnectionService connectionService;

  const SpecialKeysWidget({super.key, required this.connectionService});

  @override
  State<SpecialKeysWidget> createState() => _SpecialKeysWidgetState();
}

class _SpecialKeysWidgetState extends State<SpecialKeysWidget> {
  // Sticky modifier states
  bool _ctrlActive = false;
  bool _superActive = false;
  bool _altActive = false;
  bool _shiftActive = false;

  // FN row visibility
  bool _showFnRow = false;

  void _toggleModifier(String key, bool currentVal, ValueChanged<bool> updater) {
    HapticFeedback.lightImpact();
    final newVal = !currentVal;
    updater(newVal);
    widget.connectionService.sendKeyEvent(key, newVal ? 'down' : 'up');
  }

  void _sendKeyPress(String key) {
    HapticFeedback.selectionClick();
    widget.connectionService.sendKeyEvent(key, 'press');

    // If sticky modifiers were active, unlatch them if desired or keep until manual unlatch
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Optional FN Panel (F1-F12 + Media Keys)
        if (_showFnRow) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
                bottom: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
              ),
            ),
            child: Column(
              children: [
                // F1-F12 horizontally scrollable row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(12, (index) {
                      final fKey = 'F${index + 1}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: OutlinedButton(
                          onPressed: () => _sendKeyPress(fKey),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            minimumSize: const Size(42, 36),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(fKey, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 6),
                // Media Controls & Navigation extras
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildIconKey(Icons.volume_mute, 'MUTE', tooltip: l10n.mute),
                    _buildIconKey(Icons.volume_down, 'VOLDOWN', tooltip: l10n.volumeDown),
                    _buildIconKey(Icons.volume_up, 'VOLUP', tooltip: l10n.volumeUp),
                    _buildIconKey(Icons.play_arrow, 'PLAYPAUSE', tooltip: l10n.playPause),
                    _buildTextKey('Home', 'HOME'),
                    _buildTextKey('End', 'END'),
                    _buildTextKey('PgUp', 'PAGEUP'),
                    _buildTextKey('PgDn', 'PAGEDOWN'),
                  ],
                ),
              ],
            ),
          ),
        ],

        // Main Modifiers and Special Keys Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          color: theme.colorScheme.surfaceContainerHigh,
          child: Column(
            children: [
              // Row 1: Modifiers (CTRL, SUPER, ALT, SHIFT) + FN toggle
              Row(
                children: [
                  _buildModifierButton(
                    label: 'CTRL',
                    isActive: _ctrlActive,
                    onTap: () => _toggleModifier('CTRL', _ctrlActive, (v) => setState(() => _ctrlActive = v)),
                  ),
                  _buildModifierButton(
                    label: 'SUPER',
                    isActive: _superActive,
                    onTap: () => _toggleModifier('SUPER', _superActive, (v) => setState(() => _superActive = v)),
                  ),
                  _buildModifierButton(
                    label: 'ALT',
                    isActive: _altActive,
                    onTap: () => _toggleModifier('ALT', _altActive, (v) => setState(() => _altActive = v)),
                  ),
                  _buildModifierButton(
                    label: 'SHIFT',
                    isActive: _shiftActive,
                    onTap: () => _toggleModifier('SHIFT', _shiftActive, (v) => setState(() => _shiftActive = v)),
                  ),
                  // FN Button (Toggles secondary function row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FilterChip(
                        selected: _showFnRow,
                        label: const Center(
                          child: Text(
                            'FN',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        showCheckmark: false,
                        onSelected: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _showFnRow = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Row 2: TAB, ESC, STAMP, Arrows
              Row(
                children: [
                  _buildActionKey('TAB', 'TAB'),
                  _buildActionKey('ESC', 'ESC'),
                  _buildActionKey('STAMP', 'STAMP', tooltip: 'Print Screen'),
                  const Spacer(),
                  // Mini D-Pad / Arrows
                  _buildArrowKey(Icons.arrow_back, 'LEFT'),
                  _buildArrowKey(Icons.arrow_upward, 'UP'),
                  _buildArrowKey(Icons.arrow_downward, 'DOWN'),
                  _buildArrowKey(Icons.arrow_forward, 'RIGHT'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModifierButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: isActive ? theme.colorScheme.primary : null,
            foregroundColor: isActive ? theme.colorScheme.onPrimary : null,
            padding: const EdgeInsets.symmetric(vertical: 10),
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(String label, String key, {String? tooltip}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip ?? label,
        child: OutlinedButton(
          onPressed: () => _sendKeyPress(key),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildArrowKey(IconData icon, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: IconButton.outlined(
        onPressed: () => _sendKeyPress(key),
        icon: Icon(icon, size: 16),
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildIconKey(IconData icon, String key, {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? key,
      child: IconButton.filledTonal(
        onPressed: () => _sendKeyPress(key),
        icon: Icon(icon, size: 18),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildTextKey(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        onPressed: () => _sendKeyPress(key),
      ),
    );
  }
}
