#!/usr/bin/env node
/* eslint-disable no-console */

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "..");
const CONFIG_DIR = path.join(ROOT, "scripts", "config");

const CH6_TYPES = [
  "ch6_patrol_immortal_soldier",
  "ch6_lingfeng",
  "ch6_shadow_wanderer",
  "ch6_zhuyou",
  "ch6_mountain_colossus",
  "ch6_duanyue",
  "ch6_west_celestial_soldier",
  "ch6_pojun",
  "ch6_zhenyuan",
  "ch6_heng_marshal",
  "ch6_east_celestial_soldier",
  "ch6_qingfeng",
  "ch6_leice",
  "ch6_ha_marshal",
  "ch6_toad_immortal",
  "ch6_gua_master",
  "ch6_mojun_shixuan",
];

const ALLOWED_KNOCKBACK = new Set([
  "ch6_duanyue",
  "ch6_ha_marshal",
  "ch6_toad_immortal",
]);
const SAINT_NEW_SKILL_OWNERS = new Set(["ch6_gua_master", "ch6_mojun_shixuan"]);
const VALID_SHAPES = new Set(["circle", "cone", "cross", "line", "rect"]);
const VALID_EFFECTS = new Set(["poison", "knockback", "stun", "slow", "burn"]);

const errors = [];
const warnings = [];

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), "utf8");
}

function fail(message) {
  errors.push(message);
}

function warn(message) {
  warnings.push(message);
}

function findMatchingBrace(source, openIndex) {
  let depth = 0;
  let quote = null;
  let escape = false;
  for (let i = openIndex; i < source.length; i += 1) {
    const c = source[i];
    if (quote) {
      if (escape) {
        escape = false;
      } else if (c === "\\") {
        escape = true;
      } else if (c === quote) {
        quote = null;
      }
      continue;
    }
    if (c === "\"" || c === "'") {
      quote = c;
      continue;
    }
    if (c === "{") depth += 1;
    if (c === "}") {
      depth -= 1;
      if (depth === 0) return i;
    }
  }
  return -1;
}

function collectBlocks(source, regex) {
  const out = {};
  let match;
  while ((match = regex.exec(source)) !== null) {
    const id = match[1];
    const open = source.indexOf("{", match.index);
    const close = findMatchingBrace(source, open);
    if (open < 0 || close < 0) {
      fail(`unclosed block for ${id}`);
      continue;
    }
    out[id] = source.slice(open, close + 1);
    regex.lastIndex = close + 1;
  }
  return out;
}

function stripComments(block) {
  return block.replace(/--[^\n\r]*/g, "");
}

function strField(block, key) {
  const clean = stripComments(block);
  const re = new RegExp(`${key}\\s*=\\s*"([^"]*)"`);
  const m = clean.match(re);
  return m ? m[1] : null;
}

function numField(block, key) {
  const clean = stripComments(block);
  const re = new RegExp(`${key}\\s*=\\s*([0-9.]+)`);
  const m = clean.match(re);
  return m ? Number(m[1]) : null;
}

function hasField(block, key) {
  const clean = stripComments(block);
  const re = new RegExp(`${key}\\s*=`);
  return re.test(clean);
}

function listField(block, key) {
  const clean = stripComments(block);
  const re = new RegExp(`${key}\\s*=\\s*\\{([^{}]*)\\}`);
  const m = clean.match(re);
  if (!m) return [];
  return Array.from(m[1].matchAll(/"([^"]+)"/g)).map((x) => x[1]);
}

function fieldBlock(block, key) {
  const clean = stripComments(block);
  const re = new RegExp(`${key}\\s*=\\s*\\{`);
  const m = clean.match(re);
  if (!m) return null;
  const open = clean.indexOf("{", m.index);
  const close = findMatchingBrace(clean, open);
  return close >= 0 ? clean.slice(open, close + 1) : null;
}

function phaseBlocks(typeBlock) {
  const pb = fieldBlock(typeBlock, "phaseConfig");
  if (!pb) return [];
  const phases = [];
  for (let i = 1; i < pb.length - 1; i += 1) {
    if (pb[i] !== "{") continue;
    const close = findMatchingBrace(pb, i);
    if (close > i) {
      phases.push(pb.slice(i, close + 1));
      i = close;
    }
  }
  return phases;
}

