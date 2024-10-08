import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/size.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/widget/buttons/base_styled_button.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flutter/material.dart';

class DocumentBanner extends StatelessWidget {
  const DocumentBanner({
    super.key,
    required this.viewName,
    required this.onRestore,
    required this.onDelete,
  });

  final String viewName;
  final void Function() onRestore;
  final void Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Container(
        width: double.infinity,
        color: colorScheme.surfaceContainerHighest,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              FlowyText.medium(
                LocaleKeys.deletePagePrompt_text.tr(),
                color: colorScheme.tertiary,
                fontSize: 14,
              ),
              const HSpace(20),
              BaseStyledButton(
                minWidth: 160,
                minHeight: 40,
                contentPadding: EdgeInsets.zero,
                bgColor: Colors.transparent,
                highlightColor: Theme.of(context).colorScheme.onErrorContainer,
                outlineColor: colorScheme.tertiaryContainer,
                borderRadius: Corners.s8Border,
                onPressed: onRestore,
                child: FlowyText.medium(
                  LocaleKeys.deletePagePrompt_restore.tr(),
                  color: colorScheme.tertiary,
                  fontSize: 13,
                ),
              ),
              const HSpace(20),
              BaseStyledButton(
                minWidth: 220,
                minHeight: 40,
                contentPadding: EdgeInsets.zero,
                bgColor: Colors.transparent,
                highlightColor: Theme.of(context).colorScheme.error,
                outlineColor: colorScheme.tertiaryContainer,
                borderRadius: Corners.s8Border,
                onPressed: () => showConfirmDeletionDialog(
                  context: context,
                  name: viewName.trim().isEmpty
                      ? LocaleKeys.menuAppHeader_defaultNewPageName.tr()
                      : viewName,
                  description: LocaleKeys
                      .deletePagePrompt_deletePermanentDescription
                      .tr(),
                  onConfirm: onDelete,
                ),
                child: FlowyText.medium(
                  LocaleKeys.deletePagePrompt_deletePermanent.tr(),
                  color: colorScheme.tertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
