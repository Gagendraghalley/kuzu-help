import 'package:flutter/material.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Bottom sheet listing [options], with a tick by [selected]. Returns the
/// option tapped, or null if dismissed (dzongkhag and sort pickers).
/// With [searchHint], a box at the top narrows the list as you type: to
/// options whose label, or one of [searchTermsOf] (other spellings, towns),
/// contains what's typed; a match on one of those is shown under the label.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T? selected,
  required String Function(T option) labelOf,
  String? searchHint,
  List<String> Function(T option)? searchTermsOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    // Tall enough to show most of the 20 dzongkhags at once.
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ChoiceSheet<T>(
      title: title,
      options: options,
      selected: selected,
      labelOf: labelOf,
      searchHint: searchHint,
      searchTermsOf: searchTermsOf,
    ),
  );
}

class _ChoiceSheet<T> extends StatefulWidget {
  final String title;
  final List<T> options;
  final T? selected;
  final String Function(T option) labelOf;
  final String? searchHint;
  final List<String> Function(T option)? searchTermsOf;

  const _ChoiceSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.searchHint,
    required this.searchTermsOf,
  });

  @override
  State<_ChoiceSheet<T>> createState() => _ChoiceSheetState<T>();
}

class _ChoiceSheetState<T> extends State<_ChoiceSheet<T>> {
  String _query = '';

  /// Lower case, without spaces or dashes: 'wangdue' finds 'Wangdue Phodrang',
  /// 'trashi yangtse' finds 'Trashiyangtse'.
  static String _plain(String text) => text.toLowerCase().replaceAll(RegExp(r'[\s\-]'), '');

  /// The options left, each with what else it matched by (null: its label, or nothing typed).
  List<(T, String?)> get _shown {
    final query = _plain(_query);
    if (query.isEmpty) return [for (final o in widget.options) (o, null)];
    return [
      for (final option in widget.options)
        if (_plain(widget.labelOf(option)).contains(query))
          (option, null)
        else if ((widget.searchTermsOf?.call(option) ?? const <String>[])
                .where((term) => _plain(term).contains(query))
                .firstOrNull
            case final term?)
          (option, term),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final searchHint = widget.searchHint;
    final shown = _shown;
    // Keeps the list above the keyboard while typing.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (searchHint != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    textInputAction: TextInputAction.search,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: searchHint,
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (text) => setState(() => _query = text),
                    // Enter picks the only one left.
                    onSubmitted: (_) {
                      if (shown.length == 1) Navigator.pop(context, shown.single.$1);
                    },
                  ),
                ),
              Flexible(
                child: shown.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(AppStrings.nothingMatches(_query.trim()),
                            textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        children: [
                          for (final (option, matchedBy) in shown)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              selectedTileColor: AppColors.peach,
                              title: Text(widget.labelOf(option)),
                              subtitle: matchedBy == null ? null : Text(matchedBy),
                              selected: option == widget.selected,
                              trailing: option == widget.selected ? const Icon(Icons.check_rounded) : null,
                              onTap: () => Navigator.pop(context, option),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded button showing the current choice, e.g. the dzongkhag (C1, C2).
class PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const PillButton({super.key, required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.outline, width: 1.2),
        foregroundColor: AppColors.ink,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: AppColors.primaryDeep),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.muted),
        ],
      ),
    );
  }
}
