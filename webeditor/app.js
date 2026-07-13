/* FS25 Workflow Manager — Web Editor
   Standalone static app: edits workflows compatible with the in-game
   WorkflowStorage.lua format (workflowManager.xml, formatVersion 2). */

"use strict";

/* ============================================================
   Constants (mirror src/WorkflowManager.lua)
   ============================================================ */

const STEP_AUTODRIVE = "autodrive";
const STEP_COURSEPLAY = "courseplay";
const STEP_WAIT_FOR_LEADER = "wait_for_leader";
const STEP_UNLOCK_FOLLOWER = "unlock_follower";
const STEP_PARK = "park";
const STEP_REFUEL = "refuel";
const STEP_REPAIR = "repair";

const STEP_TYPES = [STEP_AUTODRIVE, STEP_COURSEPLAY, STEP_WAIT_FOR_LEADER, STEP_UNLOCK_FOLLOWER, STEP_PARK, STEP_REFUEL, STEP_REPAIR];
const AD_ACTIONS = ["drive", "pickup_deliver", "deliver", "load", "unload"];
const CP_ACTIONS = ["fieldwork", "bale_collect"];

// "Marker" here means "no target/action fields" (sync markers, plus Park/Refuel/Repair,
// which AD resolves automatically) — mirrors WorkflowManager:isTargetlessStepType in-game.
const isMarkerType = (t) => t === STEP_WAIT_FOR_LEADER || t === STEP_UNLOCK_FOLLOWER
  || t === STEP_PARK || t === STEP_REFUEL || t === STEP_REPAIR;
const actionNeedsUnloadTarget = (type, action) =>
  type === STEP_AUTODRIVE && (action === "unload" || action === "pickup_deliver" || action === "load");
const actionNeedsFillType = (type, action) =>
  type === STEP_AUTODRIVE && (action === "pickup_deliver" || action === "load");

/* ============================================================
   i18n (labels match translations/translation_en.xml / _de.xml)
   ============================================================ */

const I18N = {
  en: {
    appTitle: "Workflow Manager", appSubtitle: "FS25 Web Editor",
    targetsBtn: "Targets", importBtn: "Import XML", exportBtn: "Export XML",
    searchPlaceholder: "Search workflows…", newWorkflow: "New workflow",
    emptyTitle: "Plan your farm's day — before you even start the game",
    emptyText: "Create AutoDrive & Courseplay workflows here, then export workflowManager.xml into your savegame folder.",
    emptyHint: "Tip: you can also drop a workflowManager.xml file anywhere on this page.",
    namePlaceholder: "Workflow name", duplicate: "Duplicate", delete: "Delete", cancel: "Cancel",
    save: "Save", add: "Add", done: "Done",
    adSettingsTitle: "AD / CP Settings",
    adSettingsHint: "Per-workflow AutoDrive overrides. Leave a field empty to use AutoDrive's own setting.",
    unloadFill: "Unload Fill Level", pipeOffset: "Pipe Offset", preCall: "Pre-Call Level",
    steps: "Steps", addStep: "Add step", addSupport: "Add support step",
    noSteps: "No steps defined. Click “Add step” to create the first one.",
    typeAd: "AutoDrive", typeCp: "Courseplay", typeWait: "Wait for Leader", typeUnlock: "Unlock Follower",
    typePark: "Park", typeRefuel: "Refuel", typeRepair: "Repair",
    type: "Type", mode: "Mode", action: "Action", target: "Target",
    pickup: "Pickup", loadAt: "Load At", unloadFirst: "Unload", deliverTo: "Deliver To", returnTo: "Return To",
    fillTypes: "Fill Types", fillSearchPh: "Search fill types…",
    dialogAddStep: "Add Step", dialogEditStep: "Edit Step",
    dialogAddSupport: "Add Support Step", dialogEditSupport: "Edit Support Step",
    markerWaitInfo: "Sync marker: the vehicle waits here until its leader passes the matching “Unlock Follower” marker. No target or action needed.",
    markerUnlockInfo: "Sync marker: passing this step releases followers waiting at their matching “Wait for Leader” marker. No target or action needed.",
    parkInfo: "Drives to the vehicle's AutoDrive park position (checking its rear-attached implement first, then the vehicle itself). No target or action needed — configure the park position in AutoDrive.",
    refuelInfo: "Drives to the nearest AutoDrive-reachable fuel station matching the vehicle's fuel type. No target or action needed. If the vehicle is already fueled or no station is reachable, the step completes immediately instead of failing.",
    repairInfo: "Drives to the nearest AutoDrive-reachable workshop and repairs the vehicle. No target or action needed. Fails if no repair station is reachable.",
    actionNames: {
      drive: "Drive To", pickup_deliver: "Pickup and Deliver", deliver: "Deliver",
      load: "Load", unload: "Unload Combine", fieldwork: "Field Work", bale_collect: "Bale Collect",
    },
    targetsTitle: "Targets & Courses",
    targetsHint: "The game reads AutoDrive destinations and Courseplay courses live — the browser can't. Maintain the lists here so step dialogs offer suggestions. Names found in imported workflows are added automatically.",
    adDests: "AutoDrive destinations", cpCourses: "Courseplay courses",
    addDestPh: "Add destination…", addCoursePh: "Add course…",
    importAdConfig: "Import from AutoDrive_config.xml", importCpCourses: "Import course files (.xml)",
    noEntries: "No entries yet",
    noMatches: "No matches — free text is kept as-is",
    targetHintAd: "AutoDrive map marker name. Manage suggestions under “Targets”.",
    targetHintCp: "Courseplay course name (with folder prefix if used). Manage suggestions under “Targets”.",
    confirmDeleteWf: (n) => `Delete workflow “${n}”?`,
    confirmDeleteStep: "Delete this step (including its support steps)?",
    confirmDeleteSupport: "Delete this support step?",
    copySuffix: "(Copy)", newWfName: "New Workflow", unnamed: "Unnamed",
    stepCount: (n) => `${n} step${n === 1 ? "" : "s"}`,
    wfCount: (n) => `${n} workflow${n === 1 ? "" : "s"}`,
    supportCount: (n) => `${n} support`,
    toastImported: (n) => `Imported ${n} workflow(s)`,
    toastImportFailed: "Import failed: not a valid workflowManager.xml",
    toastExported: "workflowManager.xml downloaded — place it in your savegame folder",
    toastNothingToExport: "Nothing to export — create a workflow first",
    toastAdImported: (n) => `Imported ${n} AutoDrive destination(s)`,
    toastAdImportFailed: "No map markers found in that file",
    toastCpImported: (n) => `Imported ${n} course name(s)`,
    toastMigrated: "Old save format detected — migrated automatically",
    settingsSet: (n) => `${n} override(s) set`, settingsNone: "using AutoDrive defaults",
    validationMissingTarget: "Target missing",
    metaId: "ID", metaSteps: "Steps", metaSupport: "Support steps",
    moveUp: "Move up", moveDown: "Move down", edit: "Edit", langName: "EN",
    dropHere: "Drop workflowManager.xml to import",
  },
  de: {
    appTitle: "Workflow Manager", appSubtitle: "FS25 Web-Editor",
    targetsBtn: "Ziele", importBtn: "XML importieren", exportBtn: "XML exportieren",
    searchPlaceholder: "Workflows suchen…", newWorkflow: "Neuer Workflow",
    emptyTitle: "Plane den Hoftag — noch bevor das Spiel startet",
    emptyText: "Erstelle hier AutoDrive- & Courseplay-Workflows und exportiere workflowManager.xml in deinen Spielstand-Ordner.",
    emptyHint: "Tipp: Du kannst eine workflowManager.xml auch einfach auf diese Seite ziehen.",
    namePlaceholder: "Workflow-Name", duplicate: "Duplizieren", delete: "Löschen", cancel: "Abbrechen",
    save: "Speichern", add: "Hinzufügen", done: "Fertig",
    adSettingsTitle: "AD / CP Einstellungen",
    adSettingsHint: "AutoDrive-Überschreibungen pro Workflow. Leere Felder verwenden die AutoDrive-Einstellung.",
    unloadFill: "Abladen ab Level", pipeOffset: "Offset Rohr", preCall: "Vorab-Ruf Level",
    steps: "Schritte", addStep: "Schritt hinzufügen", addSupport: "Unterstützungsschritt hinzufügen",
    noSteps: "Keine Schritte definiert. Klicke auf „Schritt hinzufügen“.",
    typeAd: "AutoDrive", typeCp: "Courseplay", typeWait: "Auf Anführer warten", typeUnlock: "Folger freigeben",
    typePark: "Parken", typeRefuel: "Auftanken", typeRepair: "Reparieren",
    type: "Typ", mode: "Modus", action: "Aktion", target: "Ziel",
    pickup: "Abholung", loadAt: "Beladen bei", unloadFirst: "Entladen", deliverTo: "Liefern an", returnTo: "Zurück zu",
    fillTypes: "Fülltypen", fillSearchPh: "Fülltypen suchen…",
    dialogAddStep: "Schritt hinzufügen", dialogEditStep: "Schritt bearbeiten",
    dialogAddSupport: "Unterstützungsschritt hinzufügen", dialogEditSupport: "Unterstützungsschritt bearbeiten",
    markerWaitInfo: "Sync-Marker: Das Fahrzeug wartet hier, bis sein Anführer den passenden „Folger freigeben“-Marker passiert. Kein Ziel/keine Aktion nötig.",
    markerUnlockInfo: "Sync-Marker: Beim Passieren dieses Schritts werden Folger freigegeben, die an ihrem „Auf Anführer warten“-Marker warten. Kein Ziel/keine Aktion nötig.",
    parkInfo: "Fährt zur in AutoDrive konfigurierten Parkposition des Fahrzeugs (zuerst wird das rückseitig angehängte Gerät geprüft, dann das Fahrzeug selbst). Kein Ziel/keine Aktion nötig — die Parkposition wird in AutoDrive konfiguriert.",
    refuelInfo: "Fährt zur nächsten über AutoDrive erreichbaren Tankstelle für den benötigten Kraftstofftyp. Kein Ziel/keine Aktion nötig. Ist das Fahrzeug bereits betankt oder keine Tankstelle erreichbar, wird der Schritt sofort abgeschlossen statt fehlzuschlagen.",
    repairInfo: "Fährt zur nächsten über AutoDrive erreichbaren Werkstatt und repariert das Fahrzeug. Kein Ziel/keine Aktion nötig. Schlägt fehl, wenn keine Werkstatt erreichbar ist.",
    actionNames: {
      drive: "Fahren zu", pickup_deliver: "Abholen und Liefern", deliver: "Abladen",
      load: "Abholen", unload: "Drescher abfahren", fieldwork: "Feldarbeit", bale_collect: "Ballen sammeln",
    },
    targetsTitle: "Ziele & Kurse",
    targetsHint: "Das Spiel liest AutoDrive-Ziele und Courseplay-Kurse live — der Browser kann das nicht. Pflege die Listen hier, damit die Schritt-Dialoge Vorschläge anbieten. Namen aus importierten Workflows werden automatisch ergänzt.",
    adDests: "AutoDrive-Ziele", cpCourses: "Courseplay-Kurse",
    addDestPh: "Ziel hinzufügen…", addCoursePh: "Kurs hinzufügen…",
    importAdConfig: "Aus AutoDrive_config.xml importieren", importCpCourses: "Kursdateien importieren (.xml)",
    noEntries: "Noch keine Einträge",
    noMatches: "Keine Treffer — Freitext wird übernommen",
    targetHintAd: "Name des AutoDrive-Kartenmarkers. Vorschläge unter „Ziele“ verwalten.",
    targetHintCp: "Courseplay-Kursname (ggf. mit Ordner-Präfix). Vorschläge unter „Ziele“ verwalten.",
    confirmDeleteWf: (n) => `Workflow „${n}“ löschen?`,
    confirmDeleteStep: "Diesen Schritt (inkl. Unterstützungsschritte) löschen?",
    confirmDeleteSupport: "Diesen Unterstützungsschritt löschen?",
    copySuffix: "(Kopie)", newWfName: "Neuer Workflow", unnamed: "Unbenannt",
    stepCount: (n) => `${n} Schritt${n === 1 ? "" : "e"}`,
    wfCount: (n) => `${n} Workflow${n === 1 ? "" : "s"}`,
    supportCount: (n) => `${n} Support`,
    toastImported: (n) => `${n} Workflow(s) importiert`,
    toastImportFailed: "Import fehlgeschlagen: keine gültige workflowManager.xml",
    toastExported: "workflowManager.xml heruntergeladen — in den Spielstand-Ordner legen",
    toastNothingToExport: "Nichts zu exportieren — erstelle zuerst einen Workflow",
    toastAdImported: (n) => `${n} AutoDrive-Ziel(e) importiert`,
    toastAdImportFailed: "Keine Kartenmarker in der Datei gefunden",
    toastCpImported: (n) => `${n} Kursname(n) importiert`,
    toastMigrated: "Altes Speicherformat erkannt — automatisch migriert",
    settingsSet: (n) => `${n} Überschreibung(en) gesetzt`, settingsNone: "AutoDrive-Standard",
    validationMissingTarget: "Ziel fehlt",
    metaId: "ID", metaSteps: "Schritte", metaSupport: "Unterstützungsschritte",
    moveUp: "Nach oben", moveDown: "Nach unten", edit: "Bearbeiten", langName: "DE",
    dropHere: "workflowManager.xml zum Importieren ablegen",
  },
};

