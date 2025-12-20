CREATE TABLE IF NOT EXISTS vault_deposits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tx_hash TEXT NOT NULL,
    user_address TEXT NOT NULL,
    amount_wei TEXT NOT NULL,
    block_number INTEGER NOT NULL,
    timestamp INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS rebases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    new_index TEXT NOT NULL,
    block_number INTEGER NOT NULL,
    timestamp INTEGER NOT NULL
);