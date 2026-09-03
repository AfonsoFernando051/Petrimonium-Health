import 'package:flutter/foundation.dart';

import '../../../core/i18n/locale_controller.dart';
import '../../../core/money/money.dart';
import '../../../core/network/api_client.dart';
import '../../../core/profile/health_profile.dart';
import '../data/health_repository.dart';
import '../domain/health_models.dart';

enum AppStage { loading, signedOut, onboarding, home }

final class CurrencyLockedException implements Exception {
  const CurrencyLockedException();
}

final class HealthController extends ChangeNotifier {
  HealthController({
    required HealthRepository repository,
    required LocaleController localeController,
  })  : _repository = repository,
        _localeController = localeController;

  final HealthRepository _repository;
  final LocaleController _localeController;

  AppStage stage = AppStage.loading;
  HealthProfile? profile;
  PetIdentity? pet;
  MonthlySummary? summary;
  List<HealthAccount> accounts = const [];
  List<HealthTransaction> transactions = const [];
  List<HealthCard> cards = const [];
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool busy = false;
  String? error;

  CurrencyCode get currency =>
      profile?.primaryCurrency ?? CurrencyCode.brl;

  Future<void> restore() async {
    stage = AppStage.loading;
    notifyListeners();
    try {
      if (!await _repository.hasSession()) {
        stage = AppStage.signedOut;
        return;
      }
      await _loadAuthenticatedState();
    } catch (exception) {
      error = exception.toString();
      stage = exception is ApiException && exception.statusCode == 401
          ? AppStage.signedOut
          : AppStage.signedOut;
    } finally {
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    await _withBusy(() async {
      await _repository.login(email, password);
      await _loadAuthenticatedState();
    });
  }

  Future<void> register(String name, String email, String password) async {
    await _withBusy(() async {
      await _repository.register(name, email, password);
      await _loadAuthenticatedState();
    });
  }

  Future<void> _loadAuthenticatedState() async {
    final loadedProfile = await _repository.getProfile();
    if (loadedProfile == null) {
      profile = null;
      stage = AppStage.onboarding;
      return;
    }
    profile = loadedProfile;
    await _localeController.setLocale(loadedProfile.interfaceLocale);
    stage = AppStage.home;
    await refreshData();
    try {
      pet = await _repository.getPet();
    } catch (_) {
      pet = null;
    }
  }

  Future<void> saveOnboarding(HealthProfile value) async {
    await _withBusy(() async {
      final saved = await _repository.saveProfile(value);
      profile = saved;
      await _localeController.setLocale(saved.interfaceLocale);
      stage = AppStage.home;
      await refreshData();
      try {
        pet = await _repository.getPet();
      } catch (_) {
        pet = null;
      }
    });
  }

  Future<void> updateProfile(HealthProfile value) async {
    final existing = profile;
    if (existing != null &&
        existing.primaryCurrency != value.primaryCurrency &&
        !existing.currencyChangeAllowed) {
      throw const CurrencyLockedException();
    }
    await _withBusy(() async {
      final saved = await _repository.saveProfile(value);
      profile = saved;
      await _localeController.setLocale(saved.interfaceLocale);
    });
  }

  Future<void> logout() async {
    await _repository.logout();
    profile = null;
    pet = null;
    summary = null;
    accounts = const [];
    transactions = const [];
    cards = const [];
    error = null;
    stage = AppStage.signedOut;
    notifyListeners();
  }

  Future<void> selectMonth(DateTime month) async {
    selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
    await refreshData();
  }

  Future<void> refreshData() async {
    final currentProfile = profile;
    if (currentProfile == null) return;
    try {
      final results = await Future.wait<Object>([
        _repository.getAccounts(),
        _repository.getTransactions(
          from: DateTime(selectedMonth.year, selectedMonth.month),
          to: DateTime(selectedMonth.year, selectedMonth.month + 1, 0),
        ),
        _repository.getCards(),
        _repository.getSummary(selectedMonth),
      ]);
      accounts = results[0] as List<HealthAccount>;
      transactions = results[1] as List<HealthTransaction>;
      cards = results[2] as List<HealthCard>;
      summary = results[3] as MonthlySummary;
      _ensureCurrency(summary!.currency);
      for (final account in accounts) {
        _ensureCurrency(account.currency);
      }
      for (final transaction in transactions) {
        _ensureCurrency(transaction.amount.currency);
      }
      for (final card in cards) {
        _ensureCurrency(card.currency);
      }
      error = null;
    } catch (exception) {
      error = exception.toString();
    }
    notifyListeners();
  }

  Future<void> createAccount({
    required String name,
    required AccountType type,
    required Money initialBalance,
    required DateTime referenceDate,
  }) async {
    _ensureCurrency(initialBalance.currency);
    await _withBusy(() => _repository.createAccount(
          name: name,
          type: type,
          initialBalance: initialBalance,
          balanceReferenceDate: referenceDate,
        ));
    await refreshData();
  }

  Future<void> updateAccount(HealthAccount account) async {
    _ensureCurrency(account.currency);
    await _withBusy(() => _repository.updateAccount(account));
    await refreshData();
  }

  Future<void> archiveAccount(int id) async {
    await _withBusy(() => _repository.archiveAccount(id));
    await refreshData();
  }

  Future<void> createTransaction({
    required int accountId,
    required TransactionType type,
    required TransactionStatus status,
    required Money amount,
    required String description,
    required String category,
    required DateTime date,
    bool recurring = false,
  }) async {
    _ensureCurrency(amount.currency);
    await _withBusy(() async {
      if (recurring) {
        await _repository.createRecurrence(
          accountId: accountId,
          type: type,
          amount: amount,
          description: description,
          category: category,
          dayOfMonth: date.day,
          startDate: date,
        );
      } else {
        await _repository.createTransaction(
          accountId: accountId,
          type: type,
          status: status,
          amount: amount,
          description: description,
          category: category,
          date: date,
        );
      }
    });
    await refreshData();
  }

  Future<void> updateTransaction(HealthTransaction transaction) async {
    _ensureCurrency(transaction.amount.currency);
    await _withBusy(() => _repository.updateTransaction(transaction));
    await refreshData();
  }

  Future<void> deleteTransaction(int id) async {
    await _withBusy(() => _repository.deleteTransaction(id));
    await refreshData();
  }

  Future<void> confirmTransaction(int id) async {
    await _withBusy(() => _repository.confirmTransaction(id));
    await refreshData();
  }

  Future<void> transfer({
    required int fromAccountId,
    required int toAccountId,
    required Money amount,
    required DateTime date,
    required String description,
  }) async {
    _ensureCurrency(amount.currency);
    await _withBusy(() => _repository.createTransfer(
          fromAccountId: fromAccountId,
          toAccountId: toAccountId,
          amount: amount,
          date: date,
          description: description,
        ));
    await refreshData();
  }

  Future<void> createCard({
    required String name,
    required int closingDay,
    required int dueDay,
  }) async {
    await _withBusy(() => _repository.createCard(
          name: name,
          currency: currency,
          closingDay: closingDay,
          dueDay: dueDay,
        ));
    await refreshData();
  }

  Future<void> updateCard(HealthCard card) async {
    _ensureCurrency(card.currency);
    await _withBusy(() => _repository.updateCard(card));
    await refreshData();
  }

  Future<void> archiveCard(int id) async {
    await _withBusy(() => _repository.archiveCard(id));
    await refreshData();
  }

  Future<void> createCardPurchase({
    required int cardId,
    required Money amount,
    required String description,
    required String category,
    required DateTime purchaseDate,
    required int installmentCount,
  }) async {
    _ensureCurrency(amount.currency);
    await _withBusy(() => _repository.createCardPurchase(
          cardId: cardId,
          amount: amount,
          description: description,
          category: category,
          purchaseDate: purchaseDate,
          installmentCount: installmentCount,
        ));
    await refreshData();
  }

  Future<List<CardInvoice>> getInvoices(int cardId) =>
      _repository.getInvoices(cardId);

  Future<void> payInvoice({
    required int invoiceId,
    required int accountId,
    required DateTime paymentDate,
  }) async {
    await _withBusy(() => _repository.payInvoice(
          invoiceId: invoiceId,
          accountId: accountId,
          currency: currency,
          paymentDate: paymentDate,
        ));
    await refreshData();
  }

  void _ensureCurrency(CurrencyCode actual) {
    if (actual != currency) {
      throw CurrencyMismatchException(currency, actual);
    }
  }

  Future<void> _withBusy(Future<void> Function() operation) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await operation();
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
