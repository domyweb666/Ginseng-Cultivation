// 照 iap_products.json 在 App Store Connect 建內購商品（付費立繪造型，組塊 M）。
// 三種模式，環境變數 MODE：
//   check       只讀：找得到 app、列出已經有的內購與審核截圖、說明 create 會做什麼。不改任何東西。
//   create      沒有的建、有的照 json 更新名稱、審核備註、中文名稱與描述、價格、上架地區。
//   screenshots 傳審核截圖：iap_review_screenshots/{代碼}.png（代碼是產品 ID 最後一段，全套是 all），
//               已經有一張的先刪掉再傳新的。只傳給已經建好的商品，不會建商品。
// 跑幾次都一樣：已經有的產品 ID 不會再建一個（產品 ID 建了不能改、刪了不能再用）。
// 審核截圖由 UI 測試 IAPReviewShotsUITests 在模擬器上拍（組塊 M4），看過再放進 iap_review_screenshots/。
// API 的簽章與呼叫在 asc_api.mjs，零套件。
// 用法（環境變數）：ASC_KEY_ID、ASC_ISSUER_ID、ASC_KEY_P8_PATH、BUNDLE_ID、MODE
import { createHash } from "node:crypto";
import { readFileSync, statSync } from "node:fs";
import { ascClient, env } from "./asc_api.mjs";

const MODES = ["check", "create", "screenshots"];
// Apple 的字數上限
const MAX_DISPLAY_NAME = 30;
const MAX_DESCRIPTION = 45;
const MAX_REVIEW_NOTE = 4000;
const PRODUCT_ID_PATTERN = /^org\.domyweb\.rencan\.style\.[a-z]+$/;
// PNG 檔頭；審核截圖 Apple 收 PNG 或 JPG，這裡只傳 UI 測試拍的 PNG
const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

const mode = env("MODE");
if (!MODES.includes(mode)) {
  throw new Error(`MODE 只能是 ${MODES.join(" 或 ")}，收到 ${mode}`);
}
const bundleId = env("BUNDLE_ID");
const spec = JSON.parse(readFileSync(new URL("./iap_products.json", import.meta.url), "utf8"));
validate(spec);
const screenshotFiles = mode === "screenshots" ? readScreenshots(spec.products) : null;

const call = ascClient();

const apps = await call("GET", `/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`);
const app = apps.data[0];
if (!app) {
  throw new Error(`App Store Connect 找不到 bundle id ${bundleId} 的 app`);
}
console.log(`app：${app.attributes.name}（${app.id}）`);

const existingById = new Map();
const existing = await call("GET", `/v1/apps/${app.id}/inAppPurchasesV2?limit=200`);
for (const item of existing.data) {
  existingById.set(item.attributes.productId, item);
}
console.log(`App Store Connect 上已經有 ${existingById.size} 個內購商品`);
for (const item of existing.data) {
  console.log(`  ${item.attributes.productId}　${item.attributes.name}　狀態 ${item.attributes.state}`);
}

const territories = await call("GET", "/v1/territories?limit=200");
console.log(`上架地區共 ${territories.data.length} 個，基準地區 ${spec.baseTerritory}`);

if (mode === "check") {
  for (const product of spec.products) {
    const found = existingById.get(product.productId);
    const verb = found ? "更新" : "新建";
    console.log(`create 會${verb}：${product.productId}　${product.displayName}　NT$${product.price}`);
    if (found) {
      const shot = await currentScreenshot(found.id);
      console.log(`  審核截圖：${shot ? `有（${shot.attributes.fileName}）` : "還沒有"}`);
    }
  }
  console.log("check 模式到這裡，沒有改任何東西");
  process.exit(0);
}

if (mode === "screenshots") {
  for (const product of spec.products) {
    const found = existingById.get(product.productId);
    if (!found) {
      throw new Error(`${product.productId} 還沒建，先跑 create`);
    }
    console.log(`--- ${product.productId}`);
    await uploadScreenshot(found.id, screenshotFiles.get(product.productId));
  }
  console.log("十二張審核截圖都傳好了");
  process.exit(0);
}

for (const product of spec.products) {
  console.log(`--- ${product.productId}`);
  const iapId = await ensureProduct(product);
  await ensureLocalization(iapId, product);
  await setPrice(iapId, product.price);
  await ensureAvailability(iapId);
}

const after = await call("GET", `/v1/apps/${app.id}/inAppPurchasesV2?limit=200`);
console.log("建完之後 App Store Connect 上的內購：");
for (const item of after.data) {
  console.log(`  ${item.attributes.productId}　${item.attributes.name}　狀態 ${item.attributes.state}`);
}

