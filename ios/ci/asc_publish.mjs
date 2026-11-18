// 上架用的寫入動作（片 J2、J4），asc_release.mjs 的 check 看過現況再跑。
// 環境變數 MODE：
//   fill    文字與設定：副標、隱私政策網址、類別、年齡分級、內容版權聲明、版權、描述、關鍵字、
//           支援網址、宣傳文字、審核聯絡資訊與備註、價格（免費）、上架地區（全部）。
//           資料在 asc_listing.json；描述與送審備註直接從 docs/上架文稿.md 的程式碼區塊抽，兩邊同一份。
//   media   傳商品頁截圖（store/6.9/*.jpg，照檔名順序）與送審錄影（store/review.mp4，附在審核資料）。
//           同一格已經有的先換掉。
//   submit  選建置（BUILD_NUMBER，沒給就挑最新一個處理好的）、把內購送審、建一筆送審並送出。
// 跑幾次都一樣：已經有的照 json 更新，不會多建。出錯就停，不跳過。
// 用法（環境變數）：ASC_KEY_ID、ASC_ISSUER_ID、ASC_KEY_P8_PATH、BUNDLE_ID、MODE、
//   REVIEW_CONTACT_JSON（fill 用，GitHub secret，審核聯絡人；repo 公開，不進版控）、BUILD_NUMBER（submit 選用）
import { createHash } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { ascClient, env } from "./asc_api.mjs";

const MODES = ["fill", "media", "submit"];
const MAX = { subtitle: 30, keywords: 100, promotionalText: 170, description: 4000, notes: 4000 };

const mode = env("MODE");
if (!MODES.includes(mode)) {
  throw new Error(`MODE 只能是 ${MODES.join(" 或 ")}，收到 ${mode}`);
}
const bundleId = env("BUNDLE_ID");
const here = (path) => new URL(path, import.meta.url);
const listing = JSON.parse(readFileSync(here("./asc_listing.json"), "utf8"));
const copyDoc = readFileSync(here(listing.descriptionFile), "utf8");
const description = codeBlockStarting(copyDoc, listing.descriptionStart);
const reviewNotes = `${codeBlockStarting(copyDoc, listing.reviewNotesStart)}\n\n${listing.reviewNotesExtra}`;
validateListing();

const call = ascClient();
const apps = await call("GET", `/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`);
const app = apps.data[0];
if (!app) throw new Error(`找不到 bundle id ${bundleId} 的 app`);
console.log(`app：${app.attributes.name}（${app.id}）`);
const version = await editableVersion();
console.log(`版本 ${version.attributes.versionString}（${version.id}）狀態 ${version.attributes.appStoreState}`);

if (mode === "fill") await fill();
if (mode === "media") await media();
if (mode === "submit") await submit();

/// 從文稿裡找開頭是 start 的 ``` 區塊，回傳區塊內文。找不到就停，免得送出空的描述。
function codeBlockStarting(text, start) {
  const blocks = text.split("```");
  for (let index = 1; index < blocks.length; index += 2) {
    const body = blocks[index].replace(/^[^\n]*\n/, "").trim();
    if (body.startsWith(start)) return body;
  }
  throw new Error(`docs/上架文稿.md 裡找不到開頭是「${start}」的程式碼區塊`);
}

function validateListing() {
  const checks = [
    ["副標", listing.subtitle, MAX.subtitle],
    ["關鍵字", listing.keywords, MAX.keywords],
    ["宣傳文字", listing.promotionalText, MAX.promotionalText],
    ["描述", description, MAX.description],
    ["送審備註", reviewNotes, MAX.notes],
  ];
  for (const [label, value, limit] of checks) {
    if (!value || value.length > limit) {
      throw new Error(`${label}是空的或超過 ${limit} 字（現在 ${value?.length ?? 0}）`);
    }
    console.log(`${label} ${value.length}／${limit}`);
  }
  if (/\s/.test(listing.keywords)) throw new Error("關鍵字不能有空白");
}

