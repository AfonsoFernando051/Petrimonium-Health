import '../../../core/money/money.dart';
import '../../../core/profile/health_profile.dart';
import '../domain/health_models.dart';
import '../domain/mentor_models.dart';

abstract interface class HealthRepository {
  Future<bool> hasSession();
  Future<void> login(String email, String password);
  Future<void> register(String name, String email, String password);
  Future<void> logout();

  /// `GET /api/users/me` — shared identity endpoint, used only for display.
  Future<AccountIdentity?> getCurrentUser();

  Future<HealthProfile?> getProfile();
  Future<HealthProfile> saveProfile(HealthProfile profile);
  Future<PetIdentity?> getPet();

  /// `POST /api/pets/configure` — shared with Academy/Wallet. Creates the
  /// account's single Petrimonium Pet, or re-labels it if one already
  /// exists. `specie` is a `PetSpecieEnum` value (e.g. `FOX`).
  Future<void> configurePet({required String specie, required String name});

  Future<MonthlySummary> getSummary(DateTime month);
  Future<List<HealthAccount>> getAccounts();
  Future<HealthAccount> createAccount({
    required String name,
    required AccountType type,
    required Money initialBalance,
    required DateTime balanceReferenceDate,
  });
  Future<HealthAccount> updateAccount(HealthAccount account);
  Future<void> archiveAccount(int id);

  Future<List<HealthTransaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    int? accountId,
    String? category,
    TransactionStatus? status,
  });
  Future<HealthTransaction> createTransaction({
    required int accountId,
    required TransactionType type,
    required TransactionStatus status,
    required Money amount,
    required String description,
    required String category,
    required DateTime date,
  });
  Future<HealthTransaction> updateTransaction(HealthTransaction transaction);
  Future<void> deleteTransaction(int id);
  Future<HealthTransaction> confirmTransaction(int id);
  Future<void> createTransfer({
    required int fromAccountId,
    required int toAccountId,
    required Money amount,
    required DateTime date,
    required String description,
  });
  Future<void> createRecurrence({
    required int accountId,
    required TransactionType type,
    required Money amount,
    required String description,
    required String category,
    required int dayOfMonth,
    required DateTime startDate,
    DateTime? endDate,
  });
  Future<List<HealthRecurrence>> getRecurrences();
  Future<HealthRecurrence> updateRecurrence(HealthRecurrence recurrence);
  Future<void> deleteRecurrence(int id);

  Future<List<HealthCard>> getCards();
  Future<HealthCard> createCard({
    required String name,
    required CurrencyCode currency,
    required int closingDay,
    required int dueDay,
  });
  Future<HealthCard> updateCard(HealthCard card);
  Future<void> archiveCard(int id);
  Future<void> createCardPurchase({
    required int cardId,
    required Money amount,
    required String description,
    required String category,
    required DateTime purchaseDate,
    required int installmentCount,
  });
  Future<List<CardInvoice>> getInvoices(int cardId);
  Future<void> payInvoice({
    required int invoiceId,
    required int accountId,
    required CurrencyCode currency,
    required DateTime paymentDate,
  });

  /// `GET /api/mentor/suggestions` — shared Mentor endpoint. Suggested
  /// conversation-starter prompts for the empty chat state.
  Future<List<String>> getMentorSuggestions({
    String language = 'pt',
    int limit = 5,
  });

  /// `POST /api/mentor/chat` — shared Mentor endpoint. Free-form question;
  /// `conversationId` continues an existing thread, or starts a new one when
  /// null.
  Future<MentorReply> sendMentorMessage({
    required String message,
    int? conversationId,
  });
}
