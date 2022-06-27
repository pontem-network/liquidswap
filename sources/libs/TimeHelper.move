module MultiSwap::TimeHelper {
    // Errors.
    const ERR_WRONG_DURATION: u64 = 0;

    // Constants.

    // Describing possible durations as u8 numbers (e.g. similar to enums).
    /// One week.
    const D_WEEK: u8 = 0;
    /// One month.
    const D_MONTH: u8 = 1;
    /// One year.
    const D_YEAR: u8 = 2;
    /// Four years.
    const D_FOUR_YEARS: u8 = 3;

    /// One week in seconds.
    const SECONDS_IN_WEEK: u64 = 604800;

    /// Get duration (week, month, year, four years) in weeks (1 period = 1 week).
    public fun get_duration_in_weeks(duration: u8): u64 {
        if (duration == D_WEEK) {
            1
        } else if (duration == D_MONTH) {
            4
        } else if (duration == D_YEAR) {
            52
        } else if (duration == D_FOUR_YEARS) {
            208
        } else {
            abort ERR_WRONG_DURATION
        }
    }

    /// Get amount of seconds in one week.
    public fun get_seconds_in_week(): u64 {
        SECONDS_IN_WEEK
    }
}
