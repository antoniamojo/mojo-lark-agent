// LaunchAgent entry point (macOS).
// macOS privacy (TCC) blocks /bin/zsh started by launchd from reading ~/Documents, ~/Desktop and
// ~/Downloads, while a node binary that already has access can. So launchd starts node, node starts
// run.sh, and the children (cc-connect, claude) inherit node's access. If your agent and workspace
// live outside those folders you can point the plist at run.sh directly instead.
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const runSh = path.join(path.dirname(fileURLToPath(import.meta.url)), 'run.sh');
const child = spawn('/bin/zsh', [runSh], { stdio: 'inherit' });
for (const sig of ['SIGTERM', 'SIGINT', 'SIGHUP']) process.on(sig, () => child.kill(sig));
child.on('exit', (code, signal) => process.exit(code ?? (signal ? 1 : 0)));
