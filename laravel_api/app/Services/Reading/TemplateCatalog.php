<?php

namespace App\Services\Reading;

class TemplateCatalog
{
    /**
     * @return array<string, array<int, string>>
     */
    public static function personality(): array
    {
        return [
            'steady' => [
                'You tend to approach decisions with a practical, measured rhythm.',
                'Your style is stable and methodical, preferring consistency over sudden shifts.',
            ],
            'adaptive' => [
                'You often adapt quickly and can reframe situations with ease.',
                'Your profile suggests flexibility and responsiveness under change.',
            ],
            'intense' => [
                'You appear to engage deeply with goals and relationships once committed.',
                'There is a focused, high-investment pattern in your choices and attention.',
            ],
        ];
    }

    /**
     * @return array<string, array<int, string>>
     */
    public static function career(): array
    {
        return [
            'incremental' => [
                'Career and wealth momentum likely improves through compounding small wins.',
                'Progress may come from consistent process discipline rather than abrupt pivots.',
            ],
            'opportunity' => [
                'Your pattern points to gains when timing and experimentation are balanced.',
                'You may benefit from selectively pursuing asymmetric opportunities.',
            ],
            'leadership' => [
                'Indicators suggest stronger outcomes when you direct initiatives or systems.',
                'Higher upside appears when you can shape strategy, not only execute tasks.',
            ],
        ];
    }

    /**
     * @return array<string, array<int, string>>
     */
    public static function relationships(): array
    {
        return [
            'reserved' => [
                'You may prefer trust to build gradually before full emotional openness.',
                'Relationship pace appears deliberate, with emphasis on reliability.',
            ],
            'balanced' => [
                'A balance of autonomy and closeness is likely important to you.',
                'You tend to value reciprocal effort and clear communication.',
            ],
            'expressive' => [
                'The profile indicates stronger expressiveness once emotional safety is present.',
                'You may form intense bonds when values and direction align.',
            ],
        ];
    }

    /**
     * @return array<string, array<int, string>>
     */
    public static function vitality(): array
    {
        return [
            'conserve' => [
                'Energy management seems strongest with predictable recovery cycles.',
                'Sustained output may improve when you avoid prolonged overextension.',
            ],
            'steady' => [
                'Your vitality pattern appears fairly even across routine demands.',
                'A stable baseline suggests good response to consistent habits.',
            ],
            'surge' => [
                'You may perform in strong bursts, followed by meaningful reset periods.',
                'High-intensity phases likely work best when recovery is intentionally scheduled.',
            ],
        ];
    }

    /**
     * @return array<int, string>
     */
    public static function timingNotes(): array
    {
        return [
            'Timing signals are probabilistic only and should be treated as directional, not certain.',
            'Potential timing windows are trend-based estimates rather than fixed predictions.',
            'Timing cues suggest likelihood patterns, not guaranteed events.',
        ];
    }

    /**
     * @return array<int, string>
     */
    public static function narrativeIntros(): array
    {
        return [
            'Here is the interpretation I would share with a close friend in practical terms.',
            'If we read this in a grounded way, this is the direction your pattern suggests.',
            'Viewed as a practical reflection, your palm pattern points to the following tendencies.',
        ];
    }

    /**
     * @return array<int, string>
     */
    public static function timingBridges(): array
    {
        return [
            'For timing, treat this as directional context rather than a fixed schedule:',
            'On timing, use this as a planning signal instead of a hard prediction:',
            'For timing, this is best used as probability guidance:',
        ];
    }

    /**
     * @return array<string, array<int, string>>
     */
    public static function suggestionFocus(): array
    {
        return [
            'steady' => [
                'Keep momentum by protecting a simple weekly structure and reviewing priorities at the same time each week.',
                'Preserve your consistency advantage by narrowing your focus to one meaningful objective before adding new commitments.',
            ],
            'adaptive' => [
                'Use your flexibility well by setting one fixed anchor habit each day so change does not become drift.',
                'Turn adaptability into results by deciding in advance which metrics will tell you a pivot is working.',
            ],
            'intense' => [
                'Channel depth productively by committing to one high-impact priority at a time and closing it fully.',
                'Protect your attention by batching decisions and reducing low-value context switching during focused phases.',
            ],
        ];
    }

    /**
     * @return array<string, array<int, string>>
     */
    public static function suggestionCareer(): array
    {
        return [
            'incremental' => [
                'In career and wealth, track one measurable micro-win each week so gains compound with clarity.',
                'Build durable progress by turning small wins into repeatable systems rather than isolated effort bursts.',
            ],
            'opportunity' => [
                'When pursuing opportunities, pair each upside move with a clear downside boundary before acting.',
                'Keep experimentation effective by limiting parallel bets and reviewing outcomes on a fixed cadence.',
            ],
            'leadership' => [
                'Where possible, step into ownership roles where you can shape direction and not only execution.',
                'Strengthen leadership upside by documenting decisions, assumptions, and follow-through in a visible loop.',
            ],
        ];
    }

    /**
     * @return array<string, array<int, string>>
     */
    public static function suggestionVitality(): array
    {
        return [
            'conserve' => [
                'For energy stability, schedule recovery before overload appears, not after it accumulates.',
                'Protect consistency with lighter recovery days that are planned and non-negotiable.',
            ],
            'steady' => [
                'Maintain your baseline by keeping sleep, hydration, and movement predictable even on busy weeks.',
                'Support steady energy by using short reset breaks between demanding blocks of work.',
            ],
            'surge' => [
                'Use high-output windows intentionally, then follow them with planned reset periods to prevent burnout.',
                'Convert surge capacity into sustainable progress by pacing intensity across the week instead of each day.',
            ],
        ];
    }

    /**
     * @return array<int, string>
     */
    public static function narrativeClosers(): array
    {
        return [
            'Overall, this pattern looks promising when applied with consistency, reflection, and measured decision-making.',
            'In short, your best outcomes are likely to come from structured execution rather than reactive intensity.',
            'Taken together, the strongest path appears to be disciplined action with periodic recalibration.',
        ];
    }
}
