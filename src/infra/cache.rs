use anyhow::Result;
use redis::Client;

#[derive(Clone)]
pub struct RedisCache {
    client: Client,
}

impl RedisCache {
    pub async fn connect(redis_url: &str) -> Result<Self> {
        let client = Client::open(redis_url)?;
        let mut conn = client.get_multiplexed_async_connection().await?;
        redis::cmd("PING").query_async::<_, String>(&mut conn).await?;
        Ok(Self { client })
    }

    pub fn client(&self) -> &Client {
        &self.client
    }

    pub async fn ping(&self) -> Result<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        redis::cmd("PING").query_async::<_, String>(&mut conn).await?;
        Ok(())
    }
}

