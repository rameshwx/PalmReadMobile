<?php

namespace App\Services\Reading;

final class EnglishOnlyGuard
{
    /**
     * @param array{narrative:string,disclaimer:string,line_situations:array<int,array<string,mixed>>} $payload
     */
    public static function payloadIsEnglish(array $payload): bool
    {
        $texts = [
            (string) ($payload['narrative'] ?? ''),
            (string) ($payload['disclaimer'] ?? ''),
        ];

        foreach ($payload['line_situations'] ?? [] as $entry) {
            if (! is_array($entry)) {
                continue;
            }

            $texts[] = (string) ($entry['title'] ?? '');
            $texts[] = (string) ($entry['situation'] ?? '');
            $texts[] = (string) ($entry['prediction'] ?? '');
            $texts[] = (string) ($entry['suggestion'] ?? '');
        }

        foreach ($texts as $text) {
            $normalized = trim($text);
            if ($normalized === '') {
                return false;
            }

            if (self::containsNonEnglishScript($normalized)) {
                return false;
            }
        }

        return true;
    }

    /**
     * @param array<string, mixed>|null $resultJson
     */
    public static function resultJsonIsEnglish(?array $resultJson, ?string $readingText): bool
    {
        if (! is_array($resultJson)) {
            return false;
        }

        $lineSituations = $resultJson['line_situations'] ?? null;

        return self::payloadIsEnglish([
            'narrative' => (string) ($resultJson['narrative'] ?? $readingText ?? ''),
            'disclaimer' => (string) ($resultJson['disclaimer'] ?? ''),
            'line_situations' => is_array($lineSituations) ? $lineSituations : [],
        ]);
    }

    private static function containsNonEnglishScript(string $text): bool
    {
        if (preg_match('/[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}\p{Cyrillic}\p{Arabic}\p{Hebrew}\p{Thai}\p{Devanagari}]/u', $text) === 1) {
            return true;
        }

        $totalChars = mb_strlen($text);
        if ($totalChars === 0) {
            return false;
        }

        $asciiOnly = preg_replace('/[^\x00-\x7F]/u', '', $text);
        $asciiChars = is_string($asciiOnly) ? strlen($asciiOnly) : 0;
        $nonAsciiRatio = max(0.0, ($totalChars - $asciiChars) / $totalChars);

        return $nonAsciiRatio > 0.08;
    }
}

