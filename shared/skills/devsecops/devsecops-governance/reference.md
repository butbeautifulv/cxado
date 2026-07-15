# DSO document outlines (from DAF xlsx)

## Audit report sections

- Описание текущих процессов разработки ПО
- Сильные/слабые стороны, возможности улучшения
- Рекомендации по встраиванию практик на каждом этапе

## Положение по безопасной разработке (structure)

1. Общие положения (назначение, нормативная база)
2. Процессы безопасной разработки (принципы, ЖЦ, роли)
3. Требования ИБ по этапам ЖЦ (3.1–3.9):
   - Планирование, проектирование, разработка
   - Сборка, тестирование, выпуск, эксплуатация, вывод
4. Контроль и ответственность

## Регламент — key processes (4.x)

- 4.4 SCA / composition analysis
- 4.7 SAST
- 4.9 IaC / configuration security
- 4.10 DAST
- 4.12 Security functional testing
- 4.13 Pentest
- 4.14 Defect management (ASTO)

## Repo artifacts mapping

| Process | Repo artifact |
|---------|---------------|
| SAST | `jobs/sast.*`, policy `sast:` |
| Defects | SARIF → DefectDojo |
| Release | `docs/release-gate-checklist.md` |
| Metrics | pipeline badges, Dependency-Track |

## Security Champions

`P-ROLE-SC`: one SecChamp per team — typical rollout Q+1 in miniRoadmap
