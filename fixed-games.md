# Playport 分支：遊戲修正紀錄

分支 `steam-api-choice-in-release`，整理日期 2026-11-08。
每項列出症狀、原因、修法，以及對應的決策紀錄（`docs/decisions/`）、patch 和 commit。
「狀態」是最後一次在手機上測試的結果。

---

## 一覽

| 遊戲 | Steam App ID | 狀態 | 相關決策 |
| --- | --- | --- | --- |
| CHRONO TRIGGER | 613830 | 可玩 | 0183、0184、0186、0187 |
| Resident Evil HD REMASTER | 304240 | 可玩，MOD 正常（日文語音，2026-11-08 確認） | 0188、0189、0200 |
| Guilty Gear XX Accent Core Plus R | 348550 | 可玩，存檔正常 | 0190、0192 |
| Mega Man 11 | 742300 | 可玩，存檔正常 | 0192 |
| Mega Man Legacy Collection 2 | 495050 | 可玩 | 0193、0194、0196 |
| DRAGON QUEST VII Reimagined Demo | 2499870 | 可玩，聲音正常（2026-11-08 確認） | 0197、0198、0199 |
| GUILTY GEAR Xrd REV 2 | 520440 | 放棄（模擬器層級當機） | 0185 |
| Shining Resonance Refrain | 809890 | 放棄 | 0191 |
| Resident Evil（原版） | 4249100 | 放棄（加殼的 Steam 檢查） | 0195 |
| ONE、Persona 3 Reload | — | 放棄 | — |

---

## CHRONO TRIGGER（613830）

**1. 開始遊戲兩秒後跳出「SteamController()->Init failed」並結束**
- 原因：Playport 的 Steam 客戶端對沒實作的介面一律回答 0，所以 Steam Input 的 `Init` 回答「失敗」。真正的 Steam 不管有沒有接控制器都回答成功。
- 修法：`Init` 回答成功。
- 決策 0183，commit `2c0ad95d`。

**2. 只能用鍵盤，手把沒反應**
- 原因：遊戲是透過 winmm 的舊式搖桿 API（`joyGetPosEx`）讀手把，而 Wine 的 winmm 經由 DirectInput 找搖桿，在這個環境裡什麼都找不到。
- 修法：winmm 的搖桿 API 直接讀 iOS 接上的手把。
- 決策 0184，commit `1414b833`。

**3. 無法切換成其他語言**
- 原因：Steam 客戶端和模擬器都固定告訴遊戲語言是 `english`。
- 修法：遊戲頁面新增語言選項，Steam API 照玩家的選擇回答。
- 決策 0186，commit `aab40c1e`。

**4. 繁體中文的每個字都顯示成方框**
- 原因：執行環境只附 Tahoma 和 Marlett。遊戲指名要的「Microsoft JhengHei」等 Windows 字型，以及預設的字型連結檔（`MINGLIU.TTC` 等）都不存在。
- 修法：用手機內建的中日韓字型代替 Windows 的字型。
- 決策 0187，commit `36722a99`、`1caa410b`、`2c74510a`。

---

## Resident Evil HD REMASTER（304240）

**1. 第一個畫面出現一秒後當機**
- 原因：這是 32 位元遊戲。Playport 的 WoW64 位址視窗裡，遊戲看到的位址跟主機上的實際位址不同；`ReadFileEx` 完成時，回呼收到的是被截成 32 位元的主機位址，指向無效記憶體。
- 修法：把 APC 裡的位址換回遊戲自己的位址。
- 決策 0188，commit `0311948c`。

**2. Capcom 標誌之後就黑畫面**
- 原因：32 位元遊戲的 winegstreamer（影片和壓縮音訊解碼）呼叫全部被送到空的呼叫表，所以無法播放任何影片。
- 修法：32 位元遊戲也能使用 winegstreamer 的呼叫表，並註冊 asf 解碼器以播放 WMV 影片。
- 決策 0189，commit `3ad65b9f`、`7f1619f8`。

**3. 裝 MOD 後啟動時跳出「Fatal error.」**
- 原因：MOD 是從 Mac 複製進來的。Finder 和「檔案」App 遇到同名資料夾會整個取代，不會合併，所以遊戲原本的 `nativePC/arcPC/id/` 被刪掉，啟動時找不到 `common.arc`（錯誤碼 3：找不到路徑）。另外有一個沒複製完的 0 B `.sngw`。
- 修法：遊戲頁面新增「Install a mod」和「Remove mods」。MOD 用合併的方式裝進遊戲資料夾，會自動判斷放置位置、略過 Mac 的垃圾檔和 0 B 壞檔；被取代的原檔會備份，可以還原。先用「Check game files」和「Repair from Steam」補回缺的檔案，再用新功能安裝 MOD。
- 結果：MOD 正常生效，語音變成日文。
- 決策 0200，commit `24fb22aa`。

