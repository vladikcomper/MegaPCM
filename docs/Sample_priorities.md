
# Mega PCM 2 Sample Priority System

Since version 2.1 Mega PCM comes with a proper sample priority system. Here's a brief overview of the system, which is quite straight-forward.

## The Basics

- There a total of 8 priority levels: 4 for normal samples, 4 for SFX samples.
- SFX samples (samples with `FLAGS_SFX`) always have higher priority than normal samples. No exceptions.
- Priority levels are specified in Sample table alongside flags.
- Both normal and SFX samples can pick 4 priority levels across their kind:
    - `PRIO_LOW`
    - `PRIO_NORMAL` - that's the default level if not specified
    - `PRIO_HIGH`
    - `PRIO_HIGHEST`
- When a new sample is requested while another one is already playing, Mega PCM 2 compares their priority levels:
    - If new sample has the same or higher priority, it interrupts the current sample;
    - Otherwise, it's completely ignored and current sample takes precedence.

## How It Works

When you define a sample in a [Sample table](./Sample_table_format.md), you can specify sample kind (normal or SFX) and priority level in flags field, e.g.:

```m68k
SampleTable:
;name?              type            pointer     Hz?     flags?
        dcSample    TYPE_DPCM,      Kick,       8000
        dcSample    TYPE_PCM,       Snare,      0       PRIO_HIGHEST
        dcSample    TYPE_DPCM,      Timpani,    7250
sfx:    dcSample    TYPE_PCM,       MySFX,      22050,  FLAGS_SFX
sfx2:   dcSample    TYPE_PCM,       MySFX2,     0,      FLAGS_SFX|PRIO_HIGH
sfx3:   dcSample    TYPE_PCM,       MySFX2,     0,      FLAGS_SFX|PRIO_LOW
        dc.w    -1  ; end marker
```

In this example, sample priorities go as follows:

1. `sfx2` has the top priority of all samples in the table (`FLAGS_SFX|PRIO_HIGH`)
2. Then comes `sfx` with normal SFX priority (if `PRIO_*` flag is not specified, it defaults to `PRIO_NORMAL`)
3. Then comes `sfx3` with low SFX priority (`FLAGS_SFX|PRIO_LOW`)
4. Then comes "Snare" with higest non-SFX priority (`PRIO_HIGHEST`)
5. Finally, all other samples (Kick, Snare, Timpani) share the same, even lower priority level (non-SFX normal).

## Priority Level Table

| Sample Flags             | Internal priority value   | Description                          |
|--------------------------|---------------------------|--------------------------------------|
| `PRIO_LOW`               | `00h`                     | non-SFX low                          |
| `PRIO_NORMAL`            | `10h`                     | non-SFX normal (default)             |
| `PRIO_HIGH`              | `20h`                     | non-SFX high                         |
| `PRIO_HIGHEST`           | `30h`                     | non-SFX highest                      |
| `FLAGS_SFX\|PRIO_LOW`    | `40h`                     | SFX low                              |
| `FLAGS_SFX\|PRIO_NORMAL` | `50h`                     | SFX normal (default)                 |
| `FLAGS_SFX\|PRIO_HIGH`   | `60h`                     | SFX high                             |
| `FLAGS_SFX\|PRIO_HIGHEST`| `70h`                     | SFX highest                          |

> [!NOTE]
>
> 1. `PRIO_NORMAL` flag is optional;
> 2. `FLAGS_SFX` is technically a part of internal's priorty level bitfield, which helps clear separate of non-SFX and SFX samples into distinct "priority buckets" (see `.desc` [field format](./Sample_table_format.md#named-samples));
> 3. If a new sample is requested while another is playing, Mega PCM will only accept it if new sample's internal priority value is larger or the same as the current one's.
