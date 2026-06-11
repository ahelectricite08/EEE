import 'package:flutter/material.dart';

// ── Base animated skeleton block ───────────────────────────────────────────────
class DVCRSkeleton extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const DVCRSkeleton({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
  });

  @override
  State<DVCRSkeleton> createState() => _DVCRSkeletonState();
}

class _DVCRSkeletonState extends State<DVCRSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.95).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1C1C), Color(0xFF252525)],
          ),
        ),
      ),
    );
  }
}

// ── Generic card skeleton (articles, etc.) ────────────────────────────────────
class DVCRCardSkeleton extends StatelessWidget {
  const DVCRCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          DVCRSkeleton(height: 14, width: 110),
          SizedBox(height: 14),
          DVCRSkeleton(height: 22, width: 210),
          SizedBox(height: 10),
          DVCRSkeleton(height: 12, width: 170),
          SizedBox(height: 18),
          DVCRSkeleton(height: 90),
        ],
      ),
    );
  }
}

// ── Search / list row skeleton ─────────────────────────────────────────────────
class DVCRSearchSkeleton extends StatelessWidget {
  const DVCRSearchSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: const [
          DVCRSkeleton(
            height: 54,
            width: 54,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DVCRSkeleton(height: 10, width: 72),
                SizedBox(height: 8),
                DVCRSkeleton(height: 15),
                SizedBox(height: 8),
                DVCRSkeleton(height: 11, width: 150),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Match card skeleton ───────────────────────────────────────────────────────
class DVCRMatchCardSkeleton extends StatelessWidget {
  const DVCRMatchCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: const [
          // Competition + date row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DVCRSkeleton(height: 11, width: 100),
              DVCRSkeleton(height: 11, width: 70),
            ],
          ),
          SizedBox(height: 16),
          // Teams + score row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    DVCRSkeleton(
                      height: 44,
                      width: 44,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    SizedBox(height: 8),
                    DVCRSkeleton(height: 13, width: 70),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: DVCRSkeleton(height: 30, width: 60),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    DVCRSkeleton(
                      height: 44,
                      width: 44,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    SizedBox(height: 8),
                    DVCRSkeleton(height: 13, width: 70),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          // Footer row
          DVCRSkeleton(height: 36, borderRadius: BorderRadius.all(Radius.circular(10))),
        ],
      ),
    );
  }
}

// ── Article row skeleton (home feed style) ─────────────────────────────────────
class DVCRArticleRowSkeleton extends StatelessWidget {
  const DVCRArticleRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Color accent bar
          Container(
            width: 3,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DVCRSkeleton(height: 10, width: 90),
                SizedBox(height: 8),
                DVCRSkeleton(height: 15),
                SizedBox(height: 6),
                DVCRSkeleton(height: 11, width: 130),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DVCRSkeleton(
            height: 52,
            width: 52,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ],
      ),
    );
  }
}

// ── Profile hero skeleton ─────────────────────────────────────────────────────
class DVCRProfileHeroSkeleton extends StatelessWidget {
  const DVCRProfileHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      height: 392,
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar placeholder
          Row(
            children: [
              const DVCRSkeleton(
                height: 34,
                width: 34,
                borderRadius: BorderRadius.all(Radius.circular(17)),
              ),
              const Spacer(),
              const DVCRSkeleton(
                height: 34,
                width: 34,
                borderRadius: BorderRadius.all(Radius.circular(17)),
              ),
            ],
          ),
          const Spacer(),
          // Avatar
          const Center(
            child: DVCRSkeleton(
              height: 80,
              width: 80,
              borderRadius: BorderRadius.all(Radius.circular(40)),
            ),
          ),
          const SizedBox(height: 14),
          // Name
          const Center(child: DVCRSkeleton(height: 20, width: 140)),
          const SizedBox(height: 8),
          const Center(child: DVCRSkeleton(height: 14, width: 90)),
          const SizedBox(height: 18),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _StatChipSkeleton(),
              _StatChipSkeleton(),
              _StatChipSkeleton(),
            ],
          ),
          const SizedBox(height: 14),
          // Member since chip
          const Center(child: DVCRSkeleton(height: 32, width: 160)),
        ],
      ),
    );
  }
}

class _StatChipSkeleton extends StatelessWidget {
  const _StatChipSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        DVCRSkeleton(height: 22, width: 40),
        SizedBox(height: 4),
        DVCRSkeleton(height: 11, width: 60),
      ],
    );
  }
}

// ── Matches list skeleton (3 rows) ─────────────────────────────────────────────
class DVCRMatchesListSkeleton extends StatelessWidget {
  const DVCRMatchesListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        DVCRMatchCardSkeleton(),
        DVCRMatchCardSkeleton(),
        DVCRMatchCardSkeleton(),
      ],
    );
  }
}
