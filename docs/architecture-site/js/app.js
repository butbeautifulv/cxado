(function () {
  "use strict";

  const NAV_LINKS = document.querySelectorAll("nav.sidebar a[href^='#']");
  const SECTIONS = document.querySelectorAll("main section[id]");

  function setActiveNav() {
    let current = "";
    SECTIONS.forEach((sec) => {
      const top = sec.getBoundingClientRect().top;
      if (top <= 120) current = sec.id;
    });
    NAV_LINKS.forEach((a) => {
      a.classList.toggle("active", a.getAttribute("href") === "#" + current);
    });
  }

  function serviceHost() {
    const h = window.location.hostname;
    if (h === "127.0.0.1" || h === "localhost") return "localhost";
    if (h) return h;
    return window.CXADO_SERVICES?.defaultHost || "10.8.185.15";
  }

  function serviceUrl(port, path) {
    return "https://" + serviceHost() + ":" + port + (path || "/");
  }

  function renderServiceLinks() {
    const cfg = window.CXADO_SERVICES;
    if (!cfg) return;

    const hostEl = document.getElementById("services-host");
    if (hostEl) hostEl.textContent = serviceHost();

    const dock = document.getElementById("service-dock");
    const grid = document.getElementById("services-external-body");
    const internalBody = document.getElementById("services-internal-body");
    const infraBody = document.getElementById("services-infra-body");

    const groupLabel = { app: "Приложения", data: "Данные", obs: "Observability", meta: "Документация" };

    cfg.external.forEach((svc) => {
      const url = serviceUrl(svc.port, svc.path);

      if (dock) {
        const card = document.createElement("a");
        card.className = "service-card" + (svc.current ? " current" : "");
        card.href = svc.current ? "#services" : url;
        card.target = svc.current ? "_self" : "_blank";
        card.rel = "noopener noreferrer";
        card.innerHTML =
          '<span class="service-port">:' +
          svc.port +
          '</span><span class="service-name">' +
          svc.name +
          '</span><span class="service-hint">' +
          (groupLabel[svc.group] || svc.hint) +
          "</span>";
        dock.appendChild(card);
      }

      if (grid) {
        const tr = document.createElement("tr");
        const linkCell = svc.current
          ? "<em>вы здесь</em>"
          : '<a href="' + url + '" target="_blank" rel="noopener">' + url + "</a>";
        tr.innerHTML =
          "<td>:" +
          svc.port +
          "</td><td><strong>" +
          svc.name +
          "</strong></td><td>" +
          (groupLabel[svc.group] || "") +
          "</td><td class='muted'>" +
          svc.hint +
          "</td><td>" +
          linkCell +
          "</td>";
        grid.appendChild(tr);
      }
    });

    if (internalBody) {
      cfg.internal.forEach((svc) => {
        const tr = document.createElement("tr");
        const portCell = svc.port ? ":" + svc.port + " " + (svc.proto || "") : "—";
        tr.innerHTML =
          "<td>" +
          svc.name +
          "</td><td><code>" +
          svc.ns +
          "</code></td><td>" +
          portCell +
          "</td><td class='muted'>" +
          (svc.note || "ClusterIP only") +
          "</td>";
        internalBody.appendChild(tr);
      });
    }

    if (infraBody && cfg.clusterInfra) {
      cfg.clusterInfra.forEach((svc) => {
        const tr = document.createElement("tr");
        tr.innerHTML =
          "<td>" +
          svc.name +
          "</td><td><code>" +
          svc.ns +
          "</code></td><td class='muted'>" +
          (svc.note || "") +
          "</td>";
        infraBody.appendChild(tr);
      });
    }
  }

  function renderCredentials() {
    const cfg = window.CXADO_CREDENTIALS;
    if (!cfg) return;

    const warn = document.getElementById("credentials-warning");
    const body = document.getElementById("credentials-body");
    const updated = document.getElementById("credentials-updated");
    if (warn && cfg.warning) warn.textContent = "⚠ " + cfg.warning;
    if (updated && cfg.updated) updated.textContent = cfg.updated;
    if (!body) return;

    cfg.entries.forEach((entry) => {
      entry.rows.forEach((row, idx) => {
        const tr = document.createElement("tr");
        const notes =
          idx === 0 && entry.notes && entry.notes.length
            ? "<ul class='cred-notes'>" +
              entry.notes.map((n) => "<li>" + n + "</li>").join("") +
              "</ul>"
            : "";
        tr.innerHTML =
          "<td>" +
          (idx === 0 ? "<strong>" + entry.service + "</strong>" : "") +
          "</td><td>" +
          (idx === 0 ? ":" + entry.port : "") +
          "</td><td>" +
          (idx === 0 ? entry.auth || "—" : "") +
          "</td><td>" +
          (row.user || "—") +
          "</td><td>" +
          (row.password || "—") +
          "</td><td>" +
          notes +
          "</td>";
        body.appendChild(tr);
      });
    });
  }

  async function loadDiagram(container) {
    const id = container.dataset.diagram;
    const spec = window.ARCH_DIAGRAMS[id];
    if (!spec) {
      container.innerHTML = "<p class='diagram-loading'>Diagram " + id + " not found</p>";
      return;
    }
    try {
      const res = await fetch(spec.file);
      if (!res.ok) throw new Error(res.statusText);
      const src = await res.text();
      const pre = document.createElement("pre");
      pre.className = "mermaid";
      pre.textContent = src.trim();
      container.innerHTML = "";
      container.appendChild(pre);
      await mermaid.run({ nodes: [pre] });
      container.dataset.mermaidSrc = src.trim();
      container.dataset.diagramTitle = spec.title || id;
      container.addEventListener("click", () => openDiagramModal(container));
    } catch (err) {
      container.innerHTML =
        "<p class='diagram-loading'>Не удалось загрузить диаграмму " +
        id +
        ": " +
        err.message +
        "</p>";
    }
  }

  const diagramModal = {
    el: null,
    body: null,
    title: null,
    zoomLabel: null,
    stage: null,
    scale: 1,
    panX: 0,
    panY: 0,
    dragging: false,
    dragStartX: 0,
    dragStartY: 0,
    panStartX: 0,
    panStartY: 0,
  };

  function initDiagramModal() {
    diagramModal.el = document.getElementById("diagram-modal");
    diagramModal.body = document.getElementById("diagram-modal-body");
    diagramModal.title = document.getElementById("diagram-modal-title");
    diagramModal.zoomLabel = document.getElementById("diagram-modal-zoom");
    if (!diagramModal.el) return;

    diagramModal.el.querySelectorAll("[data-diagram-close]").forEach((btn) => {
      btn.addEventListener("click", closeDiagramModal);
    });

    diagramModal.el.querySelectorAll("[data-zoom]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const action = btn.getAttribute("data-zoom");
        if (action === "in") setDiagramZoom(diagramModal.scale * 1.25);
        else if (action === "out") setDiagramZoom(diagramModal.scale / 1.25);
        else if (action === "fit") fitDiagramZoom();
      });
    });

    diagramModal.body.addEventListener("wheel", (e) => {
      if (!diagramModal.el.classList.contains("open")) return;
      e.preventDefault();
      const factor = e.deltaY < 0 ? 1.12 : 1 / 1.12;
      setDiagramZoom(diagramModal.scale * factor);
    }, { passive: false });

    diagramModal.body.addEventListener("mousedown", (e) => {
      if (e.button !== 0) return;
      diagramModal.dragging = true;
      diagramModal.dragStartX = e.clientX;
      diagramModal.dragStartY = e.clientY;
      diagramModal.panStartX = diagramModal.panX;
      diagramModal.panStartY = diagramModal.panY;
      diagramModal.body.classList.add("dragging");
    });

    window.addEventListener("mousemove", (e) => {
      if (!diagramModal.dragging) return;
      diagramModal.panX = diagramModal.panStartX + (e.clientX - diagramModal.dragStartX);
      diagramModal.panY = diagramModal.panStartY + (e.clientY - diagramModal.dragStartY);
      applyDiagramTransform();
    });

    window.addEventListener("mouseup", () => {
      diagramModal.dragging = false;
      if (diagramModal.body) diagramModal.body.classList.remove("dragging");
    });

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") closeDiagramModal();
    });
  }

  function applyDiagramTransform() {
    if (!diagramModal.stage) return;
    diagramModal.stage.style.transform =
      "translate(" + diagramModal.panX + "px," + diagramModal.panY + "px) scale(" + diagramModal.scale + ")";
    if (diagramModal.zoomLabel) {
      diagramModal.zoomLabel.textContent = Math.round(diagramModal.scale * 100) + "%";
    }
  }

  function setDiagramZoom(scale) {
    diagramModal.scale = Math.min(4, Math.max(0.25, scale));
    applyDiagramTransform();
  }

  function fitDiagramZoom() {
    if (!diagramModal.stage || !diagramModal.body) return;
    const svg = diagramModal.stage.querySelector("svg");
    if (!svg) return;
    const pad = 48;
    const availW = diagramModal.body.clientWidth - pad;
    const availH = diagramModal.body.clientHeight - pad;
    const bbox = svg.getBoundingClientRect();
    const svgW = svg.width?.baseVal?.value || bbox.width / diagramModal.scale;
    const svgH = svg.height?.baseVal?.value || bbox.height / diagramModal.scale;
    const fit = Math.min(availW / svgW, availH / svgH, 2.5);
    diagramModal.panX = 16;
    diagramModal.panY = 16;
    setDiagramZoom(fit);
  }

  async function openDiagramModal(container) {
    if (!diagramModal.el || !diagramModal.body) return;
    const src = container.dataset.mermaidSrc;
    if (!src) return;

    diagramModal.title.textContent = container.dataset.diagramTitle || "Диаграмма";
    diagramModal.body.innerHTML = "";
    diagramModal.stage = document.createElement("div");
    diagramModal.stage.className = "diagram-modal-stage";

    const pre = document.createElement("pre");
    pre.className = "mermaid";
    pre.textContent = src;
    diagramModal.stage.appendChild(pre);
    diagramModal.body.appendChild(diagramModal.stage);

    diagramModal.panX = 16;
    diagramModal.panY = 16;
    diagramModal.scale = 1;

    diagramModal.el.classList.add("open");
    diagramModal.el.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";

    const renderId = "mermaid-modal-" + Date.now();
    const { svg } = await mermaid.render(renderId, src);
    diagramModal.stage.innerHTML = svg;
    fitDiagramZoom();
  }

  function closeDiagramModal() {
    if (!diagramModal.el) return;
    diagramModal.el.classList.remove("open");
    diagramModal.el.setAttribute("aria-hidden", "true");
    document.body.style.overflow = "";
    if (diagramModal.body) diagramModal.body.innerHTML = "";
    diagramModal.stage = null;
  }

  document.addEventListener("DOMContentLoaded", async () => {
    renderServiceLinks();
    renderCredentials();
    initDiagramModal();

    mermaid.initialize({
      startOnLoad: false,
      theme: "dark",
      securityLevel: "strict",
      flowchart: { curve: "basis", htmlLabels: true },
      sequence: { useMaxWidth: false },
    });

    const containers = document.querySelectorAll(".diagram[data-diagram]");
    for (const el of containers) {
      await loadDiagram(el);
    }
  });

  window.addEventListener("scroll", setActiveNav, { passive: true });
  setActiveNav();
})();
