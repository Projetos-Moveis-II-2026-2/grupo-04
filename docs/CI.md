# Integração Contínua (CI)

O workflow [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) roda em todo
`pull_request` e `push` para as branches `main` e `dev`. Execuções antigas do
mesmo ref são canceladas automaticamente (`concurrency`).

## O que o job `analyze-and-test` valida

1. `flutter pub get` — resolve as dependências.
2. `dart format --output=none --set-exit-if-changed lib test` — garante que
   `lib/` e `test/` estão formatados.
3. `flutter analyze --fatal-infos` — análise estática sem warnings ou infos.
4. `flutter test --coverage --exclude-tags integration` — testes unitários e de
   widget, ignorando testes marcados com a tag `integration`.
5. Publica `coverage/lcov.info` como artifact e escreve um resumo da cobertura
   (percentual de linhas) no sumário da execução.

## Verificação local

Antes de abrir um PR, rode os mesmos comandos do CI:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --coverage --exclude-tags integration
```

Se a formatação falhar, aplique as correções com:

```bash
dart format lib test
```

## Gate de merge (branch protection)

O gate é configurado **manualmente** por um administrador do repositório no
GitHub, pois o workflow não tem permissão para alterar as regras de proteção.

Para `main` e `dev`:

1. Acesse **Settings → Branches → Add branch protection rule** (ou
   **Rulesets**, no formato novo).
2. Em **Branch name pattern**, informe `main` (repita o processo para `dev`).
3. Marque **Require status checks to pass before merging**.
4. Busque e selecione o check **`analyze-and-test`**.
5. Opcionalmente marque **Require branches to be up to date before merging**.
6. Salve a regra.

Com isso, um PR só poderá ser mergeado quando o job `analyze-and-test`
terminar verde; se qualquer etapa (formatação, análise, testes) falhar, o merge
fica bloqueado.

> Observação: o nome do check aparece depois da primeira execução do workflow
> no repositório. Se ele ainda não estiver listado, abra um PR de teste para
> que o GitHub registre o check.