/* ============================================================
   FS25 base-game fill types (name = internal ID stored in XML)
   ============================================================ */

const FILL_TYPES = [
  ["WHEAT", "Wheat", "Weizen"], ["BARLEY", "Barley", "Gerste"], ["OAT", "Oat", "Hafer"],
  ["CANOLA", "Canola", "Raps"], ["SORGHUM", "Sorghum", "Hirse"], ["MAIZE", "Corn", "Mais"],
  ["SUNFLOWER", "Sunflower", "Sonnenblumen"], ["SOYBEAN", "Soybeans", "Sojabohnen"],
  ["POTATO", "Potatoes", "Kartoffeln"], ["SUGARBEET", "Sugar Beet", "Zuckerrüben"],
  ["SUGARBEET_CUT", "Sugar Beet Cuts", "Zuckerrübenschnitzel"], ["COTTON", "Cotton", "Baumwolle"],
  ["SUGARCANE", "Sugarcane", "Zuckerrohr"], ["GRAPE", "Grapes", "Trauben"], ["OLIVE", "Olives", "Oliven"],
  ["PEA", "Peas", "Erbsen"], ["SPINACH", "Spinach", "Spinat"], ["GREENBEAN", "Green Beans", "Grüne Bohnen"],
  ["RICE", "Rice", "Reis"], ["RICELONGGRAIN", "Long Grain Rice", "Langkornreis"],
  ["CARROT", "Carrots", "Karotten"], ["PARSNIP", "Parsnips", "Pastinaken"], ["BEETROOT", "Red Beet", "Rote Bete"],
  ["GRASS_WINDROW", "Grass", "Gras"], ["DRYGRASS_WINDROW", "Hay", "Heu"], ["STRAW", "Straw", "Stroh"],
  ["SILAGE", "Silage", "Silage"], ["CHAFF", "Chaff", "Häckselgut"], ["FORAGE", "Forage", "Futter"],
  ["FORAGE_MIXING", "Forage Mix", "Mischfutter"], ["WOODCHIPS", "Wood Chips", "Hackschnitzel"],
  ["MANURE", "Manure", "Mist"], ["LIQUIDMANURE", "Liquid Manure", "Gülle"], ["DIGESTATE", "Digestate", "Gärreste"],
  ["FERTILIZER", "Fertilizer", "Dünger"], ["LIQUIDFERTILIZER", "Liquid Fertilizer", "Flüssigdünger"],
  ["HERBICIDE", "Herbicide", "Herbizid"], ["LIME", "Lime", "Kalk"], ["SEEDS", "Seeds", "Saatgut"],
  ["ROADSALT", "Road Salt", "Streusalz"], ["SNOW", "Snow", "Schnee"], ["WATER", "Water", "Wasser"],
  ["DIESEL", "Diesel", "Diesel"], ["DEF", "DEF (AdBlue)", "AdBlue"], ["METHANE", "Methane", "Methan"],
  ["SILAGE_ADDITIVE", "Silage Additive", "Siliermittel"], ["MINERAL_FEED", "Mineral Feed", "Mineralfutter"],
  ["PIGFOOD", "Pig Food", "Schweinefutter"], ["STONE", "Stones", "Steine"],
  ["MILK", "Milk", "Milch"], ["BUFFALOMILK", "Buffalo Milk", "Büffelmilch"], ["GOATMILK", "Goat Milk", "Ziegenmilch"],
  ["EGG", "Eggs", "Eier"], ["WOOL", "Wool", "Wolle"], ["HONEY", "Honey", "Honig"],
  ["FLOUR", "Flour", "Mehl"], ["BREAD", "Bread", "Brot"], ["CAKE", "Cake", "Kuchen"],
  ["BUTTER", "Butter", "Butter"], ["CHEESE", "Cheese", "Käse"], ["FABRIC", "Fabric", "Stoff"],
  ["CLOTHES", "Clothes", "Kleidung"], ["SUNFLOWER_OIL", "Sunflower Oil", "Sonnenblumenöl"],
  ["CANOLA_OIL", "Canola Oil", "Rapsöl"], ["OLIVE_OIL", "Olive Oil", "Olivenöl"],
  ["GRAPEJUICE", "Grape Juice", "Traubensaft"], ["RAISINS", "Raisins", "Rosinen"],
  ["CHOCOLATE", "Chocolate", "Schokolade"], ["SUGAR", "Sugar", "Zucker"],
  ["LETTUCE", "Lettuce", "Salat"], ["TOMATO", "Tomatoes", "Tomaten"], ["STRAWBERRY", "Strawberries", "Erdbeeren"],
  ["BOARDS", "Boards", "Bretter"], ["WOODBEAM", "Wood Beams", "Holzbalken"], ["PLANKS", "Planks", "Bohlen"],
  ["FURNITURE", "Furniture", "Möbel"], ["PREFABWALL", "Prefab Walls", "Fertigwände"],
];

