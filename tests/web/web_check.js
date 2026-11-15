// Browser check of the real web export, driven by Playwright with the installed Google Chrome.
//
// 1. Copy the export to <root>/game/ and tests/web/harness.html to <root>/ (any folder outside the project).
// 2. Serve it:  python -m http.server 8831 --bind 127.0.0.1 --directory <root>   (check the port is free)
// 3. Run:       $env:NODE_PATH = "<game-sim-server>\node_modules"; $env:PORT = "8831"
//               node tests/web/web_check.js <folder for screenshots> [headed]
//    "headed" opens a visible Chrome window (real GPU); without it Chrome runs headless (software GL).
//    QUICK=1 shortens the 60 s no-input wait to 6 s.
// Exit code 0 only if every check passes. Screenshots are for a person to look at afterwards.
//
// Sound: the page's AudioBufferSourceNode.start is wrapped to count how many sounds the game starts.
// That proves the game asked the browser to play them; it does not prove a person can hear them.
const { chromium } = require('playwright');
const shots = process.argv[2] || '.';
const headed = process.argv[3] === 'headed';
const port = process.env.PORT || '8831';
const base = 'http://127.0.0.1:' + port;
const idleMs = process.env.QUICK ? 6000 : 60000;

const results = [];
function check(ok, label) {
	results.push({ ok: !!ok, label });
	console.log((ok ? '  ok    ' : '  FAIL  ') + label);
}

// Tab counts to reach a control when nothing is focused (see scripts/main.gd `_focus_ring`).
// Menu ring: Sound, Vol-, Vol+, Motion, Classroom, Abstract, Clotting, Glucose.
// Module ring starts: Menu, Next Module, Sound, Vol-, Vol+, Motion, then the module's own buttons.
const BAR = 6;

