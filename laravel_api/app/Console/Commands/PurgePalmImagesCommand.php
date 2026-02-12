<?php

namespace App\Console\Commands;

use App\Models\PalmRead;
use App\Services\Storage\PalmImageStorage;
use Illuminate\Console\Command;

class PurgePalmImagesCommand extends Command
{
    protected $signature = 'palms:purge-images';

    protected $description = 'Delete palm images that passed configured retention period.';

    public function handle(PalmImageStorage $storage): int
    {
        $toDelete = PalmRead::query()
            ->whereNotNull('image_path')
            ->whereNotNull('image_delete_after_at')
            ->where('image_delete_after_at', '<=', now())
            ->cursor();

        $deleted = 0;

        foreach ($toDelete as $read) {
            $storage->deleteIfExists($read->image_path);
            $read->image_path = null;
            $read->save();
            $deleted++;
        }

        $this->info("Purged {$deleted} image(s).");

        return self::SUCCESS;
    }
}