/* ============================================================
   State + persistence
   ============================================================ */

const LS_KEY = "fs25wm.webeditor.v1";

const state = {
  workflows: [],
  hud: null,                 // {posX, posY} preserved from import for round-trip
  selectedId: null,
  targets: { ad: [], cp: [] },
  customFillTypes: [],       // [{name, title}]
  lang: (navigator.language || "en").toLowerCase().startsWith("de") ? "de" : "en",
  theme: null,               // null = follow system
};

function saveState() {
  try {
    localStorage.setItem(LS_KEY, JSON.stringify({
      workflows: state.workflows, hud: state.hud, selectedId: state.selectedId,
      targets: state.targets, customFillTypes: state.customFillTypes,
      lang: state.lang, theme: state.theme,
    }));
  } catch (e) { /* storage full/blocked — editing still works in-memory */ }
}

function loadState() {
  try {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return;
    const data = JSON.parse(raw);
    if (Array.isArray(data.workflows)) state.workflows = data.workflows;
    if (data.hud) state.hud = data.hud;
    state.selectedId = data.selectedId || null;
    if (data.targets) state.targets = { ad: data.targets.ad || [], cp: data.targets.cp || [] };
    if (Array.isArray(data.customFillTypes)) state.customFillTypes = data.customFillTypes;
    if (data.lang === "en" || data.lang === "de") state.lang = data.lang;
    if (data.theme === "light" || data.theme === "dark") state.theme = data.theme;
  } catch (e) { /* corrupted storage — start fresh */ }
}

const t = (key, ...args) => {
  const v = I18N[state.lang][key] ?? I18N.en[key] ?? key;
  return typeof v === "function" ? v(...args) : v;
};

function commit() { saveState(); render(); }

/* ============================================================
   Model helpers
   ============================================================ */

function generateWorkflowId() {
  // Same shape as WorkflowManager:generateWorkflowId() (workflow_<time>_<rand>)
  return `workflow_${Date.now()}_${1000 + Math.floor(Math.random() * 9000)}`;
}

function newWorkflow(name) {
  return { id: generateWorkflowId(), name: name || t("newWfName"), adSettings: {}, steps: [] };
}

function selectedWorkflow() {
  return state.workflows.find((w) => w.id === state.selectedId) || null;
}

function stepTypeLabel(type) {
  switch (type) {
    case STEP_AUTODRIVE: return t("typeAd");
    case STEP_COURSEPLAY: return t("typeCp");
    case STEP_WAIT_FOR_LEADER: return t("typeWait");
    case STEP_UNLOCK_FOLLOWER: return t("typeUnlock");
    case STEP_PARK: return t("typePark");
    case STEP_REFUEL: return t("typeRefuel");
    case STEP_REPAIR: return t("typeRepair");
    default: return type;
  }
}

/** Info text shown in the step dialog for targetless types (null for AD/CP). */
function stepInfoKey(type) {
  switch (type) {
    case STEP_WAIT_FOR_LEADER: return "markerWaitInfo";
    case STEP_UNLOCK_FOLLOWER: return "markerUnlockInfo";
    case STEP_PARK: return "parkInfo";
    case STEP_REFUEL: return "refuelInfo";
    case STEP_REPAIR: return "repairInfo";
    default: return null;
  }
}

function actionLabel(action) {
  return I18N[state.lang].actionNames[action] || I18N.en.actionNames[action] || action || "";
}

function allFillTypes() {
  const base = FILL_TYPES.map(([name, en, de]) => ({ name, title: state.lang === "de" ? de : en }));
  const extra = state.customFillTypes.filter((c) => !base.some((b) => b.name === c.name));
  return base.concat(extra).sort((a, b) => a.title.localeCompare(b.title, state.lang));
}

function fillTypeTitle(name) {
  const ft = allFillTypes().find((f) => f.name === name);
  return ft ? ft.title : name;
}

function rememberTarget(kind, name) {
  if (!name) return;
  const list = state.targets[kind];
  if (!list.includes(name)) { list.push(name); list.sort((a, b) => a.localeCompare(b)); }
}

/** Collect target names used by a step into the suggestion library. */
function harvestStepTargets(step) {
  if (isMarkerType(step.type)) return;
  const kind = step.type === STEP_COURSEPLAY ? "cp" : "ad";
  rememberTarget(kind, step.target);
  if (step.unloadTarget) rememberTarget("ad", step.unloadTarget);
  if (step.fillTypes) {
    for (const name of step.fillTypes) {
      if (!FILL_TYPES.some(([n]) => n === name) && !state.customFillTypes.some((c) => c.name === name)) {
        state.customFillTypes.push({ name, title: name });
      }
    }
  }
}

/* ============================================================
   XML import (mirrors WMStorage:loadWorkflows incl. migrations)
   ============================================================ */

function parseFillTypesAttr(str) {
  if (!str) return null;
  const arr = str.split(",").map((s) => s.trim()).filter(Boolean);
  return arr.length ? arr : null;
}

function attr(el, name, fallback = null) {
  return el.hasAttribute(name) ? el.getAttribute(name) : fallback;
}
function floatAttr(el, name) {
  if (!el || !el.hasAttribute(name)) return null;
  const v = parseFloat(el.getAttribute(name));
  return Number.isFinite(v) ? v : null;
}
function boolAttr(el, name, fallback) {
  if (!el.hasAttribute(name)) return fallback;
  return el.getAttribute(name) !== "false";
}

function parseStepEl(el, withSupport) {
  const step = {
    type: attr(el, "type", STEP_AUTODRIVE),
    target: attr(el, "target", ""),
    action: attr(el, "action", "default"),
    unloadTarget: attr(el, "unloadTarget") || null,
    fillTypes: parseFillTypesAttr(attr(el, "fillTypes")) || parseFillTypesAttr(attr(el, "fillType")),
    // Legacy fields read for migration only
    syncGroup: el.hasAttribute("syncGroup") ? parseInt(el.getAttribute("syncGroup"), 10) : null,
    isSyncTarget: boolAttr(el, "isSyncTarget", true),
    isSyncSource: boolAttr(el, "isSyncSource", true),
  };
  if (withSupport) {
    step.support = [...el.children]
      .filter((c) => c.tagName === "support")
      .map((c) => parseStepEl(c, false));
  }
  return step;
}

