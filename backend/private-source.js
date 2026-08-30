'use strict';

// Keep the premium proxy implementation isolated from the startup wrapper so stats/bot
// changes cannot accidentally rewrite source authorization, cloud configs, or session checks.
const core = require('./private-source-core');

const number = (value, fallback, min, max) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.max(min, Math.min(max, parsed)) : fallback;
};
const PORT = number(process.env.PORT, 3000, 1, 65535);

if (require.main === module) {
  core.server.listen(PORT, () => console.log('AetherV2 premium-source service listening on ' + PORT));
  if (process.env.DISCORD_TOKEN) {
    try {
      require('./discord-bot').startDiscordBot().catch(error => console.error('[AetherV2] Discord bot failed:', error.message || error));
    } catch (error) {
      console.error('[AetherV2] Discord bot could not start:', error.message || error);
    }
  }
}

module.exports = core;
