import '../../../core/money/money.dart';
import '../../../core/profile/health_profile.dart';
import '../domain/health_models.dart';

abstract interface class HealthRepository {
  Future<bool> hasSession();
  Future<void> login(String email, String password);
  Future<void> register(String name, String email, String password);
  Future<void> logout();

  Future<HealthProfile?> getProfile();
  Future<HealthProfile> saveProfile(HealthProfile profile);
  Future<PetIdentity?> getPet();

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
}