**備註**：先前的「約 216 秒後當機」可能是早期 MOD 造成的，依使用者判斷不再追查。

---

## Guilty Gear XX Accent Core Plus R（348550）

**1. 無法存檔**
- 原因：遊戲把「我的文件」轉成路徑時，Wine 缺少 `WantsFORPARSING` 這個登錄值，得到的是虛擬路徑 `::{450d8fba-…}`，所以存檔失敗。
- 修法：讓「我的文件」的 shell 項目解析成實際資料夾。
- 決策 0190，commit `9470d235`。

**2. 透過 Steam API 存的資料檔讀不到也寫不了**
- 見下方「共通修正：Steam 雲端存檔 API」（決策 0192）。

---

## Mega Man 11（742300）

**存檔無法讀取也無法建立**
- 原因：預設模式（Playport 的 Steam 客戶端）沒有實作 `ISteamRemoteStorage`，`FileExists` 和 `FileWrite` 都回答失敗，以前只能手動切到模擬器模式。
- 修法：Playport 的 Steam 客戶端實作了 `ISteamRemoteStorage`。
- 決策 0192，commit `0d274c0d`。

---

## Mega Man Legacy Collection 2（495050）

**1. 啟動後立刻顯示「Steam user must be logged in」並結束**
- 原因：Playport 在背景時（例如匯出報告、切換 App），iOS 會關掉它跟 Steam 伺服器的連線。下一次按 Play 時，客戶端就告訴遊戲「沒有登入」。
- 修法：啟動時如果發現連線已斷，先重新登入。
- 決策 0193，commit `ff768d18`、`7106a56b`。

**2. 操作說明畫面之後因除以零當機**
- 原因：遊戲的字型貼圖是用 `D3DX11CreateShaderResourceViewFromMemory` 載入的，但 Wine 的這個函式只是個空殼，貼圖寬度變成 0。另外這些字型都是 BC7 格式的 DX10 DDS，d3dx 原本不認得這個格式。
- 修法：實作這個函式，並讓 d3dx 支援 BC7，包括 DX10 標頭那條路徑。
- 決策 0194，commit `5f0268b3`、`f7d370f1`、`4ad32c67`、`348eb829`（另有診斷 commit `9bae9939`）。

**3. 連按兩下 Play，遊戲 0 秒就結束**
- 原因：第二次 Play 把第一次的登入憑證換掉了，等遊戲真正啟動時，連線已經關閉。
- 修法：上一次 Play 還在準備時，拒絕新的 Play。
- 決策 0196，commit `3cb9230c`。

**其他**
- 語音和介面一直是英文：是存檔覆蓋了語言設定，從遊戲內的語言選項就能改，不是 bug。
- 這款遊戲沒有 Steam 雲端存檔，要備份的話，用「檔案」App 手動複製 `prefix/drive_c/users/playport/AppData/Roaming/MegaMan2/`。

---

## DRAGON QUEST VII Reimagined Demo（2499870）

**1. 預設模式 loading 後一直黑畫面**
- 原因：遊戲會呼叫 `RequestCurrentStats`，然後等待 `UserStatsReceived_t` 回呼，但 Playport 的 Steam 客戶端不回應，模擬器模式則會回應。
- 修法：客戶端回應這個請求並送出回呼。
- 決策 0197，commit `34c4d691`。

**2. 模擬器模式完全沒有聲音**
- 原因：遊戲輸出 12 聲道（7.1.4）的聲音，iOS 音訊驅動原本只播前兩個聲道。
- 修法：多聲道依聲道遮罩混成立體聲。
- 決策 0198，commit `34c4d691`（另有 `c83ae3bf`）。

**3. 兩種模式都持續爆音**
- 原因：遊戲用的是 Windows 空間音效 API（ISpatialAudioClient）。Wine 是把每個聲音物件「累加」進驅動給的緩衝區，卻沒有先清空。iOS 驅動每次都交回同一塊緩衝區，上一輪的聲音還在裡面，於是一輪疊一輪，聲音越來越大，最後變成噪音。
- 修法：Wine 每輪混音前先把緩衝區清成靜音（wine-pe patch 0071）。
- 排查過但無關：改用 AVX 以外的指令（已證實無效並撤回）；把多聲道混音音量調低（已撤回）。
- 決策 0199，commit `11209be8`。

