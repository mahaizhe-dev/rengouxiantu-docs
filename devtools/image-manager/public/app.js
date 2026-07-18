const state = {
  index: null,
  assetByPath: new Map(),
  view: "all",
  search: "",
  area: "all",
  status: "all",
  equipmentTier: "all",
  equipmentMapping: "all",
  monsterChapter: "all",
  monsterCategory: "all",
  specialSource: "all",
  specialSlot: "all",
  sort: "path",
  selectedPath: null,
};

const elements = {
  navItems: [...document.querySelectorAll(".nav-item")],
  viewTitle: document.querySelector("#view-title"),
  projectPath: document.querySelector("#project-path"),
  rescanButton: document.querySelector("#rescan-button"),
  scanTime: document.querySelector("#scan-time"),
  scanDuration: document.querySelector("#scan-duration"),
  summaryAssets: document.querySelector("#summary-assets"),
  summarySize: document.querySelector("#summary-size"),
  summaryDirect: document.querySelector("#summary-direct"),
  summaryDynamic: document.querySelector("#summary-dynamic"),
  summaryPending: document.querySelector("#summary-pending"),
  summaryMissing: document.querySelector("#summary-missing"),
  navAllCount: document.querySelector("#nav-all-count"),
  navEquipmentCount: document.querySelector("#nav-equipment-count"),
  navMonsterCount: document.querySelector("#nav-monster-count"),
  navSpecialEquipmentCount: document.querySelector(
    "#nav-special-equipment-count",
  ),
  navPendingCount: document.querySelector("#nav-pending-count"),
  navDuplicateCount: document.querySelector("#nav-duplicate-count"),
  navMissingCount: document.querySelector("#nav-missing-count"),
  navNamingCount: document.querySelector("#nav-naming-count"),
  toolbar: document.querySelector("#asset-toolbar"),
  searchInput: document.querySelector("#search-input"),
  areaSelect: document.querySelector("#area-select"),
  statusSelect: document.querySelector("#status-select"),
  equipmentTierField: document.querySelector("#equipment-tier-field"),
  equipmentTierSelect: document.querySelector("#equipment-tier-select"),
  equipmentMappingField: document.querySelector("#equipment-mapping-field"),
  equipmentMappingSelect: document.querySelector("#equipment-mapping-select"),
  monsterChapterField: document.querySelector("#monster-chapter-field"),
  monsterChapterSelect: document.querySelector("#monster-chapter-select"),
  monsterCategoryField: document.querySelector("#monster-category-field"),
  monsterCategorySelect: document.querySelector("#monster-category-select"),
  specialSourceField: document.querySelector("#special-source-field"),
  specialSourceSelect: document.querySelector("#special-source-select"),
  specialSlotField: document.querySelector("#special-slot-field"),
  specialSlotSelect: document.querySelector("#special-slot-select"),
  sortSelect: document.querySelector("#sort-select"),
  tileSizeInput: document.querySelector("#tile-size-input"),
  resultCount: document.querySelector("#result-count"),
  resultNote: document.querySelector("#result-note"),
  assetGrid: document.querySelector("#asset-grid"),
  issueList: document.querySelector("#issue-list"),
  emptyState: document.querySelector("#empty-state"),
  detailDrawer: document.querySelector("#detail-drawer"),
  detailClose: document.querySelector("#detail-close"),
  detailStatus: document.querySelector("#detail-status"),
  detailName: document.querySelector("#detail-name"),
  detailContent: document.querySelector("#detail-content"),
  drawerScrim: document.querySelector("#drawer-scrim"),
  toast: document.querySelector("#toast"),
};

const viewTitles = {
  all: "全部资源",
  "standard-equipment": "制式装备",
  monsters: "怪物",
  "special-equipment": "特殊装备",
  pending: "待确认",
  duplicates: "重复内容",
  missing: "缺失引用",
  naming: "命名问题",
};

const statusLabels = {
  direct: "直接引用",
  dynamic: "动态引用",
  development: "仅开发引用",
  unreferenced: "未发现引用",
};

const namingLabels = {
  contains_spaces: "包含空格",
  non_ascii: "非 ASCII",
  not_snake_case: "不符合 snake_case",
  timestamp_suffix: "带时间戳",
  version_marker: "带版本标记",
};

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatBytes(bytes) {
  if (!Number.isFinite(bytes)) return "--";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
}

function formatInteger(value) {
  return new Intl.NumberFormat("zh-CN").format(value ?? 0);
}

