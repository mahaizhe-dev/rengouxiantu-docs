import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

const PNG_EXTENSION = ".png";
const SOURCE_EXTENSIONS = new Set([".lua", ".json", ".xml"]);
const TIER_ICON_SLOTS = [
  "weapon",
  "helmet",
  "armor",
  "shoulder",
  "belt",
  "boots",
  "ring",
  "necklace",
  "cape",
  "exclusive",
];
const STANDARD_EQUIPMENT_SLOT_LABELS = {
  weapon: "武器",
  helmet: "头盔",
  armor: "衣甲",
  shoulder: "护肩",
  belt: "腰带",
  boots: "鞋靴",
  ring: "戒指",
  necklace: "项链",
  cape: "披风",
  treasure: "宝物",
  exclusive: "专属",
};
const STANDARD_EQUIPMENT_SLOT_ORDER = Object.keys(
  STANDARD_EQUIPMENT_SLOT_LABELS,
);
const T1_STANDARD_EQUIPMENT = new Map([
  ["icon_weapon.png", "weapon"],
  ["icon_helmet.png", "helmet"],
  ["icon_armor.png", "armor"],
  ["icon_shoulder.png", "shoulder"],
  ["icon_belt.png", "belt"],
  ["icon_boots.png", "boots"],
  ["icon_ring.png", "ring"],
  ["icon_necklace.png", "necklace"],
  ["icon_cape.png", "cape"],
  ["image/gourd_green.png", "treasure"],
  ["icon_exclusive.png", "exclusive"],
]);
const XIAN1_STANDARD_EQUIPMENT = new Map([
  ["image/icon_t11_weapon_zhexian_diagonal_20260630132255.png", "weapon"],
  ["image/icon_t11_helmet_zhexian_20260630131845.png", "helmet"],
  ["image/icon_t11_armor_zhexian_20260630131845.png", "armor"],
  ["image/icon_t11_shoulder_zhexian_20260630131845.png", "shoulder"],
  ["image/icon_t11_belt_zhexian_20260630131845.png", "belt"],
  ["image/icon_t11_boots_zhexian_20260630131939.png", "boots"],
  ["image/icon_t11_ring_zhexian_20260630131939.png", "ring"],
  ["image/icon_t11_necklace_zhexian_20260630131939.png", "necklace"],
]);
const MONSTER_CATEGORY_LABELS = {
  normal: "普通",
  elite: "精英",
  boss: "首领",
  king_boss: "王级首领",
  emperor_boss: "帝级首领",
  saint_boss: "圣级首领",
  unknown: "未标注",
};
const MONSTER_CATEGORY_ORDER = {
  normal: 0,
  elite: 1,
  boss: 2,
  king_boss: 3,
  emperor_boss: 4,
  saint_boss: 5,
  unknown: 99,
};
const MONSTER_SOURCE_GROUPS = {
  "MonsterTypes_ch1.lua": { key: "ch1", label: "第一章", order: 1 },
  "MonsterTypes_ch2.lua": { key: "ch2", label: "第二章", order: 2 },
  "MonsterTypes_ch3_Challenge.lua": {
    key: "ch3_challenge",
    label: "第三章挑战",
    order: 3.1,
  },
  "MonsterTypes_ch3_Desert.lua": {
    key: "ch3_desert",
    label: "第三章沙漠",
    order: 3,
  },
  "MonsterTypes_ch3_Reputation.lua": {
    key: "ch3_reputation",
    label: "第三章声望",
    order: 3.2,
  },
  "MonsterTypes_ch4.lua": { key: "ch4", label: "第四章", order: 4 },
  "MonsterTypes_ch5.lua": { key: "ch5", label: "第五章", order: 5 },
  "MonsterTypes_ch6.lua": { key: "ch6", label: "第六章", order: 6 },
  "MonsterTypes_xianjie.lua": {
    key: "xianjie",
    label: "仙劫战场",
    order: 7,
  },
  "MonsterTypes_xianyun.lua": {
    key: "xianyun",
    label: "仙陨战场",
    order: 8,
  },
  "MonsterTypes_training.lua": {
    key: "training",
    label: "训练场",
    order: 9,
  },
};
const SPECIAL_EQUIPMENT_SOURCE_GROUPS = {
  "EquipmentData_Special_ch1to3.lua": {
    key: "ch1to3",
    label: "第一至三章表",
    order: 1,
  },
  "EquipmentData_Special_ch4.lua": {
    key: "ch4",
    label: "第四章/法宝表",
    order: 4,
  },
  "EquipmentData_Special_ch5.lua": {
    key: "ch5",
    label: "第五章表",
    order: 5,
  },
  "EquipmentData_Special_ch6.lua": {
    key: "ch6",
    label: "第六章表",
    order: 6,
  },
};
const QUALITY_LABELS = {
  white: "白",
  green: "绿",
  blue: "蓝",
  purple: "紫",
  orange: "橙",
  cyan: "青",
  red: "红",
  gold: "金",
  rainbow: "彩",
};

