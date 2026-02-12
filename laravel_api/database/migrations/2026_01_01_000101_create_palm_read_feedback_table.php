<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('palm_read_feedback', function (Blueprint $table): void {
            $table->id();
            $table->ulid('palm_read_id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->boolean('is_correct');
            $table->text('note')->nullable();
            $table->uuid('correlation_id');
            $table->timestamp('created_at')->useCurrent();

            $table->foreign('palm_read_id')->references('id')->on('palm_reads')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('palm_read_feedback');
    }
};