function formatDate(value) {
  if (!value) return "--";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function statusClass(status) {
  return `status-${status}`;
}

function referenceCount(asset) {
  return (
    asset.references.length +
    asset.dynamicReferences.length +
    asset.developmentReferences.length
  );
}

function showToast(message) {
  elements.toast.textContent = message;
  elements.toast.classList.add("is-visible");
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => {
    elements.toast.classList.remove("is-visible");
  }, 1800);
}

function updateSummary() {
  const { summary } = state.index;
  const pending =
    summary.statusCounts.unreferenced + summary.statusCounts.development;

  elements.projectPath.textContent = state.index.projectRoot;
  elements.scanTime.textContent = formatDate(state.index.generatedAt);
  elements.scanDuration.textContent = `${state.index.scanDurationMs} ms`;
  elements.summaryAssets.textContent = formatInteger(summary.assets);
  elements.summarySize.textContent = formatBytes(summary.totalBytes);
  elements.summaryDirect.textContent = formatInteger(summary.statusCounts.direct);
  elements.summaryDynamic.textContent = formatInteger(summary.statusCounts.dynamic);
  elements.summaryPending.textContent = formatInteger(pending);
  elements.summaryMissing.textContent = formatInteger(summary.missingReferenceCount);

  elements.navAllCount.textContent = formatInteger(summary.assets);
  elements.navEquipmentCount.textContent = formatInteger(
    summary.standardEquipment.assets,
  );
  elements.navMonsterCount.textContent = formatInteger(summary.monsters.assets);
  elements.navSpecialEquipmentCount.textContent = formatInteger(
    summary.specialEquipment.assets,
  );
  elements.navPendingCount.textContent = formatInteger(pending);
  elements.navDuplicateCount.textContent = formatInteger(summary.duplicateGroups);
  elements.navMissingCount.textContent = formatInteger(summary.missingReferenceCount);
  elements.navNamingCount.textContent = formatInteger(summary.namingIssueCount);
}

function updateAreaOptions() {
  const previous = elements.areaSelect.value;
  const areas = Object.entries(state.index.summary.areaCounts).sort((left, right) =>
    left[0].localeCompare(right[0], "zh-CN"),
  );

  elements.areaSelect.innerHTML = [
    '<option value="all">全部目录</option>',
    ...areas.map(
      ([area, count]) =>
        `<option value="${escapeHtml(area)}">${escapeHtml(area)} (${formatInteger(count)})</option>`,
    ),
  ].join("");
  elements.areaSelect.value = areas.some(([area]) => area === previous)
    ? previous
    : "all";
  state.area = elements.areaSelect.value;
}

function updateEquipmentTierOptions() {
  const previous = elements.equipmentTierSelect.value;
  const tiers = state.index.summary.standardEquipment.tiers;

  elements.equipmentTierSelect.innerHTML = [
    '<option value="all">全部阶位</option>',
    ...tiers.map(
      (tier) =>
        `<option value="${escapeHtml(tier.tierKey)}">${escapeHtml(tier.tierLabel)} (${formatInteger(tier.effectiveAssets)})</option>`,
    ),
  ].join("");
  elements.equipmentTierSelect.value = tiers.some(
    (tier) => tier.tierKey === previous,
  )
    ? previous
    : "all";
  state.equipmentTier = elements.equipmentTierSelect.value;
}

function updateSelectOptions(element, items, allLabel, stateKey) {
  const previous = element.value;
  element.innerHTML = [
    `<option value="all">${escapeHtml(allLabel)}</option>`,
    ...items.map(
      (item) =>
        `<option value="${escapeHtml(item.key)}">${escapeHtml(item.label)} (${formatInteger(item.assets)})</option>`,
    ),
  ].join("");
  element.value = items.some((item) => item.key === previous)
    ? previous
    : "all";
  state[stateKey] = element.value;
}

function updateCollectionOptions() {
  updateSelectOptions(
    elements.monsterChapterSelect,
    state.index.summary.monsters.chapters,
    "全部章节",
    "monsterChapter",
  );
  updateSelectOptions(
    elements.monsterCategorySelect,
    state.index.summary.monsters.categories,
    "全部类型",
    "monsterCategory",
  );
  updateSelectOptions(
    elements.specialSourceSelect,
    state.index.summary.specialEquipment.sources,
    "全部配置表",
    "specialSource",
  );
  updateSelectOptions(
    elements.specialSlotSelect,
    state.index.summary.specialEquipment.slots,
    "全部槽位",
    "specialSlot",
  );
}