/** Old linked-workflow-pair format -> hierarchical support format (port of Lua migration). */
function migrateOldLinkedWorkflows(workflows) {
  if (!workflows.some((wf) => wf.linkRole != null)) return { workflows, migrated: false };

  const byId = new Map(workflows.map((wf) => [wf.id, wf]));
  const toRemove = new Set();

  for (const wf of workflows) {
    if (wf.linkRole === "main" && wf.linkedWorkflowId) {
      const supportWf = byId.get(wf.linkedWorkflowId);
      if (supportWf && supportWf.linkRole === "support" && supportWf.steps.length > 0) {
        const groupSteps = new Map();
        for (const step of supportWf.steps) {
          if (step.syncGroup != null) {
            if (!groupSteps.has(step.syncGroup)) groupSteps.set(step.syncGroup, []);
            groupSteps.get(step.syncGroup).push({
              type: step.type, target: step.target, action: step.action,
              unloadTarget: step.unloadTarget, fillTypes: step.fillTypes ? [...step.fillTypes] : null,
            });
          }
        }
        const lastIndexForGroup = new Map();
        wf.steps.forEach((step, i) => {
          if (step.syncGroup != null) lastIndexForGroup.set(step.syncGroup, i);
        });
        for (const [g, idx] of lastIndexForGroup) {
          if (groupSteps.has(g)) wf.steps[idx].support = groupSteps.get(g);
        }
        toRemove.add(supportWf.id);
      }
    }
  }

  const result = workflows.filter((wf) => !toRemove.has(wf.id));
  for (const wf of result) {
    delete wf.linkedWorkflowId;
    delete wf.linkRole;
    for (const step of wf.steps) {
      if (!step.support) step.support = [];
      step.syncGroup = null;
    }
  }
  return { workflows: result, migrated: toRemove.size > 0 };
}

/** Old per-step sync flags -> explicit wait/unlock marker steps (port of Lua migration). */
function migrateSyncFlagsToMarkers(workflows, formatVersion) {
  if (formatVersion >= 2) {
    for (const wf of workflows) for (const step of wf.steps) {
      delete step.isSyncTarget; delete step.isSyncSource;
    }
    return { workflows, migrated: false };
  }
  let migrated = false;
  for (const wf of workflows) {
    const newSteps = [];
    for (const step of wf.steps) {
      if (step.isSyncSource !== false) {
        newSteps.push({ type: STEP_WAIT_FOR_LEADER, target: "", support: [] });
        migrated = true;
      }
      if (step.isSyncTarget !== false) {
        newSteps.push({ type: STEP_UNLOCK_FOLLOWER, target: "", support: [] });
        migrated = true;
      }
      delete step.isSyncTarget; delete step.isSyncSource;
      newSteps.push(step);
    }
    wf.steps = newSteps;
  }
  return { workflows, migrated };
}

function importWorkflowsXml(xmlText) {
  const doc = new DOMParser().parseFromString(xmlText, "text/xml");
  const root = doc.querySelector("WorkflowManager");
  if (!root || doc.querySelector("parsererror")) return null;

  const formatVersion = parseInt(root.getAttribute("formatVersion") || "1", 10) || 1;

  let workflows = [...root.querySelectorAll(":scope > workflows > workflow")].map((wfEl) => {
    const adEl = wfEl.querySelector(":scope > adSettings");
    return {
      id: attr(wfEl, "id", generateWorkflowId()),
      name: attr(wfEl, "name", "Unnamed Workflow"),
      linkedWorkflowId: attr(wfEl, "linkedWorkflowId"),
      linkRole: attr(wfEl, "linkRole"),
      adSettings: {
        unloadFillLevel: floatAttr(adEl, "unloadFillLevel"),
        pipeOffset: floatAttr(adEl, "pipeOffset"),
        preCallLevel: floatAttr(adEl, "preCallLevel"),
      },
      steps: [...wfEl.children].filter((c) => c.tagName === "step").map((s) => parseStepEl(s, true)),
    };
  });

  let anyMigrated = false;
  ({ workflows, migrated: anyMigrated } = migrateOldLinkedWorkflows(workflows));
  const m2 = migrateSyncFlagsToMarkers(workflows, formatVersion);
  workflows = m2.workflows;
  anyMigrated = anyMigrated || m2.migrated;

  // Normalize: drop migration-only fields, ensure arrays
  for (const wf of workflows) {
    for (const step of wf.steps) {
      delete step.syncGroup;
      if (!step.support) step.support = [];
      for (const sub of step.support) { delete sub.syncGroup; delete sub.isSyncTarget; delete sub.isSyncSource; }
    }
  }

  const hudEl = root.querySelector(":scope > settings > hud");
  const hud = hudEl ? { posX: floatAttr(hudEl, "posX"), posY: floatAttr(hudEl, "posY") } : null;

  return { workflows, hud, migrated: anyMigrated };
}

/* ============================================================
   XML export (mirrors WMStorage:saveWorkflows, formatVersion 2)
   ============================================================ */

function xmlEscape(s) {
  return String(s).replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&apos;" }[c]));
}

function fmtFloat(v) {
  // Trim trailing zeros but keep game-compatible decimal notation
  return String(Math.round(v * 1e6) / 1e6);
}

function stepAttrs(step) {
  let s = ` type="${xmlEscape(step.type)}"`;
  if (!isMarkerType(step.type)) {
    s += ` target="${xmlEscape(step.target || "")}"`;
    s += ` action="${xmlEscape(step.action || "default")}"`;
  }
  if (step.unloadTarget) s += ` unloadTarget="${xmlEscape(step.unloadTarget)}"`;
  if (step.fillTypes && step.fillTypes.length) s += ` fillTypes="${xmlEscape(step.fillTypes.join(","))}"`;
  return s;
}

function exportWorkflowsXml() {
  const lines = [];
  lines.push('<?xml version="1.0" encoding="utf-8" standalone="no"?>');
  lines.push('<WorkflowManager formatVersion="2">');
  lines.push("    <workflows>");
  for (const wf of state.workflows) {
    lines.push(`        <workflow id="${xmlEscape(wf.id)}" name="${xmlEscape(wf.name || "Unnamed Workflow")}">`);
    const s = wf.adSettings || {};
    if (s.unloadFillLevel != null || s.pipeOffset != null || s.preCallLevel != null) {
      let a = "";
      if (s.unloadFillLevel != null) a += ` unloadFillLevel="${fmtFloat(s.unloadFillLevel)}"`;
      if (s.pipeOffset != null) a += ` pipeOffset="${fmtFloat(s.pipeOffset)}"`;
      if (s.preCallLevel != null) a += ` preCallLevel="${fmtFloat(s.preCallLevel)}"`;
      lines.push(`            <adSettings${a}/>`);
    }
    for (const step of wf.steps) {
      const support = step.support || [];
      if (support.length === 0) {
        lines.push(`            <step${stepAttrs(step)}/>`);
      } else {
        lines.push(`            <step${stepAttrs(step)}>`);
        for (const sub of support) lines.push(`                <support${stepAttrs(sub)}/>`);
        lines.push("            </step>");
      }
    }
    lines.push("        </workflow>");
  }
  lines.push("    </workflows>");
  if (state.hud && state.hud.posX != null && state.hud.posY != null) {
    lines.push("    <settings>");
    lines.push(`        <hud posX="${fmtFloat(state.hud.posX)}" posY="${fmtFloat(state.hud.posY)}"/>`);
    lines.push("    </settings>");
  }
  lines.push("</WorkflowManager>");
  lines.push("");
  return lines.join("\n");
}

/* ============================================================
   AutoDrive config / CP course file import (target suggestions)
   ============================================================ */

function importAdConfigXml(xmlText) {
  const doc = new DOMParser().parseFromString(xmlText, "text/xml");
  if (doc.querySelector("parsererror")) return 0;
  const names = new Set();
  // AutoDrive config: <mapmarker><mm1><name>Field 1</name>…  (id/name variants tolerated)
  for (const mm of doc.querySelectorAll("mapmarker > *")) {
    const nameEl = mm.querySelector("name");
    const name = (nameEl ? nameEl.textContent : "").trim();
    if (name) names.add(name);
  }
  // Fallback: <marker name="..."> style
  if (names.size === 0) {
    for (const m of doc.querySelectorAll("marker[name]")) {
      const name = m.getAttribute("name").trim();
      if (name) names.add(name);
    }
  }
  let added = 0;
  for (const name of names) {
    if (!state.targets.ad.includes(name)) { state.targets.ad.push(name); added++; }
  }
  state.targets.ad.sort((a, b) => a.localeCompare(b));
  return names.size === 0 ? -1 : added;
}

function importCpCourseFiles(files) {
  let added = 0;
  for (const f of files) {
    const name = f.name.replace(/\.xml$/i, "").trim();
    if (name && !state.targets.cp.includes(name)) { state.targets.cp.push(name); added++; }
  }
  state.targets.cp.sort((a, b) => a.localeCompare(b));
  return added;
}

