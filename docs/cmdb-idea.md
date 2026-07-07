Если CMDB планируется использовать не только для эксплуатации, но и для **аудита ИБ (ISO 27001, CIS Controls, PCI DSS, НКЦКИ, ГОСТ 57580 и т.д.)**, то обычных полей вроде *hostname/IP/ОС* недостаточно.

Я бы разделил поля на несколько блоков.

| Категория     | Поля                                                                  |
| ------------- | --------------------------------------------------------------------- |
| Идентификация | Hostname, FQDN, Asset ID, Серийный номер, Инвентарный номер           |
| Владелец      | Владелец системы, технический владелец, подразделение, контакты       |
| Расположение  | ДЦ, площадка, стойка, облако, регион                                  |
| Тип           | Сервер, ВМ, контейнер, рабочая станция, сетевое устройство, БД и т.д. |
| Критичность   | Criticality, уровень влияния на бизнес, SLA                           |

---

## Для аудита ИБ обязательно добавил бы

### ОС

* Производитель ОС
* Название ОС
* Версия ОС
* Build number
* Версия ядра (Kernel)
* Архитектура (x86_64, ARM)
* Дата установки ОС
* Дата последнего обновления
* Статус поддержки (EOL/EOS)
* Автоматические обновления (вкл/выкл)

Например

```
Ubuntu 22.04.5
Kernel 6.8.0-58
Last update: 2026-06-15
EOL: Supported
```

---

### Патчи

Очень важный блок.

* Последний установленный security patch
* Дата последнего патча
* Missing security updates
* Patch compliance (%)
* Источник обновлений (WSUS, Satellite, Landscape)

---

### Уязвимости

Если есть сканер.

* Последнее сканирование
* Количество Critical
* Количество High
* Максимальный CVSS
* Ссылка на отчет
* Статус устранения

---

### Endpoint Security

Очень любят аудиторы.

* Антивирус
* Версия агента
* EDR/XDR
* Версия
* Последний heartbeat
* Последнее обновление сигнатур
* Tamper Protection

---

### Шифрование

* Полное шифрование диска
* Алгоритм
* TPM используется
* Secure Boot
* BitLocker/LUKS/FileVault статус

---

### Аутентификация

* Входит в AD/LDAP
* MFA для администраторов
* Локальные администраторы
* Используется PAM
* Используется Bastion

---

### SSH/RDP

* SSH version
* Root Login Enabled
* Password Authentication
* Key Authentication
* RDP Enabled
* NLA Enabled

---

### Сетевые данные

* IPv4
* IPv6
* VLAN
* MAC
* Firewall Zone
* Internet Facing (Да/Нет)
* NAT
* Public IP

---

### Сертификаты

Очень часто забывают.

* Используется TLS
* Версия TLS
* Сертификат
* Issuer
* Expiration Date
* Автоматическое продление

---

### Приложения

Не только ОС.

* Установленное ПО
* Версия
* Java Version
* Python Version
* .NET
* OpenSSL Version

Особенно:

* Apache
* nginx
* Tomcat
* PostgreSQL
* MySQL
* Oracle
* MSSQL

---

### Конфигурация безопасности

Можно сделать отдельный раздел.

* CIS Benchmark Version
* CIS Compliance %
* STIG Compliance
* Security Baseline Version
* Hardening Applied
* Last Hardening Review

---

### Логирование

* Логи отправляются в SIEM
* Какой SIEM
* Syslog включен
* Auditd включен
* Windows Event Forwarding
* Retention

---

### Backup

* Backup Enabled
* Backup Solution
* Последний успешный backup
* Проверка восстановления
* Частота

---

### Доступ

Очень полезно.

* Последний вход администратора
* Количество локальных администраторов
* Service Accounts
* Privileged Accounts
* Password Rotation Date

---

### Контейнеры/Kubernetes

Если используются.

* Kubernetes Version
* Docker Version
* Container Runtime
* Namespace
* Image
* Image Version
* Image Digest
* Pod Security Standard
* Admission Controller

---

### Облако

* Cloud Provider
* Account ID
* Subscription
* Region
* Security Group
* IAM Role
* Public Exposure

---

### Соответствие

Хорошо помогает на аудите.

* ISO 27001 Scope
* PCI Scope
* SOX Scope
* GDPR Scope
* КИИ (если применимо)
* Класс защищенности
* Уровень критичности

---

### Жизненный цикл

* Дата ввода в эксплуатацию
* Плановая дата вывода
* EOS
* EOL
* Warranty End
* Support Contract

---

## Очень полезные вычисляемые поля

Не обязательно хранить вручную — их можно рассчитывать автоматически:

* 🟢 Patch Compliance (%)
* 🔴 Количество Critical CVE
* 🔴 Количество High CVE
* 🟡 Возраст последнего патча (дней)
* 🟡 Возраст ОС
* 🟢 До окончания сертификата (дней)
* 🔴 До EOL ОС (дней)
* 🟢 До окончания гарантии (дней)
* 🔴 Secure Score
* 🟢 CIS Compliance (%)

## Если строить CMDB именно под аудит ИБ, я бы рекомендовал минимальный обязательный набор из ~40–50 полей:

* Идентификация актива.
* Владелец (бизнес и технический).
* ОС (версия, build, ядро, EOL).
* Версии ключевого ПО (веб-сервер, СУБД, JVM/.NET/OpenSSL и др.).
* Статус патчей и дата последнего обновления.
* Результаты сканирования уязвимостей (Critical/High/CVSS).
* Наличие и состояние EDR/антивируса.
* Шифрование дисков и Secure Boot.
* Сетевой контекст (IP, VLAN, Internet-facing, Public IP).
* Статус отправки логов в SIEM.
* Резервное копирование и дата последней успешной проверки.
* TLS-сертификаты и срок их действия.
* Критичность актива и классификация данных.
* Даты ввода в эксплуатацию, EOL/EOS и окончания поддержки.

Такой набор уже покрывает большинство вопросов, которые задают аудиторы ИБ, и позволяет быстро выявлять активы с повышенным риском.