function getViewAssets() {
  let assets = [...state.index.assets];

  if (state.view === "standard-equipment") {
    assets = assets.filter((asset) => asset.standardEquipment);
  } else if (state.view === "monsters") {
    assets = assets.filter((asset) => asset.monster);
  } else if (state.view === "special-equipment") {
    assets = assets.filter((asset) => asset.specialEquipment);
  } else if (state.view === "pending") {
    assets = assets.filter(
      (asset) => asset.status === "unreferenced" || asset.status === "development",
    );
  } else if (state.view === "duplicates") {
    assets = assets.filter((asset) => asset.duplicateCount > 1);
  } else if (state.view === "naming") {
    assets = assets.filter((asset) => asset.namingIssues.length > 0);
  }

  if (state.area !== "all") {
    assets = assets.filter((asset) => asset.area === state.area);
  }
  if (state.status !== "all") {
    assets = assets.filter((asset) => asset.status === state.status);
  }
  if (state.view === "standard-equipment" && state.equipmentTier !== "all") {
    const selectedTier = state.index.summary.standardEquipment.tiers.find(
      (tier) => tier.tierKey === state.equipmentTier,
    );
    assets = assets.filter((asset) => {
      const equipment = asset.standardEquipment;
      return (
        equipment.tierKey === state.equipmentTier ||
        equipment.inheritedBy.includes(selectedTier?.tierLabel)
      );
    });
  }
  if (state.view === "standard-equipment" && state.equipmentMapping !== "all") {
    const active = state.equipmentMapping === "active";
    assets = assets.filter(
      (asset) => asset.standardEquipment.activeMapping === active,
    );
  }
  if (state.view === "monsters" && state.monsterChapter !== "all") {
    assets = assets.filter((asset) =>
      asset.monster.definitions.some(
        (definition) => definition.sourceKey === state.monsterChapter,
      ),
    );
  }
  if (state.view === "monsters" && state.monsterCategory !== "all") {
    assets = assets.filter((asset) =>
      asset.monster.definitions.some(
        (definition) => definition.category === state.monsterCategory,
      ),
    );
  }
  if (state.view === "special-equipment" && state.specialSource !== "all") {
    assets = assets.filter((asset) =>
      asset.specialEquipment.definitions.some(
        (definition) => definition.sourceKey === state.specialSource,
      ),
    );
  }
  if (state.view === "special-equipment" && state.specialSlot !== "all") {
    assets = assets.filter((asset) =>
      asset.specialEquipment.definitions.some(
        (definition) => definition.slotKey === state.specialSlot,
      ),
    );
  }
  if (state.search) {
    const needle = state.search.toLocaleLowerCase("zh-CN");
    assets = assets.filter((asset) =>
      [
        asset.path,
        asset.name,
        asset.uuid,
        asset.variantKey,
        asset.standardEquipment?.tierLabel,
        asset.standardEquipment?.slotLabel,
        ...(asset.monster?.definitions.flatMap((definition) => [
          definition.id,
          definition.name,
          definition.sourceLabel,
          definition.categoryLabel,
          definition.zone,
        ]) ?? []),
        ...(asset.specialEquipment?.definitions.flatMap((definition) => [
          definition.id,
          definition.name,
          definition.sourceLabel,
          definition.slotLabel,
          definition.tierLabel,
          definition.qualityLabel,
        ]) ?? []),
      ]
        .filter(Boolean)
        .some((value) => value.toLocaleLowerCase("zh-CN").includes(needle)),
    );
  }

  assets.sort((left, right) => {
    if (state.sort === "equipment") {
      const leftEquipment = left.standardEquipment;
      const rightEquipment = right.standardEquipment;
      if (leftEquipment && rightEquipment) {
        if (state.equipmentTier !== "all") {
          return (
            leftEquipment.slotOrder - rightEquipment.slotOrder ||
            Number(rightEquipment.tierKey === state.equipmentTier) -
              Number(leftEquipment.tierKey === state.equipmentTier) ||
            left.path.localeCompare(right.path, "zh-CN")
          );
        }
        return (
          leftEquipment.tier - rightEquipment.tier ||
          leftEquipment.slotOrder - rightEquipment.slotOrder ||
          left.path.localeCompare(right.path, "zh-CN")
        );
      }
      if (leftEquipment) return -1;
      if (rightEquipment) return 1;
    }
    if (state.sort === "monster") {
      const leftName = left.monster?.definitions[0]?.name ?? left.name;
      const rightName = right.monster?.definitions[0]?.name ?? right.name;
      return leftName.localeCompare(rightName, "zh-CN");
    }
    if (state.sort === "special-equipment") {
      const leftDefinition = left.specialEquipment?.definitions[0];
      const rightDefinition = right.specialEquipment?.definitions[0];
      if (leftDefinition && rightDefinition) {
        return (
          (leftDefinition.tier ?? 999) - (rightDefinition.tier ?? 999) ||
          leftDefinition.slotOrder - rightDefinition.slotOrder ||
          leftDefinition.name.localeCompare(rightDefinition.name, "zh-CN")
        );
      }
      if (leftDefinition) return -1;
      if (rightDefinition) return 1;
    }
    if (state.sort === "size-desc") return right.size - left.size;
    if (state.sort === "refs-desc") {
      return referenceCount(right) - referenceCount(left);
    }
    if (state.sort === "modified-desc") {
      return new Date(right.modifiedAt).getTime() - new Date(left.modifiedAt).getTime();
    }
    return left.path.localeCompare(right.path, "zh-CN");
  });

  return assets;
}

