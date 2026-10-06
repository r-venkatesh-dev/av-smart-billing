import 'package:flutter/material.dart';

enum SummaryChipVariant {
  primary,
  success,
  warning,
  danger,
  neutral,
  info,
}

class SummaryChipItem<T> {
  const SummaryChipItem({
    required this.value,
    required this.label,
    required this.count,
    this.variant = SummaryChipVariant.neutral,
  });

  final T value;
  final String label;
  final int count;
  final SummaryChipVariant variant;
}

class SummaryFilterChips<T> extends StatelessWidget {
  const SummaryFilterChips({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<SummaryChipItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _SummaryChip<T>(
              item: items[i],
              isSelected: items[i].value == selectedValue,
              onTap: () => onSelected(items[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip<T> extends StatelessWidget {
  const _SummaryChip({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final SummaryChipItem<T> item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _getColors(context, item.variant, isSelected);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: colors.backgroundColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.borderColor,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  color: colors.textColor,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.badgeBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.count.toString(),
                  style: TextStyle(
                    color: colors.badgeTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ChipColors _getColors(
    BuildContext context,
    SummaryChipVariant variant,
    bool isSelected,
  ) {
    const teal = Color(0xff057c73);
    const darkTeal = Color(0xff004d40);

    if (isSelected) {
      switch (variant) {
        case SummaryChipVariant.primary:
          return const _ChipColors(
            backgroundColor: darkTeal,
            borderColor: darkTeal,
            textColor: Colors.white,
            badgeBackgroundColor: Colors.white,
            badgeTextColor: darkTeal,
          );
        case SummaryChipVariant.success:
          return const _ChipColors(
            backgroundColor: Color(0xff16a34a),
            borderColor: Color(0xff16a34a),
            textColor: Colors.white,
            badgeBackgroundColor: Colors.white,
            badgeTextColor: Color(0xff16a34a),
          );
        case SummaryChipVariant.warning:
          return const _ChipColors(
            backgroundColor: Color(0xffd97706),
            borderColor: Color(0xffd97706),
            textColor: Colors.white,
            badgeBackgroundColor: Colors.white,
            badgeTextColor: Color(0xffd97706),
          );
        case SummaryChipVariant.danger:
          return const _ChipColors(
            backgroundColor: Color(0xffdc2626),
            borderColor: Color(0xffdc2626),
            textColor: Colors.white,
            badgeBackgroundColor: Colors.white,
            badgeTextColor: Color(0xffdc2626),
          );
        case SummaryChipVariant.info:
          return const _ChipColors(
            backgroundColor: Color(0xff0284c7),
            borderColor: Color(0xff0284c7),
            textColor: Colors.white,
            badgeBackgroundColor: Colors.white,
            badgeTextColor: Color(0xff0284c7),
          );
        case SummaryChipVariant.neutral:
          return const _ChipColors(
            backgroundColor: Color(0xff334155),
            borderColor: Color(0xff334155),
            textColor: Colors.white,
            badgeBackgroundColor: Colors.white,
            badgeTextColor: Color(0xff334155),
          );
      }
    }

    // Unselected chip states matching the image design
    switch (variant) {
      case SummaryChipVariant.primary:
        return const _ChipColors(
          backgroundColor: Color(0xffe6f2f0),
          borderColor: Color(0xffa2d6d0),
          textColor: teal,
          badgeBackgroundColor: Color(0xffbfe5e0),
          badgeTextColor: darkTeal,
        );
      case SummaryChipVariant.success:
        return const _ChipColors(
          backgroundColor: Color(0xffecfdf5),
          borderColor: Color(0xffa7f3d0),
          textColor: Color(0xff065f46),
          badgeBackgroundColor: Color(0xffa7f3d0),
          badgeTextColor: Color(0xff044e39),
        );
      case SummaryChipVariant.warning:
        return const _ChipColors(
          backgroundColor: Color(0xfffffbeb),
          borderColor: Color(0xfffde68a),
          textColor: Color(0xff92400e),
          badgeBackgroundColor: Color(0xfffcd34d),
          badgeTextColor: Color(0xff78350f),
        );
      case SummaryChipVariant.danger:
        return const _ChipColors(
          backgroundColor: Color(0xfffef2f2),
          borderColor: Color(0xfffecaca),
          textColor: Color(0xff991b1b),
          badgeBackgroundColor: Color(0xfffecaca),
          badgeTextColor: Color(0xff7f1d1d),
        );
      case SummaryChipVariant.info:
        return const _ChipColors(
          backgroundColor: Color(0xfff0f9ff),
          borderColor: Color(0xffbae6fd),
          textColor: Color(0xff0369a1),
          badgeBackgroundColor: Color(0xffbae6fd),
          badgeTextColor: Color(0xff075985),
        );
      case SummaryChipVariant.neutral:
        return const _ChipColors(
          backgroundColor: Color(0xfff1f5f9),
          borderColor: Color(0xffcbd5e1),
          textColor: Color(0xff475569),
          badgeBackgroundColor: Color(0xffcbd5e1),
          badgeTextColor: Color(0xff334155),
        );
    }
  }
}

class _ChipColors {
  const _ChipColors({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.badgeBackgroundColor,
    required this.badgeTextColor,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color badgeBackgroundColor;
  final Color badgeTextColor;
}
