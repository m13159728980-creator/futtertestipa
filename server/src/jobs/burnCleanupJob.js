function createBurnCleanupJob({ messageService, notifier, intervalMs = 1000 } = {}) {
  let timer = null;

  async function runOnce() {
    const expired = await messageService.expireBurnedMessages();
    for (const result of expired) {
      if (notifier) {
        notifier(result.targets, 'message.burn.expire', { message: result.message });
      }
    }
    return expired;
  }

  function start() {
    if (!timer) {
      timer = setInterval(runOnce, intervalMs);
    }
    return timer;
  }

  function stop() {
    if (timer) {
      clearInterval(timer);
      timer = null;
    }
  }

  return {
    runOnce,
    start,
    stop
  };
}

module.exports = {
  createBurnCleanupJob
};
