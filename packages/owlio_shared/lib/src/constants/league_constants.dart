/// Zone size for league promotion/demotion.
///
/// Determines how many students promote/demote per weekly reset.
/// Must match the thresholds in process_weekly_league_reset() SQL function.
int leagueZoneSize(int groupSize) {
  if (groupSize < 10) return 1;
  if (groupSize <= 25) return 2;
  if (groupSize <= 50) return 3;
  return 5;
}