function renderAssetCard(asset) {
  const refs = referenceCount(asset);
  const equipment = asset.standardEquipment;
  const monster = asset.monster;
  const specialEquipment = asset.specialEquipment;
  const duplicateFlag =
    asset.duplicateCount > 1
      ? `<span class="duplicate-flag">${asset.duplicateCount} 个相同</span>`
      : "";
  const equipmentMeta = equipment
    ? `
        <span class="equipment-meta">
          <span class="equipment-tier">${escapeHtml(equipment.tierLabel)}</span>
          <span>${escapeHtml(equipment.slotLabel)}</span>
          <span class="mapping-badge ${equipment.activeMapping ? "is-active" : "is-inactive"}">
            ${equipment.activeMapping ? "已接入" : "未接入"}
          </span>
        </span>
      `
    : "";
  const matchingMonsterDefinitions =
    monster?.definitions.filter(
      (definition) =>
        (state.monsterChapter === "all" ||
          definition.sourceKey === state.monsterChapter) &&
        (state.monsterCategory === "all" ||
          definition.category === state.monsterCategory),
    ) ?? [];
  const monsterDefinition =
    matchingMonsterDefinitions[0] ?? monster?.definitions[0];
  const visibleMonsterDefinitionCount =
    matchingMonsterDefinitions.length || monster?.definitionCount || 0;
  const monsterMeta =
    state.view === "monsters" && monsterDefinition
      ? `
        <span class="classification-meta">
          <span class="classification-chip">${escapeHtml(monsterDefinition.sourceLabel)}</span>
          <span>${escapeHtml(monsterDefinition.categoryLabel)}</span>
          ${
            visibleMonsterDefinitionCount > 1
              ? `<span class="classification-count">${formatInteger(visibleMonsterDefinitionCount)} 个配置</span>`
              : ""
          }
        </span>
      `
      : "";
  const matchingSpecialDefinitions =
    specialEquipment?.definitions.filter(
      (definition) =>
        (state.specialSource === "all" ||
          definition.sourceKey === state.specialSource) &&
        (state.specialSlot === "all" ||
          definition.slotKey === state.specialSlot),
    ) ?? [];
  const specialDefinition =
    matchingSpecialDefinitions[0] ?? specialEquipment?.definitions[0];
  const visibleSpecialDefinitionCount =
    matchingSpecialDefinitions.length || specialEquipment?.definitionCount || 0;
  const specialEquipmentMeta =
    state.view === "special-equipment" && specialDefinition
      ? `
        <span class="classification-meta">
          <span class="classification-chip">${escapeHtml(specialDefinition.tierLabel)}</span>
          <span>${escapeHtml(specialDefinition.slotLabel)}</span>
          <span>${escapeHtml(specialDefinition.qualityLabel)}</span>
          ${
            visibleSpecialDefinitionCount > 1
              ? `<span class="classification-count">${formatInteger(visibleSpecialDefinitionCount)} 件共用</span>`
              : ""
          }
        </span>
      `
      : "";
  const displayName =
    state.view === "monsters" && monsterDefinition
      ? `${monsterDefinition.name}${visibleMonsterDefinitionCount > 1 ? ` 等 ${visibleMonsterDefinitionCount} 个` : ""}`
      : state.view === "special-equipment" && specialDefinition
        ? `${specialDefinition.name}${visibleSpecialDefinitionCount > 1 ? ` 等 ${visibleSpecialDefinitionCount} 件` : ""}`
        : asset.name;

  return `
    <button class="asset-card" type="button" data-asset-path="${escapeHtml(asset.path)}">
      <span class="asset-thumb">
        <img src="${escapeHtml(asset.imageUrl)}" alt="" loading="lazy" />
        <span class="status-badge ${statusClass(asset.status)}">${statusLabels[asset.status]}</span>
        ${duplicateFlag}
      </span>
      <span class="asset-body">
        ${equipmentMeta}
        ${monsterMeta}
        ${specialEquipmentMeta}
        <span class="asset-name" title="${escapeHtml(displayName)}">${escapeHtml(displayName)}</span>
        <span class="asset-path">${escapeHtml(asset.path)}</span>
        <span class="asset-meta">
          <span>${asset.width}×${asset.height}</span>
          <span>${formatBytes(asset.size)} · ${refs} 引用</span>
        </span>
      </span>
    </button>
  `;
}

