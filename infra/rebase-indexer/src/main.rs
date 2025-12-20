mod db;

use db::Db;
use std::{fs, path::PathBuf};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let mut path = std::env::current_dir()?;
    path.push("data");
    fs::create_dir_all(&path)?;

    path.push("indexer.db");

    let absolute = path.canonicalize()?;
    let db_url = format!("sqlite:///{}", absolute.display());

    println!("DB URL = {}", db_url);

    let _db = Db::new(&db_url).await?;

    println!("✅ SQLite opened");
    Ok(())
}