/// json 先整份驗過才打 API：產品 ID 建錯救不回來，寧可一個都不建。
function validate(data) {
  const ids = new Set();
  if (!data.reviewNote || data.reviewNote.length > MAX_REVIEW_NOTE) {
    throw new Error("reviewNote 是空的或超過 4000 字");
  }
  for (const product of data.products) {
    const where = product.productId ?? "（沒有 productId）";
    if (!PRODUCT_ID_PATTERN.test(product.productId ?? "")) {
      throw new Error(`${where}：產品 ID 格式不對，要是 org.domyweb.rencan.style.小寫英文`);
    }
    if (ids.has(product.productId)) {
      throw new Error(`${where}：產品 ID 重複`);
    }
    ids.add(product.productId);
    if (!product.referenceName || !product.displayName || !product.description) {
      throw new Error(`${where}：參考名稱、顯示名稱、描述不能空`);
    }
    if (product.displayName.length > MAX_DISPLAY_NAME) {
      throw new Error(`${where}：顯示名稱超過 ${MAX_DISPLAY_NAME} 字`);
    }
    if (product.description.length > MAX_DESCRIPTION) {
      throw new Error(`${where}：描述超過 ${MAX_DESCRIPTION} 字`);
    }
    if (!Number.isInteger(product.price) || product.price <= 0) {
      throw new Error(`${where}：價格要是正整數（新台幣）`);
    }
  }
  console.log(`json 驗過：${data.products.length} 個商品`);
}

function reviewNoteFor(product) {
  return product.isBundle ? `${spec.reviewNote} ${spec.bundleReviewNoteExtra}` : spec.reviewNote;
}

/// 沒有就建，有就把參考名稱與審核備註改成 json 的。回傳內購的 id。
async function ensureProduct(product) {
  const found = existingById.get(product.productId);
  const attributes = { name: product.referenceName, reviewNote: reviewNoteFor(product) };
  if (found) {
    await call("PATCH", `/v2/inAppPurchases/${found.id}`, {
      data: { type: "inAppPurchases", id: found.id, attributes },
    });
    console.log("已經有，更新參考名稱與審核備註");
    return found.id;
  }
  const created = await call("POST", "/v2/inAppPurchases", {
    data: {
      type: "inAppPurchases",
      attributes: {
        ...attributes,
        productId: product.productId,
        inAppPurchaseType: "NON_CONSUMABLE",
        familySharable: false,
      },
      relationships: { app: { data: { type: "apps", id: app.id } } },
    },
  });
  console.log(`新建（${created.data.id}）`);
  return created.data.id;
}

async function ensureLocalization(iapId, product) {
  const list = await call("GET", `/v2/inAppPurchases/${iapId}/inAppPurchaseLocalizations`);
  const current = list.data.find((item) => item.attributes.locale === spec.locale);
  const attributes = { name: product.displayName, description: product.description };
  if (current) {
    await call("PATCH", `/v1/inAppPurchaseLocalizations/${current.id}`, {
      data: { type: "inAppPurchaseLocalizations", id: current.id, attributes },
    });
    console.log(`更新 ${spec.locale} 名稱與描述`);
    return;
  }
  await call("POST", "/v1/inAppPurchaseLocalizations", {
    data: {
      type: "inAppPurchaseLocalizations",
      attributes: { ...attributes, locale: spec.locale },
      relationships: { inAppPurchaseV2: { data: { type: "inAppPurchases", id: iapId } } },
    },
  });
  console.log(`寫入 ${spec.locale} 名稱與描述`);
}

/// 照基準地區（台灣）的新台幣價格找 Apple 的價位，設成這個商品現在的價格；其他地區 Apple 自動換算。
/// 找不到一樣的價位就停下來，不挑一個接近的價格亂設。
async function setPrice(iapId, price) {
  const points = await call(
    "GET",
    `/v2/inAppPurchases/${iapId}/pricePoints?filter[territory]=${spec.baseTerritory}&limit=8000`,
  );
  const point = points.data.find((item) => Number(item.attributes.customerPrice) === price);
  if (!point) {
    const near = points.data
      .map((item) => Number(item.attributes.customerPrice))
      .filter((value) => Math.abs(value - price) <= price * 0.3)
      .sort((a, b) => a - b);
    throw new Error(`台灣沒有 NT$${price} 這個價位，附近有：${near.join("、") || "沒有"}`);
  }
  await call("POST", "/v1/inAppPurchasePriceSchedules", {
    data: {
      type: "inAppPurchasePriceSchedules",
      relationships: {
        inAppPurchase: { data: { type: "inAppPurchases", id: iapId } },
        baseTerritory: { data: { type: "territories", id: spec.baseTerritory } },
        manualPrices: { data: [{ type: "inAppPurchasePrices", id: "${price}" }] },
      },
    },
    included: [
      {
        type: "inAppPurchasePrices",
        id: "${price}",
        attributes: { startDate: null },
        relationships: {
          inAppPurchaseV2: { data: { type: "inAppPurchases", id: iapId } },
          inAppPurchasePricePoint: { data: { type: "inAppPurchasePricePoints", id: point.id } },
        },
      },
    ],
  });
  console.log(`價格設成 NT$${price}`);
}

