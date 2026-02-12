<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PalmReadFeedback extends Model
{
    use HasFactory;

    public const UPDATED_AT = null;

    protected $table = 'palm_read_feedback';

    protected $fillable = [
        'palm_read_id',
        'user_id',
        'is_correct',
        'note',
        'correlation_id',
    ];

    protected $casts = [
        'is_correct' => 'boolean',
    ];

    public function palmRead(): BelongsTo
    {
        return $this->belongsTo(PalmRead::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