/// 還能編輯的那個 iOS 版本（準備送審、被退回、開發者退回）。沒有就停。
async function editableVersion() {
  const editable = ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"];
  const list = await call("GET", `/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS&limit=10`);
  const found = list.data.find((item) => editable.includes(item.attributes.appStoreState));
  if (!found) {
    const states = list.data.map((item) => `${item.attributes.versionString} ${item.attributes.appStoreState}`);
    throw new Error(`沒有可以編輯的版本：${states.join("、")}`);
  }
  return found;
}

async function patch(type, id, attributes, relationships) {
  const data = { type, id, attributes };
  if (relationships) data.relationships = relationships;
  return call("PATCH", `/v1/${type}/${id}`, { data });
}

// ---------- fill ----------

async function fill() {
  const contact = JSON.parse(env("REVIEW_CONTACT_JSON"));
  for (const key of ["firstName", "lastName", "email", "phone"]) {
    if (!contact[key]) throw new Error(`REVIEW_CONTACT_JSON 少了 ${key}`);
  }
  await patch("apps", app.id, { contentRightsDeclaration: listing.contentRightsDeclaration });
  console.log("內容版權聲明：沒有用第三方內容");

  const infos = await call("GET", `/v1/apps/${app.id}/appInfos`);
  const info = infos.data.find((item) => item.attributes.state !== "READY_FOR_DISTRIBUTION") ?? infos.data[0];
  await patch("appInfos", info.id, undefined, {
    primaryCategory: { data: { type: "appCategories", id: listing.primaryCategory } },
    secondaryCategory: { data: { type: "appCategories", id: listing.secondaryCategory } },
  });
  console.log(`類別：${listing.primaryCategory}、${listing.secondaryCategory}`);

  const infoLocs = await call("GET", `/v1/appInfos/${info.id}/appInfoLocalizations`);
  const infoLoc = infoLocs.data.find((item) => item.attributes.locale === listing.locale);
  if (!infoLoc) throw new Error(`app 資訊沒有 ${listing.locale} 語系`);
  await patch("appInfoLocalizations", infoLoc.id, {
    subtitle: listing.subtitle,
    privacyPolicyUrl: listing.privacyPolicyUrl,
  });
  console.log("副標、隱私政策網址");

  const age = await call("GET", `/v1/appInfos/${info.id}/ageRatingDeclaration`);
  await patch("ageRatingDeclarations", age.data.id, listing.ageRating);
  const after = await call("GET", `/v1/appInfos/${info.id}/ageRatingDeclaration`);
  const empty = Object.entries(after.data.attributes)
    .filter(([key, value]) => value === null && !["kidsAgeBand", "developerAgeRatingInfoUrl"].includes(key))
    .map(([key]) => key);
  console.log(`年齡分級：填好，還是空的欄位 ${empty.length ? empty.join("、") : "沒有"}`);

  await patch("appStoreVersions", version.id, { copyright: listing.copyright });
  console.log(`版權：${listing.copyright}`);

  const locs = await call("GET", `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`);
  const loc = locs.data.find((item) => item.attributes.locale === listing.locale);
  if (!loc) throw new Error(`版本沒有 ${listing.locale} 語系`);
  await patch("appStoreVersionLocalizations", loc.id, {
    description,
    keywords: listing.keywords,
    supportUrl: listing.supportUrl,
    promotionalText: listing.promotionalText,
  });
  console.log("描述、關鍵字、支援網址、宣傳文字");

  await reviewDetail(contact);
  await freePrice();
  await allTerritories();
}

async function reviewDetail(contact) {
  const attributes = {
    contactFirstName: contact.firstName,
    contactLastName: contact.lastName,
    contactEmail: contact.email,
    contactPhone: contact.phone,
    demoAccountRequired: false,
    notes: reviewNotes,
  };
  const current = await call("GET", `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`).catch(
    (error) => {
      if (error.status === 404) return null;
      throw error;
    },
  );
  if (current?.data) {
    await patch("appStoreReviewDetails", current.data.id, attributes);
  } else {
    await call("POST", "/v1/appStoreReviewDetails", {
      data: {
        type: "appStoreReviewDetails",
        attributes,
        relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: version.id } } },
      },
    });
  }
  console.log("審核聯絡人與備註");
}

