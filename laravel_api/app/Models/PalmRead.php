<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUlids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PalmRead extends Model
{
    use HasFactory;
    use HasUlids;

    protected $table = 'palm_reads';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'user_id',
        'handedness',
        'status',
        'image_path',
        'image_w',
        'image_h',
        'roi_meta',
        'hand_signature_hash',
        'features_json',
        'quantized_features_json',
        'result_json',
        'reading_text',
        'overlay_json',
        'processing_ms',
        'failure_reason',
        'correlation_id',
        'deduped_from_read_id',
        'image_delete_after_at',
    ];

    protected $casts = [
        'roi_meta' => 'array',
        'features_json' => 'array',
        'quantized_features_json' => 'array',
        'result_json' => 'array',
        'overlay_json' => 'array',
        'processing_ms' => 'integer',
        'image_delete_after_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function dedupedFrom(): BelongsTo
    {
        return $this->belongsTo(self::class, 'deduped_from_read_id');
    }
}
