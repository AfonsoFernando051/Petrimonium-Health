# Papel no ecossistema — Petrimonium Health

> O contrato de integração entre os três produtos **não mora aqui**. Ele mora
> em um lugar só, no repositório que consegue executá-lo:
>
> **➜ [`Petrimonium-Backend/docs/INTEGRATION.md`](../../Petrimonium-Backend/docs/INTEGRATION.md)**
>
> Este arquivo registra apenas o que é específico do Health: o seu papel, as
> obrigações que ele assume perante aquele contrato e o que ainda falta.

## 1. A pergunta que este app responde

> *Como está o meu mês, e quanto ainda terei disponível depois dos
> compromissos que já conheço?*

É a primeira pergunta da jornada financeira, e a razão de o Health existir
separado do Wallet: **fluxo de caixa vem antes de patrimônio.** Quem não fecha
o mês não tem o que investir. O Wallet responde "como está o meu patrimônio";
a Academy responde "eu entendo o que estou fazendo". São três perguntas
diferentes, feitas pela mesma pessoa em momentos diferentes — por isso três
apps, e não três abas.

## 2. O que este app compartilha com os outros dois

Só quatro coisas, e todas passam pelo backend (nunca de app para app):

| Costura | Como o Health participa |
|---|---|
| **Identidade** | Mesma conta Petrimonium. `POST /auth/register` não tem contexto: quem se cadastra aqui já existe para Wallet e Academy. `GET /api/users/me` é a rota compartilhada. |
| **Pet** | O mesmo companheiro, pelas mesmas rotas (`GET /api/pets/my-pet`, `POST /api/pets/configure`). A raposa nomeada aqui é a mesma raposa que aparece no Wallet. |
| **XP e nível** | Lidos do ledger compartilhado — mas **o Health não produz XP hoje** (§5.2). |
| **Mentor** | A aba existe e está ligada a `/api/mentor/**` — mas hoje ela responde 403 (§5.1). |

Tudo o mais é isolado. Nenhum dado financeiro do Health sai do contexto
`health`, e nenhum dado de patrimônio ou de carteira simulada entra.

## 3. O que este app **não** pode fazer

Regras herdadas do contrato, listadas aqui porque é neste repositório que elas
seriam quebradas primeiro:

1. **Nunca tratar investimento como saldo de conta.** O patrimônio do Wallet
   não é dinheiro disponível para o mês. As duas telas respondem perguntas
   diferentes e somá-las produziria um número que não significa nada.
2. **Nunca fazer o Pet reagir a dinheiro.** Fatura paga, mês fechado no azul,
   meta batida — nada disso comemora. O Pet reage a **comportamento**
   (constância, registro em dia), nunca a resultado financeiro. Esta regra é
   idêntica nos três apps e existe para o companheiro não virar reforço de
   decisão financeira.
3. **Nunca converter moeda trocando o símbolo.** Cada perfil tem uma moeda
   principal (`BRL` ou `EUR`), gravada e validada pelo backend em todo dado
   financeiro, travada depois que existe dado. Não há câmbio nesta versão.
4. **Nunca inferir país/moeda/idioma do dispositivo.** São três escolhas
   independentes do onboarding — ver [README](../README.md#escopo-de-localização).

## 4. O que é específico deste repositório

| Fato | Valor |
|---|---|
| `app_context` | `'health'` — `lib/core/config/api_config.dart`, fixo, não é flag de build |
| Rotas exclusivas | `/api/v1/health/**` (`APP_CONTEXT_HEALTH`) |
| Rotas compartilhadas usadas | `/auth/**`, `/api/users/me`, `/api/pets/**`, `/api/mentor/**` (esta ainda 403) |
| Schema no banco | `health` — 9 tabelas, migrations `V29` (estrutura) e `V30` (separação, só Postgres) |
| Persistência no backend | **`JdbcHealthStore`, não JPA** — único contexto assim; ver §5.3 |
| Shell | 4 abas: `home`, `transactions`, `accounts`, `mentor` |
| Estado | `HealthController` + `HealthScope` — próprios, **não** a DI estática do Wallet/Academy |
| Cliente HTTP | `lib/core/network/` — próprio, não o `ApiClient` dos outros dois |
| Contrato HTTP completo | [`docs/API.md`](API.md) |
| Regras monetárias | [`docs/FINANCIAL_RULES.md`](FINANCIAL_RULES.md) |

**Aviso que vale para todo PR aqui:** o Health *não* nasceu do clone
`Invest-Game-V2` de onde vieram Wallet e Academy. Ele tem a própria camada de
rede, o próprio controller de estado e o próprio tema. Uma correção feita no
`ApiClient` do Wallet **não** chega aqui — e um arquivo de mesmo nome nos
outros repositórios provavelmente tem outra implementação.

## 5. Lacunas conhecidas

Verificadas no código em 2026-09-04. Detalhe completo em
[`INTEGRATION.md`](../../Petrimonium-Backend/docs/INTEGRATION.md) §8.

### 5.1 A aba Mentor responde 403 (bug vivo)

`lib/features/health/data/remote_health_repository.dart:481,498` chama
`GET /api/mentor/suggestions` e `POST /api/mentor/chat`. O `SecurityConfig` do
backend gateia `/api/mentor/**` a `WALLET` **ou** `ACADEMY` — toda sessão
Health leva 403.

O conserto é no backend e **não é apenas abrir o gate**: não existe
`MentorSystemPromptBuilder.buildForHealth`, e o use case cai no caminho
"seguro para Wallet" quando o contexto não resolve. Abrir a rota antes de
existir um prompt de Health serviria dado de patrimônio real numa conversa de
fluxo de caixa. Prompt primeiro, gate depois.

### 5.2 O Pet fica no nível 1 para sempre

O XP compartilhado só é gerado por eventos de aprendizado
(`LESSON_COMPLETED`, `MODULE_COMPLETED`, `SIMULATOR_COMPLETED`) — ou seja, só
a Academy produz XP. Quem usa apenas o Health vê o companheiro parado.

É decisão de produto em aberto, não bug. E a saída **não pode** ser XP por
dinheiro: se houver XP de Health, terá de ser por comportamento — confirmar
lançamentos, manter o mês em dia, revisar recorrências — nunca pelo valor.

### 5.3 A rede de segurança do schema não cobre o Health

O backend usa `ddl-auto=validate`: uma coluna JPA sem migration derruba a
aplicação no boot. O `health` não é JPA — é `JdbcTemplate` com prefixo de
schema resolvido em runtime. Aqui, uma coluna que existe no SQL do store e não
existe na migration só falha **na primeira chamada que a tocar**.

### 5.4 Idioma tem duas fontes de verdade

`/api/settings/language` guarda o idioma da conta; o perfil Health guarda o
próprio `localeTag`. Nada reconcilia os dois, e não está decidido qual vence.

### 5.5 Nenhuma ponte com Wallet ou Academy

Não há deep link em nenhuma direção (nem proposto, no caso do Health). Os
momentos naturais existem — sobrou dinheiro no mês → Wallet; um compromisso
recorrente virou dúvida conceitual → Academy — mas nada está construído. As
três regras que uma implementação futura terá de respeitar estão no contrato,
§6.

### 5.6 O Atlas ainda não tem fatias do Health

As fatias 26–29 (perfil/moeda, contas e transferências, recorrências e
cartões, resumo mensal) estão no índice como pendentes. Até que existam,
[`docs/API.md`](API.md) é a referência — boa para o contrato HTTP, mas não
descreve o caminho do dado ponta a ponta.
