<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('palm_reads', function (Blueprint $table): void {
            $table->ulid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('handedness', 16)->default('unknown');
            $table->string('status', 32)->index();
            $table->string('image_path')->nullable();
            $table->unsignedInteger('image_w')->nullable();
            $table->unsignedInteger('image_h')->nullable();
            $table->json('roi_meta')->nullable();
            $table->char('hand_signature_hash', 64)->nullable()->index();
            $table->json('features_json')->nullable();
            $table->json('quantized_features_json')->nullable();
            $table->json('result_json')->nullable();
            $table->text('reading_text')->nullable();
            $table->json('overlay_json')->nullable();
            $table->unsignedInteger('processing_ms')->nullable();
            $table->string('failure_reason')->nullable();
            $table->uuid('correlation_id')->index();
            $table->ulid('deduped_from_read_id')->nullable();
            $table->timestamp('image_delete_after_at')->nullable();
            $table->timestamps();

        });
    }

    public function down(): void
    {
        Schema::dropIfExists('palm_reads');
    }
};
