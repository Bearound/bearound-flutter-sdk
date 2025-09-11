# GitHub Actions Workflows

Este diretório contém os workflows do GitHub Actions para o Bearound Flutter SDK.

## Workflows Disponíveis

### 🔄 CI/CD Pipeline (`ci.yml`)

**Triggers:**
- Push para branch `develop`
- Pull Requests para branch `main`
- Execução manual (`workflow_dispatch`)

**Jobs:**

1. **Code Quality & Formatting**
   - Verificação de formatação (`dart format`)
   - Análise estática (`flutter analyze`)
   - Verificação de fixes automáticos (`dart fix`)

2. **Unit Tests**
   - Execução de todos os testes unitários
   - Geração de relatório de cobertura
   - Upload para CodeCov

3. **Build Validation**
   - Build para Android (APK e App Bundle)
   - Build para iOS (simulação sem code signing)
   - Matrix strategy para ambas as plataformas

4. **Dependency Validation**
   - Verificação de dependências desatualizadas
   - Validação do pubspec.yaml
   - Teste de publicação no pub.dev (dry-run)

5. **Documentation Validation**
   - Geração da documentação
   - Validação de links
   - Verificação de APIs não documentadas

### 🚀 Release (`release.yml`)

**Triggers:**
- Push de tags com padrão `v*` (ex: `v1.0.0`)
- Execução manual com input de versão

**Jobs:**

1. **Pre-Release Validation**
   - Execução de todos os testes
   - Análise de código
   - Validação do CHANGELOG.md
   - Verificação de prontidão para pub.dev

2. **Create GitHub Release**
   - Extração de changelog da versão
   - Criação do release no GitHub
   - Suporte para pre-releases

3. **Publish to pub.dev** (Opcional)
   - Publicação automática no pub.dev
   - Requer configuração de secrets

## Configuração Necessária

### Secrets do Repository

Para funcionalidade completa, configure os seguintes secrets:

#### Para CodeCov (Opcional):
```
CODECOV_TOKEN
```

#### Para pub.dev (Opcional):
```
PUB_DEV_PUBLISH_ACCESS_TOKEN
PUB_DEV_PUBLISH_REFRESH_TOKEN
PUB_DEV_PUBLISH_ID_TOKEN
PUB_DEV_PUBLISH_TOKEN_ENDPOINT
```

### Variables do Repository

```
ENABLE_PUBDEV_PUBLISH=true  # Para habilitar publicação automática
```

## Como Usar

### Para Desenvolvimento

1. **Push para `develop`**: Executa o pipeline completo de CI
2. **PR para `main`**: Executa validação completa antes do merge

### Para Release

#### Método 1: Tag Git
```bash
git tag v1.0.0
git push origin v1.0.0
```

#### Método 2: Execução Manual
1. Acesse Actions > Release
2. Clique em "Run workflow"
3. Digite a versão (ex: `1.0.0`)

## Status Badges

Adicione os seguintes badges ao README principal:

```markdown
[![CI](https://github.com/seu-usuario/bearound_flutter_sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/seu-usuario/bearound_flutter_sdk/actions/workflows/ci.yml)
[![Release](https://github.com/seu-usuario/bearound_flutter_sdk/actions/workflows/release.yml/badge.svg)](https://github.com/seu-usuario/bearound_flutter_sdk/actions/workflows/release.yml)
[![codecov](https://codecov.io/gh/seu-usuario/bearound_flutter_sdk/branch/main/graph/badge.svg)](https://codecov.io/gh/seu-usuario/bearound_flutter_sdk)
```

## Timeouts e Limites

- **CI Jobs**: 10-20 minutos cada
- **Release Jobs**: 10-15 minutos cada
- **Total Pipeline**: ~30-45 minutos

## Troubleshooting

### CI Falhando

1. Verifique formatação: `dart format .`
2. Execute análise: `flutter analyze`
3. Execute testes: `flutter test`
4. Verifique build: `cd example && flutter build apk --debug`

### Release Falhando

1. Verifique se CHANGELOG.md contém a versão
2. Certifique-se que todos os testes passam
3. Valide pub.dev readiness: `flutter pub publish --dry-run`