/* ============================================================
   DOM helpers
   ============================================================ */

const $ = (id) => document.getElementById(id);

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") node.className = v;
    else if (k === "html") node.innerHTML = v;
    else if (k.startsWith("on")) node.addEventListener(k.slice(2), v);
    else if (v != null && v !== false) node.setAttribute(k, v === true ? "" : v);
  }
  for (const c of children) {
    if (c == null) continue;
    node.append(c.nodeType ? c : document.createTextNode(c));
  }
  return node;
}

const ICONS = {
  grip: '<svg viewBox="0 0 10 18"><circle cx="2.5" cy="3" r="1.6" fill="currentColor"/><circle cx="7.5" cy="3" r="1.6" fill="currentColor"/><circle cx="2.5" cy="9" r="1.6" fill="currentColor"/><circle cx="7.5" cy="9" r="1.6" fill="currentColor"/><circle cx="2.5" cy="15" r="1.6" fill="currentColor"/><circle cx="7.5" cy="15" r="1.6" fill="currentColor"/></svg>',
  up: '<svg viewBox="0 0 24 24"><path d="m6 14 6-6 6 6" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  down: '<svg viewBox="0 0 24 24"><path d="m6 10 6 6 6-6" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  edit: '<svg viewBox="0 0 24 24"><path d="M4 20h4L19.5 8.5a2.1 2.1 0 0 0-3-3L5 17z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/></svg>',
  trash: '<svg viewBox="0 0 24 24"><path d="M4 7h16M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2m3 0-1 13a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2L6 7" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>',
  copy: '<svg viewBox="0 0 24 24"><rect x="8" y="8" width="12" height="12" rx="2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2" fill="none" stroke="currentColor" stroke-width="2"/></svg>',
  plusSub: '<svg viewBox="0 0 24 24"><path d="M8 5v10a2 2 0 0 0 2 2h3" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M17 14v6m-3-3h6" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>',
};

function miniBtn(icon, title, onClick, opts = {}) {
  const b = el("button", { class: `mini ${opts.class || ""}`, title, html: ICONS[icon] });
  if (opts.disabled) b.disabled = true;
  b.addEventListener("click", (e) => { e.stopPropagation(); onClick(); });
  return b;
}

function toast(msg, isError = false) {
  const node = el("div", { class: `toast${isError ? " error" : ""}` }, msg);
  $("toastWrap").append(node);
  setTimeout(() => { node.style.opacity = "0"; node.style.transition = "opacity .3s"; }, 3200);
  setTimeout(() => node.remove(), 3600);
}

let confirmCallback = null;
function askConfirm(text, onOk) {
  confirmCallback = onOk;
  $("confirmText").textContent = text;
  $("confirmModal").showModal();
}

/* ============================================================
   Rendering
   ============================================================ */

function applyI18nStatic() {
  document.documentElement.lang = state.lang;
  for (const node of document.querySelectorAll("[data-i18n]")) {
    node.textContent = t(node.dataset.i18n);
  }
  for (const node of document.querySelectorAll("[data-i18n-ph]")) {
    node.placeholder = t(node.dataset.i18nPh);
  }
  $("langLabel").textContent = t("langName");
  $("btnQuickWait").title = t("typeWait");
  $("btnQuickUnlock").title = t("typeUnlock");
  $("btnQuickPark").title = t("typePark");
  $("btnQuickRefuel").title = t("typeRefuel");
  $("btnQuickRepair").title = t("typeRepair");
}

function applyTheme() {
  if (state.theme) document.documentElement.dataset.theme = state.theme;
  else {
    const dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    document.documentElement.dataset.theme = dark ? "dark" : "light";
  }
  const isDark = document.documentElement.dataset.theme === "dark";
  $("iconSun").hidden = isDark;
  $("iconMoon").hidden = !isDark;
}

function render() {
  applyI18nStatic();
  renderSidebar();
  renderEditor();
}

function renderSidebar() {
  const list = $("wfList");
  const q = $("wfSearch").value.trim().toLowerCase();
  list.replaceChildren();

  const filtered = state.workflows.filter((w) => !q || (w.name || "").toLowerCase().includes(q));
  if (filtered.length === 0) {
    list.append(el("div", { class: "wf-list-empty" }, t("noEntries")));
  }
  for (const wf of filtered) {
    const supportCount = wf.steps.reduce((n, s) => n + (s.support ? s.support.length : 0), 0);
    const sub = t("stepCount", wf.steps.length) + (supportCount ? ` · ${t("supportCount", supportCount)}` : "");
    const item = el("button", { class: `wf-item${wf.id === state.selectedId ? " active" : ""}` },
      el("div", { class: "wf-item-main" },
        el("div", { class: "wf-item-name" }, wf.name || t("unnamed")),
        el("div", { class: "wf-item-sub" }, sub)),
      el("div", { class: "wf-item-actions" },
        miniBtn("copy", t("duplicate"), () => duplicateWorkflow(wf.id)),
        miniBtn("trash", t("delete"), () => requestDeleteWorkflow(wf.id), { class: "danger" })));
    item.addEventListener("click", () => { state.selectedId = wf.id; commit(); });
    list.append(item);
  }
  $("wfCount").textContent = t("wfCount", state.workflows.length);
}

function renderEditor() {
  const wf = selectedWorkflow();
  $("editorEmpty").hidden = !!wf;
  $("editorView").hidden = !wf;
  if (!wf) return;

  const nameInput = $("wfName");
  if (nameInput.value !== (wf.name || "")) nameInput.value = wf.name || "";

  const supportCount = wf.steps.reduce((n, s) => n + (s.support ? s.support.length : 0), 0);
  $("wfMeta").replaceChildren(
    el("span", {}, `${t("metaId")}: ${wf.id}`),
    el("span", {}, `${t("metaSteps")}: ${wf.steps.length}`),
    el("span", {}, `${t("metaSupport")}: ${supportCount}`),
  );

  // AD settings
  const s = wf.adSettings || {};
  setNumInput($("adUnloadFill"), s.unloadFillLevel != null ? Math.round(s.unloadFillLevel * 100) : null);
  setNumInput($("adPipeOffset"), s.pipeOffset);
  setNumInput($("adPreCall"), s.preCallLevel != null ? Math.round(s.preCallLevel * 100) : null);
  const nSet = [s.unloadFillLevel, s.pipeOffset, s.preCallLevel].filter((v) => v != null).length;
  $("adSettingsSummary").textContent = nSet ? t("settingsSet", nSet) : t("settingsNone");

  renderSteps(wf);
}

function setNumInput(input, value) {
  const str = value != null ? String(value) : "";
  if (input.value !== str && document.activeElement !== input) input.value = str;
}

function renderSteps(wf) {
  const list = $("stepList");
  list.replaceChildren();
  $("stepsEmpty").hidden = wf.steps.length > 0;

  wf.steps.forEach((step, i) => {
    const group = el("div", { class: "step-group" });
    group.append(stepRow(wf, step, i, null));
    (step.support || []).forEach((sub, j) => group.append(stepRow(wf, sub, i, j)));
    list.append(group);
  });
}

function typeBadgeClass(type) {
  if (type === STEP_AUTODRIVE) return "ad";
  if (type === STEP_COURSEPLAY) return "cp";
  return "marker";
}

