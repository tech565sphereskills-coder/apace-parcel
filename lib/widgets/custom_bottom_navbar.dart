import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class NavTabItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool hasBadge;

  const NavTabItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    this.hasBadge = false,
  });
}

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool hasActiveOrder;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.hasActiveOrder = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      const NavTabItem(
        activeIcon: Icons.home_rounded,
        inactiveIcon: Icons.home_outlined,
        label: 'Home',
      ),
      NavTabItem(
        activeIcon: Icons.local_shipping_rounded,
        inactiveIcon: Icons.local_shipping_outlined,
        label: 'Orders',
        hasBadge: hasActiveOrder,
      ),
      const NavTabItem(
        activeIcon: Icons.account_balance_wallet_rounded,
        inactiveIcon: Icons.account_balance_wallet_outlined,
        label: 'Wallet',
      ),
      const NavTabItem(
        activeIcon: Icons.person_rounded,
        inactiveIcon: Icons.person_outline_rounded,
        label: 'Profile',
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2A0F172A),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(items.length, (index) {
            return _AnimatedNavTab(
              index: index,
              item: items[index],
              isSelected: currentIndex == index,
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(index);
              },
            );
          }),
        ),
      ),
    );
  }
}

class _AnimatedNavTab extends StatefulWidget {
  final int index;
  final NavTabItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedNavTab({
    required this.index,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AnimatedNavTab> createState() => _AnimatedNavTabState();
}

class _AnimatedNavTabState extends State<_AnimatedNavTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _motionAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 480),
      vsync: this,
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.26), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.26, end: 0.94), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _motionAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isSelected) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedNavTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAnimatedIcon() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Offset offset = Offset.zero;
        double rotation = 0.0;

        if (widget.index == 0) {
          offset = Offset(0, -3.5 * _motionAnim.value);
        } else if (widget.index == 1) {
          offset = Offset(4.5 * _motionAnim.value, 0);
        } else if (widget.index == 2) {
          rotation = -0.22 * _motionAnim.value;
        } else {
          offset = Offset(0, -3.0 * _motionAnim.value);
          rotation = 0.14 * _motionAnim.value;
        }

        return Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: widget.isSelected ? _scaleAnim.value : 1.0,
              child: child,
            ),
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Icon(
              widget.isSelected ? widget.item.activeIcon : widget.item.inactiveIcon,
              key: ValueKey('${widget.index}_${widget.isSelected}'),
              color: widget.isSelected ? Colors.white : const Color(0xFF94A3B8),
              size: 22,
            ),
          ),
          if (widget.item.hasBadge)
            Positioned(
              right: -3,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isSelected
                        ? AppColors.primaryOrange
                        : const Color(0xFF0F172A),
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: widget.isSelected ? 16 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: widget.isSelected
              ? const LinearGradient(
                  colors: [AppColors.primaryOrange, Color(0xFFFF8A2B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(22),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAnimatedIcon(),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: widget.isSelected
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 7),
                        Text(
                          widget.item.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

