import path from "node:path";
import { fileURLToPath } from "node:url";
import { scanProject } from "./lib/scanner.mjs";

const currentDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(currentDirectory, "../..");
const index = await scanProject(projectRoot);

if (process.argv.includes("--json")) {
  process.stdout.write(`${JSON.stringify(index, null, 2)}\n`);
} else {
  const { summary } = index;
  console.log(`Images: ${summary.assets}`);
  console.log(`Size: ${(summary.totalBytes / 1024 / 1024).toFixed(2)} MB`);
  console.log(
    `Usage: direct=${summary.statusCounts.direct}, dynamic=${summary.statusCounts.dynamic}, development=${summary.statusCounts.development}, unreferenced=${summary.statusCounts.unreferenced}`,
  );
  console.log(
    `Standard equipment: assets=${summary.standardEquipment.assets}, active=${summary.standardEquipment.activeMappings}, inactive=${summary.standardEquipment.inactiveAssets}, missing=${summary.standardEquipment.missingActiveMappings}`,
  );
  console.log(
    `Monsters: assets=${summary.monsters.assets}, definitions=${summary.monsters.definitions}, missing=${summary.monsters.missingDefinitions}`,
  );
  console.log(
    `Special equipment: assets=${summary.specialEquipment.assets}, definitions=${summary.specialEquipment.definitions}, missing=${summary.specialEquipment.missingDefinitions}`,
  );
  console.log(
    `Duplicates: ${summary.duplicateGroups} groups / ${summary.duplicateFiles} files`,
  );
  console.log(`Missing references: ${summary.missingReferenceCount}`);
  console.log(`Naming issues: ${summary.namingIssueCount}`);
  console.log(`Scan time: ${index.scanDurationMs} ms`);
}