function stepRow(wf, step, stepIndex, supportIndex) {
  const isSupport = supportIndex != null;
  const marker = isMarkerType(step.type);
  const missingTarget = !marker && !(step.target || "").trim();

  const row = el("div", {
    class: `step-row${isSupport ? " support-row" : ""}${missingTarget ? " invalid" : ""}`,
    draggable: "true",
  });
  row.dataset.step = stepIndex;
  if (isSupport) row.dataset.support = supportIndex;

  // drag handle
  row.append(el("span", { class: "drag", html: ICONS.grip, title: "" }));
  row.append(el("span", { class: "step-num" }, isSupport ? `${stepIndex + 1}.${supportIndex + 1}` : `${stepIndex + 1}`));

  const line1 = el("div", { class: "step-line1" },
    el("span", { class: `type-badge ${typeBadgeClass(step.type)}` }, stepTypeLabel(step.type)),
    marker ? null : el("span", { class: "step-action" }, actionLabel(step.action)));

  const main = el("div", { class: "step-main" }, line1);

  if (!marker) {
    const tgtLine = el("div", { class: "step-target-line" });
    tgtLine.append(el("span", { class: `tgt${missingTarget ? " missing" : ""}` },
      missingTarget ? `⚠ ${t("validationMissingTarget")}` : step.target));
    if (step.unloadTarget) {
      tgtLine.append(el("span", { class: "arrow" }, "→"), el("span", { class: "tgt" }, step.unloadTarget));
    }
    main.append(tgtLine);
    if (step.fillTypes && step.fillTypes.length) {
      const chips = el("div", { class: "fill-chips" });
      for (const ft of step.fillTypes) chips.append(el("span", { class: "fill-chip" }, fillTypeTitle(ft)));
      main.append(chips);
    }
  }
  row.append(main);

  const siblings = isSupport ? wf.steps[stepIndex].support : wf.steps;
  const idx = isSupport ? supportIndex : stepIndex;
  const actions = el("div", { class: "step-actions" });
  if (!isSupport) {
    actions.append(miniBtn("plusSub", t("addSupport"), () => openStepModal(wf, { stepIndex, supportIndex: null, isNewSupport: true }), { class: "support-add" }));
  }
  actions.append(
    miniBtn("up", t("moveUp"), () => moveStep(wf, stepIndex, supportIndex, -1), { disabled: idx === 0 }),
    miniBtn("down", t("moveDown"), () => moveStep(wf, stepIndex, supportIndex, +1), { disabled: idx === siblings.length - 1 }),
    miniBtn("edit", t("edit"), () => openStepModal(wf, { stepIndex, supportIndex })),
    miniBtn("copy", t("duplicate"), () => duplicateStep(wf, stepIndex, supportIndex)),
    miniBtn("trash", t("delete"), () => requestDeleteStep(wf, stepIndex, supportIndex), { class: "danger" }),
  );
  row.append(actions);

  row.addEventListener("dblclick", () => openStepModal(wf, { stepIndex, supportIndex }));
  wireStepDrag(row, wf, stepIndex, supportIndex);
  return row;
}

/* ---------- step mutations ---------- */

function moveStep(wf, stepIndex, supportIndex, delta) {
  const list = supportIndex != null ? wf.steps[stepIndex].support : wf.steps;
  const i = supportIndex != null ? supportIndex : stepIndex;
  const j = i + delta;
  if (j < 0 || j >= list.length) return;
  [list[i], list[j]] = [list[j], list[i]];
  commit();
}

function duplicateStep(wf, stepIndex, supportIndex) {
  if (supportIndex != null) {
    const sub = wf.steps[stepIndex].support[supportIndex];
    wf.steps[stepIndex].support.splice(supportIndex + 1, 0, structuredClone(sub));
  } else {
    wf.steps.splice(stepIndex + 1, 0, structuredClone(wf.steps[stepIndex]));
  }
  commit();
}

function requestDeleteStep(wf, stepIndex, supportIndex) {
  const hasSupport = supportIndex == null && (wf.steps[stepIndex].support || []).length > 0;
  const doDelete = () => {
    if (supportIndex != null) wf.steps[stepIndex].support.splice(supportIndex, 1);
    else wf.steps.splice(stepIndex, 1);
    commit();
  };
  if (supportIndex != null || hasSupport) {
    askConfirm(supportIndex != null ? t("confirmDeleteSupport") : t("confirmDeleteStep"), doDelete);
  } else {
    doDelete();
  }
}

function addMarkerStep(wf, type) {
  wf.steps.push({ type, target: "", support: [] });
  commit();
}

/* ---------- drag & drop (reorder within same level) ---------- */

let dragInfo = null;

function wireStepDrag(row, wf, stepIndex, supportIndex) {
  row.addEventListener("dragstart", (e) => {
    dragInfo = { stepIndex, supportIndex };
    row.classList.add("dragging");
    e.dataTransfer.effectAllowed = "move";
    e.dataTransfer.setData("text/plain", "");
  });
  row.addEventListener("dragend", () => {
    row.classList.remove("dragging");
    dragInfo = null;
    document.querySelectorAll(".drop-above,.drop-below").forEach((n) => n.classList.remove("drop-above", "drop-below"));
  });
  row.addEventListener("dragover", (e) => {
    if (!dragInfo) return;
    const sameLevel = (dragInfo.supportIndex == null) === (supportIndex == null)
      && (dragInfo.supportIndex == null || dragInfo.stepIndex === stepIndex);
    if (!sameLevel) return;
    e.preventDefault();
    const rect = row.getBoundingClientRect();
    const below = e.clientY > rect.top + rect.height / 2;
    row.classList.toggle("drop-above", !below);
    row.classList.toggle("drop-below", below);
  });
  row.addEventListener("dragleave", () => row.classList.remove("drop-above", "drop-below"));
  row.addEventListener("drop", (e) => {
    if (!dragInfo) return;
    e.preventDefault();
    const rect = row.getBoundingClientRect();
    const below = e.clientY > rect.top + rect.height / 2;
    if (supportIndex == null && dragInfo.supportIndex == null) {
      let to = stepIndex + (below ? 1 : 0);
      const [moved] = wf.steps.splice(dragInfo.stepIndex, 1);
      if (dragInfo.stepIndex < to) to--;
      wf.steps.splice(to, 0, moved);
    } else if (supportIndex != null && dragInfo.supportIndex != null && dragInfo.stepIndex === stepIndex) {
      const list = wf.steps[stepIndex].support;
      let to = supportIndex + (below ? 1 : 0);
      const [moved] = list.splice(dragInfo.supportIndex, 1);
      if (dragInfo.supportIndex < to) to--;
      list.splice(to, 0, moved);
    } else {
      return;
    }
    dragInfo = null;
    commit();
  });
}

/* ============================================================
   Workflow list actions
   ============================================================ */

function createWorkflow() {
  const wf = newWorkflow();
  state.workflows.push(wf);
  state.selectedId = wf.id;
  commit();
  $("wfName").focus();
  $("wfName").select();
}

function duplicateWorkflow(id) {
  const src = state.workflows.find((w) => w.id === id);
  if (!src) return;
  const copy = structuredClone(src);
  copy.id = generateWorkflowId();
  copy.name = `${src.name || t("unnamed")} ${t("copySuffix")}`;
  const idx = state.workflows.indexOf(src);
  state.workflows.splice(idx + 1, 0, copy);
  state.selectedId = copy.id;
  commit();
}

function requestDeleteWorkflow(id) {
  const wf = state.workflows.find((w) => w.id === id);
  if (!wf) return;
  askConfirm(t("confirmDeleteWf", wf.name || t("unnamed")), () => {
    const idx = state.workflows.indexOf(wf);
    state.workflows.splice(idx, 1);
    if (state.selectedId === id) {
      state.selectedId = state.workflows[Math.min(idx, state.workflows.length - 1)]?.id || null;
    }
    commit();
  });
}

/* ============================================================
   Step modal
   ============================================================ */

const modal = {
  wf: null,
  stepIndex: null,     // main step index (edit main / context for support)
  supportIndex: null,  // support index when editing a support step
  isNewSupport: false,
  isNew: false,
  type: STEP_AUTODRIVE,
  action: "drive",
  fillTypes: [],
};

function openStepModal(wf, { stepIndex = null, supportIndex = null, isNewSupport = false } = {}) {
  modal.wf = wf;
  modal.stepIndex = stepIndex;
  modal.supportIndex = supportIndex;
  modal.isNewSupport = isNewSupport;
  modal.isNew = isNewSupport || stepIndex == null;

  let existing = null;
  if (!modal.isNew) {
    existing = supportIndex != null ? wf.steps[stepIndex].support[supportIndex] : wf.steps[stepIndex];
  }

  modal.type = existing?.type || STEP_AUTODRIVE;
  modal.action = existing?.action && existing.action !== "default"
    ? existing.action
    : (modal.type === STEP_COURSEPLAY ? "fieldwork" : "drive");
  modal.fillTypes = existing?.fillTypes ? [...existing.fillTypes] : [];
  $("stepTarget").value = existing?.target || "";
  $("stepUnloadTarget").value = existing?.unloadTarget || "";
  $("fillSearch").value = "";

  const titleKey = isNewSupport ? "dialogAddSupport"
    : supportIndex != null ? "dialogEditSupport"
    : modal.isNew ? "dialogAddStep" : "dialogEditStep";
  $("stepModalTitle").textContent = t(titleKey);

  renderStepModal();
  $("stepModal").showModal();
  if (!isMarkerType(modal.type)) $("stepTarget").focus();
}

