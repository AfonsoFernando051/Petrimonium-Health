import 'package:flutter/foundation.dart';

import '../../../core/i18n/locale_controller.dart';
import '../../../core/money/money.dart';
import '../../../core/profile/health_profile.dart';
import '../data/health_repository.dart';
import '../domain/category_catalog.dart';
import '../domain/health_models.dart';
import '../domain/mentor_models.dart';
import '../domain/pet_species.dart';

enum AppStage { loading, signedOut, onboarding, home }

/// Which onboarding screen to show. There is no Pet yet on a brand-new
/// account; an account that already has a Pet from Academy/Wallet skips
/// straight to `quickSetup` (country/currency/locale) — see
/// `Petrimonium Health.dc.html`'s `screenIsPetSetup`/`screenIsQuickSetup`.
enum OnboardingStep { petSetup, quickSetup }

enum AuthMode { login, signup }

/// Screen stacked above the main tab scaffold (back-navigable), mirroring
/// the prototype's `subScreen`.
enum AppSubScreen { root, profile, regionalPreferences, addDebt, addIncome }

enum AppTab { home, transactions, accounts, mentor }

final class CurrencyLockedException implements Exception {
  const CurrencyLockedException();
}

final class HealthController extends ChangeNotifier {
  HealthController({
    required HealthRepository repository,
    required LocaleController localeController,
  }) : _repository = repository,
       _localeController = localeController;

  final HealthRepository _repository;
  final LocaleController _localeController;

  AppStage stage = AppStage.loading;
  AccountIdentity? account;
  HealthProfile? profile;
  PetIdentity? pet;
  MonthlySummary? summary;
  List<HealthAccount> accounts = const [];
  List<HealthTransaction> transactions = const [];
  List<HealthTransaction> plannedTransactions = const [];
  List<HealthRecurrence> recurrences = const [];
  List<HealthCard> cards = const [];
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool busy = false;
  bool refreshing = false;
  String? error;

  // --- Screen-flow state (mirrors the design prototype's Component.state) ---
  AuthMode authMode = AuthMode.login;
  AppSubScreen subScreen = AppSubScreen.root;
  AppTab tab = AppTab.home;
  bool notifOpen = false;
  bool insightDismissed = false;

  // --- Mentor chat ---
  List<ChatMessage> mentorMessages = const [];
  int? mentorConversationId;
  List<String> mentorSuggestions = const [];
  bool mentorBusy = false;
  String? mentorError;

  CurrencyCode get currency => profile?.primaryCurrency ?? CurrencyCode.brl;

  OnboardingStep get onboardingStep =>
      pet == null ? OnboardingStep.petSetup : OnboardingStep.quickSetup;

  /// Whether *this* onboarding pass started without a Pet — decided once,
  /// the moment `stage` first becomes `onboarding`, so the progress dots on
  /// `quickSetup` stay correct (2 steps) even after `createPet` makes `pet`
  /// non-null and `onboardingStep` flips.
  bool onboardingHadPetStep = false;

  int get onboardingTotalSteps => onboardingHadPetStep ? 2 : 1;

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
      stage = AppStage.signedOut;
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
    Future<PetIdentity?> loadPet() async {
      try {
        return await _repository.getPet();
      } catch (_) {
        return null;
      }
    }

    Future<AccountIdentity?> loadAccount() async {
      try {
        return await _repository.getCurrentUser();
      } catch (_) {
        return null;
      }
    }

