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

### Idempotência

Toda criação (`POST`) de conta, lançamento, transferência, recorrência, cartão, compra e pagamento de fatura exige `idempotencyKey`: uma string de até 64 caracteres gerada pelo aplicativo e única por operação.

- Repetir a requisição com a mesma chave e os mesmos dados devolve o registro já criado, sem cobrar ou transferir de novo.
- A mesma chave com dados diferentes é recusada com 409 `IDEMPOTENCY_KEY_REUSED`.
- A unicidade vale por usuário: dois usuários podem usar a mesma chave sem colidir.

Atualizações (`PUT`) e arquivamentos (`DELETE`) não usam chave: identificam o recurso pela rota.

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
  "type": "CHECKING",
  "initialBalance": "850.00",
  "balanceReferenceDate": "2026-09-01",
  "currency": "EUR",
  "idempotencyKey": "acc-4f2a"
}
```

`type` aceita `CHECKING`, `SAVINGS`, `CASH` ou `OTHER`. A resposta acrescenta `id`, `currentBalance` e `archived`.

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
  "category": "utilities",
  "date": "2026-09-12",
  "idempotencyKey": "tx-91c3"
}
```

A resposta acrescenta `id`, `source` (`MANUAL`, `IMPORTED` ou `SYSTEM`) e, quando existirem, `transferId`, `recurrenceId` e `invoiceId`. Um lançamento com um desses vínculos foi gerado pelo backend — uma perna de transferência, uma ocorrência de recorrência ou o pagamento de uma fatura — e não pode ser editado nem excluído como lançamento isolado (409 `SYSTEM_ENTRY_IMMUTABLE`).

## Transferências

```http
POST /api/v1/health/transfers
```

Exemplo:

```json
{
  "fromAccountId": 10,
  "toAccountId": 11,
  "amount": "100.00",
  "currency": "EUR",
  "date": "2026-09-03",
  "description": "Reserva",
  "idempotencyKey": "tr-77bd"
}
```

A resposta representa uma transferência única, com as duas pernas que ela gerou em `outLeg` e `inLeg`; não devolve duas receitas/despesas independentes. As contas precisam ser diferentes, ativas, do mesmo usuário e da mesma moeda.

## Recorrências

```http
GET    /api/v1/health/recurrences
POST   /api/v1/health/recurrences
PUT    /api/v1/health/recurrences/{recurrenceId}
DELETE /api/v1/health/recurrences/{recurrenceId}
```

A criação mensal informa tipo, conta, valor/moeda, categoria, `dayOfMonth`, `startDate` e, opcionalmente, `endDate`.

Não existe rota de geração: as ocorrências são materializadas pelo próprio backend ao consultar lançamentos ou o resumo, até a competência consultada. A operação é idempotente por recorrência e competência — consultar o mesmo mês várias vezes não duplica nada. Dias ausentes no mês são ajustados para o último dia.

Cada ocorrência nasce `PLANNED`; confirmá-la é uma operação de lançamento comum. `PUT` altera o modelo e as ocorrências ainda previstas da competência atual em diante, preservando o que já foi confirmado. `DELETE` desativa a recorrência e remove apenas as ocorrências futuras ainda previstas.

## Cartões, compras e faturas

```http
GET    /api/v1/health/cards
POST   /api/v1/health/cards
PUT    /api/v1/health/cards/{cardId}
DELETE /api/v1/health/cards/{cardId}

POST   /api/v1/health/cards/{cardId}/purchases
GET    /api/v1/health/cards/{cardId}/invoices
POST   /api/v1/health/cards/invoices/{invoiceId}/pay
```

As faturas vêm em ordem cronológica, do ciclo mais antigo para o mais recente: a primeira da lista é a que vence primeiro.

Compra parcelada informa valor total e quantidade de prestações. A resposta inclui as prestações geradas e sua associação a faturas; a soma deve ser exata.