function renderStepModal() {
  // Type segmented control
  const seg = $("stepTypeSeg");
  seg.replaceChildren();
  for (const type of STEP_TYPES) {
    const cls = type === STEP_AUTODRIVE ? "t-ad" : type === STEP_COURSEPLAY ? "t-cp" : "t-marker";
    const b = el("button", { type: "button", class: `${cls}${modal.type === type ? " active" : ""}` }, stepTypeLabel(type));
    b.addEventListener("click", () => {
      if (modal.type === type) return;
      modal.type = type;
      modal.action = type === STEP_COURSEPLAY ? "fieldwork" : "drive";
      $("stepTarget").value = "";
      $("stepUnloadTarget").value = "";
      modal.fillTypes = [];
      renderStepModal();
    });
    seg.append(b);
  }

  const marker = isMarkerType(modal.type);
  $("markerInfo").hidden = !marker;
  $("fieldAction").hidden = marker;
  $("fieldTarget").hidden = marker;
  if (marker) {
    $("markerInfo").textContent = t(stepInfoKey(modal.type));
    $("fieldUnloadTarget").hidden = true;
    $("fieldFillTypes").hidden = true;
    return;
  }

  // Action select
  const actions = modal.type === STEP_AUTODRIVE ? AD_ACTIONS : CP_ACTIONS;
  if (!actions.includes(modal.action)) modal.action = actions[0];
  const sel = $("stepAction");
  sel.replaceChildren(...actions.map((a) => el("option", { value: a, selected: a === modal.action }, actionLabel(a))));
  $("actionLabel").textContent = modal.type === STEP_AUTODRIVE ? t("mode") : t("action");

  // Target labels per action (mirrors in-game dialog labels)
  let targetLabel = t("target");
  if (modal.type === STEP_AUTODRIVE) {
    if (modal.action === "unload") targetLabel = t("unloadFirst");
    else if (modal.action === "pickup_deliver") targetLabel = t("pickup");
    else if (modal.action === "load") targetLabel = t("returnTo");
  }
  $("targetLabel").textContent = targetLabel;
  $("targetHint").textContent = modal.type === STEP_AUTODRIVE ? t("targetHintAd") : t("targetHintCp");

  const needsUnload = actionNeedsUnloadTarget(modal.type, modal.action);
  $("fieldUnloadTarget").hidden = !needsUnload;
  if (needsUnload) {
    let ulLabel = t("deliverTo");
    if (modal.action === "unload") ulLabel = t("target");
    else if (modal.action === "load") ulLabel = t("loadAt");
    $("unloadTargetLabel").textContent = ulLabel;
  }

  const needsFill = actionNeedsFillType(modal.type, modal.action);
  $("fieldFillTypes").hidden = !needsFill;
  if (needsFill) renderFillPicker();
}

function saveStepModal() {
  const wf = modal.wf;
  if (!wf) return;

  let step;
  if (isMarkerType(modal.type)) {
    step = { type: modal.type, target: "" };
  } else {
    const target = $("stepTarget").value.trim();
    if (!target) { $("stepTarget").focus(); return; }
    step = { type: modal.type, action: modal.action, target };
    if (modal.type === STEP_AUTODRIVE) {
      const unload = $("stepUnloadTarget").value.trim();
      if (actionNeedsUnloadTarget(modal.type, modal.action) && unload) step.unloadTarget = unload;
      if (actionNeedsFillType(modal.type, modal.action) && modal.fillTypes.length) step.fillTypes = [...modal.fillTypes];
    }
    harvestStepTargets(step);
  }

  if (modal.isNewSupport) {
    const main = wf.steps[modal.stepIndex];
    if (!main.support) main.support = [];
    main.support.push(step);
  } else if (modal.supportIndex != null) {
    wf.steps[modal.stepIndex].support[modal.supportIndex] = step;
  } else if (modal.isNew) {
    step.support = [];
    wf.steps.push(step);
  } else {
    step.support = wf.steps[modal.stepIndex].support || [];
    wf.steps[modal.stepIndex] = step;
  }

  $("stepModal").close();
  commit();
}

/* ---------- combobox (target / unload target) ---------- */

function comboOptions(kind) {
  return kind === "cp" ? state.targets.cp : state.targets.ad;
}

function setupCombo(inputId, listId, kindFn) {
  const input = $(inputId);
  const list = $(listId);
  let hlIndex = -1;

  const close = () => { list.hidden = true; hlIndex = -1; };

  const open = () => {
    const q = input.value.trim().toLowerCase();
    const opts = comboOptions(kindFn()).filter((o) => !q || o.toLowerCase().includes(q));
    list.replaceChildren();
    if (opts.length === 0) {
      list.append(el("div", { class: "opt none" }, t("noMatches")));
    } else {
      opts.slice(0, 100).forEach((o) => {
        const div = el("div", { class: "opt" }, o);
        // mousedown so it fires before input blur
        div.addEventListener("mousedown", (e) => { e.preventDefault(); input.value = o; close(); });
        list.append(div);
      });
    }
    list.hidden = false;
    hlIndex = -1;
  };

  input.addEventListener("focus", open);
  input.addEventListener("input", open);
  input.addEventListener("blur", () => setTimeout(close, 120));
  input.addEventListener("keydown", (e) => {
    const opts = [...list.querySelectorAll(".opt:not(.none)")];
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      if (list.hidden) { open(); return; }
      e.preventDefault();
      hlIndex = e.key === "ArrowDown" ? Math.min(hlIndex + 1, opts.length - 1) : Math.max(hlIndex - 1, 0);
      opts.forEach((o, i) => o.classList.toggle("hl", i === hlIndex));
      opts[hlIndex]?.scrollIntoView({ block: "nearest" });
    } else if (e.key === "Enter") {
      if (!list.hidden && hlIndex >= 0 && opts[hlIndex]) {
        e.preventDefault();
        input.value = opts[hlIndex].textContent;
        close();
      }
    } else if (e.key === "Escape" && !list.hidden) {
      e.stopPropagation();
      close();
    }
  });
}

/* ---------- fill type picker ---------- */

function renderFillPicker() {
  const selWrap = $("fillSelected");
  selWrap.replaceChildren();
  for (const name of modal.fillTypes) {
    const chip = el("span", { class: "chip" }, fillTypeTitle(name));
    const x = el("button", { type: "button", "aria-label": "remove" }, "✕");
    x.addEventListener("click", () => {
      modal.fillTypes = modal.fillTypes.filter((n) => n !== name);
      renderFillPicker();
    });
    chip.append(x);
    selWrap.append(chip);
  }

  const q = $("fillSearch").value.trim().toLowerCase();
  const list = $("fillList");
  list.replaceChildren();
  const fts = allFillTypes().filter((f) =>
    !q || f.title.toLowerCase().includes(q) || f.name.toLowerCase().includes(q));

  if (fts.length === 0) {
    // Allow adding a custom (mod) fill type ID by typing it
    const custom = $("fillSearch").value.trim().toUpperCase().replace(/[^A-Z0-9_]/g, "");
    if (custom) {
      const addRow = el("div", { class: "ft" }, `+ "${custom}"`);
      addRow.addEventListener("click", () => {
        state.customFillTypes.push({ name: custom, title: custom });
        modal.fillTypes.push(custom);
        $("fillSearch").value = "";
        saveState();
        renderFillPicker();
      });
      list.append(addRow);
    } else {
      list.append(el("div", { class: "none" }, t("noEntries")));
    }
    return;
  }

  for (const f of fts) {
    const checked = modal.fillTypes.includes(f.name);
    const cb = el("input", { type: "checkbox" });
    cb.checked = checked;
    const row = el("label", { class: "ft" }, cb, f.title, el("span", { class: "ft-id" }, f.name));
    cb.addEventListener("change", () => {
      if (cb.checked) modal.fillTypes.push(f.name);
      else modal.fillTypes = modal.fillTypes.filter((n) => n !== f.name);
      renderFillPicker();
    });
    list.append(row);
  }
}

/* ============================================================
   Targets modal
   ============================================================ */