    // These resources are independent. Loading them concurrently bounds a
    // stalled/offline startup to one HTTP timeout instead of three in a row.
    final results = await Future.wait<Object?>([
      loadPet(),
      loadAccount(),
      _repository.getProfile(),
    ]);
    pet = results[0] as PetIdentity?;
    account = results[1] as AccountIdentity?;
    final loadedProfile = results[2] as HealthProfile?;
    if (loadedProfile == null) {
      profile = null;
      onboardingHadPetStep = pet == null;
      stage = AppStage.onboarding;
      return;
    }
    profile = loadedProfile;
    await _localeController.setLocale(loadedProfile.interfaceLocale);
    stage = AppStage.home;
    await refreshData();
  }

  /// `POST /api/pets/configure` — shared identity endpoint, not Health-only.
  /// Advances `onboardingStep` to `quickSetup` as soon as `pet` is set.
  Future<void> createPet({
    required PetSpecies species,
    required String name,
  }) async {
    await _withBusy(() async {
      await _repository.configurePet(specie: species.apiValue, name: name);
      pet = PetIdentity(name: name, species: species.apiValue);
    });
  }

  Future<void> saveOnboarding(HealthProfile value) async {
    await _withBusy(() async {
      final saved = await _repository.saveProfile(value);
      profile = saved;
      await _localeController.setLocale(saved.interfaceLocale);
      stage = AppStage.home;
      await refreshData();
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
    account = null;
    profile = null;
    pet = null;
    summary = null;
    accounts = const [];
    transactions = const [];
    plannedTransactions = const [];
    recurrences = const [];
    cards = const [];
    error = null;
    stage = AppStage.signedOut;
    onboardingHadPetStep = false;
    authMode = AuthMode.login;
    subScreen = AppSubScreen.root;
    tab = AppTab.home;
    notifOpen = false;
    insightDismissed = false;
    mentorMessages = const [];
    mentorConversationId = null;
    notifyListeners();
  }

  Future<void> selectMonth(DateTime month) async {
    selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
    await refreshData();
  }

  Future<void> refreshData() async {
    final currentProfile = profile;
    if (currentProfile == null || refreshing) return;
    refreshing = true;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.getAccounts(),
        _repository.getTransactions(
          from: DateTime(selectedMonth.year, selectedMonth.month),
          to: DateTime(selectedMonth.year, selectedMonth.month + 1, 0),
        ),
        _repository.getCards(),
        _repository.getSummary(selectedMonth),
        _repository.getTransactions(status: TransactionStatus.planned),
        _repository.getRecurrences(),
      ]);
      accounts = results[0] as List<HealthAccount>;
      transactions = results[1] as List<HealthTransaction>;
      cards = results[2] as List<HealthCard>;
      summary = results[3] as MonthlySummary;
      plannedTransactions = results[4] as List<HealthTransaction>;
      recurrences = results[5] as List<HealthRecurrence>;
      _ensureCurrency(summary!.currency);
      for (final account in accounts) {
        _ensureCurrency(account.currency);
      }
      error = null;
    } catch (exception) {
      error = exception.toString();
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  // --- Debts & income sources ------------------------------------------
  //
  // Health has no dedicated "debt"/"income source" resource in the shared
  // backend. Both are ordinary planned transactions — a debt is a planned
  // EXPENSE, an income source a planned INCOME — namespaced under
  // `DebtCategory`/`IncomeCategory` (see category_catalog.dart) so the Home
  // screen can single them out. Recurring ones live as `HealthRecurrence`
  // templates; one-off ones as planned transactions with no recurrence link.

  List<HealthRecurrence> get debtRecurrences => recurrences
      .where(
        (r) =>
            r.active &&
            r.type == TransactionType.expense &&
            DebtCategory.fromApiCategory(r.category) != null,
      )
      .toList(growable: false);

  List<HealthTransaction> get oneOffDebts => plannedTransactions
      .where(
        (t) =>
            t.type == TransactionType.expense &&
            DebtCategory.fromApiCategory(t.category) != null,
      )
      .toList(growable: false);

  List<HealthRecurrence> get incomeRecurrences => recurrences
      .where(
        (r) =>
            r.active &&
            r.type == TransactionType.income &&
            IncomeCategory.fromApiCategory(r.category) != null,
      )
      .toList(growable: false);

  List<HealthTransaction> get oneOffIncomes => plannedTransactions
      .where(
        (t) =>
            t.type == TransactionType.income &&
            IncomeCategory.fromApiCategory(t.category) != null,
      )
      .toList(growable: false);

  Future<void> addDebt({
    required DebtCategory category,
    required String name,
    required Money value,
    required bool recurring,
  }) async {
    await _withBusy(() async {
      final accountId = await _ensureDefaultAccount();
      final now = DateTime.now();
      if (recurring) {
        await _repository.createRecurrence(
          accountId: accountId,
          type: TransactionType.expense,
          amount: value,
          description: name,
          category: category.apiCategory,
          dayOfMonth: now.day,
          startDate: now,
        );
      } else {
        await _repository.createTransaction(
          accountId: accountId,
          type: TransactionType.expense,
          status: TransactionStatus.planned,
          amount: value,
          description: name,
          category: category.apiCategory,
          date: now,
        );
      }
    });
    await refreshData();
  }

  Future<void> addIncome({
    required IncomeCategory category,
    required String name,
    required Money value,
    required bool recurring,
  }) async {
    await _withBusy(() async {
      final accountId = await _ensureDefaultAccount();
      final now = DateTime.now();
      if (recurring) {
        await _repository.createRecurrence(
          accountId: accountId,
          type: TransactionType.income,
          amount: value,
          description: name,
          category: category.apiCategory,
          dayOfMonth: now.day,
          startDate: now,
        );
      } else {
        await _repository.createTransaction(
          accountId: accountId,
          type: TransactionType.income,
          status: TransactionStatus.planned,
          amount: value,
          description: name,
          category: category.apiCategory,
          date: now,
        );
      }
    });
    await refreshData();
  }

  /// Returns the id of an account to attach manual entries to, creating a
  /// single default one the first time it is needed — the design never
  /// surfaces account selection for debts/income, so this stays invisible.
  Future<int> _ensureDefaultAccount() async {
    if (accounts.isNotEmpty) return accounts.first.id;
    final created = await _repository.createAccount(
      name: 'Conta principal',
      type: AccountType.checking,
      initialBalance: Money.zero(currency),
      balanceReferenceDate: DateTime.now(),
    );
    accounts = [created];
    return created.id;
  }

  Future<void> createAccount({
    required String name,
    required AccountType type,
    required Money initialBalance,
    required DateTime referenceDate,
  }) async {
    _ensureCurrency(initialBalance.currency);
    await _withBusy(
      () => _repository.createAccount(
        name: name,
        type: type,
        initialBalance: initialBalance,
        balanceReferenceDate: referenceDate,
      ),
    );
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

  Future<void> deleteRecurrence(int id) async {
    await _withBusy(() => _repository.deleteRecurrence(id));
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
    await _withBusy(
      () => _repository.createTransfer(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        date: date,
        description: description,
      ),
    );
    await refreshData();
  }

  Future<void> createCard({
    required String name,
    required int closingDay,
    required int dueDay,
  }) async {
    await _withBusy(
      () => _repository.createCard(
        name: name,
        currency: currency,
        closingDay: closingDay,
        dueDay: dueDay,
      ),
    );
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
    await _withBusy(
      () => _repository.createCardPurchase(
        cardId: cardId,
        amount: amount,
        description: description,
        category: category,
        purchaseDate: purchaseDate,
        installmentCount: installmentCount,
      ),
    );
    await refreshData();
  }

  Future<List<CardInvoice>> getInvoices(int cardId) =>
      _repository.getInvoices(cardId);

  Future<void> payInvoice({
    required int invoiceId,
    required int accountId,
    required DateTime paymentDate,
  }) async {
    await _withBusy(
      () => _repository.payInvoice(
        invoiceId: invoiceId,
        accountId: accountId,
        currency: currency,
        paymentDate: paymentDate,
      ),
    );
    await refreshData();
  }

  // --- Screen-flow navigation -------------------------------------------

  void setAuthMode(AuthMode mode) {
    authMode = mode;
    notifyListeners();
  }

  void openProfile() {
    subScreen = AppSubScreen.profile;
    notifyListeners();
  }

  void openRegionalPreferences() {
    subScreen = AppSubScreen.regionalPreferences;
    notifyListeners();
  }

  void openAddDebt() {
    subScreen = AppSubScreen.addDebt;
    notifyListeners();
  }

  void openAddIncome() {
    subScreen = AppSubScreen.addIncome;
    notifyListeners();
  }

  void closeSubScreen() {
    subScreen = AppSubScreen.root;
    notifyListeners();
  }

  void selectTab(AppTab value) {
    tab = value;
    notifOpen = false;
    notifyListeners();
  }

  void toggleNotif() {
    notifOpen = !notifOpen;
    notifyListeners();
  }

  void dismissInsight() {
    insightDismissed = true;
    notifyListeners();
  }

  // --- Mentor chat --------------------------------------------------------

  Future<void> loadMentorSuggestions() async {
    try {
      final language = _localeController.current.tag.split('-').first;
      mentorSuggestions = await _repository.getMentorSuggestions(
        language: language,
      );
    } catch (_) {
      mentorSuggestions = const [];
    }
    notifyListeners();
  }

  void startNewMentorConversation() {
    mentorConversationId = null;
    mentorMessages = const [];
    mentorError = null;
    notifyListeners();
  }

  Future<void> sendMentorMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || mentorBusy) return;
    final userMessage = ChatMessage(
      id: 'u-${DateTime.now().microsecondsSinceEpoch}',
      author: ChatAuthor.user,
      text: trimmed,
    );
    mentorMessages = [...mentorMessages, userMessage];
    mentorBusy = true;
    mentorError = null;
    notifyListeners();
    try {
      final reply = await _repository.sendMentorMessage(
        message: trimmed,
        conversationId: mentorConversationId,
      );
      mentorConversationId = reply.conversationId;
      mentorMessages = [
        ...mentorMessages,
        ChatMessage(
          id: 'm-${DateTime.now().microsecondsSinceEpoch}',
          author: ChatAuthor.mentor,
          text: reply.reply,
          sources: reply.sources,
        ),
      ];
    } catch (exception) {
      mentorError = exception.toString();
    } finally {
      mentorBusy = false;
      notifyListeners();
    }
  }

  void toggleMessageWhy(String messageId) {
    for (final message in mentorMessages) {
      if (message.id == messageId) {
        message.whyOpen = !message.whyOpen;
        break;
      }
    }
    notifyListeners();
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
