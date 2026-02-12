from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    cv_host: str = "0.0.0.0"
    cv_port: int = 8001
    cv_max_image_side: int = 1600
    cv_roi_size: int = 512
    cv_timeout_ms: int = 8000
    cv_num_threads: int = 1
    log_level: str = "INFO"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
