/// Zone size for league promotion/demotion.
///
/// With virtual bots, display size is always 30 (zone size = 5).
/// This table handles edge cases where real member count is used directly.
/// Must match the thresholds in process_weekly_league_reset() SQL function.
int leagueZoneSize(int groupSize) {
  if (groupSize < 5) return 0;
  if (groupSize < 10) return 1;
  if (groupSize < 15) return 2;
  if (groupSize < 25) return 3;
  return 5;
}
