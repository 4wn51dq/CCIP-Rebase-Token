use sqlx::SqlitePool;

pub mod types;

pub struct Db {
    pub pool: SqlitePool,
}

impl Db {
    pub async fn new(url: &str) -> anyhow::Result<Self> {
        let pool = SqlitePool::connect(url).await?;
        Ok(Self { pool })
    }
}