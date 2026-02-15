<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Carbon;

class OtpCodeMail extends Mailable
{
    use Queueable;
    use SerializesModels;

    public function __construct(
        public readonly string $code,
        public readonly Carbon $expiresAt
    ) {
    }

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Your PalmRead code'
        );
    }

    public function content(): Content
    {
        $expiresInMinutes = max(1, now()->diffInMinutes($this->expiresAt));

        return new Content(
            view: 'emails.otp_code',
            with: [
                'code' => $this->code,
                'expiresInMinutes' => $expiresInMinutes,
            ]
        );
    }
}

