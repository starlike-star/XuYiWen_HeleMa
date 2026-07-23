CREATE DATABASE IF NOT EXISTS helema
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE helema;

CREATE TABLE IF NOT EXISTS users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    nickname VARCHAR(50) NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
        ON UPDATE CURRENT_TIMESTAMP(3)
);

-- Idempotent column migration compatible with MySQL versions that do not
-- support ADD COLUMN IF NOT EXISTS.
SELECT COUNT(*) INTO @column_exists
FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'phone';
SET @migration_sql = IF(
    @column_exists = 0,
    'ALTER TABLE users ADD COLUMN phone VARCHAR(14) NULL AFTER id',
    'DO 0'
);
PREPARE migration_statement FROM @migration_sql;
EXECUTE migration_statement;
DEALLOCATE PREPARE migration_statement;

SELECT COUNT(*) INTO @column_exists
FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'password_hash';
SET @migration_sql = IF(
    @column_exists = 0,
    'ALTER TABLE users ADD COLUMN password_hash VARCHAR(255) NULL AFTER phone',
    'DO 0'
);
PREPARE migration_statement FROM @migration_sql;
EXECUTE migration_statement;
DEALLOCATE PREPARE migration_statement;

SELECT COUNT(*) INTO @column_exists
FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'status';
SET @migration_sql = IF(
    @column_exists = 0,
    'ALTER TABLE users ADD COLUMN status ENUM(''active'', ''disabled'') NOT NULL DEFAULT ''active'' AFTER nickname',
    'DO 0'
);
PREPARE migration_statement FROM @migration_sql;
EXECUTE migration_statement;
DEALLOCATE PREPARE migration_statement;

SELECT COUNT(*) INTO @column_exists
FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'failed_login_count';
SET @migration_sql = IF(
    @column_exists = 0,
    'ALTER TABLE users ADD COLUMN failed_login_count INT NOT NULL DEFAULT 0 AFTER status',
    'DO 0'
);
PREPARE migration_statement FROM @migration_sql;
EXECUTE migration_statement;
DEALLOCATE PREPARE migration_statement;

SELECT COUNT(*) INTO @column_exists
FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'locked_until';
SET @migration_sql = IF(
    @column_exists = 0,
    'ALTER TABLE users ADD COLUMN locked_until DATETIME(3) NULL AFTER failed_login_count',
    'DO 0'
);
PREPARE migration_statement FROM @migration_sql;
EXECUTE migration_statement;
DEALLOCATE PREPARE migration_statement;

SELECT COUNT(*) INTO @column_exists
FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'last_login_at';
SET @migration_sql = IF(
    @column_exists = 0,
    'ALTER TABLE users ADD COLUMN last_login_at DATETIME(3) NULL AFTER locked_until',
    'DO 0'
);
PREPARE migration_statement FROM @migration_sql;
EXECUTE migration_statement;
DEALLOCATE PREPARE migration_statement;

SELECT COUNT(*) INTO @phone_index_exists
FROM information_schema.statistics
WHERE table_schema = DATABASE() AND table_name = 'users' AND index_name = 'uk_users_phone';
SET @phone_index_sql = IF(
    @phone_index_exists = 0,
    'ALTER TABLE users ADD UNIQUE KEY uk_users_phone (phone)',
    'DO 0'
);
PREPARE phone_index_statement FROM @phone_index_sql;
EXECUTE phone_index_statement;
DEALLOCATE PREPARE phone_index_statement;

CREATE TABLE IF NOT EXISTS user_sessions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    refresh_token_hash CHAR(64) NOT NULL,
    expires_at DATETIME(3) NOT NULL,
    revoked_at DATETIME(3) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    INDEX idx_user_sessions_user_active (user_id, revoked_at, expires_at),
    CONSTRAINT fk_user_sessions_user
        FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS water_records (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    amount_ml INT NULL,
    drank_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    idempotency_key VARCHAR(160) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    INDEX idx_water_records_user_date (user_id, drank_at),
    UNIQUE INDEX uk_water_records_idempotency (idempotency_key),
    CONSTRAINT fk_water_records_user
        FOREIGN KEY (user_id) REFERENCES users(id)
);

ALTER TABLE water_records MODIFY COLUMN idempotency_key VARCHAR(160) NULL;

CREATE TABLE IF NOT EXISTS user_daily_goals (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    effective_date DATE NOT NULL,
    target_count INT NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
        ON UPDATE CURRENT_TIMESTAMP(3),
    UNIQUE KEY uk_user_daily_goals_user_date (user_id, effective_date),
    INDEX idx_user_daily_goals_lookup (user_id, effective_date),
    CONSTRAINT fk_user_daily_goals_user
        FOREIGN KEY (user_id) REFERENCES users(id)
);

INSERT INTO users (id, nickname)
VALUES (1, '默认用户')
ON DUPLICATE KEY UPDATE nickname = '默认用户';
