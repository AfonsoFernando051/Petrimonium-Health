# Regras financeiras do Petrimonium Health

Este documento é o contrato funcional da primeira versão do Health. Cálculos no aplicativo servem para apresentação; o backend é a autoridade sobre persistência, moeda, saldos, faturas e projeções.

## 1. Representação monetária

1. Valores monetários no backend usam `BigDecimal` e colunas `numeric(19,2)`.
2. Valores monetários no JSON são strings decimais, por exemplo `"1520.35"`. Não são números binários JSON.
3. A API aceita no máximo duas casas decimais. Um valor com mais casas é rejeitado; não é arredondado silenciosamente.
4. Cálculos e persistência não usam `double`/`float`.
5. A divisão de uma compra em prestações usa escala 2 e `HALF_UP`. Qualquer diferença de centavos é distribuída de forma determinística, e a soma das prestações deve ser exatamente igual ao total da compra.
6. Formatação é responsabilidade da interface e segue o locale selecionado. Ela nunca muda o valor persistido.

Exemplos de apresentação do mesmo valor decimal:

| Moeda e locale | Apresentação esperada |
|---|---|
| BRL, pt-BR | `R$ 1.234,56` |
| EUR, pt-PT | `1 234,56 €` conforme os dados de locale da biblioteca `intl` |

O texto formatado não volta para a API. A interface normaliza a entrada do usuário e envia uma string decimal canônica com ponto como separador.

## 2. Invariante de moeda única

- O perfil Health tem uma `primaryCurrency`: `BRL` ou `EUR`.
- Conta, lançamento, transferência, recorrência, cartão, compra, prestação e fatura pertencem a essa mesma moeda.
- Cada representação financeira da API inclui seu `currency` explícito.
- O backend compara o código recebido com a moeda do perfil antes de persistir ou calcular.
- Uma divergência retorna HTTP 409 com o código estável `CURRENCY_MISMATCH`.
- O resumo mensal agrupa apenas dados cuja moeda já foi validada. BRL e EUR nunca são somados.

Alterar somente `R$` para `€`, ou somente `BRL` para `EUR`, não é conversão. O Health não possui taxa de câmbio nesta etapa.

### Bloqueio de troca

A moeda pode ser corrigida enquanto o perfil ainda não possui nenhum registro monetário. Depois que houver qualquer dado cujo significado dependa da moeda — inclusive saldo inicial — a troca é rejeitada com HTTP 409 e `PRIMARY_CURRENCY_LOCKED`.

A interface deve explicar, em pt-BR ou pt-PT, que mudar o código reinterpretaria os valores existentes e que ainda não existe fluxo de migração. O backend não atualiza parcialmente o perfil e não regrava dados existentes.

## 3. Contas e saldo atual

Uma conta possui saldo inicial e data de referência. Saldo inicial é ponto de partida, não receita.

O saldo atual calculado de uma conta é:

```text
saldo inicial
+ receitas realizadas na conta
- despesas realizadas diretamente na conta
+ transferências recebidas
- transferências enviadas
- pagamentos de fatura realizados pela conta
```

Não entram no saldo atual:

- lançamentos previstos;
- limite disponível de cartão;
- compras no cartão ainda não pagas pela conta;
- o pagamento da fatura como uma segunda despesa.

Arquivar uma conta a remove dos fluxos de seleção para novos registros, mas preserva histórico, saldos e referências. Operações históricas não devem ser apagadas em cascata por causa do arquivamento.

## 4. Receitas e despesas

Um lançamento tem tipo (`INCOME` ou `EXPENSE`) e situação (`PLANNED` ou `REALIZED`).

- `PLANNED` participa da projeção, mas não altera o saldo atual.
- `REALIZED` altera o saldo atual uma única vez.
- Confirmar recebimento ou pagamento muda o estado do lançamento existente; não cria uma cópia.
- Excluir um lançamento remove seu efeito calculado; a operação deve respeitar as restrições de histórico e referências.
- Valor, data, conta e categoria pertencem ao mesmo usuário autenticado.

