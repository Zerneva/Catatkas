import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class CatatKasAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String subtitle;
  final List<Widget>? actions;

  const CatatKasAppBar({
    super.key,
    required this.subtitle,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 16,
      shape: const Border(
        bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
      ),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CatatKas • $subtitle',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    const Icon(
                      Icons.cloud_done_rounded,
                      size: 12,
                      color: AppColors.piutang,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tersinkronisasi',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.piutang,
                            fontSize: 10.5,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: actions ??
          [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: 'Notifikasi',
                  icon: const Icon(Icons.notifications_outlined, size: 22),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('1 tagihan jatuh tempo besok (Dimas Arya)'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                Positioned(
                  right: 11,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.hutang,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(
                  'BS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
    );
  }
}

class PartnerAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double radius;
  final bool isVerified;

  const PartnerAvatar({
    super.key,
    required this.name,
    required this.color,
    this.radius = 22,
    this.isVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: color.withValues(alpha: 0.14),
          child: Text(
            Formatters.initials(name),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: radius * 0.62,
            ),
          ),
        ),
        if (isVerified)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 14,
                color: AppColors.secondary,
              ),
            ),
          ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
