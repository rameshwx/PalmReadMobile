<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class EmailOtp extends Model
{
    use HasFactory;
    use HasUlids;

    protected $table = 'email_otps';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'email',
        'code_hash',
        'expires_at',
        'resend_available_at',
        'attempts',
        'max_attempts',
        'consumed_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'resend_available_at' => 'datetime',
        'consumed_at' => 'datetime',
        'attempts' => 'integer',
        'max_attempts' => 'integer',
    ];
}

