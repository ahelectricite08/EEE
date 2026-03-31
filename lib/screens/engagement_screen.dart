import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/dvcr_theme.dart';

class EngagementScreen extends StatefulWidget {
  const EngagementScreen({super.key});

  @override
  State<EngagementScreen> createState() => _EngagementScreenState();
}

class _EngagementScreenState extends State<EngagementScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DVCRTheme.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 🎯 Header Engagement
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ENGAGEMENT',
                      style: DVCRTheme.displayLarge.copyWith(
                        color: DVCRTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Suivez notre saison',
                      style: DVCRTheme.bodyLarge.copyWith(
                        color: DVCRTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 🏷️ Navigation par onglets
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: DVCRTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: DVCRTheme.greenGradient,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  labelColor: Colors.black,
                  unselectedLabelColor: DVCRTheme.textSecondary,
                  labelStyle: DVCRTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: DVCRTheme.titleMedium,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'CALENDRIER'),
                    Tab(text: 'RÉSULTATS'),
                    Tab(text: 'CLASSEMENT'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 📊 Contenu des onglets
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    CalendarTab(),
                    ResultsTab(),
                    RankingTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CalendarTab extends StatelessWidget {
  const CalendarTab({super.key});

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('dd MMMM yyyy', 'fr_FR').format(date);
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('date', isGreaterThan: Timestamp.now())
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: DVCRTheme.primaryGreen,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 80,
                  color: DVCRTheme.textMuted,
                ),
                const SizedBox(height: 20),
                Text(
                  'Aucun match à venir',
                  style: DVCRTheme.titleLarge.copyWith(
                    color: DVCRTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le calendrier sera bientôt mis à jour',
                  style: DVCRTheme.bodyMedium.copyWith(
                    color: DVCRTheme.textMuted,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final match = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final team1 = match['team1'] ?? 'Équipe 1';
            final team2 = match['team2'] ?? 'Équipe 2';
            final date = match['date'] as Timestamp;
            final location = match['location'] ?? 'Lieu à définir';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: DVCRCard(
                borderColor: DVCRTheme.primaryGreen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📅 Date et lieu
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: DVCRTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: DVCRTheme.primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatDate(date),
                            style: DVCRTheme.titleMedium.copyWith(
                              color: DVCRTheme.primaryGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.access_time,
                            color: DVCRTheme.primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(date),
                            style: DVCRTheme.bodyMedium.copyWith(
                              color: DVCRTheme.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // ⚽ Match
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  team1.toUpperCase(),
                                  style: DVCRTheme.titleLarge.copyWith(
                                    color: DVCRTheme.primaryGreen,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: DVCRTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: DVCRTheme.primaryGreen.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  'VS',
                                  style: DVCRTheme.titleMedium.copyWith(
                                    color: DVCRTheme.primaryGreen,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  team2.toUpperCase(),
                                  style: DVCRTheme.titleLarge.copyWith(
                                    color: DVCRTheme.primaryRed,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // 📍 Lieu
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: DVCRTheme.textSecondary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                location,
                                style: DVCRTheme.bodyMedium.copyWith(
                                  color: DVCRTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ResultsTab extends StatelessWidget {
  const ResultsTab({super.key});

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('dd MMMM', 'fr_FR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('date', isLessThan: Timestamp.now())
          .orderBy('date', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: DVCRTheme.primaryRed,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sports_score_outlined,
                  size: 80,
                  color: DVCRTheme.textMuted,
                ),
                const SizedBox(height: 20),
                Text(
                  'Aucun résultat disponible',
                  style: DVCRTheme.titleLarge.copyWith(
                    color: DVCRTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les résultats apparaîtront ici après les matchs',
                  style: DVCRTheme.bodyMedium.copyWith(
                    color: DVCRTheme.textMuted,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final match = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final team1 = match['team1'] ?? 'Équipe 1';
            final team2 = match['team2'] ?? 'Équipe 2';
            final score1 = match['score1'] ?? 0;
            final score2 = match['score2'] ?? 0;
            final date = match['date'] as Timestamp;

            Color resultColor = DVCRTheme.textSecondary;
            String resultText = '';
            
            if (score1 > score2) {
              resultColor = DVCRTheme.primaryGreen;
              resultText = 'VICTOIRE';
            } else if (score1 < score2) {
              resultColor = DVCRTheme.primaryRed;
              resultText = 'DÉFAITE';
            } else {
              resultColor = Colors.grey;
              resultText = 'NUL';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: DVCRCard(
                borderColor: resultColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📅 Date
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: resultColor.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _formatDate(date),
                            style: DVCRTheme.titleMedium.copyWith(
                              color: resultColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: resultColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              resultText,
                              style: DVCRTheme.labelLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // ⚽ Score
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  team1.toUpperCase(),
                                  style: DVCRTheme.titleLarge.copyWith(
                                    color: DVCRTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$score1',
                                  style: DVCRTheme.displayLarge.copyWith(
                                    color: DVCRTheme.primaryGreen,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: DVCRTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '-',
                              style: DVCRTheme.titleLarge.copyWith(
                                color: DVCRTheme.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  team2.toUpperCase(),
                                  style: DVCRTheme.titleLarge.copyWith(
                                    color: DVCRTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$score2',
                                  style: DVCRTheme.displayLarge.copyWith(
                                    color: DVCRTheme.primaryRed,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class RankingTab extends StatelessWidget {
  const RankingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ranking')
          .orderBy('position')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: const Color(0xFFFFD700),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 80,
                  color: DVCRTheme.textMuted,
                ),
                const SizedBox(height: 20),
                Text(
                  'Classement non disponible',
                  style: DVCRTheme.titleLarge.copyWith(
                    color: DVCRTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le classement sera mis à jour pendant la saison',
                  style: DVCRTheme.bodyMedium.copyWith(
                    color: DVCRTheme.textMuted,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final team = doc.data() as Map<String, dynamic>;
            final position = team['position'] ?? (index + 1);
            final name = team['name'] ?? 'Équipe';
            final played = team['played'] ?? 0;
            final won = team['won'] ?? 0;
            final drawn = team['drawn'] ?? 0;
            final lost = team['lost'] ?? 0;
            final points = team['points'] ?? 0;

            Color positionColor = DVCRTheme.textSecondary;
            Color bgColor = DVCRTheme.surfaceLight;
            IconData positionIcon = Icons.numbers;

            if (position == 1) {
              positionColor = const Color(0xFFFFD700);
              bgColor = const Color(0xFFFFD700).withOpacity(0.1);
              positionIcon = Icons.emoji_events;
            } else if (position == 2) {
              positionColor = Colors.grey;
              bgColor = Colors.grey.withOpacity(0.1);
              positionIcon = Icons.emoji_events;
            } else if (position == 3) {
              positionColor = const Color(0xFFCD7F32);
              bgColor = const Color(0xFFCD7F32).withOpacity(0.1);
              positionIcon = Icons.emoji_events;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: DVCRCard(
                borderColor: positionColor,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // 🏆 Position
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: positionColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          positionIcon,
                          color: positionColor,
                          size: 20,
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // 📊 Équipe
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: DVCRTheme.titleMedium.copyWith(
                                color: DVCRTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'MJ: $played  V: $won  N: $drawn  D: $lost',
                              style: DVCRTheme.bodySmall.copyWith(
                                color: DVCRTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // 🎯 Points
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: positionColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$points',
                          style: DVCRTheme.titleLarge.copyWith(
                            color: positionColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}