function toPosix(value) {
  return value.replaceAll("\\", "/");
}

function normalizeResourcePath(value) {
  let normalized = toPosix(value.trim());
  if (!normalized || normalized.includes("://")) return null;
  if (/^[a-zA-Z]:\//.test(normalized)) return null;
  if (normalized.startsWith("/")) return null;
  normalized = normalized.replace(/^\.\/+/, "");
  normalized = normalized.replace(/^assets\//i, "");
  if (!normalized || normalized === PNG_EXTENSION) return null;
  return normalized;
}

function isImagePath(value) {
  return /\.png$/i.test(value.trim());
}

async function walkFiles(root, predicate = () => true) {
  const result = [];

  async function visit(directory) {
    let entries;
    try {
      entries = await fs.readdir(directory, { withFileTypes: true });
    } catch (error) {
      if (error.code === "ENOENT") return;
      throw error;
    }

    await Promise.all(
      entries.map(async (entry) => {
        const absolutePath = path.join(directory, entry.name);
        if (entry.isDirectory()) {
          await visit(absolutePath);
        } else if (entry.isFile() && predicate(absolutePath)) {
          result.push(absolutePath);
        }
      }),
    );
  }

  await visit(root);
  return result;
}

async function mapWithConcurrency(items, concurrency, mapper) {
  const results = new Array(items.length);
  let cursor = 0;

  async function worker() {
    while (cursor < items.length) {
      const index = cursor;
      cursor += 1;
      results[index] = await mapper(items[index], index);
    }
  }

  await Promise.all(
    Array.from({ length: Math.min(concurrency, items.length) }, () => worker()),
  );
  return results;
}

function readPngDimensions(buffer) {
  if (
    buffer.length < 24 ||
    buffer[0] !== 0x89 ||
    buffer.toString("ascii", 1, 4) !== "PNG"
  ) {
    return { width: 0, height: 0, validPng: false };
  }

  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
    validPng: true,
  };
}

function deriveArea(relativePath) {
  const parts = relativePath.split("/");
  if (parts.length === 1) return "root";
  if (parts[0].toLowerCase() === "image") return "image";
  if (parts[0].toLowerCase() === "textures") return "Textures";
  return parts[0];
}

function deriveVariantKey(stem) {
  return stem
    .toLowerCase()
    .replace(/_20\d{12}$/u, "")
    .replace(/_(?:v|r)\d+$/u, "")
    .replace(/^(?:edited|new|final|copy)_/u, "")
    .replace(/_(?:edited|new|final|copy)$/u, "");
}

function createStandardEquipmentMetadata({
  tier,
  slot,
  activeMapping,
  mappingSource,
  mappingNote = "",
  inheritedBy = [],
}) {
  return {
    tier,
    tierKey: tier === 11 ? "xian1" : `t${tier}`,
    tierLabel: tier === 11 ? "仙1" : `T${tier}`,
    slot,
    slotLabel: STANDARD_EQUIPMENT_SLOT_LABELS[slot],
    slotOrder: STANDARD_EQUIPMENT_SLOT_ORDER.indexOf(slot),
    activeMapping,
    mappingSource,
    mappingNote,
    inheritedBy,
  };
}

function classifyStandardEquipment(relativePath) {
  const lowerPath = relativePath.toLowerCase();
  const t1Slot = T1_STANDARD_EQUIPMENT.get(lowerPath);
  if (t1Slot) {
    return createStandardEquipmentMetadata({
      tier: 1,
      slot: t1Slot,
      activeMapping: true,
      mappingSource:
        t1Slot === "treasure"
          ? "SLOT_ICONS_T1.treasure / GOURD_QUALITY_ICONS.green"
          : "SLOT_ICONS_T1",
      mappingNote:
        t1Slot === "treasure" ? "宝物槽位按葫芦品质选择图标" : "",
    });
  }

  const tierMatch = lowerPath.match(
    /^icon_t(2|3|4|5|6|7|8|9|10)_(weapon|helmet|armor|shoulder|belt|boots|ring|necklace|cape|treasure|exclusive)\.png$/u,
  );
  if (tierMatch) {
    const tier = Number(tierMatch[1]);
    const slot = tierMatch[2];
    const isTreasure = slot === "treasure";
    const inheritedBy =
      tier === 10 && (slot === "cape" || slot === "exclusive") ? ["仙1"] : [];
    return createStandardEquipmentMetadata({
      tier,
      slot,
      activeMapping: !isTreasure,
      mappingSource: isTreasure
        ? "文件存在，当前 GetSlotIcon 未使用"
        : "GetSlotIcon 动态路径",
      mappingNote: isTreasure
        ? "宝物槽位改用 GOURD_QUALITY_ICONS，此图当前未接入"
        : inheritedBy.length > 0
          ? "仙1暂无专用图标时沿用此 T10 图标"
          : "",
      inheritedBy,
    });
  }

  const xian1Slot = XIAN1_STANDARD_EQUIPMENT.get(lowerPath);
  if (xian1Slot) {
    return createStandardEquipmentMetadata({
      tier: 11,
      slot: xian1Slot,
      activeMapping: true,
      mappingSource: "XIAN_SLOT_ICONS[11]",
    });
  }

  return null;
}

function lineNumberAt(text, index) {
  return text.slice(0, index).split("\n").length;
}

function extractLuaStringField(block, field) {
  const match = block.match(
    new RegExp(`^[ \\t]*${field}\\s*=\\s*([\"'])(.*?)\\1`, "mu"),
  );
  return match?.[2] ?? "";
}

function extractLuaNumberField(block, field) {
  const match = block.match(
    new RegExp(`^[ \\t]*${field}\\s*=\\s*(-?\\d+(?:\\.\\d+)?)`, "mu"),
  );
  return match ? Number(match[1]) : null;
}

function getMonsterSourceGroup(file) {
  return MONSTER_SOURCE_GROUPS[path.posix.basename(file)] ?? {
    key: "other",
    label: "其他怪物",
    order: 99,
  };
}

function getSpecialEquipmentSourceGroup(file) {
  return SPECIAL_EQUIPMENT_SOURCE_GROUPS[path.posix.basename(file)] ?? {
    key: "other",
    label: "其他来源",
    order: 99,
  };
}

function parseMonsterDefinitions(sourceTexts) {
  const definitions = [];

  for (const [file, text] of sourceTexts.entries()) {
    if (!/^scripts\/config\/MonsterTypes.*\.lua$/u.test(file)) continue;
    const entryPattern =
      /^[ \t]*M\.Types\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:dummyDef\s*)?\{/gmu;
    const matches = [...text.matchAll(entryPattern)];
    const sourceGroup = getMonsterSourceGroup(file);

    for (let index = 0; index < matches.length; index += 1) {
      const match = matches[index];
      const block = text.slice(
        match.index,
        matches[index + 1]?.index ?? text.length,
      );
      const resourcePath = normalizeResourcePath(
        extractLuaStringField(block, "portrait"),
      );
      if (!resourcePath) continue;
      const category =
        extractLuaStringField(block, "category") ||
        (sourceGroup.key === "training" ? "boss" : "unknown");

      definitions.push({
        id: match[1],
        name: extractLuaStringField(block, "name") || match[1],
        path: resourcePath,
        category,
        categoryLabel: MONSTER_CATEGORY_LABELS[category] ?? category,
        categoryOrder: MONSTER_CATEGORY_ORDER[category] ?? 99,
        sourceKey: sourceGroup.key,
        sourceLabel: sourceGroup.label,
        sourceOrder: sourceGroup.order,
        zone: extractLuaStringField(block, "zone"),
        source: {
          file,
          line: lineNumberAt(text, match.index),
        },
      });
    }
  }

  return definitions;
}

function parseSpecialEquipmentDefinitions(sourceTexts) {
  const definitions = [];

  for (const [file, text] of sourceTexts.entries()) {
    const baseName = path.posix.basename(file);
    if (!SPECIAL_EQUIPMENT_SOURCE_GROUPS[baseName]) continue;
    const entryPattern = /^    ([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{/gmu;
    const matches = [...text.matchAll(entryPattern)];
    const sourceGroup = getSpecialEquipmentSourceGroup(file);

    for (let index = 0; index < matches.length; index += 1) {
      const match = matches[index];
      const block = text.slice(
        match.index,
        matches[index + 1]?.index ?? text.length,
      );
      const resourcePath = normalizeResourcePath(
        extractLuaStringField(block, "icon"),
      );
      if (!resourcePath) continue;
      const slot = extractLuaStringField(block, "slot");
      const normalizedSlot =
        slot === "ring1" || slot === "ring2" ? "ring" : slot;
      const tier = extractLuaNumberField(block, "tier");
      const quality = extractLuaStringField(block, "quality");

      definitions.push({
        id: match[1],
        name: extractLuaStringField(block, "name") || match[1],
        path: resourcePath,
        slot,
        slotKey: normalizedSlot,
        slotLabel: STANDARD_EQUIPMENT_SLOT_LABELS[normalizedSlot] ?? slot,
        slotOrder: STANDARD_EQUIPMENT_SLOT_ORDER.indexOf(normalizedSlot),
        tier,
        tierLabel: tier === 11 ? "仙1" : tier ? `T${tier}` : "未标注",
        quality,
        qualityLabel: QUALITY_LABELS[quality] ?? quality,
        sourceKey: sourceGroup.key,
        sourceLabel: sourceGroup.label,
        sourceOrder: sourceGroup.order,
        source: {
          file,
          line: lineNumberAt(text, match.index),
        },
      });
    }
  }

  return definitions;
}

function groupConfiguredDefinitions(definitions, assetLookup, metadataKey) {
  const byPath = new Map();
  const missing = [];

  for (const definition of definitions) {
    const lowerPath = definition.path.toLowerCase();
    if (!assetLookup.has(lowerPath)) {
      missing.push(definition);
      continue;
    }
    if (!byPath.has(lowerPath)) {
      byPath.set(lowerPath, { definitions: [] });
    }
    byPath.get(lowerPath).definitions.push(definition);
  }

  for (const value of byPath.values()) {
    value.definitions.sort((left, right) =>
      left.name.localeCompare(right.name, "zh-CN"),
    );
    value.definitionCount = value.definitions.length;
    value.names = [...new Set(value.definitions.map((item) => item.name))];
    value.ids = [...new Set(value.definitions.map((item) => item.id))];
    value.metadataKey = metadataKey;
  }

  return { byPath, missing };
}

function buildDefinitionFilters(
  definitions,
  byPath,
  keyField,
  labelField,
  orderField,
) {
  const groups = new Map();

  for (const definition of definitions) {
    const key = definition[keyField] || "unknown";
    const label = definition[labelField] || key;
    if (!groups.has(key)) {
      groups.set(key, {
        key,
        label,
        definitions: 0,
        assetPaths: new Set(),
        order: definition[orderField] ?? 99,
      });
    }
    const group = groups.get(key);
    group.definitions += 1;
    if (byPath.has(definition.path.toLowerCase())) {
      group.assetPaths.add(definition.path.toLowerCase());
    }
  }

  return [...groups.values()]
    .map((group) => ({
      key: group.key,
      label: group.label,
      definitions: group.definitions,
      assets: group.assetPaths.size,
      order: group.order,
    }))
    .sort(
      (left, right) =>
        left.order - right.order ||
        left.label.localeCompare(right.label, "zh-CN"),
    )
    .map(({ order, ...group }) => group);
}

function scanConfiguredCollections(referenceScan, assetLookup) {
  const monsterDefinitions = parseMonsterDefinitions(referenceScan.sourceTexts);
  const specialEquipmentDefinitions = parseSpecialEquipmentDefinitions(
    referenceScan.sourceTexts,
  );
  const monsters = groupConfiguredDefinitions(
    monsterDefinitions,
    assetLookup,
    "monster",
  );
  const specialEquipment = groupConfiguredDefinitions(
    specialEquipmentDefinitions,
    assetLookup,
    "specialEquipment",
  );

  return {
    monsters: {
      ...monsters,
      definitions: monsterDefinitions,
      chapters: buildDefinitionFilters(
        monsterDefinitions,
        monsters.byPath,
        "sourceKey",
        "sourceLabel",
        "sourceOrder",
      ),
      categories: buildDefinitionFilters(
        monsterDefinitions,
        monsters.byPath,
        "category",
        "categoryLabel",
        "categoryOrder",
      ),
    },
    specialEquipment: {
      ...specialEquipment,
      definitions: specialEquipmentDefinitions,
      sources: buildDefinitionFilters(
        specialEquipmentDefinitions,
        specialEquipment.byPath,
        "sourceKey",
        "sourceLabel",
        "sourceOrder",
      ),
      slots: buildDefinitionFilters(
        specialEquipmentDefinitions,
        specialEquipment.byPath,
        "slotKey",
        "slotLabel",
        "slotOrder",
      ),
    },
  };
}

function getNamingIssues(fileName) {
  const stem = path.basename(fileName, path.extname(fileName));
  const issues = [];

  if (/\s/u.test(fileName)) issues.push("contains_spaces");
  if (/[^\x00-\x7F]/u.test(fileName)) issues.push("non_ascii");
  if (!/^[a-z0-9]+(?:_[a-z0-9]+)*$/u.test(stem)) issues.push("not_snake_case");
  if (/_20\d{12}$/u.test(stem)) issues.push("timestamp_suffix");
  if (/(?:^|_)(?:v\d+|r\d+|final|new|copy|edited)(?:_|$)/u.test(stem)) {
    issues.push("version_marker");
  }

  return issues;
}

function parseLuaStrings(text) {
  const strings = [];
  let index = 0;
  let line = 1;

  function consumeNewline(character) {
    if (character === "\n") line += 1;
  }

  while (index < text.length) {
    const character = text[index];
    const next = text[index + 1];

    if (character === "-" && next === "-") {
      if (text[index + 2] === "[" && text[index + 3] === "[") {
        index += 4;
        while (index < text.length && !(text[index] === "]" && text[index + 1] === "]")) {
          consumeNewline(text[index]);
          index += 1;
        }
        index += 2;
      } else {
        index += 2;
        while (index < text.length && text[index] !== "\n") index += 1;
      }
      continue;
    }

    if (character === "'" || character === '"') {
      const quote = character;
      const startLine = line;
      let value = "";
      index += 1;

      while (index < text.length) {
        const current = text[index];
        if (current === "\\") {
          const escaped = text[index + 1];
          if (escaped === "n") value += "\n";
          else if (escaped === "r") value += "\r";
          else if (escaped === "t") value += "\t";
          else if (escaped !== undefined) value += escaped;
          index += 2;
          continue;
        }
        if (current === quote) {
          index += 1;
          break;
        }
        value += current;
        consumeNewline(current);
        index += 1;
      }

      strings.push({ value, line: startLine });
      continue;
    }

    if (character === "[" && next === "[") {
      const startLine = line;
      let value = "";
      index += 2;
      while (index < text.length && !(text[index] === "]" && text[index + 1] === "]")) {
        value += text[index];
        consumeNewline(text[index]);
        index += 1;
      }
      index += 2;
      strings.push({ value, line: startLine });
      continue;
    }

    consumeNewline(character);
    index += 1;
  }

  return strings;
}

function parseQuotedStrings(text) {
  const strings = [];
  let index = 0;
  let line = 1;

  while (index < text.length) {
    const character = text[index];
    if (character === "\n") {
      line += 1;
      index += 1;
      continue;
    }
    if (character !== '"' && character !== "'") {
      index += 1;
      continue;
    }

    const quote = character;
    const startLine = line;
    let value = "";
    index += 1;

    while (index < text.length) {
      const current = text[index];
      if (current === "\\") {
        const escaped = text[index + 1];
        value += escaped ?? "";
        index += 2;
        continue;
      }
      if (current === quote) {
        index += 1;
        break;
      }
      if (current === "\n") line += 1;
      value += current;
      index += 1;
    }

    strings.push({ value, line: startLine });
  }

  return strings;
}

function classifySource(projectRoot, absolutePath) {
  const relativePath = toPosix(path.relative(projectRoot, absolutePath));
  const baseName = path.basename(absolutePath);
  const isDevelopment =
    /(?:^|\/)(?:tests|_proc)(?:\/|$)/u.test(relativePath) ||
    /^(?:test_|preview_)/u.test(baseName) ||
    /\.bak(?:\.|$)/u.test(baseName);

  return {
    relativePath,
    scope: isDevelopment ? "development" : "runtime",
  };
}

async function scanReferences(projectRoot, assetLookup, basenameLookup) {
  const scriptsRoot = path.join(projectRoot, "scripts");
  const sourceFiles = await walkFiles(scriptsRoot, (absolutePath) =>
    SOURCE_EXTENSIONS.has(path.extname(absolutePath).toLowerCase()),
  );
  const directReferences = new Map();
  const developmentReferences = new Map();
  const missingReferences = new Map();
  const sourceTexts = new Map();

  function pushReference(targetMap, key, reference) {
    const lowerKey = key.toLowerCase();
    if (!targetMap.has(lowerKey)) targetMap.set(lowerKey, []);
    targetMap.get(lowerKey).push(reference);
  }

  await mapWithConcurrency(sourceFiles, 24, async (absolutePath) => {
    const text = await fs.readFile(absolutePath, "utf8");
    const source = classifySource(projectRoot, absolutePath);
    sourceTexts.set(source.relativePath, text);
    const extension = path.extname(absolutePath).toLowerCase();
    const strings = extension === ".lua" ? parseLuaStrings(text) : parseQuotedStrings(text);

    for (const item of strings) {
      if (!isImagePath(item.value)) continue;
      const resourcePath = normalizeResourcePath(item.value);
      if (!resourcePath) continue;

      const lowerPath = resourcePath.toLowerCase();
      const reference = {
        file: source.relativePath,
        line: item.line,
        scope: source.scope,
        value: resourcePath,
        kind: "literal",
      };

      if (assetLookup.has(lowerPath)) {
        const targetMap =
          source.scope === "runtime" ? directReferences : developmentReferences;
        pushReference(targetMap, lowerPath, reference);
      } else {
        const basename = path.posix.basename(resourcePath).toLowerCase();
        const suggestions = (basenameLookup.get(basename) ?? []).slice(0, 8);
        if (!missingReferences.has(lowerPath)) {
          missingReferences.set(lowerPath, {
            path: resourcePath,
            kind: "literal",
            sources: [],
            suggestions,
          });
        }
        missingReferences.get(lowerPath).sources.push(reference);
      }
    }
  });

  return {
    directReferences,
    developmentReferences,
    missingReferences,
    sourceTexts,
    sourceFileCount: sourceFiles.length,
  };
}

function scanDynamicFamilies(referenceScan, assetLookup) {
  const dynamicReferences = new Map();
  const missing = [];
  const families = [];
  const sourceEntry = [...referenceScan.sourceTexts.entries()].find(
    ([file, text]) =>
      file.endsWith("scripts/systems/loot/generation.lua") &&
      text.includes('"icon_t" .. iconTier .. "_" .. baseSlot .. ".png"'),
  );

  if (!sourceEntry) {
    return { dynamicReferences, missing, families };
  }

  const [sourceFile, sourceText] = sourceEntry;
  const line =
    sourceText.slice(0, sourceText.indexOf('"icon_t" .. iconTier')).split("\n").length;
  const expected = [];
  const present = [];

  for (let tier = 2; tier <= 10; tier += 1) {
    for (const slot of TIER_ICON_SLOTS) {
      const resourcePath = `icon_t${tier}_${slot}.png`;
      const lowerPath = resourcePath.toLowerCase();
      expected.push(resourcePath);

      const reference = {
        file: sourceFile,
        line,
        scope: "runtime",
        value: resourcePath,
        kind: "dynamic_family",
        family: "tier_equipment_icons",
      };

      if (assetLookup.has(lowerPath)) {
        dynamicReferences.set(lowerPath, [reference]);
        present.push(resourcePath);
      } else {
        missing.push({
          path: resourcePath,
          kind: "dynamic_family",
          sources: [reference],
          suggestions: [],
        });
      }
    }
  }

  families.push({
    id: "tier_equipment_icons",
    label: "等级装备图标",
    pattern: "icon_t{2..10}_{slot}.png",
    expected: expected.length,
    present: present.length,
    missing: missing.length,
    source: { file: sourceFile, line },
  });

  return { dynamicReferences, missing, families };
}

async function readMakerRegistry(projectRoot) {
  const registryPath = path.join(
    projectRoot,
    ".maker",
    "assets",
    "generated-assets.json",
  );

  try {
    const raw = await fs.readFile(registryPath, "utf8");
    const registry = JSON.parse(raw);
    const byPath = new Map();

    for (const [key, value] of Object.entries(registry)) {
      const localPath = normalizeResourcePath(value.localPath ?? key);
      if (!localPath) continue;
      byPath.set(localPath.toLowerCase(), {
        tool: value.tool ?? "",
        name: value.name ?? "",
        prompt: value.prompt ?? "",
        cdnUrl: value.cdnUrl ?? "",
        previewUrl: value.previewUrl ?? "",
        createdAt: value.createdAt ?? "",
        localPath,
      });
    }

    return { registryPath, entries: Object.keys(registry).length, byPath };
  } catch (error) {
    if (error.code === "ENOENT") {
      return { registryPath, entries: 0, byPath: new Map(), error: null };
    }
    return {
      registryPath,
      entries: 0,
      byPath: new Map(),
      error: error.message,
    };
  }
}

function groupAssets(assets, keySelector) {
  const groups = new Map();
  for (const asset of assets) {
    const key = keySelector(asset);
    if (!key) continue;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(asset);
  }
  return groups;
}

export async function scanProject(projectRoot) {
  const startedAt = Date.now();
  const resolvedProjectRoot = path.resolve(projectRoot);
  const assetsRoot = path.join(resolvedProjectRoot, "assets");
  const imageFiles = await walkFiles(
    assetsRoot,
    (absolutePath) => path.extname(absolutePath).toLowerCase() === PNG_EXTENSION,
  );

  const assetRecords = await mapWithConcurrency(imageFiles, 16, async (absolutePath) => {
    const [buffer, stat] = await Promise.all([
      fs.readFile(absolutePath),
      fs.stat(absolutePath),
    ]);
    const relativePath = toPosix(path.relative(assetsRoot, absolutePath));
    const metaPath = `${absolutePath}.meta`;
    let uuid = "";
    let metaValid = true;

    try {
      const meta = JSON.parse(await fs.readFile(metaPath, "utf8"));
      uuid = meta.uuid ?? "";
    } catch (error) {
      if (error.code === "ENOENT") metaValid = false;
      else metaValid = false;
    }

    const dimensions = readPngDimensions(buffer);
    return {
      id: uuid || relativePath,
      path: relativePath,
      name: path.posix.basename(relativePath),
      stem: path.posix.basename(relativePath, PNG_EXTENSION),
      directory: path.posix.dirname(relativePath) === "." ? "" : path.posix.dirname(relativePath),
      area: deriveArea(relativePath),
      size: stat.size,
      modifiedAt: stat.mtime.toISOString(),
      width: dimensions.width,
      height: dimensions.height,
      validPng: dimensions.validPng,
      hash: crypto.createHash("sha256").update(buffer).digest("hex"),
      uuid,
      metaValid,
      namingIssues: getNamingIssues(relativePath),
      variantKey: deriveVariantKey(path.posix.basename(relativePath, PNG_EXTENSION)),
      references: [],
      developmentReferences: [],
      dynamicReferences: [],
      status: "unreferenced",
      duplicateGroupId: null,
      duplicateCount: 1,
      variantGroupId: null,
      variantCount: 1,
      maker: null,
      standardEquipment: classifyStandardEquipment(relativePath),
      monster: null,
      specialEquipment: null,
      imageUrl: `/asset/${relativePath
        .split("/")
        .map((segment) => encodeURIComponent(segment))
        .join("/")}`,
    };
  });

  assetRecords.sort((left, right) => left.path.localeCompare(right.path, "zh-CN"));

  const assetLookup = new Map(
    assetRecords.map((asset) => [asset.path.toLowerCase(), asset]),
  );
  const basenameLookup = new Map();
  for (const asset of assetRecords) {
    const key = asset.name.toLowerCase();
    if (!basenameLookup.has(key)) basenameLookup.set(key, []);
    basenameLookup.get(key).push(asset.path);
  }

  const [referenceScan, makerRegistry, metaFiles] = await Promise.all([
    scanReferences(resolvedProjectRoot, assetLookup, basenameLookup),
    readMakerRegistry(resolvedProjectRoot),
    walkFiles(assetsRoot, (absolutePath) =>
      absolutePath.toLowerCase().endsWith(".png.meta"),
    ),
  ]);
  const dynamicScan = scanDynamicFamilies(referenceScan, assetLookup);
  const configuredScan = scanConfiguredCollections(referenceScan, assetLookup);

  for (const asset of assetRecords) {
    const key = asset.path.toLowerCase();
    asset.references = referenceScan.directReferences.get(key) ?? [];
    asset.developmentReferences =
      referenceScan.developmentReferences.get(key) ?? [];
    asset.dynamicReferences = dynamicScan.dynamicReferences.get(key) ?? [];
    asset.maker = makerRegistry.byPath.get(key) ?? null;
    asset.monster = configuredScan.monsters.byPath.get(key) ?? null;
    asset.specialEquipment =
      configuredScan.specialEquipment.byPath.get(key) ?? null;

    if (asset.references.length > 0) asset.status = "direct";
    else if (asset.dynamicReferences.length > 0) asset.status = "dynamic";
    else if (asset.developmentReferences.length > 0) asset.status = "development";
  }

  const duplicateGroups = [];
  const duplicateMap = groupAssets(assetRecords, (asset) => asset.hash);
  let duplicatePotentialBytes = 0;
  let duplicateFileCount = 0;

  for (const [hash, members] of duplicateMap.entries()) {
    if (members.length < 2) continue;
    const id = `dup-${duplicateGroups.length + 1}`;
    const sortedMembers = members
      .map((asset) => asset.path)
      .sort((left, right) => left.localeCompare(right, "zh-CN"));
    const savings = members.slice(1).reduce((sum, asset) => sum + asset.size, 0);
    duplicatePotentialBytes += savings;
    duplicateFileCount += members.length;
    duplicateGroups.push({
      id,
      hash,
      size: members[0].size,
      count: members.length,
      potentialSavings: savings,
      members: sortedMembers,
    });
    for (const asset of members) {
      asset.duplicateGroupId = id;
      asset.duplicateCount = members.length;
    }
  }

  duplicateGroups.sort((left, right) => right.potentialSavings - left.potentialSavings);

  const variantGroups = [];
  const variantMap = groupAssets(assetRecords, (asset) => asset.variantKey);
  for (const [variantKey, members] of variantMap.entries()) {
    if (members.length < 2) continue;
    const id = `variant-${variantGroups.length + 1}`;
    variantGroups.push({
      id,
      key: variantKey,
      count: members.length,
      members: members.map((asset) => asset.path),
    });
    for (const asset of members) {
      asset.variantGroupId = id;
      asset.variantCount = members.length;
    }
  }
  variantGroups.sort((left, right) => right.count - left.count);

  const orphanMeta = [];
  for (const metaPath of metaFiles) {
    const imagePath = metaPath.slice(0, -".meta".length);
    try {
      await fs.access(imagePath);
    } catch {
      orphanMeta.push(toPosix(path.relative(assetsRoot, metaPath)));
    }
  }
  orphanMeta.sort((left, right) => left.localeCompare(right, "zh-CN"));

  const missingReferences = [
    ...referenceScan.missingReferences.values(),
    ...dynamicScan.missing,
  ].sort((left, right) => left.path.localeCompare(right.path, "zh-CN"));

  const statusCounts = {
    direct: 0,
    dynamic: 0,
    development: 0,
    unreferenced: 0,
  };
  const areaCounts = {};
  let totalBytes = 0;
  let namingIssueCount = 0;
  let metaIssueCount = 0;
  let makerPresent = 0;
  const standardEquipmentTierCounts = {};

  for (const asset of assetRecords) {
    statusCounts[asset.status] += 1;
    areaCounts[asset.area] = (areaCounts[asset.area] ?? 0) + 1;
    totalBytes += asset.size;
    if (asset.namingIssues.length > 0) namingIssueCount += 1;
    if (!asset.metaValid || !asset.uuid) metaIssueCount += 1;
    if (asset.maker) makerPresent += 1;
    if (asset.standardEquipment) {
      const tierKey = asset.standardEquipment.tierKey;
      if (!standardEquipmentTierCounts[tierKey]) {
        standardEquipmentTierCounts[tierKey] = {
          tier: asset.standardEquipment.tier,
          tierKey,
          tierLabel: asset.standardEquipment.tierLabel,
          assets: 0,
          activeMappings: 0,
          inactiveAssets: 0,
        };
      }
      const tierCount = standardEquipmentTierCounts[tierKey];
      tierCount.assets += 1;
      if (asset.standardEquipment.activeMapping) tierCount.activeMappings += 1;
      else tierCount.inactiveAssets += 1;
    }
  }

  const standardEquipmentAssets = assetRecords.filter(
    (asset) => asset.standardEquipment,
  );
  const standardEquipmentActiveMappings = standardEquipmentAssets.filter(
    (asset) => asset.standardEquipment.activeMapping,
  ).length;
  const standardEquipmentInheritedMappings = standardEquipmentAssets.reduce(
    (sum, asset) => sum + asset.standardEquipment.inheritedBy.length,
    0,
  );
  const standardEquipmentTiers = Object.values(standardEquipmentTierCounts).sort(
    (left, right) => left.tier - right.tier,
  );
  for (const tier of standardEquipmentTiers) {
    tier.inheritedAssets = standardEquipmentAssets.filter((asset) =>
      asset.standardEquipment.inheritedBy.includes(tier.tierLabel),
    ).length;
    tier.effectiveAssets = tier.assets + tier.inheritedAssets;
  }

  const makerMissingLocal = [...makerRegistry.byPath.keys()].filter(
    (resourcePath) => !assetLookup.has(resourcePath),
  );
  const imageFolderAssets = assetRecords.filter((asset) => asset.area === "image");
  const imageFolderWithoutRegistry = imageFolderAssets.filter(
    (asset) => !asset.maker,
  ).length;

  return {
    schemaVersion: 3,
    generatedAt: new Date().toISOString(),
    projectRoot: resolvedProjectRoot,
    scanDurationMs: Date.now() - startedAt,
    summary: {
      assets: assetRecords.length,
      totalBytes,
      statusCounts,
      areaCounts,
      duplicateGroups: duplicateGroups.length,
      duplicateFiles: duplicateFileCount,
      duplicatePotentialBytes,
      variantGroups: variantGroups.length,
      namingIssueCount,
      metaIssueCount,
      orphanMetaCount: orphanMeta.length,
      missingReferenceCount: missingReferences.length,
      sourceFileCount: referenceScan.sourceFileCount,
      standardEquipment: {
        assets: standardEquipmentAssets.length,
        activeMappings: standardEquipmentActiveMappings,
        inactiveAssets:
          standardEquipmentAssets.length - standardEquipmentActiveMappings,
        missingActiveMappings: dynamicScan.missing.length,
        inheritedMappings: standardEquipmentInheritedMappings,
        tiers: standardEquipmentTiers,
      },
      monsters: {
        assets: configuredScan.monsters.byPath.size,
        definitions: configuredScan.monsters.definitions.length,
        missingDefinitions: configuredScan.monsters.missing.length,
        chapters: configuredScan.monsters.chapters,
        categories: configuredScan.monsters.categories,
      },
      specialEquipment: {
        assets: configuredScan.specialEquipment.byPath.size,
        definitions: configuredScan.specialEquipment.definitions.length,
        missingDefinitions: configuredScan.specialEquipment.missing.length,
        sources: configuredScan.specialEquipment.sources,
        slots: configuredScan.specialEquipment.slots,
      },
      maker: {
        registryEntries: makerRegistry.entries,
        present: makerPresent,
        missingLocal: makerMissingLocal.length,
        imageFolderWithoutRegistry,
        error: makerRegistry.error ?? null,
      },
    },
    dynamicFamilies: dynamicScan.families,
    missingReferences,
    orphanMeta,
    duplicateGroups,
    variantGroups,
    assets: assetRecords,
  };
}
