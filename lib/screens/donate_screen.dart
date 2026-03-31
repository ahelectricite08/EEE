import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/dvcr_theme.dart';
import '../services/user_service.dart';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  UserRole? _userRole;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _donationUrl;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _loadData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final role = await UserService.getCurrentRole();
        final userData = await UserService.getUserDataByUid(user.uid);
        final donationDoc = await FirebaseFirestore.instance
            .collection('config')
            .doc('donate')
            .get();

        setState(() {
          _userRole = role;
          _userData = userData;
          _donationUrl = donationDoc.data()?['url'] ?? 'https://www.helloasso.com';
          _isLoading = false;
        });
      } else {
        final donationDoc = await FirebaseFirestore.instance
            .collection('config')
            .doc('donate')
            .get();

        setState(() {
          _userRole = null;
          _userData = null;
          _donationUrl = donationDoc.data()?['url'] ?? 'https://www.helloasso.com';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _donationUrl = 'https://www.helloasso.com';
      });
    }
  }

  Future<void> _openDonationLink() async {
    final Uri uri = Uri.parse(_donationUrl ?? 'https://www.helloasso.com');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Impossible d\'ouvrir le lien de donation'),
            backgroundColor: DVCRTheme.primaryRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: DVCRTheme.darkBackground,
        body: const Center(
          child: CircularProgressIndicator(
            color: DVCRTheme.primaryGreen,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DVCRTheme.darkBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: DVCRTheme.darkGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🎯 Header Donation
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // Logo DVCR
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: DVCRTheme.greenGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: DVCRTheme.primaryGreen.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: const Text(
                              'DVCR',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Badge MEDIA
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: DVCRTheme.redGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'MEDIA',
                              style: DVCRTheme.labelLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 📝 Titre principal
                    Text(
                      'SOUTENIR DVCR',
                      style: DVCRTheme.displayLarge.copyWith(
                        color: DVCRTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Drapeau Vert Carton Rouge',
                      style: DVCRTheme.titleLarge.copyWith(
                        color: DVCRTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '100% CSSA • ACTUS • LIVE • REPLAYS',
                      style: DVCRTheme.bodyMedium.copyWith(
                        color: DVCRTheme.textMuted,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 🎨 Image de fond
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/donation.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // � Carte de donation
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: DVCRTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: DVCRTheme.primaryGreen.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SOUTENIR LE MÉDIA',
                            style: DVCRTheme.titleLarge.copyWith(
                              color: DVCRTheme.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            'DVCR est un média 100% CSSA indépendant.\nVotre soutien nous permet de continuer à produire du contenu de qualité pour la communauté.',
                            style: DVCRTheme.bodyLarge.copyWith(
                              color: DVCRTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 📊 Statut utilisateur
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: DVCRTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.account_circle_outlined,
                                  color: DVCRTheme.primaryGreen,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Votre statut',
                                        style: DVCRTheme.bodySmall.copyWith(
                                          color: DVCRTheme.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            _userRole?.displayName.toUpperCase() ?? 'VISITEUR',
                                            style: DVCRTheme.titleMedium.copyWith(
                                              color: _userRole?.color ?? DVCRTheme.textMuted,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          if (_userRole != null && _userRole != UserRole.supporter) ...[
                                            const SizedBox(width: 8),
                                            RoleBadge(role: _userRole!.displayName, size: 16),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 🎯 Avantages par rôle
                          _buildBenefitsSection(),

                          const SizedBox(height: 24),

                          // 💰 Bouton de donation
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _openDonationLink,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: DVCRTheme.greenGradient,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Center(
                                  child: Text(
                                    _userRole == null || _userRole == UserRole.supporter
                                        ? 'FAIRE UN DON'
                                        : 'CONTINUER À SOUTENIR',
                                    style: DVCRTheme.titleMedium.copyWith(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Texte info
                          Text(
                            'Via HelloAsso • Sécurisé • Déductible des impôts',
                            style: DVCRTheme.bodySmall.copyWith(
                              color: DVCRTheme.textMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 📈 Stats de soutien
                    _buildStatsSection(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsSection() {
    final benefits = _getBenefitsByRole();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VOS AVANTAGES',
          style: DVCRTheme.titleMedium.copyWith(
            color: DVCRTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ...benefits.map((benefit) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: benefit['color'],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  benefit['text'],
                  style: DVCRTheme.bodyMedium.copyWith(
                    color: DVCRTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  List<Map<String, dynamic>> _getBenefitsByRole() {
    switch (_userRole) {
      case UserRole.supporter:
        return [
          {'text': 'Accès base application', 'color': DVCRTheme.textMuted},
          {'text': 'Navigation sans inscription', 'color': DVCRTheme.textMuted},
        ];
      case UserRole.donateur:
        return [
          {'text': 'Accès chat exclusif', 'color': DVCRTheme.primaryGreen},
          {'text': 'Badge donateur spécial', 'color': DVCRTheme.primaryGreen},
          {'text': 'Fonctionnalités exclusives', 'color': DVCRTheme.primaryGreen},
        ];
      case UserRole.partenaire:
        return [
          {'text': 'Accès chat exclusif', 'color': const Color(0xFFFF9800)},
          {'text': 'Badge partenaire premium', 'color': const Color(0xFFFF9800)},
          {'text': 'Contenu premium', 'color': const Color(0xFFFF9800)},
          {'text': 'Priorité support', 'color': const Color(0xFFFF9800)},
        ];
      case UserRole.communityManager:
        return [
          {'text': 'Modération chat', 'color': DVCRTheme.primaryBlue},
          {'text': 'Gestion contenu', 'color': DVCRTheme.primaryBlue},
          {'text': 'Support utilisateurs', 'color': DVCRTheme.primaryBlue},
        ];
      case UserRole.admin:
        return [
          {'text': 'Accès panneau admin', 'color': DVCRTheme.primaryPurple},
          {'text': 'Gestion rôles', 'color': DVCRTheme.primaryPurple},
          {'text': 'Contrôle total', 'color': DVCRTheme.primaryPurple},
        ];
      default:
        return [
          {'text': 'Connectez-vous pour débloquer des avantages', 'color': DVCRTheme.textMuted},
        ];
    }
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DVCRTheme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'L\'IMPACT DE VOTRE SOUTIEN',
            style: DVCRTheme.titleMedium.copyWith(
              color: DVCRTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('📺', 'Lives', 'Illimités'),
              ),
              Expanded(
                child: _buildStatItem('🎬', 'Replays', 'HD Quality'),
              ),
              Expanded(
                child: _buildStatItem('💬', 'Chat', 'Communauté'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String title, String value) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 32),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: DVCRTheme.bodySmall.copyWith(
            color: DVCRTheme.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: DVCRTheme.titleSmall.copyWith(
            color: DVCRTheme.primaryGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}