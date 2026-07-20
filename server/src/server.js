import { createApp } from './app.js';
import { loadConfig } from './config.js';
import { createRepository } from './repositories/index.js';
import { WaterService } from './waterService.js';

const config = loadConfig();
const repository = createRepository(config);
const service = new WaterService(repository, config);
const app = createApp(service);
const server = app.listen(config.serverPort, '0.0.0.0', () => {
  console.log(`喝了吗 API 已启动：http://0.0.0.0:${config.serverPort}（${config.dataMode}）`);
});

async function shutdown() {
  server.close(async () => {
    await repository.close();
    process.exit(0);
  });
}

process.once('SIGINT', shutdown);
process.once('SIGTERM', shutdown);
