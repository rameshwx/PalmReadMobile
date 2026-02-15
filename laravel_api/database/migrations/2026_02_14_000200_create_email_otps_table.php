<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class () extends Migration {
    public function up(): void
    {
        Schema::create('email_otps', function (Blueprint $table): void {
            $table->ulid('id')->primary();
            $table->string('email')->index();
            $table->string('code_hash');
            $table->dateTime('expires_at')->index();
            $table->dateTime('resend_available_at')->index();
            $table->unsignedInteger('attempts')->default(0);
            $table->unsignedInteger('max_attempts')->default(5);
            $table->dateTime('consumed_at')->nullable()->index();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('email_otps');
    }
};