function renderTargetsModal() {
  for (const [kind, listId] of [["ad", "adTargetItems"], ["cp", "cpTargetItems"]]) {
    const ul = $(listId);
    ul.replaceChildren();
    const items = state.targets[kind];
    if (items.length === 0) {
      ul.append(el("li", { class: "none" }, t("noEntries")));
      continue;
    }
    for (const name of items) {
      const li = el("li", {}, el("span", { title: name }, name));
      const rm = el("button", { type: "button", "aria-label": "remove" }, "✕");
      rm.addEventListener("click", () => {
        state.targets[kind] = state.targets[kind].filter((n) => n !== name);
        saveState();
        renderTargetsModal();
      });
      li.append(rm);
      ul.append(li);
    }
  }
}

function addTargetFromInput(kind, inputId) {
  const input = $(inputId);
  const name = input.value.trim();
  if (!name) return;
  rememberTarget(kind, name);
  input.value = "";
  saveState();
  renderTargetsModal();
}

/* ============================================================
   File import / export
   ============================================================ */

function handleWorkflowFile(file) {
  file.text().then((text) => {
    const result = importWorkflowsXml(text);
    if (!result) { toast(t("toastImportFailed"), true); return; }
    state.workflows = result.workflows;
    if (result.hud && result.hud.posX != null) state.hud = result.hud;
    for (const wf of state.workflows) {
      for (const step of wf.steps) {
        harvestStepTargets(step);
        for (const sub of step.support || []) harvestStepTargets(sub);
      }
    }
    state.selectedId = state.workflows[0]?.id || null;
    if (result.migrated) toast(t("toastMigrated"));
    toast(t("toastImported", state.workflows.length));
    commit();
  });
}

function downloadExport() {
  if (state.workflows.length === 0) { toast(t("toastNothingToExport"), true); return; }
  const xml = exportWorkflowsXml();
  const blob = new Blob([xml], { type: "text/xml" });
  const a = el("a", { href: URL.createObjectURL(blob), download: "workflowManager.xml" });
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 5000);
  toast(t("toastExported"));
}

/* ============================================================
   Wiring
   ============================================================ */

function init() {
  loadState();
  applyTheme();

  // Topbar
  $("btnTheme").addEventListener("click", () => {
    const cur = document.documentElement.dataset.theme;
    state.theme = cur === "dark" ? "light" : "dark";
    saveState();
    applyTheme();
  });
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", applyTheme);

  $("btnLang").addEventListener("click", () => {
    state.lang = state.lang === "en" ? "de" : "en";
    commit();
  });

  $("btnImport").addEventListener("click", () => $("fileImport").click());
  $("btnEmptyImport").addEventListener("click", () => $("fileImport").click());
  $("fileImport").addEventListener("change", (e) => {
    if (e.target.files[0]) handleWorkflowFile(e.target.files[0]);
    e.target.value = "";
  });
  $("btnExport").addEventListener("click", downloadExport);

  $("btnTargets").addEventListener("click", () => { renderTargetsModal(); $("targetsModal").showModal(); });

  // Sidebar
  $("btnNewWorkflow").addEventListener("click", createWorkflow);
  $("btnEmptyNew").addEventListener("click", createWorkflow);
  $("wfSearch").addEventListener("input", renderSidebar);

  // Workflow header
  $("wfName").addEventListener("input", () => {
    const wf = selectedWorkflow();
    if (wf) { wf.name = $("wfName").value; saveState(); renderSidebar(); }
  });
  $("btnDuplicateWf").addEventListener("click", () => { if (state.selectedId) duplicateWorkflow(state.selectedId); });
  $("btnDeleteWf").addEventListener("click", () => { if (state.selectedId) requestDeleteWorkflow(state.selectedId); });

  // AD settings (stored like the game: fill levels as 0..1, pipe offset in meters)
  const bindAd = (inputId, key, scale) => {
    $(inputId).addEventListener("input", () => {
      const wf = selectedWorkflow();
      if (!wf) return;
      if (!wf.adSettings) wf.adSettings = {};
      const v = parseFloat($(inputId).value);
      wf.adSettings[key] = Number.isFinite(v) ? v / scale : null;
      saveState();
      const s = wf.adSettings;
      const nSet = [s.unloadFillLevel, s.pipeOffset, s.preCallLevel].filter((x) => x != null).length;
      $("adSettingsSummary").textContent = nSet ? t("settingsSet", nSet) : t("settingsNone");
    });
  };
  bindAd("adUnloadFill", "unloadFillLevel", 100);
  bindAd("adPipeOffset", "pipeOffset", 1);
  bindAd("adPreCall", "preCallLevel", 100);

  // Steps
  $("btnAddStep").addEventListener("click", () => {
    const wf = selectedWorkflow();
    if (wf) openStepModal(wf, {});
  });
  $("btnQuickWait").addEventListener("click", () => {
    const wf = selectedWorkflow();
    if (wf) addMarkerStep(wf, STEP_WAIT_FOR_LEADER);
  });
  $("btnQuickUnlock").addEventListener("click", () => {
    const wf = selectedWorkflow();
    if (wf) addMarkerStep(wf, STEP_UNLOCK_FOLLOWER);
  });
  $("btnQuickPark").addEventListener("click", () => {
    const wf = selectedWorkflow();
    if (wf) addMarkerStep(wf, STEP_PARK);
  });
  $("btnQuickRefuel").addEventListener("click", () => {
    const wf = selectedWorkflow();
    if (wf) addMarkerStep(wf, STEP_REFUEL);
  });
  $("btnQuickRepair").addEventListener("click", () => {
    const wf = selectedWorkflow();
    if (wf) addMarkerStep(wf, STEP_REPAIR);
  });

  // Step modal
  $("stepForm").addEventListener("submit", (e) => { e.preventDefault(); saveStepModal(); });
  $("stepAction").addEventListener("change", () => { modal.action = $("stepAction").value; renderStepModal(); });
  $("fillSearch").addEventListener("input", renderFillPicker);
  setupCombo("stepTarget", "targetComboList", () => (modal.type === STEP_COURSEPLAY ? "cp" : "ad"));
  setupCombo("stepUnloadTarget", "unloadComboList", () => "ad");

  // Targets modal
  $("btnAddAdTarget").addEventListener("click", () => addTargetFromInput("ad", "newAdTarget"));
  $("btnAddCpTarget").addEventListener("click", () => addTargetFromInput("cp", "newCpTarget"));
  $("newAdTarget").addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); addTargetFromInput("ad", "newAdTarget"); } });
  $("newCpTarget").addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); addTargetFromInput("cp", "newCpTarget"); } });
  $("btnImportAdConfig").addEventListener("click", () => $("fileAdConfig").click());
  $("fileAdConfig").addEventListener("change", (e) => {
    const file = e.target.files[0];
    e.target.value = "";
    if (!file) return;
    file.text().then((text) => {
      const n = importAdConfigXml(text);
      if (n < 0) toast(t("toastAdImportFailed"), true);
      else { toast(t("toastAdImported", n)); saveState(); renderTargetsModal(); }
    });
  });
  $("btnImportCpCourses").addEventListener("click", () => $("fileCpCourses").click());
  $("fileCpCourses").addEventListener("change", (e) => {
    const n = importCpCourseFiles([...e.target.files]);
    e.target.value = "";
    toast(t("toastCpImported", n));
    saveState();
    renderTargetsModal();
  });

  // Confirm modal
  $("confirmOk").addEventListener("click", () => {
    $("confirmModal").close();
    const cb = confirmCallback;
    confirmCallback = null;
    if (cb) cb();
  });
  $("confirmCancel").addEventListener("click", () => { confirmCallback = null; $("confirmModal").close(); });

  // Generic close buttons
  document.querySelectorAll("[data-close]").forEach((b) =>
    b.addEventListener("click", () => $(b.dataset.close).close()));

  // Drag & drop file import
  let dragDepth = 0;
  window.addEventListener("dragenter", (e) => {
    if ([...e.dataTransfer.types].includes("Files")) {
      dragDepth++;
      $("dropOverlay").classList.add("active");
    }
  });
  window.addEventListener("dragleave", () => {
    dragDepth = Math.max(0, dragDepth - 1);
    if (dragDepth === 0) $("dropOverlay").classList.remove("active");
  });
  window.addEventListener("dragover", (e) => {
    if ([...e.dataTransfer.types].includes("Files")) e.preventDefault();
  });
  window.addEventListener("drop", (e) => {
    dragDepth = 0;
    $("dropOverlay").classList.remove("active");
    const file = [...e.dataTransfer.files].find((f) => /\.xml$/i.test(f.name));
    if (file) { e.preventDefault(); handleWorkflowFile(file); }
  });

  render();
}

document.addEventListener("DOMContentLoaded", init);
