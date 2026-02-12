<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    /**
     * @var array<int, class-string>
     */
    protected $commands = [
        \App\Console\Commands\PurgePalmImagesCommand::class,
        \App\Console\Commands\EnforceEnglishReadingsCommand::class,
    ];

    protected function schedule(Schedule $schedule): void
    {
        $schedule->command('palms:purge-images')->daily();
    }

    protected function commands(): void
    {
        $this->load(__DIR__.'/Commands');
    }
}
