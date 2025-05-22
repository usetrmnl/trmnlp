const trmnlp = {};

trmnlp.connectLiveRender = function () {
  const ws = new WebSocket("/live_reload");

  ws.onopen = function () {
    console.log("Connected to live reload socket");
  };

  ws.onmessage = function (msg) {
    const payload = JSON.parse(msg.data);

    if (payload.type === "reload") {
      trmnlp.setFrameSrc(trmnlp.frame._src);
      trmnlp.userData.textContent = JSON.stringify(payload.user_data, null, 2);
    }
  };

  ws.onclose = function () {
    console.log("Reconnecting to live reload socket...");
    setTimeout(trmnlp.connectLiveRender, 1000);
  };
};

trmnlp.setFrameColor = function () {
  const value = trmnlp.caseSelect.value;
  document.querySelector("trmnl-frame").setAttribute("color", value);
  localStorage.setItem("trmnlp-case", value);
};

trmnlp.setPreviewFormat = function () {
  const value = trmnlp.formatSelect.value;
  localStorage.setItem("trmnlp-format", value);

  trmnlp.setFrameSrc(`/render/${trmnlp.view}.${value}`);
};

trmnlp.setFrameSrc = function (src) {
  document.querySelector(".spinner").style.display = "inline-block";
  trmnlp.frame.setSrc(src);
};

document.addEventListener("DOMContentLoaded", function () {
  trmnlp.view = document.querySelector("meta[name='trmnl-view']").content;
  trmnlp.frame = document.querySelector("trmnl-frame");
  trmnlp.caseSelect = document.querySelector(".select-case");
  trmnlp.formatSelect = document.querySelector(".select-format");
  trmnlp.userData = document.getElementById("user-data");
  trmnlp.isLiveReloadEnabled =
    document.querySelector("meta[name='live-reload']").content === "true";

  if (trmnlp.isLiveReloadEnabled) {
    trmnlp.connectLiveRender();
  }

  const caseValue = localStorage.getItem("trmnlp-case") || "black";
  const formatValue = localStorage.getItem("trmnlp-format") || "html";

  trmnlp.caseSelect.value = caseValue;
  trmnlp.caseSelect.addEventListener("change", () => {
    trmnlp.setFrameColor();
  });

  trmnlp.formatSelect.value = formatValue;
  trmnlp.formatSelect.addEventListener("change", () => {
    trmnlp.setPreviewFormat();
  });

  trmnlp.frame._iframe.addEventListener("load", () => {
    document.querySelector(".spinner").style.display = "none";

    // On page load, trmnl-frame loads "about:blank", so wait for that to load
    // before updating the src to the preview.
    if (trmnlp.frame._src === null) {
      trmnlp.setPreviewFormat();
    }
  });

  trmnlp.setFrameColor();
});
