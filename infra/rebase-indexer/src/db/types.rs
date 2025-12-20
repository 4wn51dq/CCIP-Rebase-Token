use sqlx::FromRow;

#[derive(Debug, FromRow)]
pub struct VaultDeposit {
    pub id: i64,
    pub tx_hash: String,
    pub user_address: String,
    pub amount_wei: String,
    pub block_number: i64,
    pub timestamp: i64,
}

#[derive(Debug, FromRow)]
pub struct RebaseEvent {
    pub id: i64,
    pub new_index: String,
    pub block_number: i64,
    pub timestamp: i64,
}