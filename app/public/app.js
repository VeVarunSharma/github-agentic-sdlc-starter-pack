const runtimeGrid = document.querySelector('.runtime-grid');
const runtimeMessage = document.querySelector('#runtime-message');
const headerStatus = document.querySelector('#header-status');
const refreshButton = document.querySelector('#refresh-status');
const copyStatus = document.querySelector('#copy-status');

function setCardState(cardId, state, value, detail) {
  const card = document.querySelector(`#${cardId}-card`);
  const valueElement = document.querySelector(`#${cardId}-value`);
  const detailElement = document.querySelector(`#${cardId}-detail`);

  card.dataset.state = state;
  valueElement.textContent = value;
  detailElement.textContent = detail;
}

function setHeaderState(state, label) {
  headerStatus.dataset.state = state;
  headerStatus.querySelector('span:last-child').textContent = label;
}

async function fetchJson(path) {
  const response = await fetch(path, {
    headers: {
      Accept: 'application/json',
    },
    cache: 'no-store',
  });

  if (!response.ok) {
    throw new Error(`${path} returned HTTP ${response.status}`);
  }

  return response.json();
}

function formatUptime(seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) {
    return 'Uptime unavailable';
  }

  if (seconds < 60) {
    return `${Math.floor(seconds)} seconds uptime`;
  }

  const minutes = Math.floor(seconds / 60);
  return `${minutes} ${minutes === 1 ? 'minute' : 'minutes'} uptime`;
}

async function loadRuntimeState() {
  runtimeGrid.setAttribute('aria-busy', 'true');
  refreshButton.disabled = true;
  setHeaderState('pending', 'Checking runtime');
  setCardState('health', 'pending', 'Checking', 'Waiting for /health');
  setCardState('version', 'pending', 'Loading', 'Waiting for /api/info');
  setCardState('runtime', 'pending', 'Node.js', 'Build metadata is loading');

  const [healthResult, infoResult] = await Promise.allSettled([
    fetchJson('/health'),
    fetchJson('/api/info'),
  ]);

  if (healthResult.status === 'fulfilled') {
    const health = healthResult.value;
    if (health.status === 'ok') {
      setCardState(
        'health',
        'success',
        'Healthy',
        formatUptime(health.uptime),
      );
      setHeaderState('success', 'Runtime healthy');
    } else {
      setCardState(
        'health',
        'error',
        'Degraded',
        'The health API did not report ok',
      );
      setHeaderState('error', 'Runtime degraded');
    }
  } else {
    setCardState(
      'health',
      'error',
      'Unavailable',
      healthResult.reason.message,
    );
    setHeaderState('error', 'Runtime unavailable');
  }

  if (infoResult.status === 'fulfilled') {
    const info = infoResult.value;
    const buildDetail = info.build.sha
      ? `Build ${info.build.sha.slice(0, 12)}`
      : 'Build SHA not supplied';
    setCardState(
      'version',
      'success',
      `v${info.version}`,
      info.name,
    );
    setCardState(
      'runtime',
      'success',
      `${info.runtime.name} ${info.runtime.node}`,
      `${info.runtime.environment} · ${buildDetail}`,
    );
  } else {
    setCardState(
      'version',
      'error',
      'Unavailable',
      infoResult.reason.message,
    );
    setCardState(
      'runtime',
      'error',
      'Metadata error',
      'Runtime details could not be loaded',
    );
  }

  const failures = [healthResult, infoResult].filter(
    (result) => result.status === 'rejected',
  ).length;
  runtimeMessage.textContent =
    failures === 0
      ? 'Live state confirmed by this running container.'
      : `${failures} live API ${failures === 1 ? 'request has' : 'requests have'} failed. No success state was inferred.`;
  runtimeGrid.setAttribute('aria-busy', 'false');
  refreshButton.disabled = false;
}

refreshButton.addEventListener('click', loadRuntimeState);

for (const button of document.querySelectorAll('[data-copy]')) {
  button.addEventListener('click', async () => {
    const source = document.querySelector(`#${button.dataset.copy}`);

    try {
      if (!navigator.clipboard) {
        throw new Error('Clipboard access is unavailable');
      }
      await navigator.clipboard.writeText(source.textContent);
      copyStatus.textContent = 'Command copied to the clipboard.';
    } catch (error) {
      copyStatus.textContent = `${error.message}. Select the command and copy it manually.`;
    }
  });
}

loadRuntimeState();