/// 上架地區：全部地區，之後 Apple 新開的地區也自動上。app 本身上架到哪些地區另外在 app 那頁管。
async function ensureAvailability(iapId) {
  try {
    const current = await call("GET", `/v2/inAppPurchases/${iapId}/inAppPurchaseAvailability`);
    if (current?.data) {
      console.log("上架地區已經設過，不動");
      return;
    }
  } catch (error) {
    if (error.status !== 404) throw error;
  }
  await call("POST", "/v1/inAppPurchaseAvailabilities", {
    data: {
      type: "inAppPurchaseAvailabilities",
      attributes: { availableInNewTerritories: true },
      relationships: {
        inAppPurchase: { data: { type: "inAppPurchases", id: iapId } },
        availableTerritories: {
          data: territories.data.map((item) => ({ type: "territories", id: item.id })),
        },
      },
    },
  });
  console.log(`上架地區設成全部 ${territories.data.length} 個`);
}

/// 審核截圖的檔案先全部讀好、檢查過才打 API：少一張或不是 PNG 就一張都不傳。
function readScreenshots(products) {
  const files = new Map();
  for (const product of products) {
    const code = product.productId.split(".").pop();
    const url = new URL(`./iap_review_screenshots/${code}.png`, import.meta.url);
    let bytes;
    try {
      bytes = readFileSync(url);
    } catch (error) {
      throw new Error(`${product.productId}：找不到審核截圖 ${url.pathname}（${error.code}）`);
    }
    if (!bytes.subarray(0, PNG_SIGNATURE.length).equals(PNG_SIGNATURE)) {
      throw new Error(`${product.productId}：${code}.png 不是 PNG`);
    }
    files.set(product.productId, { fileName: `${code}.png`, bytes, size: statSync(url).size });
  }
  console.log(`審核截圖驗過：${files.size} 張`);
  return files;
}

/// 這個商品現在的審核截圖；沒有回 null。
async function currentScreenshot(iapId) {
  try {
    const found = await call("GET", `/v2/inAppPurchases/${iapId}/appStoreReviewScreenshot`);
    return found?.data ?? null;
  } catch (error) {
    if (error.status === 404) return null;
    throw error;
  }
}

/// Apple 的上傳三步：先登記檔名與大小拿到上傳位置、照它給的切片 PUT 上去、再回報傳完加上 MD5。
/// 已經有一張就先換掉（一個商品只能有一張）。
async function uploadScreenshot(iapId, file) {
  const old = await currentScreenshot(iapId);
  if (old) {
    await call("DELETE", `/v1/inAppPurchaseAppStoreReviewScreenshots/${old.id}`);
    console.log(`換掉舊的審核截圖 ${old.attributes.fileName}`);
  }
  const reserved = await call("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {
    data: {
      type: "inAppPurchaseAppStoreReviewScreenshots",
      attributes: { fileName: file.fileName, fileSize: file.size },
      relationships: { inAppPurchaseV2: { data: { type: "inAppPurchases", id: iapId } } },
    },
  });
  for (const operation of reserved.data.attributes.uploadOperations) {
    const headers = Object.fromEntries(
      (operation.requestHeaders ?? []).map((header) => [header.name, header.value]),
    );
    const slice = file.bytes.subarray(operation.offset, operation.offset + operation.length);
    const response = await fetch(operation.url, { method: operation.method, headers, body: slice });
    if (!response.ok) {
      throw new Error(`上傳 ${file.fileName} 的一段回 ${response.status}`);
    }
  }
  const checksum = createHash("md5").update(file.bytes).digest("hex");
  await call("PATCH", `/v1/inAppPurchaseAppStoreReviewScreenshots/${reserved.data.id}`, {
    data: {
      type: "inAppPurchaseAppStoreReviewScreenshots",
      id: reserved.data.id,
      attributes: { uploaded: true, sourceFileChecksum: checksum },
    },
  });
  console.log(`傳好 ${file.fileName}（${file.size} 位元組），Apple 那邊處理完才會顯示`);
}
