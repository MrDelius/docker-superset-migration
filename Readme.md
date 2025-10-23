# Резервное копирование и восстановление Apache Superset

Этот документ описывает полный цикл работы с экземпляром Apache Superset, использующим SQLite и Docker: от создания резервной копии до полного восстановления на новой системе.

---

## Часть I. Создание резервной копии (бэкапа)

Этот раздел выполняется на работающей ("старой") системе, данные которой нужно сохранить.

### Шаг 1. Узнайте имя контейнера Superset

Убедитесь, что Superset запущен, и выполните команду:

```bash
docker ps
```

Найдите в списке ваш контейнер Superset (например, `my_superset_app`) и запомните его имя.

### Шаг 2. Скопируйте файл базы данных из контейнера

Выполните команду, заменив `[ИМЯ_ВАШЕГО_КОНТЕЙНЕРА]` на имя из предыдущего шага:

```bash
docker cp [ИМЯ_ВАШЕГО_КОНТЕЙНЕРА]:/app/superset_home/superset.db ./backup_sqlite.db
```

**Пример:**

```bash
docker cp my_superset_app:/app/superset_home/superset.db ./backup_sqlite.db
```

После выполнения в вашей текущей директории появится файл `backup_sqlite.db` — это полная резервная копия базы данных Superset.

---

## Часть II. Восстановление из резервной копии

Эта часть выполняется на новой или чистой системе.

### 1. Структура проекта

Создайте рабочую папку с такой структурой:

```
/my-superset/
│-- backup_sqlite.db
│-- .env
│-- Dockerfile
│-- docker-compose.yml
│-- requirements-local.txt  (может быть пустым)
```

---

### 2. Конфигурационные файлы

#### 2.1. Файл `.env`

```env
# Замените значение на ваш собственный ключ
# Команда для генерации в PowerShell:
# (New-Guid).ToString() + (New-Guid).ToString()
SUPERSET_SECRET_KEY=a1b2c3d4-e5f6-7890-abcd-ef1234567890f1e2d3c4-b5a6-7890-abcd-ef1234567890
```

#### 2.2. Файл `Dockerfile`

```dockerfile
FROM apache/superset:latest-dev

USER root
COPY requirements-local.txt /app/
RUN pip install -r /app/requirements-local.txt
USER superset
```

#### 2.3. Файл `docker-compose.yml`

```yaml
services:
  superset:
    build: .
    container_name: my_superset_app
    restart: unless-stopped
    ports:
      - "8088:8088"
    volumes:
      - superset-data:/app/superset_home
    environment:
      SUPERSET_SECRET_KEY: ${SUPERSET_SECRET_KEY}
    env_file: .env

volumes:
  superset-data:
    driver: local
```

---

## 3. Процесс восстановления и запуска

Находясь в папке `/my-superset`, выполните команды последовательно.

### Шаг 1. Полная очистка

```bash
docker-compose down -v
```

### Шаг 2. Подготовка тома данных

1. Создайте пустой именованный том:

```bash
docker volume create my-superset_superset-data
```

2. Скопируйте файл резервной копии в том и переименуйте его в `superset.db`:

```bash
docker run --rm -v my-superset_superset-data:/superset_home -v ${PWD}:/backup_source alpine cp /backup_source/backup_sqlite.db /superset_home/superset.db
```

---

### Шаг 3. Исправление прав доступа

Этот шаг обязателен, чтобы избежать ошибки `readonly database`.

1. Узнайте ID пользователя `superset` внутри контейнера:

```bash
docker exec -it my_superset_app id superset
```

Команда вернет что-то вроде:

```
uid=1000(superset) gid=1000(superset)
```

2. Измените владельца файлов в томе:

```bash
docker run --rm -v my-superset_superset-data:/superset_home alpine chown -R 1000:1000 /superset_home
```

---

### Шаг 4. Запуск Superset

Запустите контейнер с пересборкой образа:

```bash
docker-compose up -d --build
```

---

## 4. Проверка

1. Подождите около минуты до полного запуска контейнера.  
2. Откройте в браузере адрес:

```
http://localhost:8088
```

3. Войдите, используя ваши старые учетные данные.  
4. Проверьте наличие всех дашбордов и возможность их редактирования.

---

## 5. Краткая сводка команд

| Действие                            | Команда |
|-------------------------------------|----------|
| Проверка контейнера                 | `docker ps` |
| Создание бэкапа                     | `docker cp my_superset_app:/app/superset_home/superset.db ./backup_sqlite.db` |
| Очистка системы                     | `docker-compose down -v` |
| Создание тома                       | `docker volume create my-superset_superset-data` |
| Копирование бэкапа в том            | `docker run --rm -v my-superset_superset-data:/superset_home -v ${PWD}:/backup_source alpine cp /backup_source/backup_sqlite.db /superset_home/superset.db` |
| Исправление прав                    | `docker run --rm -v my-superset_superset-data:/superset_home alpine chown -R 1000:1000 /superset_home` |
| Запуск Superset                     | `docker-compose up -d --build` |
| Обновление таблиц                   | `docker exec -it my_superset_app superset db upgrade` |
| Создаение ролей и дефолтных записей | `docker exec -it my_superset_app superset init` |