function renderMissingIssues() {
  const issues = state.index.missingReferences.filter((issue) => {
    if (!state.search) return true;
    const needle = state.search.toLocaleLowerCase("zh-CN");
    return (
      issue.path.toLocaleLowerCase("zh-CN").includes(needle) ||
      issue.sources.some((source) =>
        source.file.toLocaleLowerCase("zh-CN").includes(needle),
      )
    );
  });

  elements.resultCount.textContent = `${formatInteger(issues.length)} 项`;
  elements.resultNote.textContent = "代码指向的本地图片不存在";
  elements.assetGrid.classList.add("is-hidden");
  elements.issueList.classList.remove("is-hidden");
  elements.emptyState.classList.toggle("is-hidden", issues.length > 0);

  elements.issueList.innerHTML = issues
    .map((issue) => {
      const sources = issue.sources
        .slice(0, 4)
        .map(
          (source) =>
            `${escapeHtml(source.file)}:${source.line}${source.scope === "development" ? " · 开发" : ""}`,
        )
        .join("<br />");
      const moreSources =
        issue.sources.length > 4 ? `<br />另有 ${issue.sources.length - 4} 处` : "";
      const suggestion =
        issue.suggestions.length > 0
          ? `可能是：${escapeHtml(issue.suggestions[0])}`
          : issue.kind === "dynamic_family"
            ? "动态路径缺图"
            : "未找到同名文件";

      return `
        <article class="issue-row">
          <div class="issue-path">${escapeHtml(issue.path)}</div>
          <div class="issue-source">${sources}${moreSources}</div>
          <div class="issue-suggestion">${suggestion}</div>
        </article>
      `;
    })
    .join("");
}

function renderAssets() {
  const assets = getViewAssets();
  const equipmentSummary = state.index.summary.standardEquipment;
  const monsterSummary = state.index.summary.monsters;
  const specialEquipmentSummary = state.index.summary.specialEquipment;
  const selectedEquipmentTier = equipmentSummary.tiers.find(
    (tier) => tier.tierKey === state.equipmentTier,
  );
  const visibleMonsterDefinitions = assets.reduce(
    (count, asset) =>
      count +
      (asset.monster?.definitions.filter(
        (definition) =>
          (state.monsterChapter === "all" ||
            definition.sourceKey === state.monsterChapter) &&
          (state.monsterCategory === "all" ||
            definition.category === state.monsterCategory),
      ).length ?? 0),
    0,
  );
  const visibleSpecialDefinitions = assets.reduce(
    (count, asset) =>
      count +
      (asset.specialEquipment?.definitions.filter(
        (definition) =>
          (state.specialSource === "all" ||
            definition.sourceKey === state.specialSource) &&
          (state.specialSlot === "all" ||
            definition.slotKey === state.specialSlot),
      ).length ?? 0),
    0,
  );
  elements.resultCount.textContent = `${formatInteger(assets.length)} 项`;
  elements.resultNote.textContent =
    state.view === "duplicates"
      ? `${formatInteger(state.index.summary.duplicateGroups)} 个重复组`
      : state.view === "pending"
        ? "未发现运行时直接或动态引用"
        : state.view === "standard-equipment"
          ? selectedEquipmentTier
            ? selectedEquipmentTier.inheritedAssets > 0
              ? `${selectedEquipmentTier.tierLabel}：专用 ${formatInteger(selectedEquipmentTier.assets)} · 沿用 ${formatInteger(selectedEquipmentTier.inheritedAssets)}`
              : `${selectedEquipmentTier.tierLabel}：已接入 ${formatInteger(selectedEquipmentTier.activeMappings)} · 未接入 ${formatInteger(selectedEquipmentTier.inactiveAssets)}`
            : `已接入 ${formatInteger(equipmentSummary.activeMappings)} · 未接入 ${formatInteger(equipmentSummary.inactiveAssets)} · 缺少接入图 ${formatInteger(equipmentSummary.missingActiveMappings)}`
        : state.view === "monsters"
          ? `覆盖 ${formatInteger(visibleMonsterDefinitions)} 个怪物配置 · 全库 ${formatInteger(monsterSummary.definitions)} 个配置`
          : state.view === "special-equipment"
            ? `覆盖 ${formatInteger(visibleSpecialDefinitions)} 件特殊装备 · 全库 ${formatInteger(specialEquipmentSummary.definitions)} 件`
        : state.view === "naming"
          ? "按首版命名规则检测"
          : "";
  elements.issueList.classList.add("is-hidden");
  elements.assetGrid.classList.remove("is-hidden");
  elements.emptyState.classList.toggle("is-hidden", assets.length > 0);
  elements.assetGrid.innerHTML = assets.map(renderAssetCard).join("");
}

