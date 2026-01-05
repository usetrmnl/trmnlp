const trmnlp = {};

trmnlp.connectLiveRender = function () {
  const ws = new WebSocket("/live_reload");

  ws.onopen = function () {
    console.log("Connected to live reload socket");
  };

  ws.onmessage = function (msg) {
    const payload = JSON.parse(msg.data);

    if (payload.type === "reload") {
      trmnlp.fetchPreview();
      trmnlp.userData.textContent = JSON.stringify(payload.user_data, null, 2);
      hljs.highlightAll();
    }
  };

  ws.onclose = function () {
    console.log("Reconnecting to live reload socket...");
    setTimeout(trmnlp.connectLiveRender, 1000);
  };
};


trmnlp.fetchPreview = function (pickerState) {
  const screenClasses = (pickerState?.screenClasses || trmnlp.picker.state.screenClasses).join(" ");
  const encodedScreenClasses = encodeURIComponent(screenClasses);
  let src = `/render/${trmnlp.view}.${trmnlp.formatSelect.value}?screen_classes=${encodedScreenClasses}`;

  // If requesting a PNG, also include dimensions, dark mode, and color depth
  if (trmnlp.formatSelect.value === 'png') {
    const state = pickerState || trmnlp.picker.state;
    const width = encodeURIComponent(state.width);
    const height = encodeURIComponent(state.height);
    const isDarkMode = state.isDarkMode ? 1 : 0;

    // derive numeric color depth from classes like 'screen--1bit'
    let colorDepth = 1;
    for (const c of (state.screenClasses || [])) {
      const m = c.match(/screen--(\d+)bit/);
      if (m) { colorDepth = Number(m[1]); break; }
    }

    src += `&width=${width}&height=${height}&color_depth=${encodeURIComponent(colorDepth)}`;
  }

  trmnlp.spinner.style.display = "inline-block";
  trmnlp.iframe.src = src;
};

document.addEventListener("DOMContentLoaded", async function () {
  trmnlp.view = document.querySelector("meta[name='trmnl-view']").content;
  trmnlp.iframe = document.querySelector("iframe");
  trmnlp.formatSelect = document.querySelector(".select-format");
  trmnlp.userData = document.getElementById("user-data");
  trmnlp.spinner = document.querySelector(".spinner");
  trmnlp.isLiveReloadEnabled =
    document.querySelector("meta[name='live-reload']").content === "true";

  if (trmnlp.isLiveReloadEnabled) {
    trmnlp.connectLiveRender();
  }

  const formatValue = localStorage.getItem("trmnlp-format") || "html";

  trmnlp.formatSelect.value = formatValue;
  trmnlp.formatSelect.addEventListener("change", () => {
    localStorage.setItem("trmnlp-format", trmnlp.formatSelect.value);
    trmnlp.fetchPreview();
  });

  trmnlp.iframe.addEventListener("load", () => {
    trmnlp.spinner.style.display = "none";
  });

  document.getElementById('picker-form').addEventListener('trmnl:change', (event) => {
    trmnlp.iframe.style.width = `${event.detail.width}px`;
    trmnlp.iframe.style.height = `${event.detail.height}px`;

    trmnlp.fetchPreview(event.detail);
  });

  trmnlp.picker = await TRMNLPicker.create('picker-form', { localStorageKey: 'trmnlp-picker' });
});
