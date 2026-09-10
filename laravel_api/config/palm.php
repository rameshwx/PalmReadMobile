<?php

return [
    'storage_disk' => env('PALM_STORAGE_DISK', 'palms'),
    'image_retention_days' => (int) env('PALM_IMAGE_RETENTION_DAYS', 30),
    'upload_max_mb' => (int) env('PALM_UPLOAD_MAX_MB', 8),
    'polling_recommended_seconds' => (int) env('PALM_POLLING_RECOMMENDED_SECONDS', 2),
    'history_limit' => (int) env('PALM_HISTORY_LIMIT', 10),
    'llm_enabled' => env('PALM_LLM_ENABLED', false),
    'openrouter_api_key' => env('PALM_OPENROUTER_API_KEY', ''),
    'openrouter_base_url' => env('PALM_OPENROUTER_BASE_URL', 'https://openrouter.ai/api/v1'),
    'openrouter_model' => env('PALM_OPENROUTER_MODEL', 'openai/gpt-4o'),
    'llm_timeout_seconds' => (int) env('PALM_LLM_TIMEOUT_SECONDS', 60),
    'llm_temperature' => (float) env('PALM_LLM_TEMPERATURE', 0),
    'llm_num_predict' => (int) env('PALM_LLM_NUM_PREDICT', 900),
    'llm_seed' => (int) env('PALM_LLM_SEED', 42),
    'llm_force_english' => env('PALM_LLM_FORCE_ENGLISH', true),
    'llm_require_success' => env('PALM_LLM_REQUIRE_SUCCESS', false),
    'cv_service_base_url' => env('CV_SERVICE_BASE_URL', 'http://127.0.0.1:8001'),
    'line_keys' => ['life', 'head', 'heart', 'fate', 'sun'],
    'otp_ttl_seconds' => (int) env('PALM_OTP_TTL_SECONDS', 600),
    'otp_resend_after_seconds' => (int) env('PALM_OTP_RESEND_AFTER_SECONDS', 45),
    'otp_max_attempts' => (int) env('PALM_OTP_MAX_ATTEMPTS', 5),
    'otp_debug_echo' => env('PALM_OTP_DEBUG_ECHO', false),
    // FCM HTTP v1 credentials.
    'fcm_project_id' => env('PALM_FCM_PROJECT_ID', 'palm-read-5cfa3'),
    'fcm_service_account_path' => env('PALM_FCM_SERVICE_ACCOUNT_PATH', ''),
    'fcm_service_account_base64' => env('PALM_FCM_SERVICE_ACCOUNT_BASE64', ''),
];
