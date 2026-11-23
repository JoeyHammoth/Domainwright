// Domainwright site: the ladder demo mirrors the in-game power-of-two decomposition.

const POSITIVE_BITS = [64, 32, 16, 8, 4, 2, 1];
const NEGATIVE_BITS = [32, 16, 8, 4, 2, 1];

const MIN = -63;
const MAX = 127;

const rungsEl = document.getElementById("rungs");
const deltaEl = document.getElementById("delta");
const noteEl = document.getElementById("delta-note");

let delta = 0;

/** Exactly what dlc_apply_delta builds: greedy over powers of two. */
function rungsFor(value) {
  const magnitude = Math.abs(value);
  const bits = value < 0 ? NEGATIVE_BITS : POSITIVE_BITS;
  const active = [];
  let remaining = magnitude;

  for (const bit of bits) {
    if (remaining >= bit) {
      active.push(value < 0 ? -bit : bit);
      remaining -= bit;
    }
  }
  return active;
}

function render() {
  const active = new Set(rungsFor(delta));

  rungsEl.innerHTML = "";
  [...POSITIVE_BITS].reverse().forEach((bit) => pushRung(bit, active));
  NEGATIVE_BITS.forEach((bit) => pushRung(-bit, active));

  deltaEl.textContent = delta > 0 ? `+${delta}` : `${delta}`;
  deltaEl.style.color = delta === 0 ? "" : delta < 0 ? "#e08c7c" : "";

  const count = active.size;
  noteEl.textContent =
    delta === 0
      ? "no rungs applied"
      : `${count} rung${count === 1 ? "" : "s"} applied · natural limit ${delta > 0 ? "+" : "−"}${Math.abs(delta)}`;

  // Keep the outcome visible to a screen reader without re-reading the whole panel.
  rungsEl.setAttribute("aria-label", `Active modifiers: ${[...active].join(", ") || "none"}`);
}

function pushRung(bit, active) {
  const el = document.createElement("span");
  el.className = `rung ${bit < 0 ? "neg" : "pos"}${active.has(bit) ? " on" : ""}`;
  el.textContent = bit > 0 ? `+${bit}` : `${bit}`;
  rungsEl.appendChild(el);
}

function clamp(value) {
  return Math.max(MIN, Math.min(MAX, value));
}

document.querySelectorAll("[data-step]").forEach((button) => {
  button.addEventListener("click", () => {
    const step = button.dataset.step;
    delta = step === "reset" ? 0 : clamp(delta + Number(step));
    render();
  });
});

// Copy the mod path for the platform the visitor is on.
const copyButton = document.getElementById("copy");
const pathEl = document.getElementById("modpath");

if (/Mac|iPhone|iPad/.test(navigator.platform)) {
  pathEl.textContent = "~/Documents/Paradox Interactive/Crusader Kings III/mod/domainwright/";
} else if (/Linux/.test(navigator.platform)) {
  pathEl.textContent = "~/.local/share/Paradox Interactive/Crusader Kings III/mod/domainwright/";
}

copyButton?.addEventListener("click", async () => {
  const original = copyButton.textContent;
  try {
    await navigator.clipboard.writeText(pathEl.textContent);
    copyButton.textContent = "Copied";
  } catch {
    copyButton.textContent = "Select it";
  }
  setTimeout(() => {
    copyButton.textContent = original;
  }, 1600);
});

render();
