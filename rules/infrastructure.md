---
paths:
  - "terraform/**"
  - "pulumi/**"
  - "infra/**"
  - "tofu/**"
---
# Правила Infrastructure as Code

## Terraform / OpenTofu
- Модули в `modules/`, окружения в `environments/`
- `terraform fmt` — обязателен перед коммитом
- `tflint` — обязательный линтинг
- `checkov` / `tfsec` — обязательный статический анализ безопасности
- Каждый ресурс — теги: Name, Environment, Owner, ManagedBy
- State — удалённый backend (S3, GCS), блокировка состояния включена
- Не использовать `terraform apply -auto-approve` в production
- Документировать inputs/outputs в README модуля
- Использовать `terraform plan` перед каждым `apply`
- Версионировать провайдеры и модули явно

## Pulumi
- Типизированные стеки, явное именование ресурсов
- Stack outputs для передачи данных между стеками
- Component resources для переиспользуемых абстракций

## Общее
- Инфраструктурные изменения — через PR с review
- Drift detection: регулярная проверка расхождений state и реальности
- Секреты — через secret manager, не в state и не в коде
