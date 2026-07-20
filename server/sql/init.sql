CREATE TABLE IF NOT EXISTS users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    nickname VARCHAR(50) NOT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
        ON UPDATE CURRENT_TIMESTAMP(3)
);

CREATE TABLE IF NOT EXISTS water_records (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    amount_ml INT NULL,
    drank_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    idempotency_key VARCHAR(128) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    INDEX idx_water_records_user_date (user_id, drank_at),
    UNIQUE INDEX uk_water_records_idempotency (idempotency_key),
    CONSTRAINT fk_water_records_user
        FOREIGN KEY (user_id) REFERENCES users(id)
);

INSERT INTO users (id, nickname)
VALUES (1, '默认用户')
ON DUPLICATE KEY UPDATE nickname = VALUES(nickname);
