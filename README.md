# Petrimonium Health

Aplicativo Flutter de saúde financeira do ecossistema Petrimonium. O Health ajuda a responder:

> Como está meu mês e quanto ainda terei disponível depois dos compromissos previstos?

Esta primeira entrega é manual: contas, receitas, despesas, transferências, recorrências, cartões, faturas e projeção mensal são persistidos no backend compartilhado. Integração bancária não faz parte desta versão.

## Escopo de localização

O onboarding trata as escolhas como preferências independentes:

| Preferência | Valores iniciais | Sugestão por país |
|---|---|---|
| País | Brasil (`BR`) ou Portugal (`PT`) | a seleção do país sugere as outras duas opções |
| Moeda principal | real brasileiro (`BRL`) ou euro (`EUR`) | Brasil → BRL; Portugal → EUR |
| Idioma da interface | português do Brasil (`pt-BR`) ou português de Portugal (`pt-PT`) | Brasil → pt-BR; Portugal → pt-PT |

País, moeda e idioma não dependem da localização do dispositivo. O usuário pode alterar as sugestões antes de concluir o cadastro.

Cada perfil Health possui uma única moeda principal. O backend grava e valida o código ISO da moeda em todos os dados financeiros; o aplicativo nunca converte um valor apenas trocando seu símbolo. Consulte [Regras financeiras](docs/FINANCIAL_RULES.md) e [Contrato da API](docs/API.md).

## Relação com o ecossistema

- O Health é um aplicativo próprio, com `app_context = health`.
- Autenticação, conta Petrimonium e Pet continuam compartilhados com Wallet e Academy.
- Dados Health ficam em um contexto e schema próprios no mesmo backend.
- Dados reais do Health não são lidos pela Academy nem misturados à carteira simulada.
- Dados de investimentos da Wallet não são tratados como saldo de conta no Health.

## Pré-requisitos

- Flutter compatível com o SDK Dart declarado em `pubspec.yaml`.
- Java 21 para executar o Petrimonium Backend.
- Para desenvolvimento local, o backend usa o perfil `dev` e H2 em memória.

## Executar o backend

Em outro terminal, a partir da raiz deste workspace:

```sh
cd Petrimonium-Backend
SPRING_PROFILES_ACTIVE=dev ./mvnw spring-boot:run
```

O backend local escuta em `http://localhost:8081`. As configurações sensíveis devem vir do ambiente ou do `.env` local ignorado pelo Git; não as inclua no aplicativo.

## Executar o aplicativo

```sh
cd Petrimonium-Health
flutter pub get
flutter gen-l10n
flutter run --dart-define=API_BASE_URL=http://localhost:8081
```

No emulador Android, use `http://10.0.2.2:8081` no lugar de `localhost`:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081
```

## Verificações locais

Aplicativo:

```sh
cd Petrimonium-Health
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

Backend compartilhado:

```sh
cd Petrimonium-Backend
./mvnw -B verify
```

## Estrutura

O aplicativo segue as convenções dos demais clientes Petrimonium:

```text
lib/
├── core/                 # rede, tema, localização e utilitários
├── features/
│   ├── auth/             # conta e sessão Petrimonium compartilhadas
│   ├── onboarding/       # país, moeda, idioma e primeira conta
│   ├── accounts/         # contas e transferências
│   ├── transactions/     # receitas, despesas e recorrências
│   ├── cards/            # compras, prestações e faturas
│   ├── summary/          # visão e projeção mensal
│   └── profile/          # preferências Health e Pet
└── l10n/                 # recursos ARB pt-BR e pt-PT
```

As divisões concretas podem evoluir, mas o código de apresentação não deve concentrar regras monetárias nem acesso HTTP.

## Limitações deliberadas da primeira versão

- Uma única moeda principal por usuário no Health.
- Sem câmbio, conversão ou consolidação entre moedas.
- Sem conexão a bancos, Pix, Open Finance, MB Way ou provedores equivalentes.
- Sem deduplicação por heurística de data e valor.
- A moeda fica bloqueada depois que o perfil possui dados financeiros; ainda não existe migração de moeda.
# Petrimonium-Health
