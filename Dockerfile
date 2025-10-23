# Имя файла: Dockerfile

# 1. Берем за основу официальный образ Superset
FROM apache/superset:latest-dev

# 2. Переключаемся на пользователя root, чтобы иметь права на установку пакетов
USER root

# 3. Копируем наш файл с зависимостями в рабочую директорию /app
COPY requirements-local.txt /app/

# 4. Устанавливаем зависимости из этого файла.
RUN pip install -r /app/requirements-local.txt

# 6. Возвращаемся к пользователю superset для безопасности
USER superset