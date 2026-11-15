(() => {
	"use strict";

	// ok so the release asset names are fixed by release.yml, only the version and sizes move
	const REPO = "farfromoffice/margin";

	function detectOs() {
		const p = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || navigator.userAgent;
		if (/win/i.test(p)) return "windows";
		if (/linux|x11/i.test(p) && !/android/i.test(navigator.userAgent)) return "linux";
		return null;
	}

	// put the visitor's own platform first in the hero and mark its card
	const os = detectOs();
	if (os) {
		const actions = document.querySelector("[data-download]");
		const mine = actions && actions.querySelector(`[data-os="${os}"]`);
		if (mine && actions.firstElementChild !== mine) {
			const other = actions.firstElementChild;
			actions.insertBefore(mine, other);
			mine.classList.replace("btn--ghost", "btn--primary");
			other.classList.replace("btn--primary", "btn--ghost");
		}
		document.querySelectorAll(`.platform[data-os="${os}"]`).forEach((el) => el.classList.add("is-mine"));
	}

	// version and file sizes from the latest release; the page reads fine if this fails
	fetch(`https://api.github.com/repos/${REPO}/releases/latest`, { headers: { Accept: "application/vnd.github+json" } })
		.then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
		.then((rel) => {
			const name = document.querySelector("[data-release-name]");
			if (name && rel.tag_name) name.textContent = `Version ${rel.tag_name.replace(/^v/, "")}`;
			for (const asset of rel.assets || []) {
				const mb = Math.round(asset.size / 1e6);
				document.querySelectorAll(`[data-size="${CSS.escape(asset.name)}"]`).forEach((el) => {
					el.textContent = ` · ${mb} MB`;
				});
			}
		})
		.catch(() => {});

	// the loop tabs swap one screenshot; arrow keys move between them like a real tablist
	const tabs = [...document.querySelectorAll(".loop__tab")];
	const panel = document.getElementById("panel-loop");
	const shot = panel && panel.querySelector("img");
	const reduce = window.matchMedia("(prefers-reduced-motion: reduce)");
	let pendingSwap = 0;

	function select(tab, focus) {
		// a swap still fading out belongs to the old tab, drop it before anything else
		clearTimeout(pendingSwap);
		shot.classList.remove("is-swapping");
		tabs.forEach((t) => {
			const on = t === tab;
			t.setAttribute("aria-selected", String(on));
			t.tabIndex = on ? 0 : -1;
		});
		panel.setAttribute("aria-labelledby", tab.id);
		if (focus) tab.focus();
		if (shot.getAttribute("src") === tab.dataset.shot) return;
		const swap = () => {
			shot.src = tab.dataset.shot;
			shot.alt = tab.dataset.alt;
			shot.classList.remove("is-swapping");
		};
		if (reduce.matches) return swap();
		shot.classList.add("is-swapping");
		pendingSwap = setTimeout(swap, 180);
	}

	tabs.forEach((tab, i) => {
		tab.addEventListener("click", () => select(tab, false));
		tab.addEventListener("keydown", (e) => {
			const step = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 }[e.key];
			if (step) {
				e.preventDefault();
				select(tabs[(i + step + tabs.length) % tabs.length], true);
			} else if (e.key === "Home" || e.key === "End") {
				e.preventDefault();
				select(tabs[e.key === "Home" ? 0 : tabs.length - 1], true);
			}
		});
	});

	// click to load the video, so YouTube only shows up when someone asks for it
	const frame = document.querySelector("[data-video]");
	if (frame) {
		frame.querySelector(".watch__poster").addEventListener("click", (e) => {
			e.preventDefault();
			const iframe = document.createElement("iframe");
			iframe.src = `https://www.youtube-nocookie.com/embed/${frame.dataset.video}?autoplay=1&rel=0`;
			iframe.title = "Margin gameplay video";
			iframe.allow = "autoplay; encrypted-media; picture-in-picture; fullscreen";
			iframe.allowFullscreen = true;
			frame.replaceChildren(iframe);
			iframe.focus();
		});
	}
})();