function allAssignedSkillIds(typeBlock) {
  const ids = new Set(listField(typeBlock, "skills"));
  for (const p of phaseBlocks(typeBlock)) {
    const addSkill = strField(p, "addSkill");
    const triggerSkill = strField(p, "triggerSkill");
    if (addSkill) ids.add(addSkill);
    if (triggerSkill) ids.add(triggerSkill);
    for (const sid of listField(p, "addSkills")) ids.add(sid);
  }
  return Array.from(ids);
}

function phaseAddedSkillIds(typeBlock) {
  const ids = new Set();
  for (const p of phaseBlocks(typeBlock)) {
    const addSkill = strField(p, "addSkill");
    if (addSkill) ids.add(addSkill);
    for (const sid of listField(p, "addSkills")) ids.add(sid);
  }
  return Array.from(ids);
}

function loadSkills() {
  const skillFiles = fs
    .readdirSync(CONFIG_DIR)
    .filter((name) => /^MonsterData_Skills.*\.lua$/.test(name))
    .map((name) => path.join(CONFIG_DIR, name));
  const skills = {};
  for (const file of skillFiles) {
    Object.assign(skills, collectBlocks(fs.readFileSync(file, "utf8"), /M\.Skills\.([A-Za-z0-9_]+)\s*=/g));
  }
  return skills;
}

function simulateHit(skillId, skillBlock) {
  const shape = strField(skillBlock, "warningShape") || "circle";
  if (!VALID_SHAPES.has(shape)) {
    fail(`${skillId}: unsupported warningShape ${shape}`);
    return;
  }
  const range = numField(skillBlock, "warningRange") || 2.0;
  const rectLen = numField(skillBlock, "warningRectLength") || 2.5;
  const rectWidth = numField(skillBlock, "warningRectWidth") || 1.2;
  const lineWidth = numField(skillBlock, "warningLineWidth") || 0.8;
  const crossWidth = numField(skillBlock, "warningCrossWidth") || 0.8;
  const coneAngle = numField(skillBlock, "warningConeAngle") || 90;

  let hit = false;
  if (shape === "circle") hit = range > 0;
  if (shape === "cone") hit = range > 0 && coneAngle > 0 && coneAngle <= 180;
  if (shape === "cross") hit = range > 0 && crossWidth > 0;
  if (shape === "line") hit = range > 0 && lineWidth > 0;
  if (shape === "rect") hit = rectLen > 0 && rectWidth > 0;
  if (!hit) fail(`${skillId}: simulated warning hit failed for ${shape}`);
}

function validateSkill(skillId, skillBlock, ownerId, source) {
  if (!skillBlock) {
    fail(`${ownerId}: missing skill ${skillId}`);
    return;
  }

  const shape = strField(skillBlock, "warningShape") || "circle";
  const effect = strField(skillBlock, "effect");
  const damageMult = numField(skillBlock, "damageMult");
  const damagePercent = numField(skillBlock, "damagePercent");
  const isFieldSkill = hasField(skillBlock, "isFieldSkill");

  if (!VALID_SHAPES.has(shape)) fail(`${skillId}: shape ${shape} is not implemented by current hit logic`);
  if (effect && !VALID_EFFECTS.has(effect)) fail(`${skillId}: effect ${effect} is not handled by GameEvents`);
  if (effect === "knockback" && !ALLOWED_KNOCKBACK.has(ownerId)) {
    fail(`${ownerId}: illegal knockback skill ${skillId}`);
  }
  if (skillId.startsWith("ch6_") && !SAINT_NEW_SKILL_OWNERS.has(ownerId)) {
    fail(`${ownerId}: non-saint monster uses new chapter-6 skill ${skillId}`);
  }
  if (isFieldSkill && source !== "trigger") {
    fail(`${ownerId}: field skill ${skillId} is in ${source}; field safe zones are only initialized for triggerSkill`);
  }
  if (!isFieldSkill && source !== "trigger" && !(damageMult > 0)) {
    fail(`${skillId}: looping skill must have positive damageMult`);
  }
  if (isFieldSkill && !(damagePercent > 0) && !(damageMult > 0)) {
    fail(`${skillId}: field skill needs damagePercent or positive damageMult`);
  }
  if (!(numField(skillBlock, "castTime") > 0)) fail(`${skillId}: missing positive castTime`);
  if (!hasField(skillBlock, "warningColor")) warn(`${skillId}: no warningColor; renderer will use monster override/default`);
  simulateHit(skillId, skillBlock);
}

