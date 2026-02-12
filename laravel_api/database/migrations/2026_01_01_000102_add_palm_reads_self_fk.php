<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('palm_reads', function (Blueprint $table): void {
            $table->foreign('deduped_from_read_id')
                ->references('id')
                ->on('palm_reads')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('palm_reads', function (Blueprint $table): void {
            $table->dropForeign(['deduped_from_read_id']);
        });
    }
};
