#[derive(Debug, Clone)]
pub struct Config {
    pub redis_url: String,
    pub timescale_url: String,
}

impl Config {
    pub fn load() -> Self {
        Self {
            redis_url: "redis://localhost:6379".to_string(),
            timescale_url: "postgres://postgres:postgres@localhost:5432/postgres".to_string(),
        }
    }
}
