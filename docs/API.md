# API do Petrimonium Health

Contrato HTTP inicial entre o aplicativo Flutter e o backend compartilhado. O documento descreve as invariantes públicas; consulte os controllers e DTOs da versão em execução para a lista final de campos opcionais.

## Convenções

- Base local: `http://localhost:8081`.
- Base dos recursos Health: `/api/v1/health`.
- Conteúdo: `application/json`.
- Datas civis: ISO 8601 `YYYY-MM-DD`.
- Competências mensais: `YYYY-MM`.
- Valores monetários: strings decimais com duas casas, por exemplo `"1234.50"`.
- Moedas: códigos ISO `BRL` ou `EUR`; nunca símbolos.
- IDs são opacos para o cliente. A posse é sempre validada no backend.

Todo recurso financeiro devolvido inclui `currency`. Uma requisição que aceite dinheiro também informa `currency`; omitir o campo não autoriza o servidor a reinterpretar um valor existente.

## Autenticação e contexto

Cadastro usa a identidade compartilhada:

```http
POST /auth/register
```

Login do Health pede um token vinculado ao seu contexto:

```http
POST /auth/login
Content-Type: application/json

{
  "email": "ana@example.com",
  "password": "...",
  "appContext": "health"
}
```

O mesmo `appContext` é enviado em `/auth/google`. O access token resultante carrega `app_context=health`, e o refresh token preserva esse contexto sem aceitar substituição pelo cliente.

Todos os endpoints abaixo exigem:

```http
Authorization: Bearer <access-token>
```

Uma sessão Wallet ou Academy não pode acessar `/api/v1/health/**`. Pet e identidade continuam disponíveis pelas rotas compartilhadas existentes (`/api/pets/**` e `/api/users/**`).

## Preferências do perfil Health

```http
GET /api/v1/health/profile
PUT /api/v1/health/profile
```

Corpo de criação/atualização:

```json
{
  "countryCode": "PT",
  "primaryCurrency": "EUR",
  "localeTag": "pt-PT"
}
```

Valores aceitos:

| Campo | Valores |
|---|---|
| `countryCode` | `BR`, `PT` |
| `primaryCurrency` | `BRL`, `EUR` |
| `localeTag` | `pt-BR`, `pt-PT` |

Os campos são independentes. O servidor não troca moeda ou idioma por inferência de IP, GPS ou locale do dispositivo.

## Contas

```http
GET    /api/v1/health/accounts
POST   /api/v1/health/accounts
PUT    /api/v1/health/accounts/{accountId}
DELETE /api/v1/health/accounts/{accountId}
```

`DELETE` representa arquivamento quando esse for o contrato do controller; dados históricos não são apagados. O recurso inclui nome, saldo inicial, data de referência, saldo calculado, estado de arquivamento e moeda.

Exemplo de valor monetário enviado:

```json
{
  "name": "Conta à ordem",
  "initialBalance": "850.00",
  "balanceDate": "2026-09-01",
  "currency": "EUR"
}
```

## Lançamentos

```http
GET    /api/v1/health/transactions
POST   /api/v1/health/transactions
GET    /api/v1/health/transactions/{transactionId}
PUT    /api/v1/health/transactions/{transactionId}
DELETE /api/v1/health/transactions/{transactionId}
POST   /api/v1/health/transactions/{transactionId}/confirm
```

A listagem aceita filtros de período, conta, categoria e situação conforme definidos pelo controller. Tipos são `INCOME`/`EXPENSE`; situações são `PLANNED`/`REALIZED`. `confirm` altera o registro existente.

Exemplo:

```json
{
  "accountId": 10,
  "type": "EXPENSE",
  "status": "PLANNED",
  "amount": "42.90",
  "currency": "EUR",
  "description": "Eletricidade",
  "category": "HOUSING",
  "date": "2026-09-12"
}
```

## Transferências

```http
POST /api/v1/health/transfers
```

Exemplo:

```json
{
  "sourceAccountId": 10,
  "destinationAccountId": 11,
  "amount": "100.00",
  "currency": "EUR",
  "date": "2026-09-03"
}
```

A resposta representa uma transferência única; não devolve duas receitas/despesas independentes.

## Recorrências

```http
GET    /api/v1/health/recurrences
POST   /api/v1/health/recurrences
PUT    /api/v1/health/recurrences/{recurrenceId}
DELETE /api/v1/health/recurrences/{recurrenceId}
POST   /api/v1/health/recurrences/generate
```

A criação mensal informa tipo, conta, valor/moeda, categoria, dia de vencimento e data inicial. A geração recebe um período e é idempotente por recorrência e competência. Dias ausentes no mês são ajustados para o último dia.

## Cartões, compras e faturas

```http
GET    /api/v1/health/cards
POST   /api/v1/health/cards
PUT    /api/v1/health/cards/{cardId}
DELETE /api/v1/health/cards/{cardId}

POST   /api/v1/health/cards/{cardId}/purchases
GET    /api/v1/health/cards/{cardId}/invoices
GET    /api/v1/health/invoices/{invoiceId}
POST   /api/v1/health/invoices/{invoiceId}/pay
```

Compra parcelada informa valor total e quantidade de prestações. A resposta inclui as prestações geradas e sua associação a faturas; a soma deve ser exata.

Exemplo de compra:

```json
{
  "description": "Computador",
  "totalAmount": "999.99",
  "currency": "EUR",
  "purchaseDate": "2026-09-03",
  "installmentCount": 3,
  "category": "SHOPPING"
}
```

Pagamento de fatura referencia uma conta do mesmo usuário/moeda e não cria uma nova despesa:

```json
{
  "accountId": 10,
  "paymentDate": "2026-10-05",
  "currency": "EUR"
}
```

## Resumo mensal

```http
GET /api/v1/health/summary?month=2026-09
```

A resposta distingue, no mínimo:

- saldo atual das contas;
- receitas e despesas realizadas;
- valores previstos a receber e pagar;
- faturas abertas e próximos vencimentos;
- despesas por categoria;
- saldo projetado até o fim do mês;
- moeda comum a todos os totais.

Nenhum total mistura moedas. Pagamentos de fatura são excluídos do resultado de despesas porque as prestações já representam o gasto.

## Erros

Erros seguem `application/problem+json`/`ProblemDetail` e incluem um código estável:

```json
{
  "status": 409,
  "detail": "...",
  "code": "CURRENCY_MISMATCH",
  "timestamp": "2026-09-03T20:00:00Z"
}
```

| HTTP | Código | Significado |
|---|---|---|
| 400 | `VALIDATION_ERROR` | campos ausentes, enum inválido, valor não positivo ou mais de duas casas |
| 401 | `INVALID_CREDENTIALS`/`REQUEST_ERROR` | sessão ausente ou inválida |
| 403 | resposta do Spring Security | token válido de outro `app_context` |
| 404 | `RESOURCE_NOT_FOUND` | recurso inexistente ou não pertencente ao usuário |
| 409 | `CURRENCY_MISMATCH` | moeda do payload/recurso difere da moeda principal |
| 409 | `PRIMARY_CURRENCY_LOCKED` | troca de moeda bloquearia/reinterpretaria dados existentes |

O aplicativo decide o texto localizado a partir de `code`; não deve depender de comparar a mensagem inglesa de `detail`.

## Compatibilidade e versionamento

- Inclusões compatíveis podem acrescentar campos opcionais à resposta.
- Mudanças de semântica, enum ou remoção de campo exigem nova versão de rota.
- O código `currency` nunca é inferido de símbolo, locale ou país.
- Integração bancária futura deve acrescentar origem/identificador externo sem alterar a semântica dos registros manuais.