/// 免費：台灣的價位找 0 元那個，其他地區 Apple 照基準地區算（也是 0）。
async function freePrice() {
  const points = await call(
    "GET",
    `/v1/apps/${app.id}/appPricePoints?filter[territory]=${listing.baseTerritory}&limit=200`,
  );
  const free = points.data.find((item) => Number(item.attributes.customerPrice) === 0);
  if (!free) throw new Error("找不到 0 元的價位");
  await call("POST", "/v1/appPriceSchedules", {
    data: {
      type: "appPriceSchedules",
      relationships: {
        app: { data: { type: "apps", id: app.id } },
        baseTerritory: { data: { type: "territories", id: listing.baseTerritory } },
        manualPrices: { data: [{ type: "appPrices", id: "${free}" }] },
      },
    },
    included: [
      {
        type: "appPrices",
        id: "${free}",
        attributes: { startDate: null },
        relationships: { appPricePoint: { data: { type: "appPricePoints", id: free.id } } },
      },
    ],
  });
  console.log("價格：免費");
}

/// 上架地區：全部地區，之後 Apple 新開的也自動上。已經設過就不動。
async function allTerritories() {
  const current = await call("GET", `/v1/apps/${app.id}/appAvailabilityV2`).catch((error) => {
    if (error.status === 404) return null;
    throw error;
  });
  if (current?.data) {
    console.log("上架地區已經設過，不動");
    return;
  }
  const territories = await call("GET", "/v1/territories?limit=200");
  const included = territories.data.map((territory, index) => ({
    type: "territoryAvailabilities",
    id: `\${t${index}}`,
    attributes: { available: true },
    relationships: { territory: { data: { type: "territories", id: territory.id } } },
  }));
  await call("POST", "/v2/appAvailabilities", {
    data: {
      type: "appAvailabilities",
      attributes: { availableInNewTerritories: true },
      relationships: {
        app: { data: { type: "apps", id: app.id } },
        territoryAvailabilities: {
          data: included.map((item) => ({ type: item.type, id: item.id })),
        },
      },
    },
    included,
  });
  console.log(`上架地區：全部 ${territories.data.length} 個`);
}

// ---------- media ----------

/// Apple 的上傳三步：登記檔名與大小 → 照給的切片傳上去 → 回報傳完加 MD5。
async function upload(type, attributes, relationships, bytes) {
  const reserved = await call("POST", `/v1/${type}`, {
    data: { type, attributes: { ...attributes, fileSize: bytes.length }, relationships },
  });
  for (const operation of reserved.data.attributes.uploadOperations) {
    const headers = Object.fromEntries(
      (operation.requestHeaders ?? []).map((header) => [header.name, header.value]),
    );
    const slice = bytes.subarray(operation.offset, operation.offset + operation.length);
    const response = await fetch(operation.url, { method: operation.method, headers, body: slice });
    if (!response.ok) throw new Error(`上傳 ${attributes.fileName} 回 ${response.status}`);
  }
  const checksum = createHash("md5").update(bytes).digest("hex");
  await patch(type, reserved.data.id, { uploaded: true, sourceFileChecksum: checksum });
  console.log(`傳好 ${attributes.fileName}（${bytes.length} 位元組）`);
  return reserved.data.id;
}

