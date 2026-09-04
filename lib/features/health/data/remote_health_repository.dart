import 'dart:convert';
import 'dart:math';

import '../../../core/config/api_config.dart';
import '../../../core/money/money.dart';
import '../../../core/network/api_client.dart';
import '../../../core/profile/health_profile.dart';
import '../domain/health_models.dart';
import '../domain/mentor_models.dart';
import 'health_repository.dart';

final class RemoteHealthRepository implements HealthRepository {
  RemoteHealthRepository(this._api);

  final ApiClient _api;
  static int _sequence = 0;

  String _idempotencyKey() {
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    return 'health-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}-$random';
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _object(
    Future<dynamic> Function() request, {
    Set<int> success = const {200},
  }) async {
    final response = await request();
    if (!success.contains(response.statusCode)) throwApiError(response);
    return decodeObject(response);
  }

  @override
  Future<bool> hasSession() => _api.hasSession();

  @override
  Future<void> login(String email, String password) async {
    final response = await _api.unauthenticatedPost('/auth/login', {
      'email': email,
      'password': password,
      'appContext': ApiConfig.appContext,
    });
    if (response.statusCode != 200 && response.statusCode != 201) {
      throwApiError(response);
    }
    final json = decodeObject(response);
    await _api.tokenStore.saveTokens(
      json['accessToken'] as String,
      json['refreshToken'] as String,
    );
  }

  @override
  Future<void> register(String name, String email, String password) async {
    final response = await _api.unauthenticatedPost('/auth/register', {
      'username': name,
      'email': email,
      'password': password,
    });
    if (response.statusCode != 200 && response.statusCode != 201) {
      throwApiError(response);
    }
    await login(email, password);
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _api.tokenStore.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _api.post('/auth/logout', {'refreshToken': refreshToken});
      } catch (_) {
        // Local logout must remain possible while offline.
      }
    }
    await _api.tokenStore.clear();
  }

  @override
  Future<HealthProfile?> getProfile() async {
    final response = await _api.get('${ApiConfig.healthBase}/profile');
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throwApiError(response);
    return HealthProfile.fromJson(decodeObject(response));
  }

  @override
  Future<HealthProfile> saveProfile(HealthProfile profile) async =>
      HealthProfile.fromJson(await _object(
        () => _api.put('${ApiConfig.healthBase}/profile', profile.toJson()),
      ));

  @override
  Future<PetIdentity?> getPet() async {
    final response = await _api.get('/api/pets/my-pet');
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throwApiError(response);
    return PetIdentity.fromJson(decodeObject(response));
  }

  @override
  Future<AccountIdentity?> getCurrentUser() async {
    final response = await _api.get('/api/users/me');
    if (response.statusCode == 401 || response.statusCode == 404) return null;
    if (response.statusCode != 200) throwApiError(response);
    return AccountIdentity.fromJson(decodeObject(response));
  }

  @override
  Future<void> configurePet({required String specie, required String name}) async {
    final response = await _api.post('/api/pets/configure', {
      'specie': specie,
      'name': name,
    });
    if (response.statusCode != 200 && response.statusCode != 201) {
      throwApiError(response);
    }
  }

  @override
  Future<MonthlySummary> getSummary(DateTime month) async {
    final key = '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    final response = await _api.get('${ApiConfig.healthBase}/summary?month=$key');
    if (response.statusCode != 200) throwApiError(response);
    return MonthlySummary.fromJson(decodeObject(response));
  }

  @override
  Future<List<HealthAccount>> getAccounts() async {
    final response = await _api.get('${ApiConfig.healthBase}/accounts');
    if (response.statusCode != 200) throwApiError(response);
    return decodeList(response).map(HealthAccount.fromJson).toList(growable: false);
  }

  @override
  Future<HealthAccount> createAccount({
    required String name,
    required AccountType type,
    required Money initialBalance,
    required DateTime balanceReferenceDate,
  }) async =>
      HealthAccount.fromJson(await _object(
        () => _api.post('${ApiConfig.healthBase}/accounts', {
          'name': name,
          'type': type.apiValue,
          'initialBalance': initialBalance.toDecimalString(),
          'balanceReferenceDate': _isoDate(balanceReferenceDate),
          'currency': initialBalance.currency.code,
          'idempotencyKey': _idempotencyKey(),
        }),
        success: const {200, 201},
      ));

  @override
  Future<HealthAccount> updateAccount(HealthAccount account) async =>
      HealthAccount.fromJson(await _object(
        () => _api.put('${ApiConfig.healthBase}/accounts/${account.id}', {
          'name': account.name,
          'type': account.type.apiValue,
          'initialBalance': account.initialBalance.toDecimalString(),
          'balanceReferenceDate': _isoDate(account.balanceReferenceDate),
          'currency': account.currency.code,
        }),
      ));

  @override
  Future<void> archiveAccount(int id) async {
    final response = await _api.delete('${ApiConfig.healthBase}/accounts/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throwApiError(response);
    }
  }

  @override
  Future<List<HealthTransaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    int? accountId,
    String? category,
    TransactionStatus? status,
  }) async {
    final query = <String, String>{
      if (from != null) 'from': _isoDate(from),
      if (to != null) 'to': _isoDate(to),
      if (accountId != null) 'accountId': '$accountId',
      if (category != null && category.isNotEmpty) 'category': category,
      if (status != null) 'status': status.apiValue,
    };
    final uri = Uri(
      path: '${ApiConfig.healthBase}/transactions',
      queryParameters: query.isEmpty ? null : query,
    );
    final response = await _api.get(uri.toString());
    if (response.statusCode != 200) throwApiError(response);
    return decodeList(response)
        .map(HealthTransaction.fromJson)
        .toList(growable: false);
  }

  Map<String, dynamic> _transactionBody(HealthTransaction transaction) => {
        'accountId': transaction.accountId,
        'type': transaction.type.apiValue,
        'status': transaction.status.apiValue,
        'amount': transaction.amount.toDecimalString(),
        'currency': transaction.amount.currency.code,
        'description': transaction.description,
        'category': transaction.category,
        'date': _isoDate(transaction.date),
      };

  @override
  Future<HealthTransaction> createTransaction({
    required int accountId,
    required TransactionType type,
    required TransactionStatus status,
    required Money amount,
    required String description,
    required String category,
    required DateTime date,
  }) async =>
      HealthTransaction.fromJson(await _object(
        () => _api.post('${ApiConfig.healthBase}/transactions', {
          'accountId': accountId,
          'type': type.apiValue,
          'status': status.apiValue,
          'amount': amount.toDecimalString(),
          'currency': amount.currency.code,
          'description': description,
          'category': category,
          'date': _isoDate(date),
          'idempotencyKey': _idempotencyKey(),
        }),
        success: const {200, 201},
      ));

  @override
  Future<HealthTransaction> updateTransaction(
    HealthTransaction transaction,
  ) async =>
      HealthTransaction.fromJson(await _object(
        () => _api.put(
          '${ApiConfig.healthBase}/transactions/${transaction.id}',
          _transactionBody(transaction),
        ),
      ));

  @override
  Future<void> deleteTransaction(int id) async {
    final response = await _api.delete('${ApiConfig.healthBase}/transactions/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throwApiError(response);
    }
  }

  @override
  Future<HealthTransaction> confirmTransaction(int id) async =>
      HealthTransaction.fromJson(await _object(
        () => _api.post(
          '${ApiConfig.healthBase}/transactions/$id/confirm',
          const <String, dynamic>{},
        ),
      ));

  @override
  Future<void> createTransfer({
    required int fromAccountId,
    required int toAccountId,
    required Money amount,
    required DateTime date,
    required String description,
  }) async {
    await _object(
      () => _api.post('${ApiConfig.healthBase}/transfers', {
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'amount': amount.toDecimalString(),
        'currency': amount.currency.code,
        'date': _isoDate(date),
        'description': description,
        'idempotencyKey': _idempotencyKey(),
      }),
      success: const {200, 201},
    );
  }

  @override
  Future<void> createRecurrence({
    required int accountId,
    required TransactionType type,
    required Money amount,
    required String description,
    required String category,
    required int dayOfMonth,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final response = await _api.post('${ApiConfig.healthBase}/recurrences', {
      'accountId': accountId,
      'type': type.apiValue,
      'amount': amount.toDecimalString(),
      'currency': amount.currency.code,
      'description': description,
      'category': category,
      'dayOfMonth': dayOfMonth,
      'startDate': _isoDate(startDate),
      if (endDate != null) 'endDate': _isoDate(endDate),
      'idempotencyKey': _idempotencyKey(),
    });
    if (response.statusCode != 200 && response.statusCode != 201) {
      throwApiError(response);
    }
  }

  @override
  Future<List<HealthRecurrence>> getRecurrences() async {
    final response = await _api.get('${ApiConfig.healthBase}/recurrences');
    if (response.statusCode != 200) throwApiError(response);
    return decodeList(response)
        .map(HealthRecurrence.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> deleteRecurrence(int id) async {
    final response = await _api.delete('${ApiConfig.healthBase}/recurrences/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throwApiError(response);
    }
  }

  @override
  Future<List<HealthCard>> getCards() async {
    final response = await _api.get('${ApiConfig.healthBase}/cards');
    if (response.statusCode != 200) throwApiError(response);
    return decodeList(response).map(HealthCard.fromJson).toList(growable: false);
  }

  @override
  Future<HealthCard> createCard({
    required String name,
    required CurrencyCode currency,
    required int closingDay,
    required int dueDay,
  }) async =>
      HealthCard.fromJson(await _object(
        () => _api.post('${ApiConfig.healthBase}/cards', {
          'name': name,
          'currency': currency.code,
          'closingDay': closingDay,
          'dueDay': dueDay,
          'idempotencyKey': _idempotencyKey(),
        }),
        success: const {200, 201},
      ));

  @override
  Future<HealthCard> updateCard(HealthCard card) async =>
      HealthCard.fromJson(await _object(
        () => _api.put('${ApiConfig.healthBase}/cards/${card.id}', {
          'name': card.name,
          'currency': card.currency.code,
          'closingDay': card.closingDay,
          'dueDay': card.dueDay,
        }),
      ));

  @override
  Future<void> archiveCard(int id) async {
    final response = await _api.delete('${ApiConfig.healthBase}/cards/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throwApiError(response);
    }
  }

  @override
  Future<void> createCardPurchase({
    required int cardId,
    required Money amount,
    required String description,
    required String category,
    required DateTime purchaseDate,
    required int installmentCount,
  }) async {
    final response = await _api.post(
      '${ApiConfig.healthBase}/cards/$cardId/purchases',
      {
        'amount': amount.toDecimalString(),
        'currency': amount.currency.code,
        'description': description,
        'category': category,
        'purchaseDate': _isoDate(purchaseDate),
        'installmentCount': installmentCount,
        'idempotencyKey': _idempotencyKey(),
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throwApiError(response);
    }
  }

  @override
  Future<List<CardInvoice>> getInvoices(int cardId) async {
    final response =
        await _api.get('${ApiConfig.healthBase}/cards/$cardId/invoices');
    if (response.statusCode != 200) throwApiError(response);
    return decodeList(response).map(CardInvoice.fromJson).toList(growable: false);
  }

  @override
  Future<void> payInvoice({
    required int invoiceId,
    required int accountId,
    required CurrencyCode currency,
    required DateTime paymentDate,
  }) async {
    final response = await _api.post(
      '${ApiConfig.healthBase}/cards/invoices/$invoiceId/pay',
      {
        'accountId': accountId,
        'currency': currency.code,
        'paymentDate': _isoDate(paymentDate),
        'idempotencyKey': _idempotencyKey(),
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throwApiError(response);
    }
  }

  @override
  Future<List<String>> getMentorSuggestions({
    String language = 'pt',
    int limit = 5,
  }) async {
    final uri = Uri(
      path: '/api/mentor/suggestions',
      queryParameters: {'language': language, 'limit': '$limit'},
    );
    final response = await _api.get(uri.toString());
    if (response.statusCode != 200) throwApiError(response);
    final json = decodeObject(response);
    return ((json['suggestions'] as List?) ?? const [])
        .map((item) => item.toString())
        .toList(growable: false);
  }

  @override
  Future<MentorReply> sendMentorMessage({
    required String message,
    int? conversationId,
  }) async =>
      MentorReply.fromJson(await _object(
        () => _api.post('/api/mentor/chat', {
          'message': message,
          if (conversationId != null) 'conversationId': conversationId,
          'context': {
            'currentScreen': 'health_home',
            'language': 'pt',
          },
        }),
      ));
}
