import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:wanderwell/services/premium_service.dart';
import 'package:wanderwell/theme.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _loading = false;
  bool _processing = false;
  int _selectedPlan = 1; // 0 = monthly, 1 = annual
  StreamSubscription<bool>? _premiumSub;
  StreamSubscription<List<PurchaseDetails>>? _purchaseWatchSub;

  @override
  void initState() {
    super.initState();
    _premiumSub = PremiumService().onPremiumActivated.listen((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _premiumSub?.cancel();
    _purchaseWatchSub?.cancel();
    super.dispose();
  }

  void _watchPurchaseResult() {
    _purchaseWatchSub?.cancel();
    _purchaseWatchSub = InAppPurchase.instance.purchaseStream.listen((purchases) {
      for (final p in purchases) {
        if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
          if (mounted) setState(() => _processing = true);
        } else if (p.status == PurchaseStatus.canceled || p.status == PurchaseStatus.error) {
          if (mounted) setState(() => _processing = false);
          _purchaseWatchSub?.cancel();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final premium = PremiumService();
    final monthly = premium.monthlyProduct;
    final annual = premium.annualProduct;

    return Scaffold(
      backgroundColor: AweColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: AweColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        // Icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: Alignment(-0.3, -0.4),
                              radius: 0.7,
                              colors: [AweColors.accentTeal.withValues(alpha: 0.3), AweColors.accentSlate],
                            ),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 20),
                        // Title
                        Text(
                          'Unlock the full\nAwe experience',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: 28,
                            height: 1.1,
                            color: AweColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Feature list
                        _FeatureRow(icon: Icons.layers_outlined, text: 'All collections unlocked'),
                        const SizedBox(height: 14),
                        _FeatureRow(icon: Icons.history, text: 'Full Wonder Trail — every past wonder'),
                        const SizedBox(height: 14),
                        _FeatureRow(icon: Icons.flight_takeoff, text: 'AI-powered trip itineraries'),
                        const SizedBox(height: 14),
                        const SizedBox(height: 18),

                        // Plan cards
                        if (monthly != null)
                          _PlanCard(
                            title: 'Monthly',
                            price: _resolvePrice(monthly),
                            period: '/month',
                            badge: _hasFreeTrial(monthly) ? '7 days free' : null,
                            isSelected: _selectedPlan == 0,
                            onTap: () => setState(() => _selectedPlan = 0),
                          ),
                        const SizedBox(height: 12),
                        if (annual != null)
                          _PlanCard(
                            title: 'Annual',
                            price: _resolvePrice(annual),
                            period: '/year',
                            badge: _hasFreeTrial(annual) ? '7 days free' : null,
                            isSelected: _selectedPlan == 1,
                            onTap: () => setState(() => _selectedPlan = 1),
                          ),

                        if (monthly == null && annual == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'Subscriptions are loading...',
                              style: GoogleFonts.sourceSans3(color: AweColors.textSecondary),
                            ),
                          ),

                        const SizedBox(height: 28),

                        // Subscribe button
                        GestureDetector(
                          onTap: _loading ? null : () => _onSubscribe(context),
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: _loading ? AweColors.accentSlate.withValues(alpha: 0.5) : AweColors.accentSlate,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : Text(
                                      _subscribeButtonLabel(
                                        _selectedPlan == 1 ? annual : monthly,
                                      ),
                                      style: GoogleFonts.sourceSans3(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Restore
                        GestureDetector(
                          onTap: () async {
                            await PremiumService().restorePurchases();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Checking for previous purchases...')),
                            );
                          },
                          child: Text(
                            'Restore purchases',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 14,
                              color: AweColors.textSecondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Legal links
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(context).pushNamed('/terms'),
                              child: Text(
                                'Terms',
                                style: GoogleFonts.sourceSans3(fontSize: 12, color: AweColors.textSecondary),
                              ),
                            ),
                            Text(' · ', style: TextStyle(color: AweColors.textSecondary)),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pushNamed('/privacy'),
                              child: Text(
                                'Privacy',
                                style: GoogleFonts.sourceSans3(fontSize: 12, color: AweColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Processing overlay — shown while verifying purchase with Play API
          if (_processing)
            Container(
              color: AweColors.background.withValues(alpha: 0.92),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AweColors.accentSlate,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Activating your plan…',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AweColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Just a moment',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 13,
                        color: AweColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _hasFreeTrial(ProductDetails product) {
    if (product is GooglePlayProductDetails) {
      final offers = product.productDetails.subscriptionOfferDetails;
      if (offers != null) {
        for (final offer in offers) {
          for (final phase in offer.pricingPhases) {
            if (phase.priceAmountMicros == 0) return true;
          }
        }
      }
    }
    return false;
  }

  String _subscribeButtonLabel(ProductDetails? product) {
    if (product != null && _hasFreeTrial(product)) return 'Start 7-Day Free Trial';
    return 'Subscribe Now';
  }

  String _resolvePrice(ProductDetails product) {
    if (product is GooglePlayProductDetails) {
      final offers = product.productDetails.subscriptionOfferDetails;
      if (offers != null) {
        for (final offer in offers) {
          final phases = offer.pricingPhases;
          // Last phase is always the recurring price after any trial
          for (final phase in phases.reversed) {
            if (phase.priceAmountMicros > 0) {
              return phase.formattedPrice;
            }
          }
        }
      }
    }
    return product.price;
  }

  Future<void> _onSubscribe(BuildContext context) async {
    final premium = PremiumService();
    final product = _selectedPlan == 1 ? premium.annualProduct : premium.monthlyProduct;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription not available. Please try again.')),
      );
      return;
    }

    setState(() => _loading = true);
    _watchPurchaseResult();
    try {
      await premium.purchaseSubscription(product);
    } catch (e) {
      _purchaseWatchSub?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AweColors.accentTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AweColors.accentTeal),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.sourceSans3(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AweColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AweColors.accentSlate : const Color(0xFFECE3D4),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AweColors.accentSlate.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AweColors.accentSlate : AweColors.navInactive,
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Title + price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AweColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$price$period',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 13,
                      color: AweColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Badge
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6F8C6A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: const Color(0xFF6F8C6A),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