async function media() {
  const shotDir = here("./store/6.9/");
  const files = readdirSync(shotDir).filter((name) => name.endsWith(".jpg")).sort();
  if (files.length < 3 || files.length > 10) {
    throw new Error(`store/6.9 要有 3 到 10 張 jpg，現在 ${files.length} 張`);
  }
  const video = readFileSync(here("./store/review.mp4"));

  const locs = await call("GET", `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`);
  const loc = locs.data.find((item) => item.attributes.locale === listing.locale);
  const sets = await call("GET", `/v1/appStoreVersionLocalizations/${loc.id}/appScreenshotSets`);
  let set = sets.data.find((item) => item.attributes.screenshotDisplayType === "APP_IPHONE_67");
  if (set) {
    const old = await call("GET", `/v1/appScreenshotSets/${set.id}/appScreenshots`);
    for (const shot of old.data) {
      await call("DELETE", `/v1/appScreenshots/${shot.id}`);
    }
    console.log(`換掉舊截圖 ${old.data.length} 張`);
  } else {
    const created = await call("POST", "/v1/appScreenshotSets", {
      data: {
        type: "appScreenshotSets",
        attributes: { screenshotDisplayType: "APP_IPHONE_67" },
        relationships: {
          appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: loc.id } },
        },
      },
    });
    set = created.data;
  }
  for (const name of files) {
    await upload(
      "appScreenshots",
      { fileName: name },
      { appScreenshotSet: { data: { type: "appScreenshotSets", id: set.id } } },
      readFileSync(new URL(name, shotDir)),
    );
  }

  const detail = await call("GET", `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`);
  const attachments = await call(
    "GET",
    `/v1/appStoreReviewDetails/${detail.data.id}/appStoreReviewAttachments`,
  );
  for (const item of attachments.data) {
    await call("DELETE", `/v1/appStoreReviewAttachments/${item.id}`);
  }
  await upload(
    "appStoreReviewAttachments",
    { fileName: "rencan-review-walkthrough.mp4" },
    { appStoreReviewDetail: { data: { type: "appStoreReviewDetails", id: detail.data.id } } },
    video,
  );
  console.log("截圖與送審錄影傳好了，Apple 處理完才會顯示");
}

// ---------- submit ----------

async function submit() {
  const wanted = process.env.BUILD_NUMBER ?? "";
  const builds = await call(
    "GET",
    `/v1/builds?filter[app]=${app.id}&filter[processingState]=VALID&sort=-uploadedDate&limit=20`,
  );
  const build = wanted
    ? builds.data.find((item) => item.attributes.version === wanted)
    : builds.data[0];
  if (!build) throw new Error(`找不到處理好的建置 ${wanted || "（最新）"}`);
  await patch("appStoreVersions", version.id, undefined, {
    build: { data: { type: "builds", id: build.id } },
  });
  console.log(`建置：${build.attributes.version}（${build.id}）`);

  const iaps = await call("GET", `/v1/apps/${app.id}/inAppPurchasesV2?limit=200`);
  for (const item of iaps.data) {
    if (item.attributes.state !== "READY_TO_SUBMIT") {
      console.log(`內購 ${item.attributes.productId} 狀態 ${item.attributes.state}，不送`);
      continue;
    }
    await call("POST", "/v1/inAppPurchaseSubmissions", {
      data: {
        type: "inAppPurchaseSubmissions",
        relationships: { inAppPurchaseV2: { data: { type: "inAppPurchases", id: item.id } } },
      },
    });
    console.log(`內購 ${item.attributes.productId} 加進送審`);
  }

  const submission = await call("POST", "/v1/reviewSubmissions", {
    data: {
      type: "reviewSubmissions",
      attributes: { platform: "IOS" },
      relationships: { app: { data: { type: "apps", id: app.id } } },
    },
  });
  await call("POST", "/v1/reviewSubmissionItems", {
    data: {
      type: "reviewSubmissionItems",
      relationships: {
        reviewSubmission: { data: { type: "reviewSubmissions", id: submission.data.id } },
        appStoreVersion: { data: { type: "appStoreVersions", id: version.id } },
      },
    },
  });
  await patch("reviewSubmissions", submission.data.id, { submitted: true });
  const after = await call("GET", `/v1/reviewSubmissions/${submission.data.id}`);
  console.log(`送審了：${after.data.attributes.state}`);
}
