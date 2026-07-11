import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

const _kMonthlyId = 'awe_premium_monthly';
const _kAnnualId = 'awe_premium_annual';
const _kProductIds = {_kMonthlyId, _kAnnualId};

class PremiumService {
  PremiumService._();
  static final PremiumService _instance = PremiumService._();
  factory PremiumService() => _instance;

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final _premiumController = StreamController<bool>.broadcast();

  List<ProductDetails> _products = [];
  bool _isPremium = false;
  bool _initialized = false;
  String? _subscriptionType;
  // expiryDate = trial end date when isOnTrial=true, next renewal when false
  DateTime? _expiryDate;
  bool _isOnTrial = false;

  bool get isPremium => _isPremium;
  String? get subscriptionType => _subscriptionType;
  DateTime? get expiryDate => _expiryDate;
  bool get isOnTrial => _isOnTrial;
  List<ProductDetails> get products => _products;

  Stream<bool> get onPremiumActivated => _premiumController.stream;

  ProductDetails? get monthlyProduct =>
      _products.where((p) => p.id == _kMonthlyId).firstOrNull;
  ProductDetails? get annualProduct =>
      _products.where((p) => p.id == _kAnnualId).firstOrNull;

  /// Returns the real recurring price string (skips ₹0 trial phases).
  String? get subscriptionPriceFormatted {
    final product = _subscriptionType == 'annual' ? annualProduct : monthlyProduct;
    if (product == null) return null;
    if (product is GooglePlayProductDetails) {
      final offers = product.productDetails.subscriptionOfferDetails;
      if (offers != null) {
        for (final offer in offers) {
          for (final phase in offer.pricingPhases.reversed) {
            if (phase.priceAmountMicros > 0) return phase.formattedPrice;
          }
        }
      }
    }
    return product.price;
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('[Premium] initialize() — uid: ${_uid ?? "none"}');

    final available = await _iap.isAvailable();
    debugPrint('[Premium] Store available: $available');
    if (!available) {
      await _loadFromFirestore();
      return;
    }

    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) => debugPrint('[Premium] Purchase stream error: $e'),
    );

    await _loadProducts();
    await _loadFromFirestore();

    if (Platform.isAndroid) {
      await _syncWithPlay();
    }
  }

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(_kProductIds);
    if (response.error != null) {
      debugPrint('[Premium] Product query error: ${response.error}');
    }
    _products = response.productDetails;
    debugPrint('[Premium] Loaded ${_products.length} products');
  }

  Future<void> _loadFromFirestore() async {
    final uid = _uid;
    if (uid == null) {
      debugPrint('[Premium] _loadFromFirestore — no uid, skipping');
      return;
    }
    debugPrint('[Premium] _loadFromFirestore — reading users/$uid');

    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) {
        debugPrint('[Premium] _loadFromFirestore — user doc does not exist');
        return;
      }
      final data = doc.data()!;
      _isPremium = data['isPremium'] as bool? ?? false;
      _subscriptionType = data['subscriptionType'] as String?;
      _isOnTrial = data['isOnTrial'] as bool? ?? false;

      final expiry = data['subscriptionExpiry'];
      if (expiry is Timestamp) {
        // Always store as UTC internally; convert to local only when displaying.
        _expiryDate = expiry.toDate().toUtc();
      }

      debugPrint('[Premium] _loadFromFirestore — isPremium: $_isPremium, type: $_subscriptionType, isOnTrial: $_isOnTrial, expiry (UTC): $_expiryDate');

      // If expiry is past, mark as not premium locally but don't write to Firestore yet.
      // _syncWithPlay() is the authority — it will confirm revocation or refresh dates.
      if (_isPremium && _expiryDate != null && _expiryDate!.isBefore(DateTime.now().toUtc())) {
        debugPrint('[Premium] _loadFromFirestore — expiry in the past, flagging for Play sync');
        _isPremium = false;
      }
    } catch (e) {
      debugPrint('[Premium] _loadFromFirestore error: $e');
    }
    debugPrint('[Premium] _loadFromFirestore — final isPremium: $_isPremium');
  }

  Future<void> _syncWithPlay() async {
    debugPrint('[Premium] _syncWithPlay — querying Play for active subscriptions');
    try {
      final addition = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();

      debugPrint('[Premium] _syncWithPlay — ${response.pastPurchases.length} purchase(s) returned');
      for (final p in response.pastPurchases) {
        debugPrint('[Premium] _syncWithPlay — found: ${p.productID}, status: ${p.status}');
      }

      final activeSub = response.pastPurchases
          .where((p) => _kProductIds.contains(p.productID))
          .firstOrNull;

      if (activeSub != null) {
        _isPremium = true;
        final type = activeSub.productID == _kAnnualId ? 'annual' : 'monthly';
        _subscriptionType = type;

        // Refresh accurate dates from Play Developer API when:
        // - expiry is unknown, already past, or within 3 days (approaching renewal)
        final needsRefresh = _expiryDate == null ||
            _expiryDate!.isBefore(DateTime.now().toUtc().add(const Duration(days: 3)));
        if (needsRefresh) {
          debugPrint('[Premium] _syncWithPlay — expiry needs refresh, calling verifyPlaySubscription');
          await _verifyWithPlayApi(
            activeSub.productID,
            activeSub.verificationData.serverVerificationData,
          );
        } else {
          debugPrint('[Premium] _syncWithPlay — expiry still valid: $_expiryDate');
        }
      } else if (!_isPremium) {
        // Wasn't premium before and still no active sub — nothing to do
        debugPrint('[Premium] _syncWithPlay — no active sub, user is free tier');
      } else {
        // Was locally still considered premium but Play returned nothing — revoke
        debugPrint('[Premium] _syncWithPlay — Play returned nothing, revoking');
        _isPremium = false;
        _expiryDate = null;
        _subscriptionType = null;
        _isOnTrial = false;
        await _revokeFirestore();
      }
    } catch (e) {
      debugPrint('[Premium] _syncWithPlay error: $e');
    }
    debugPrint('[Premium] _syncWithPlay — done, isPremium: $_isPremium');
  }

  /// Calls the Cloud Function which in turn calls Play Developer API and writes
  /// accurate expiry + trial status to Firestore, then reloads.
  /// Returns true if the CF succeeded and dates were written.
  Future<bool> _verifyWithPlayApi(String productId, String purchaseToken) async {
    debugPrint('[Premium] _verifyWithPlayApi — productId: $productId');
    try {
      final fn = FirebaseFunctions.instance.httpsCallable(
        'verifyPlaySubscription',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await fn.call({'productId': productId, 'purchaseToken': purchaseToken});
      final data = result.data as Map;
      debugPrint('[Premium] _verifyWithPlayApi — response: $data');
      await _loadFromFirestore();
      _isPremium = true;
      return true;
    } catch (e) {
      debugPrint('[Premium] _verifyWithPlayApi error: $e');
      return false;
    }
  }

  /// Writes basic premium status to Firestore when Play API verification fails,
  /// so the user stays premium across restarts even without accurate dates.
  Future<void> _writeFallbackPremium(String purchaseToken) async {
    final uid = _uid;
    if (uid == null) return;
    debugPrint('[Premium] _writeFallbackPremium — uid: $uid');
    try {
      await _db.collection('users').doc(uid).set({
        'isPremium': true,
        'subscriptionType': _subscriptionType,
        'purchaseToken': purchaseToken,
        'isOnTrial': false,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Premium] _writeFallbackPremium error: $e');
    }
  }

  Future<void> purchaseSubscription(ProductDetails product) async {
    debugPrint('[Premium] purchaseSubscription — initiating: ${product.id}');
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    debugPrint('[Premium] restorePurchases — triggered by user');
    await _iap.restorePurchases();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    debugPrint('[Premium] purchaseStream — ${purchases.length} event(s)');
    for (final purchase in purchases) {
      debugPrint('[Premium] purchaseStream — id: ${purchase.productID}, status: ${purchase.status}');
      _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    debugPrint('[Premium] _handlePurchase — ${purchase.productID}, status: ${purchase.status}');

    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      final isValid = await _verifyPurchase(purchase);
      debugPrint('[Premium] _handlePurchase — verification result: $isValid');
      if (isValid) {
        _isPremium = true;
        _subscriptionType = purchase.productID == _kAnnualId ? 'annual' : 'monthly';
        debugPrint('[Premium] _handlePurchase — premium flag set, fetching accurate dates from Play API');

        final token = purchase.verificationData.serverVerificationData;
        final verified = await _verifyWithPlayApi(purchase.productID, token);
        if (!verified) {
          // CF failed — write basic premium to Firestore so it persists across restarts
          await _writeFallbackPremium(token);
        }

        _premiumController.add(true);
        debugPrint('[Premium] _handlePurchase — done. verified: $verified, isOnTrial: $_isOnTrial, expiry: $_expiryDate');
      }
    } else if (purchase.status == PurchaseStatus.pending) {
      debugPrint('[Premium] _handlePurchase — purchase pending');
    } else if (purchase.status == PurchaseStatus.canceled) {
      debugPrint('[Premium] _handlePurchase — purchase cancelled by user');
    } else if (purchase.status == PurchaseStatus.error) {
      debugPrint('[Premium] _handlePurchase — error: ${purchase.error?.message} (code: ${purchase.error?.code})');
    }

    if (purchase.pendingCompletePurchase) {
      debugPrint('[Premium] _handlePurchase — completing purchase with Play');
      await _iap.completePurchase(purchase);
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData;
    debugPrint('[Premium] _verifyPurchase — token present: ${token.isNotEmpty}');
    return token.isNotEmpty;
  }

  Future<void> _revokeFirestore() async {
    final uid = _uid;
    if (uid == null) return;
    debugPrint('[Premium] _revokeFirestore — uid: $uid');
    try {
      await _db.collection('users').doc(uid).set({
        'isPremium': false,
        'subscriptionType': null,
        'purchaseToken': null,
        'subscriptionExpiry': null,
        'isOnTrial': false,
      }, SetOptions(merge: true));
      debugPrint('[Premium] _revokeFirestore — done');
    } catch (e) {
      debugPrint('[Premium] _revokeFirestore error: $e');
    }
  }

  void dispose() {
    _purchaseSub?.cancel();
    _premiumController.close();
  }
}