Exemplo de compra:

```json
{
  "description": "Computador",
  "amount": "999.99",
  "currency": "EUR",
  "purchaseDate": "2026-09-03",
  "installmentCount": 3,
  "category": "shopping",
  "idempotencyKey": "buy-2ac1"
}
```

A resposta usa `totalAmount` para o valor da compra e traz cada prestação em `installments`, com `installmentNumber`, `amount` e o `invoiceId` da fatura em que caiu.

Pagamento de fatura referencia uma conta do mesmo usuário/moeda e não cria uma nova despesa:

```json
{
  "accountId": 10,
  "paymentDate": "2026-10-05",
  "currency": "EUR",
  "idempotencyKey": "pay-5e08"
}
```

## Resumo mensal

```http
GET /api/v1/health/summary?month=2026-09
```

Campos da resposta, todos na mesma moeda (`currency`) e como strings decimais:

| Campo | Significado |
|---|---|
| `month` | competência consultada, `YYYY-MM` |
| `currentBalance` | caixa realizado somando as contas ativas |
| `realizedIncome` / `realizedExpenses` | receitas e despesas da competência já realizadas; as despesas incluem as prestações de cartão do ciclo |
| `plannedIncome` / `plannedExpenses` | previstos da competência, que não afetam o saldo atual |
| `openCardInvoices` | faturas em aberto com vencimento na competência |
| `monthResult` | `realizedIncome - realizedExpenses` |
| `projectedEndBalance` | `currentBalance + plannedIncome - plannedExpenses - openCardInvoices` |
| `expensesByCategory` | despesas realizadas por categoria, incluindo prestações de cartão |
| `upcoming` | próximos compromissos (`TRANSACTION` ou `CARD_INVOICE`) com data e valor |

`month` é opcional; ausente, o servidor usa a competência atual. A projeção é estimativa e não deve ser apresentada como valor garantido.

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
| 400 | `INVALID_REQUEST` | campos ausentes, enum inválido, valor não positivo, mais de duas casas, `month` fora de `YYYY-MM` |
| 400 | `MALFORMED_REQUEST` | corpo ilegível ou tipo incompatível |
| 401 | `INVALID_CREDENTIALS`/`REQUEST_ERROR` | sessão ausente ou inválida |
| 403 | resposta do Spring Security | token sem `app_context` ou de outro aplicativo |
| 404 | `RESOURCE_NOT_FOUND` | recurso inexistente ou não pertencente ao usuário |
| 409 | `CURRENCY_MISMATCH` | moeda do payload/recurso difere da moeda principal |
| 409 | `CURRENCY_CHANGE_LOCKED` | troca de moeda reinterpretaria dados existentes |
| 409 | `IDEMPOTENCY_KEY_REUSED` | a mesma chave já foi usada com outros dados |
| 409 | `INVOICE_ALREADY_PAID` | a fatura já tem pagamento registrado |
| 409 | `EMPTY_INVOICE` | fatura sem prestações não é pagável |
| 409 | `SYSTEM_ENTRY_IMMUTABLE` | perna de transferência, ocorrência ou pagamento de fatura editado fora do seu fluxo |
| 409 | `ACCOUNT_ARCHIVED` / `CARD_ARCHIVED` | novo registro em conta ou cartão arquivado |

Um recurso de outro usuário responde 404, e não 403: o aplicativo nunca recebe confirmação de que aquele id existe.

O aplicativo decide o texto localizado a partir de `code`; não deve depender de comparar a mensagem inglesa de `detail`.

## Compatibilidade e versionamento

- Inclusões compatíveis podem acrescentar campos opcionais à resposta.
- Mudanças de semântica, enum ou remoção de campo exigem nova versão de rota.
- O código `currency` nunca é inferido de símbolo, locale ou país.
- Integração bancária futura deve acrescentar origem/identificador externo sem alterar a semântica dos registros manuais.