function render() {
  if (!state.index) return;
  elements.viewTitle.textContent = viewTitles[state.view];
  elements.navItems.forEach((button) => {
    button.classList.toggle("is-active", button.dataset.view === state.view);
  });
  elements.toolbar.classList.toggle("is-hidden", state.view === "missing");
  const isEquipmentView = state.view === "standard-equipment";
  const isMonsterView = state.view === "monsters";
  const isSpecialEquipmentView = state.view === "special-equipment";
  elements.equipmentTierField.classList.toggle("is-hidden", !isEquipmentView);
  elements.equipmentMappingField.classList.toggle("is-hidden", !isEquipmentView);
  elements.monsterChapterField.classList.toggle("is-hidden", !isMonsterView);
  elements.monsterCategoryField.classList.toggle("is-hidden", !isMonsterView);
  elements.specialSourceField.classList.toggle(
    "is-hidden",
    !isSpecialEquipmentView,
  );
  elements.specialSlotField.classList.toggle(
    "is-hidden",
    !isSpecialEquipmentView,
  );

  if (state.view === "missing") renderMissingIssues();
  else renderAssets();
}

function propertyRow(label, value) {
  return `
    <div class="property-row">
      <dt>${escapeHtml(label)}</dt>
      <dd>${escapeHtml(value)}</dd>
    </div>
  `;
}

function referenceSection(asset) {
  const references = [
    ...asset.references,
    ...asset.dynamicReferences,
    ...asset.developmentReferences,
  ];
  if (references.length === 0) {
    return `
      <section class="detail-section">
        <h3>引用位置</h3>
        <div class="reference-row">未发现静态引用</div>
      </section>
    `;
  }

  return `
    <section class="detail-section">
      <h3>引用位置 · ${references.length}</h3>
      <div class="reference-list">
        ${references
          .slice(0, 80)
          .map(
            (reference) => `
              <div class="reference-row">
                <strong>${escapeHtml(reference.file)}:${reference.line}</strong>
                <span>${reference.kind === "dynamic_family" ? "动态家族" : reference.scope === "development" ? "开发引用" : "直接引用"}</span>
              </div>
            `,
          )
          .join("")}
      </div>
    </section>
  `;
}

function relatedSection(asset) {
  const relatedPaths = new Set();
  if (asset.duplicateGroupId) {
    const group = state.index.duplicateGroups.find(
      (item) => item.id === asset.duplicateGroupId,
    );
    group?.members.forEach((member) => {
      if (member !== asset.path) relatedPaths.add(member);
    });
  }
  if (asset.variantGroupId) {
    const group = state.index.variantGroups.find(
      (item) => item.id === asset.variantGroupId,
    );
    group?.members.forEach((member) => {
      if (member !== asset.path) relatedPaths.add(member);
    });
  }

  const related = [...relatedPaths]
    .map((resourcePath) => state.assetByPath.get(resourcePath))
    .filter(Boolean)
    .slice(0, 40);
  if (related.length === 0) return "";

  return `
    <section class="detail-section">
      <h3>重复与版本 · ${relatedPaths.size}</h3>
      <div class="related-list">
        ${related
          .map(
            (item) => `
              <button class="related-row" type="button" data-related-path="${escapeHtml(item.path)}">
                <img class="related-thumb" src="${escapeHtml(item.imageUrl)}" alt="" loading="lazy" />
                <span>${escapeHtml(item.path)}</span>
              </button>
            `,
          )
          .join("")}
      </div>
    </section>
  `;
}

function makerSection(asset) {
  if (!asset.maker) return "";
  return `
    <section class="detail-section">
      <h3>Maker 来源</h3>
      <dl class="property-list">
        ${propertyRow("工具", asset.maker.tool || "--")}
        ${propertyRow("生成名称", asset.maker.name || "--")}
        ${propertyRow("生成时间", formatDate(asset.maker.createdAt))}
      </dl>
      ${
        asset.maker.prompt
          ? `<pre class="maker-prompt">${escapeHtml(asset.maker.prompt)}</pre>`
          : ""
      }
    </section>
  `;
}

function namingSection(asset) {
  if (asset.namingIssues.length === 0) return "";
  return `
    <section class="detail-section">
      <h3>命名问题</h3>
      <div class="tag-list">
        ${asset.namingIssues
          .map(
            (issue) =>
              `<span class="tag">${escapeHtml(namingLabels[issue] ?? issue)}</span>`,
          )
          .join("")}
      </div>
    </section>
  `;
}

