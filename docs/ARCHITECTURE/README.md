# Atlas Técnico — lado Health

O Atlas Técnico do ecossistema vive em um lugar só, porque quase toda
funcionalidade atravessa mais de um repositório e documentá-la em pedaços
separados garante que os pedaços divirjam:

**➜ `Petrimonium-Backend/docs/ARCHITECTURE/`**

- `README.md` — o método, o formato das fatias e o índice completo
- `00-visao-geral.md` — o mapa dos 4 repositórios e dos 3 produtos
- `fatias/` — uma funcionalidade por arquivo, sempre ponta a ponta

E o acordo entre os produtos — o que é compartilhado, o que nunca atravessa a
fronteira — em **`Petrimonium-Backend/docs/INTEGRATION.md`**.

## Fatias deste produto

Nenhuma escrita ainda. Estão no índice como 26–29: perfil Health (país, moeda,
idioma e a trava da moeda), contas/lançamentos/transferências, recorrências e
cartões, resumo e projeção mensal. Enquanto isso, [`../API.md`](../API.md)
descreve o contrato HTTP e [`../FINANCIAL_RULES.md`](../FINANCIAL_RULES.md) as
regras monetárias.

## O que é específico deste repositório

| Fato | Valor |
|---|---|
| `ApiConfig.appContext` | `'health'` — fixo, não é flag de build |
| Endpoints exclusivos | `/api/v1/health/**` — ver visão geral §5 |
| Estado | `HealthController` + `HealthScope` (`lib/core/app/`) — não é a DI estática do Wallet/Academy |
| Cliente HTTP | `lib/core/network/` — próprio, não o `ApiClient` dos outros dois |
| Persistência no backend | `JdbcHealthStore` (`JdbcTemplate`), único contexto sem JPA |

## Aviso que vale para todo PR neste repositório

O Health **não** é clone de `Invest-Game-V2`, ao contrário de Wallet e
Academy. Ele tem a própria camada de rede, o próprio controller de estado e o
próprio tema. Não copie correção de rede dos outros repositórios presumindo
que o código é o mesmo — não é.
