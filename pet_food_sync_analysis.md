# Pet Food Sync Rate Analysis (Normal Monsters Only)

## Chapter 1: Starting Forest (Lv 1-15)

| 小怪名 | 等级 | order | 角色经验 | 食物期望经验 | 比率 |
|--------|------|-------|----------|-------------|------|
| spider_trail | 2 | 1 | 24 | 13.0 | 0.542 |
| spider_small | 4 | 1 | 36 | 13.0 | 0.361 |
| boar_small | 7 | 2 | 63 | 18.0 | 0.286 |
| bandit_small | 9 | 3 | 88 | 18.0 | 0.205 |
| bandit_guard | 12 | 3 | 112 | 11.4 | 0.102 |
| bandit_guard_back | 12 | 3 | 112 | 11.4 | 0.102 |

**Chapter 1 Weighted Average Ratio: 0.266**

### Sync Rate Calculation:
- Estimated total char exp from normals: ~50,000 (T0 pet leveling range)
- Total food exp: 50,000 × 0.266 = 13,300
- **T0 Pet (1→20) Sync Rate: 68.6%** (13,300 / 19,400)

---

## Chapter 2: Eastern Swamp (Lv 16-35)

| 小怪名 | 等级 | order | 角色经验 | 食物期望经验 | 比率 |
|--------|------|-------|----------|-------------|------|
| swamp_snake | 18 | 4 | 180 | 8.0 | 0.044 |
| black_boar | 18 | 4 | 180 | 8.0 | 0.044 |
| poison_snake | 23 | 5 | 250 | 8.0 | 0.032 |
| wu_soldier | 28 | 7 | 360 | 8.0 | 0.022 |
| wu_servant | 31 | 7 | 396 | 8.0 | 0.020 |

**Chapter 2 Weighted Average Ratio: 0.032**

### Sync Rate Calculation:
- Estimated total char exp from normals: ~400,000 (T1 pet leveling range)
- Total food exp: 400,000 × 0.032 = 12,800
- **T1 Pet (21→40) Sync Rate: 7.7%** (12,800 / 165,600)

---

## Chapter 3: Western Desert (Lv 36-65)

| 小怪名 | 等级 | order | 角色经验 | 食物期望经验 | 比率 |
|--------|------|-------|----------|-------------|------|
| sand_scorpion_8 | 34 | 7 | 432 | 7.5 | 0.017 |
| sand_wolf_7 | 38 | 8 | 520 | 12.0 | 0.023 |
| sand_demon_6 | 42 | 9 | 616 | 12.0 | 0.019 |
| sand_scorpion_5 | 46 | 10 | 720 | 12.0 | 0.017 |
| sand_wolf_4 | 50 | 10 | 780 | 13.5 | 0.017 |
| sand_demon_3 | 54 | 11 | 896 | 18.0 | 0.020 |
| sand_demon_2 | 58 | 11 | 974 | 16.5 | 0.017 |

**Chapter 3 Weighted Average Ratio: 0.019**

### Sync Rate Calculation:
- Estimated total char exp from normals: ~3,000,000 (T2 pet leveling range)
- Total food exp: 3,000,000 × 0.019 = 57,000
- **T2 Pet (41→60) Sync Rate: 5.4%** (57,000 / 1,047,000)

---

## Chapter 4: Northern Mountains (Lv 66-100)

| 小怪名 | 等级 | order | 角色经验 | 食物期望经验 | 比率 |
|--------|------|-------|----------|-------------|------|
| kan_disciple | 68 | 12 | 1,477 | 0 | 0 |
| gen_disciple | 72 | 13 | 1,852 | 0 | 0 |
| zhen_disciple | 78 | 14 | 2,525 | 0 | 0 |
| xun_disciple | 82 | 15 | 3,138 | 0 | 0 |
| li_disciple | 88 | 16 | 4,176 | 0 | 0 |
| kun_disciple | 92 | 17 | 5,079 | 0 | 0 |
| dui_disciple | 95 | 17 | 5,654 | 0 | 0 |

**Chapter 4 Status: NO FOOD DROPS (0% sync rate)**

### Required Ratio for Sync:
- Average char exp per normal: ~3,414
- Estimated total char exp from normals: ~100,000,000 (T3+T4 leveling)
- To achieve 50% sync for T3+T4 pets (54,210,000 needed):
  - Need total food exp: 27,105,000
  - **Required ratio: 0.271** (27,105,000 / 100,000,000)
  - Each normal needs to drop ~925 food exp value

### Suggested Food Drops for Chapter 4:
To achieve 0.271 ratio with reasonable drop rates:
- **Option 1**: immortal_bone (300) at 30% + demon_essence (800) at 20% = 250 avg
- **Option 2**: demon_essence (800) at 50% + dragon_marrow (3000) at 5% = 550 avg
- **Option 3**: demon_essence (800) at 100% + dragon_marrow (3000) at 4% = 920 avg ✓

---

## Summary

| Chapter | Pet Tier | Sync Rate | Status |
|---------|----------|-----------|---------|
| Ch1 | T0 (1→20) | **68.6%** | Good sync, nearly sufficient |
| Ch2 | T1 (21→40) | **7.7%** | Very poor sync |
| Ch3 | T2 (41→60) | **5.4%** | Very poor sync |
| Ch4 | T3+T4 (61→100) | **0%** | No food drops at all |

## Key Findings:

1. **Chapter 1** has decent sync (~69%) for T0 pets due to high meat_bone drop rates
2. **Chapters 2-3** have terrible sync (<8%) - spirit_meat and beast_meat drops are too rare
3. **Chapter 4** urgently needs food drops - suggest demon_essence at high rates + some dragon_marrow

## Recommendations:

1. **Chapter 2**: Increase spirit_meat drop rates to 30-40% on normals
2. **Chapter 3**: Increase beast_meat to 20-25%, immortal_bone to 5-10%
3. **Chapter 4**: Add demon_essence at 80-100% + dragon_marrow at 3-5%