function standardEquipmentSection(asset) {
  const equipment = asset.standardEquipment;
  if (!equipment) return "";
  const inheritedBy =
    equipment.inheritedBy.length > 0 ? equipment.inheritedBy.join("、") : "无";

  return `
    <section class="detail-section">
      <h3>制式装备识别</h3>
      <dl class="property-list">
        ${propertyRow("阶位", equipment.tierLabel)}
        ${propertyRow("槽位", equipment.slotLabel)}
        ${propertyRow("接入状态", equipment.activeMapping ? "已接入" : "未接入")}
        ${propertyRow("映射来源", equipment.mappingSource)}
        ${propertyRow("被后续阶位沿用", inheritedBy)}
      </dl>
      ${
        equipment.mappingNote
          ? `<p class="detail-note">${escapeHtml(equipment.mappingNote)}</p>`
          : ""
      }
    </section>
  `;
}

function monsterSection(asset) {
  const monster = asset.monster;
  if (!monster) return "";

  return `
    <section class="detail-section">
      <h3>怪物配置 · ${formatInteger(monster.definitionCount)}</h3>
      <div class="reference-list">
        ${monster.definitions
          .map(
            (definition) => `
              <div class="reference-row">
                <strong>${escapeHtml(definition.name)} · ${escapeHtml(definition.id)}</strong>
                <span>${escapeHtml(definition.sourceLabel)} · ${escapeHtml(definition.categoryLabel)}${definition.zone ? ` · ${escapeHtml(definition.zone)}` : ""}</span>
                <span>${escapeHtml(definition.source.file)}:${definition.source.line}</span>
              </div>
            `,
          )
          .join("")}
      </div>
    </section>
  `;
}

function specialEquipmentSection(asset) {
  const equipment = asset.specialEquipment;
  if (!equipment) return "";

  return `
    <section class="detail-section">
      <h3>特殊装备配置 · ${formatInteger(equipment.definitionCount)}</h3>
      <div class="reference-list">
        ${equipment.definitions
          .map(
            (definition) => `
              <div class="reference-row">
                <strong>${escapeHtml(definition.name)} · ${escapeHtml(definition.id)}</strong>
                <span>${escapeHtml(definition.sourceLabel)} · ${escapeHtml(definition.tierLabel)} · ${escapeHtml(definition.qualityLabel)} · ${escapeHtml(definition.slotLabel)}</span>
                <span>${escapeHtml(definition.source.file)}:${definition.source.line}</span>
              </div>
            `,
          )
          .join("")}
      </div>
    </section>
  `;
}

function openDetail(resourcePath) {
  const asset = state.assetByPath.get(resourcePath);
  if (!asset) return;
  state.selectedPath = resourcePath;
  const contextualDefinition =
    state.view === "monsters"
      ? asset.monster?.definitions[0]
      : state.view === "special-equipment"
        ? asset.specialEquipment?.definitions[0]
        : null;
  elements.detailStatus.textContent =
    state.view === "monsters" && asset.monster
      ? `怪物 · ${asset.monster.definitionCount} 个配置`
      : state.view === "special-equipment" && asset.specialEquipment
        ? `特殊装备 · ${asset.specialEquipment.definitionCount} 件`
        : asset.standardEquipment
          ? `${asset.standardEquipment.tierLabel} · ${asset.standardEquipment.slotLabel}`
          : statusLabels[asset.status];
  elements.detailName.textContent = contextualDefinition?.name ?? asset.name;
  elements.detailContent.innerHTML = `
    <div class="detail-preview">
      <img src="${escapeHtml(asset.imageUrl)}" alt="${escapeHtml(asset.name)}" />
    </div>
    <div class="detail-path-row">
      <div class="detail-path">${escapeHtml(asset.path)}</div>
      <button class="small-button" id="copy-path-button" type="button">复制路径</button>
    </div>

    <section class="detail-section">
      <h3>文件信息</h3>
      <dl class="property-list">
        ${propertyRow("引用状态", statusLabels[asset.status])}
        ${propertyRow("区域", asset.area)}
        ${propertyRow("尺寸", `${asset.width} × ${asset.height}`)}
        ${propertyRow("文件大小", formatBytes(asset.size))}
        ${propertyRow("修改时间", formatDate(asset.modifiedAt))}
        ${propertyRow("UUID", asset.uuid || "缺失")}
        ${propertyRow("SHA-256", asset.hash)}
        ${propertyRow("相同内容", `${asset.duplicateCount} 个`)}
        ${propertyRow("同名家族", `${asset.variantCount} 个`)}
      </dl>
    </section>

    ${standardEquipmentSection(asset)}
    ${monsterSection(asset)}
    ${specialEquipmentSection(asset)}
    ${namingSection(asset)}
    ${referenceSection(asset)}
    ${relatedSection(asset)}
    ${makerSection(asset)}
  `;
  elements.detailDrawer.classList.add("is-open");
  elements.detailDrawer.setAttribute("aria-hidden", "false");
  elements.drawerScrim.classList.add("is-open");

  document.querySelector("#copy-path-button")?.addEventListener("click", async () => {
    await navigator.clipboard.writeText(asset.path);
    showToast("资源路径已复制");
  });
}