(async () => {
	const launch = { channel: 'chrome', headless: !headed };
	if (!headed) {
		launch.args = ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'];
	}
	const browser = await chromium.launch(launch);
	console.log('browser: Google Chrome ' + browser.version() + (headed ? ' (headed window)' : ' (headless)'));

	async function open(context, url) {
		await context.addInitScript(() => {
			window.__audioStarts = 0;
			const patch = (proto) => {
				if (!proto || !proto.start) return;
				const original = proto.start;
				proto.start = function (...args) { window.__audioStarts++; return original.apply(this, args); };
			};
			patch(window.AudioBufferSourceNode && window.AudioBufferSourceNode.prototype);
		});
		const page = await context.newPage();
		const logs = [];
		const requests = [];
		page.on('console', (m) => logs.push(m.text()));
		page.on('pageerror', (e) => logs.push('pageerror: ' + e.message));
		page.on('request', (r) => requests.push(r.url()));
		await page.goto(url);
		const waitLog = async (text, ms = 30000) => {
			const end = Date.now() + ms;
			while (Date.now() < end) {
				if (logs.some((l) => l.includes(text))) return true;
				await page.waitForTimeout(100);
			}
			return false;
		};
		const count = (text) => logs.filter((l) => l.includes(text)).length;
		return { page, logs, requests, waitLog, count };
	}
	const key = async (page, k, n = 1) => {
		for (let i = 0; i < n; i++) { await page.keyboard.press(k); await page.waitForTimeout(160); }
	};
	const same = (a, b) => Buffer.compare(a, b) === 0;
	const badLogs = (logs) => logs.filter((l) => /SCRIPT ERROR|pageerror|Parse Error|USER ERROR|^ERROR/.test(l));
	const gameFrame = (page) => page.frames().find((f) => f.url().includes('/game/')) || page.mainFrame();
	const audioStarts = (page) => gameFrame(page).evaluate(() => window.__audioStarts);
	// The reserved top-right corner is empty: a click there focuses the canvas and presses nothing.
	const clickEmpty = async (page, w = 1180) => {
		await gameFrame(page).click('canvas', { position: { x: w - 60, y: 14 } });
		await page.waitForTimeout(250);
	};

	// ---------- 1. Standalone tab, 1180x500: boot, no auto-play, menu by keyboard ----------
	console.log('standalone 1180x500');
	let ctx = await browser.newContext({ viewport: { width: 1180, height: 500 } });
	let s = await open(ctx, base + '/game/index.html');
	check(await s.waitLog('feedback: boot ok'), 'standalone: console shows "feedback: boot ok"');
	check(s.count('feedback: menu') === 1 && s.count('feedback: module') === 0, 'standalone: opens on the main menu');
	await s.page.waitForTimeout(1500);
	const idleA = await s.page.screenshot({ path: shots + '/web_menu.png' });
	await s.page.waitForTimeout(idleMs);
	const idleB = await s.page.screenshot();
	check(same(idleA, idleB), 'no auto-play: the frame is pixel-identical after ' + (idleMs / 1000) + ' s without input');
	check((await audioStarts(s.page)) === 0, 'no auto-play: no sound was started');
	await clickEmpty(s.page);
	await key(s.page, 'Tab', 5);
	await s.page.screenshot({ path: shots + '/web_menu_focus.png' });
	await key(s.page, 'Enter');
	check(await s.waitLog('feedback: module classroom', 3000), 'standalone: Tab x5 then Enter opens Classroom Chatter');
	await s.page.waitForTimeout(600);
	const waitA = await s.page.screenshot();
	await s.page.waitForTimeout(3000);
	const waitB = await s.page.screenshot();
	check(same(waitA, waitB) && (await audioStarts(s.page)) === 0, 'classroom: stays still and silent until Play is pressed');
	await key(s.page, 'Tab', BAR + 1);
	await key(s.page, 'Enter');
	check(await s.waitLog('feedback: classroom play', 3000), 'classroom: Tab to Play and Enter starts it');
	await s.page.waitForTimeout(9000);
	await s.page.screenshot({ path: shots + '/web_classroom_playing.png' });
	const startsPlaying = await audioStarts(s.page);
	check(startsPlaying >= 5, 'classroom: the game started sounds in the browser after Play (' + startsPlaying + ' so far)');
	await key(s.page, 'Enter');
	check(await s.waitLog('feedback: classroom pause', 3000), 'classroom: Enter on the same button pauses');
	await s.page.waitForTimeout(1200);
	const pausedA = await s.page.screenshot();
	const startsPaused = await audioStarts(s.page);
	await s.page.waitForTimeout(3000);
	const pausedB = await s.page.screenshot();
	check(same(pausedA, pausedB), 'classroom: Pause freezes the whole frame for 3 s (pixel-identical)');
	check((await audioStarts(s.page)) === startsPaused, 'classroom: no new sound starts while paused');
	await key(s.page, 'Enter');
	check(await s.waitLog('feedback: classroom finished', 70000), 'classroom: plays through to the end in the browser');
	await s.page.waitForTimeout(500);
	await s.page.screenshot({ path: shots + '/web_classroom_end.png' });
	// Mute: no sound may start on a muted bus... the game still calls play, so check the log instead.
	await key(s.page, 'Shift+Tab', 4);
	await key(s.page, 'Enter');
	check(await s.waitLog('feedback: sound off', 3000), 'bar: Sound button reachable by keyboard and switches sound off');
	await key(s.page, 'Enter');
	check(await s.waitLog('feedback: sound on', 3000), 'bar: Sound button switches sound back on');
	check(badLogs(s.logs).length === 0, 'standalone: no SCRIPT ERROR or page error in the console (' + badLogs(s.logs).slice(0, 2).join(' | ') + ')');
	const foreign = s.requests.filter((u) => !u.startsWith(base) && !u.startsWith('data:') && !u.startsWith('blob:'));
	check(foreign.length === 0, 'standalone: every network request stays on the game\'s own origin (' + s.requests.length + ' requests, ' + foreign.length + ' elsewhere)');
	await ctx.close();

	// ---------- 2. Class setting in the address ----------
	console.log('class setting ?module=');
	ctx = await browser.newContext({ viewport: { width: 1180, height: 500 } });
	s = await open(ctx, base + '/game/index.html?module=abstract');
	check(await s.waitLog('feedback: module abstract'), 'query: ?module=abstract opens Abstract Feedback directly');
	await clickEmpty(s.page);
	await key(s.page, 'Tab', BAR + 1);
	await key(s.page, 'Enter');
	check(await s.waitLog('feedback: abstract play', 3000), 'abstract: Play starts from the keyboard');
	await s.page.waitForTimeout(8000);
	await s.page.screenshot({ path: shots + '/web_abstract_negative.png' });
	check((await audioStarts(s.page)) >= 1, 'abstract: a BIP / BOOP sound was started');
	await key(s.page, 'Tab', 2);
	await key(s.page, 'Enter');
	check(await s.waitLog('feedback: abstract skip', 3000), 'abstract: Skip Part works from the keyboard');
	await s.page.waitForTimeout(9000);
	await s.page.screenshot({ path: shots + '/web_abstract_positive.png' });
	check(badLogs(s.logs).length === 0, 'abstract: no SCRIPT ERROR or page error');
	await s.page.close();
	s = await open(ctx, base + '/game/index.html?module=nonsense&debug=1');
	check(await s.waitLog('feedback: menu') && s.count('feedback: module') === 0, 'query: an unknown value is ignored (menu shown)');
	await ctx.close();

	// ---------- 3. The two experiments, keyboard only ----------
	console.log('experiments');
	ctx = await browser.newContext({ viewport: { width: 1180, height: 500 } });
	s = await open(ctx, base + '/game/index.html?module=clotting');
	check(await s.waitLog('feedback: module clotting'), 'clotting: opens');
	await s.page.waitForTimeout(800);
	await s.page.screenshot({ path: shots + '/web_clotting_setup.png' });
	await clickEmpty(s.page);
	await key(s.page, 'Tab', BAR + 4); // Wound, Platelets, Signals, Start
	await key(s.page, 'Enter');
	check(await s.waitLog('feedback: clotting start', 3000), 'clotting: Start Experiment from the keyboard');
	await s.page.waitForTimeout(9000);
	await s.page.screenshot({ path: shots + '/web_clotting_running.png' });
	check(await s.waitLog('feedback: clotting results', 60000), 'clotting: the experiment finishes and shows results');
	await s.page.waitForTimeout(600);
	await clickEmpty(s.page);
	await key(s.page, 'Tab', BAR + 1); // Replay
	await key(s.page, 'Enter');
	check(await s.waitLog('feedback: clotting replay on', 3000), 'clotting: Replay from the keyboard');
	await s.page.waitForTimeout(5000);
	await s.page.screenshot({ path: shots + '/web_clotting_replay.png' });
	check(badLogs(s.logs).length === 0, 'clotting: no SCRIPT ERROR or page error');
	await s.page.close();

	s = await open(ctx, base + '/game/index.html?module=glucose');
	check(await s.waitLog('feedback: module glucose'), 'glucose: opens');
	await clickEmpty(s.page);
	await key(s.page, 'Tab', BAR + 3); // Fasting, Advanced, Start (Meal and Exercise are disabled)
	await key(s.page, 'Enter');
	check(await s.waitLog('feedback: glucose start', 3000), 'glucose: Start Experiment from the keyboard');
	await s.page.waitForTimeout(2000);
	await key(s.page, 'Shift+Tab', 4); // back past Advanced, Fasting, Exercise to Eat a Meal
	await key(s.page, 'Enter');
	check(await s.waitLog('feedback: glucose meal', 3000), 'glucose: Eat a Meal from the keyboard');
	await s.page.waitForTimeout(11000);
	await s.page.screenshot({ path: shots + '/web_glucose_meal.png' });
	await key(s.page, 'Tab');
	await key(s.page, 'Enter');
	check(await s.waitLog('feedback: glucose exercise', 3000), 'glucose: Exercise from the keyboard');
	check(await s.waitLog('feedback: glucose results', 80000), 'glucose: the experiment runs its full length and shows results');
	await s.page.waitForTimeout(600);
	await s.page.screenshot({ path: shots + '/web_glucose_results.png' });
	check(badLogs(s.logs).length === 0, 'glucose: no SCRIPT ERROR or page error');
	await ctx.close();

	// ---------- 4. Same-origin iframe: the keyboard boundary ----------
	console.log('iframe 1180x500, keyboard boundary');
	ctx = await browser.newContext({ viewport: { width: 1240, height: 620 } });
	s = await open(ctx, base + '/harness.html');
	const leaves = () => s.page.evaluate(() => window.leaves);
	const active = () => s.page.evaluate(() => document.activeElement && document.activeElement.id);
	check(await s.waitLog('feedback: boot ok'), 'iframe: console shows "feedback: boot ok"');
	await s.page.waitForTimeout(1000);
	await s.page.screenshot({ path: shots + '/web_iframe_1180x500.png' });
	await clickEmpty(s.page);
	await key(s.page, 'Tab', 8);
	check((await leaves()) === 0, 'iframe: Tab walks all 8 menu controls without leaving');
	await key(s.page, 'Tab');
	check((await leaves()) === 1 && (await active()) === 'fs', 'iframe: Tab past the last control sends sims:leave-game and focus lands on the host\'s Full screen button');
	await clickEmpty(s.page);
	await key(s.page, 'Tab');
	await key(s.page, 'Shift+Tab');
	check((await leaves()) === 2 && (await active()) === 'fs', 'iframe: Shift+Tab before the first control leaves to the host');
	await clickEmpty(s.page);
	await key(s.page, 'Escape');
	check((await leaves()) === 3 && (await active()) === 'fs', 'iframe: Escape leaves to the host');
	check(badLogs(s.logs).length === 0, 'iframe: no SCRIPT ERROR or page error');
	await ctx.close();

	// ---------- 5. Other frame sizes (screenshots to inspect; boot and errors checked) ----------
	const variants = [
		{ name: 'iframe_1180x360', w: 1180, h: 360, dpr: 1, q: 'module=clotting' },
		{ name: 'iframe_dpr1_5', w: 1180, h: 500, dpr: 1.5, q: 'module=classroom' },
		{ name: 'iframe_1366x768_wide', w: 1366, h: 640, dpr: 1, q: 'module=glucose' },
		{ name: 'iframe_phone_like_380x640', w: 380, h: 640, dpr: 2, q: 'module=glucose' },
	];
	for (const v of variants) {
		console.log(v.name);
		ctx = await browser.newContext({ viewport: { width: v.w + 60, height: v.h + 120 }, deviceScaleFactor: v.dpr });
		s = await open(ctx, base + '/harness.html?w=' + v.w + '&h=' + v.h + '&q=' + encodeURIComponent(v.q));
		check(await s.waitLog('feedback: boot ok'), v.name + ': boots');
		await s.page.waitForTimeout(1200);
		await s.page.screenshot({ path: shots + '/web_' + v.name + '.png' });
		check(badLogs(s.logs).length === 0, v.name + ': no SCRIPT ERROR or page error');
		await ctx.close();
	}

	await browser.close();
	const failed = results.filter((r) => !r.ok).length;
	console.log('WEB CHECK: ' + (results.length - failed) + '/' + results.length + ' passed -> ' + (failed === 0 ? 'PASS' : 'FAIL'));
	process.exit(failed === 0 ? 0 : 1);
})().catch((e) => { console.error(e); process.exit(2); });
