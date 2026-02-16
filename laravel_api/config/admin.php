<?php

return [
    'username' => env('PALM_ADMIN_USERNAME', ''),
    'password' => env('PALM_ADMIN_PASSWORD', ''),
    'users_per_page' => (int) env('PALM_ADMIN_USERS_PER_PAGE', 25),
    'uploads_per_page' => (int) env('PALM_ADMIN_UPLOADS_PER_PAGE', 30),
];
