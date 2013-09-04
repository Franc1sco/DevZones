/** Double-include prevention */
#if defined _devzones_included_
  #endinput
#endif
#define _devzones_included_

/**
 * Called when a player has entered in a zone.
 * @param client   client that has entered in the zone.
 * @String zone   Zone name.
 */
forward Zone_OnClientEntry(client, String:zone[]);

/**
 * Called when a player has left a zone.
 * @param client   client that has left the zone.
 * @String zone   Zone name.
 */
forward Zone_OnClientLeave(client, String:zone[]);

/**
 * Get a zone position
 * @String zone   Zone name to search position.
 * @bool caseSensitive     If true, comparison is case sensitive. If false, comparison is case insensitive.
 * @Float Position   Array when the zone position will be copied
 * @return true on successfully, false otherwise
 */
native Zone_GetZonePosition(String:zone[], bool:caseSensitive=false, Float:Position[3]);