function closeDetail() {
  state.selectedPath = null;
  elements.detailDrawer.classList.remove("is-open");
  elements.detailDrawer.setAttribute("aria-hidden", "true");
  elements.drawerScrim.classList.remove("is-open");
}

function applyIndex(index) {
  state.index = index;
  state.assetByPath = new Map(index.assets.map((asset) => [asset.path, asset]));
  updateSummary();
  updateAreaOptions();
  updateEquipmentTierOptions();
  updateCollectionOptions();
  render();
  if (state.selectedPath && state.assetByPath.has(state.selectedPath)) {
    openDetail(state.selectedPath);
  }
}

async function loadIndex() {
  const response = await fetch("/api/index");
  if (!response.ok) throw new Error(`扫描数据读取失败：${response.status}`);
  applyIndex(await response.json());
}

async function rescan() {
  elements.rescanButton.disabled = true;
  elements.rescanButton.textContent = "扫描中";
  try {
    const response = await fetch("/api/rescan", { method: "POST" });
    if (!response.ok) throw new Error(`重新扫描失败：${response.status}`);
    applyIndex(await response.json());
    showToast("扫描已更新");
  } catch (error) {
    showToast(error.message);
  } finally {
    elements.rescanButton.disabled = false;
    elements.rescanButton.textContent = "重新扫描";
  }
}

elements.navItems.forEach((button) => {
  button.addEventListener("click", () => {
    state.view = button.dataset.view;
    const contextualSort = {
      "standard-equipment": "equipment",
      monsters: "monster",
      "special-equipment": "special-equipment",
    }[state.view];
    if (contextualSort) {
      state.sort = contextualSort;
      elements.sortSelect.value = contextualSort;
    } else if (
      state.sort === "equipment" ||
      state.sort === "monster" ||
      state.sort === "special-equipment"
    ) {
      state.sort = "path";
      elements.sortSelect.value = "path";
    }
    closeDetail();
    render();
  });
});

elements.searchInput.addEventListener("input", (event) => {
  state.search = event.target.value.trim();
  render();
});

elements.areaSelect.addEventListener("change", (event) => {
  state.area = event.target.value;
  render();
});

elements.statusSelect.addEventListener("change", (event) => {
  state.status = event.target.value;
  render();
});

elements.equipmentTierSelect.addEventListener("change", (event) => {
  state.equipmentTier = event.target.value;
  render();
});

elements.equipmentMappingSelect.addEventListener("change", (event) => {
  state.equipmentMapping = event.target.value;
  render();
});

elements.monsterChapterSelect.addEventListener("change", (event) => {
  state.monsterChapter = event.target.value;
  render();
});

elements.monsterCategorySelect.addEventListener("change", (event) => {
  state.monsterCategory = event.target.value;
  render();
});

elements.specialSourceSelect.addEventListener("change", (event) => {
  state.specialSource = event.target.value;
  render();
});

elements.specialSlotSelect.addEventListener("change", (event) => {
  state.specialSlot = event.target.value;
  render();
});

elements.sortSelect.addEventListener("change", (event) => {
  state.sort = event.target.value;
  render();
});

elements.tileSizeInput.addEventListener("input", (event) => {
  document.documentElement.style.setProperty("--tile-min", `${event.target.value}px`);
});

elements.assetGrid.addEventListener("click", (event) => {
  const card = event.target.closest("[data-asset-path]");
  if (card) openDetail(card.dataset.assetPath);
});

elements.detailContent.addEventListener("click", (event) => {
  const related = event.target.closest("[data-related-path]");
  if (related) openDetail(related.dataset.relatedPath);
});

elements.detailClose.addEventListener("click", closeDetail);
elements.drawerScrim.addEventListener("click", closeDetail);
elements.rescanButton.addEventListener("click", rescan);
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") closeDetail();
});

loadIndex().catch((error) => {
  elements.projectPath.textContent = error.message;
  elements.emptyState.classList.remove("is-hidden");
  elements.emptyState.querySelector("strong").textContent = "扫描数据加载失败";
  elements.emptyState.querySelector("span").textContent = error.message;
});