## 5. Transferências entre contas próprias

Uma transferência é uma operação única e atômica com origem e destino:

- reduz o saldo da conta de origem;
- aumenta o saldo da conta de destino;
- não é receita;
- não é despesa;
- exige duas contas diferentes, ativas, do mesmo usuário e da mesma moeda;
- não pode deixar apenas um dos lados persistido em caso de falha.

Repetir acidentalmente a mesma requisição não deve criar movimentos parciais. Onde o contrato expuser chave de idempotência, o backend é a autoridade sobre sua unicidade.

## 6. Recorrências

Uma recorrência mensal é um modelo; cada mês recebe uma ocorrência persistida independente.

- A chave lógica da ocorrência impede geração duplicada para a mesma recorrência e competência.
- Se o dia de vencimento não existir no mês, usa-se o último dia do mês. Exemplo: dia 31 produz 28 ou 29 de fevereiro.
- Editar uma ocorrência altera somente aquela ocorrência.
- Editar as futuras preserva ocorrências já realizadas e o histórico anterior.
- Gerar ocorrências novamente para o mesmo período é idempotente.

Datas de vencimento e competência são datas civis (`LocalDate`, ISO `YYYY-MM-DD`), sem conversão por fuso horário.

## 7. Cartões, compras, prestações e faturas

- Limite de crédito não é saldo nem dinheiro disponível.
- Uma compra à vista no cartão gera uma prestação.
- Uma compra parcelada gera `N` prestações cuja soma é exatamente o valor total.
- Cada prestação pertence a uma fatura determinada pelas regras de fechamento e vencimento do cartão.
- A despesa mensal de cartão é reconhecida pelas prestações, não pelo pagamento da fatura.
- Pagar a fatura reduz o saldo da conta escolhida e muda o estado da fatura; não cria nova despesa.
- Uma fatura não pode ser paga duas vezes pela repetição da mesma operação.
- O cartão, a conta pagadora, a compra e a fatura devem pertencer ao mesmo usuário e moeda.

## 8. Visão mensal

A resposta mensal distingue três conceitos:

1. **Saldo atual:** caixa realizado das contas, conforme a seção 3.
2. **Resultado do mês:** receitas menos despesas da competência, separando realizado e previsto. Prestações de cartão entram como despesa; pagamento de fatura não entra novamente.
3. **Saldo projetado:** saldo atual mais receitas previstas, menos despesas previstas e menos faturas abertas com vencimento no horizonte consultado.

```text
saldo projetado
= saldo atual
+ receitas previstas no horizonte
- despesas previstas diretamente em contas no horizonte
- faturas abertas com vencimento no horizonte
```

O resumo também pode mostrar despesas por categoria, próximos vencimentos e faturas, sempre sem dupla contagem. Projeção é uma estimativa baseada nos dados cadastrados; a interface não deve apresentá-la como valor garantido.

## 9. Origem e integração futura

O cadastro desta entrega é `MANUAL`. O modelo pode reservar origem importada e identificador externo opcional, mas:

- nenhuma integração bancária é exibida como funcional;
- não se presume que um provedor brasileiro atenda Portugal;
- data e valor iguais não provam que dois registros sejam duplicados;
- conciliação futura deverá usar identidade do provedor, conta e identificadores externos, com revisão do usuário quando houver ambiguidade.

## 10. Isolamento e informações sensíveis

- O usuário é derivado do JWT; IDs ou emails enviados pelo cliente nunca autorizam acesso.
- Toda consulta e mutação valida propriedade do agregado.
- Endpoints Health exigem `APP_CONTEXT_HEALTH`.
- Mensagens e logs não incluem saldos, valores, descrições, números de cartão ou corpos financeiros completos.
- CPF, Pix e campos exclusivamente brasileiros não são exigidos pelo perfil nem pelos fluxos portugueses.