function main() {
  const skills = loadSkills();
  const ch6 = read("scripts/config/MonsterTypes_ch6.lua");
  const monster = collectBlocks(ch6, /M\.Types\.([A-Za-z0-9_]+)\s*=/g);

  const monsterLua = read("scripts/entities/Monster.lua");
  if (!monsterLua.includes("phase.berserkBuff")) fail("Monster.lua does not apply phase.berserkBuff");
  if (!monsterLua.includes("skillCooldownMult")) fail("Monster.lua does not apply persistent skill CDR");
  if (!monsterLua.includes("GetSkillCooldown")) fail("Monster.lua does not use GetSkillCooldown");

  const race = ch6.match(/ch6_demon_lord\s*=\s*\{\s*hp\s*=\s*([0-9.]+)/);
  const demonRaceHp = race ? Number(race[1]) : null;
  if (!(demonRaceHp > 0.86 && demonRaceHp < 0.88)) fail(`ch6_demon_lord hp mod expected ~0.87, got ${demonRaceHp}`);
  const effectiveDemonHp = demonRaceHp * 1.5;
  if (!(effectiveDemonHp > 1.29 && effectiveDemonHp < 1.32)) fail(`mojun effective demon HP expected ~1.30, got ${effectiveDemonHp}`);

  for (const id of CH6_TYPES) {
    const block = monster[id];
    if (!block) {
      fail(`missing monster ${id}`);
      continue;
    }
    const category = strField(block, "category");
    const baseSkills = listField(block, "skills");
    const phases = phaseBlocks(block);

    if (category === "boss") {
      if (baseSkills.length !== 2) fail(`${id}: boss must have exactly 2 base skills`);
      if (phases.length !== 0) fail(`${id}: boss must not have phases`);
    } else if (category === "king_boss") {
      if (baseSkills.length !== 3) fail(`${id}: king boss must have exactly 3 base skills`);
      if (phases.length !== 0) fail(`${id}: king boss must not have phases`);
    } else if (category === "emperor_boss") {
      if (baseSkills.length !== 2) fail(`${id}: emperor boss must have exactly 2 base skills`);
      if (id === "ch6_lingfeng" || id === "ch6_zhuyou") {
        if (phases.length !== 1) fail(`${id}: should have only one 30% trigger phase`);
        if (!strField(phases[0] || "", "triggerSkill")) fail(`${id}: 30% phase must trigger one skill`);
        if (strField(phases[0] || "", "addSkill") || listField(phases[0] || "", "addSkills").length) {
          fail(`${id}: should not add looping phase skill`);
        }
      } else {
        if (phases.length !== 2) fail(`${id}: emperor boss must have 70% and 30% phases`);
        for (const p of phases) {
          if (!strField(p, "addSkill") && listField(p, "addSkills").length === 0) {
            fail(`${id}: every non-early emperor phase must add a looping skill`);
          }
        }
      }
      if ((id === "ch6_heng_marshal" || id === "ch6_ha_marshal") && !hasField(phases[1] || "", "berserkBuff")) {
        fail(`${id}: 30% phase must apply berserkBuff`);
      }
    } else if (category === "saint_boss") {
      if (baseSkills.length !== 4) fail(`${id}: saint boss must start with 4 skills`);
      if (phases.length !== 2) fail(`${id}: saint boss must have two phases`);
      if (!strField(phases[0] || "", "addSkill")) fail(`${id}: 70% phase must add a looping skill`);
      if (!strField(phases[1] || "", "addSkill") || !strField(phases[1] || "", "triggerSkill")) {
        fail(`${id}: 30% phase must add a looping skill and trigger a burst`);
      }
    }

    for (const skillId of baseSkills) validateSkill(skillId, skills[skillId], id, "base");
    for (const skillId of phaseAddedSkillIds(block)) validateSkill(skillId, skills[skillId], id, "phase-add");
    for (const p of phases) {
      const trigger = strField(p, "triggerSkill");
      if (trigger) validateSkill(trigger, skills[trigger], id, "trigger");
    }
  }

  if (errors.length) {
    console.error("[FAIL] ch6 monster skill matrix");
    for (const e of errors) console.error(`  - ${e}`);
    process.exit(1);
  }
  console.log(`[PASS] ch6 monster skill matrix: ${CH6_TYPES.length} monsters, ${Object.keys(skills).length} skills scanned`);
  if (warnings.length) {
    console.log("[WARN]");
    for (const w of warnings) console.log(`  - ${w}`);
  }
}

main();