**4. 聲音持續斷斷續續（開場動畫就開始）**
- 原因：驅動每次用 `usleep(10000)` 睡 10 毫秒再叫醒遊戲補聲音，但在手機上實際約 11 毫秒，每 10 秒只叫醒約 910 次，正常應為 1000 次。空間音效每次被叫醒只交一個週期的資料，所以聲音只有 9 成。
- 修法：計時器改成照時鐘的絕對時間點叫醒（madeira-unix patch 0294）。修正後實測每 10 秒正好 1000 次。
- 決策 0199，commit `2864b083`（另有診斷 commit `b59c6f0d`）。

**5. 三指開關選單後聲音幾乎消失**
- 原因：選單暫停讓遊戲以為音訊裝置中斷了，回來後對還在播放的串流呼叫 Reset。照規則應該拒絕，但 iOS 驅動直接把串流停掉，遊戲卻以為它還在播，結果只剩約 10% 的聲音。
- 修法：Reset 照 WASAPI 規則，對播放中的串流回答 `AUDCLNT_E_NOT_STOPPED`（madeira-unix patch 0295）。
- 決策 0199，commit `710bb88f`。2026-11-08 手機測試確認：開關選單七次，聲音都正常。

**其他**
- 耗電和部分卡頓是效能本身（x86 轉譯、D3D11→Vulkan→Metal 兩層轉換、UE4 本身就重）：手機熱的時候 iOS 會降頻，遊戲用到約 5 GB 記憶體，而且模擬器第一次跑時要轉譯大量程式碼。

---

## 放棄的遊戲

**GUILTY GEAR Xrd REV 2（520440）**
- 視窗出現約一秒後當機（`0xC00000BB`），換任何繪圖後端或 Steam 模式都一樣。每次當機前都在同一個位址出現 FEX 的 call-return 堆疊下溢，判斷是模擬器層級的問題。
- 為了排查，release 版開放了 x86 模擬器的選項（決策 0185，commit `eb89f5d8`），但沒有找到能繞過的設定。

**Shining Resonance Refrain（809890）**
- 每次啟動都立刻結束（`0xC0000018`）。原因是它的 200 MiB 執行檔沒有重定位資訊，只能載入在固定位址，而這個位址被 JIT 記憶體池佔走了。
- 已修正讓這類執行檔保有固定位址（決策 0191，commit `191b2d02`），但之後還有其他問題，所以放棄。

**Resident Evil 原版（4249100）**
- 顯示「Application load error 3:0000065432」並結束。執行檔用 Enigma Protector 加殼，Steam 檢查藏在殼裡，無法分析。
- 為了排查，加了 Steam 客戶端第一次呼叫的紀錄（決策 0195，commit `23b4b519`），但沒能找出它要的東西。

**ONE、Persona 3 Reload**
- 已放棄，沒有對應的修正。

---

## 共通修正（所有遊戲都受益）

| 決策 | 內容 | commit |
| --- | --- | --- |
| 0180 | 遊戲的資料夾可以在「檔案」App 裡開啟 | `a58d5268` |
| 0181 | 下載會在背景繼續 | `2147b279` |
| 0182 | 遊戲結束碼和打不開的檔案，用文字寫進 log | `5deda958` |
| 0185 | release 版也能調整 x86 模擬器選項 | `eb89f5d8` |
| 0186 | 每款遊戲可以選 Steam 語言 | `aab40c1e` |
| 0187 | 用手機的中日韓字型代替 Windows 字型 | `36722a99` 等 |
| 0189 | 32 位元遊戲可以解碼影片和音訊 | `3ad65b9f` |
| 0192 | 預設模式支援 Steam 雲端存檔 API | `0d274c0d` |
| 0193 | 連線被 iOS 中斷後，啟動時自動重新登入 | `ff768d18` |
| 0194 | d3dx11 能從記憶體建立貼圖並支援 BC7 | `5f0268b3` 等 |
| 0196 | 防止連按 Play | `3cb9230c` |
| 0197 | Steam 客戶端回應成就和統計請求 | `34c4d691` |
| 0198 | 多聲道聲音混成立體聲 | `34c4d691` |
| 0199 | 修正空間音效累加、計時器漂移和 Reset 規則 | `11209be8`、`2864b083`、`710bb88f` |
| 0200 | 遊戲頁面可以用合併方式安裝 MOD，並能移除還原 | `24fb22aa` |

---

## 尚未處理

- FINAL FANTASY RESONANCE DEMO（4474710）：啟動 2 秒後結束（`exit=0x2329`），還沒調查。
- GUILTY GEAR -STRIVE-：有 3 個雲端存檔衝突（SYSTEM.sav、SYSTEM2.sav、REPLAY.sav），下次按 Play 時要在介面裡選擇保留哪邊。
- 上游 issue 草稿（`.work/reports/issue-new-findings.md`）還沒補上決策 0190 以後的發現。
